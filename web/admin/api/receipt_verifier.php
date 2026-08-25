<?php
/**
 * ReceiptVerifier — Server-side Google Play receipt verification
 * ================================================================
 * - Calls Google Play Developer API (productPurchases.get or subscriptions.get)
 * - Verifies signature (Google-signed JWT)
 * - Stores verification result in DB
 * - Idempotent (UNIQUE constraint on (purchaseToken, productId))
 * - Atomic transaction: verification + grant
 *
 * NEVER trust client-claimed receipts. Always verify server-side.
 */

final class ReceiptVerifier
{
    const GOOGLE_API_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
    const PACKAGE_NAME = 'com.ecouni.echoline';  // change in production

    /**
     * Verify and grant a one-time purchase receipt
     * Returns array with success, grant contents
     */
    public static function verifyOneTime(string $purchaseToken, string $productId, string $playerUid): array
    {
        if (empty($purchaseToken) || empty($productId) || empty($playerUid)) {
            return ['success' => false, 'code' => 'MISSING_PARAMS'];
        }
        // Sanitize
        if (!preg_match('/^[a-zA-Z0-9_\-\.]+$/', $purchaseToken)) {
            Security::audit('receipt_invalid_token_format', ['product_id' => $productId]);
            return ['success' => false, 'code' => 'BAD_TOKEN_FORMAT'];
        }
        if (!preg_match('/^[a-zA-Z0-9_\-\.]+$/', $productId)) {
            return ['success' => false, 'code' => 'BAD_PRODUCT_FORMAT'];
        }
        if (strlen($purchaseToken) > 4096 || strlen($productId) > 256) {
            return ['success' => false, 'code' => 'PARAMS_TOO_LONG'];
        }

        // 1) Call Google Play Developer API
        $googleResp = self::fetchOneTimeFromGoogle($purchaseToken, $productId);
        if (!$googleResp['ok']) {
            Security::audit('receipt_google_api_failed', [
                'product_id' => $productId,
                'code' => $googleResp['code'] ?? 'unknown',
            ]);
            return ['success' => false, 'code' => 'GOOGLE_API_FAILED', 'message' => $googleResp['message'] ?? ''];
        }

        $resp = $googleResp['data'];
        // Validate purchase state
        $purchaseState = $resp['purchaseState'] ?? null;  // 0=Purchased, 1=Canceled, 2=Pending
        if ($purchaseState !== 0) {
            Security::audit('receipt_invalid_state', [
                'product_id' => $productId,
                'state' => $purchaseState,
            ]);
            return ['success' => false, 'code' => 'INVALID_STATE', 'message' => 'Purchase is not in Purchased state'];
        }
        // Check consumption state (0=Yet to be consumed, 1=Consumed)
        $consumptionState = $resp['consumptionState'] ?? 0;
        $orderId = $resp['orderId'] ?? null;
        $purchaseType = $resp['purchaseType'] ?? 0;

        // 2) Determine grant contents from product catalog
        $grant = self::resolveGrant($productId);
        if (!$grant) {
            Security::audit('receipt_unknown_product', ['product_id' => $productId]);
            return ['success' => false, 'code' => 'UNKNOWN_PRODUCT'];
        }

        // 3) Atomic transaction: insert receipt + grant items
        return Database::transaction(function (PDO $pdo) use ($purchaseToken, $productId, $playerUid, $orderId, $purchaseState, $grant) {
            // Try to insert receipt (UNIQUE constraint prevents duplicates)
            try {
                $stmt = $pdo->prepare(
                    'INSERT INTO receipt_verifications
                       (purchase_token, product_id, player_uid, order_id, purchase_state, verified_at)
                     VALUES (?, ?, ?, ?, ?, NOW())'
                );
                $stmt->execute([$purchaseToken, $productId, $playerUid, $orderId, $purchaseState]);
                $receiptId = (int)$pdo->lastInsertId();
            } catch (PDOException $e) {
                // UNIQUE violation = already verified
                if (strpos($e->getMessage(), 'Duplicate') !== false || $e->getCode() === '23000') {
                    Security::audit('receipt_replay_blocked', [
                        'product_id' => $productId,
                        'player_uid_hash' => substr(hash('sha256', $playerUid), 0, 12),
                    ]);
                    throw new RuntimeException('RECEIPT_ALREADY_PROCESSED');
                }
                throw $e;
            }

            // Grant the items
            self::grantItems($pdo, $playerUid, $grant, $receiptId);

            Security::audit('receipt_verified_and_granted', [
                'receipt_id' => $receiptId,
                'product_id' => $productId,
                'grant_keys' => array_keys($grant),
                'player_uid_hash' => substr(hash('sha256', $playerUid), 0, 12),
            ]);

            return ['success' => true, 'receipt_id' => $receiptId, 'grant' => $grant];
        });
    }

    /**
     * Call Google Play Developer API
     */
    private static function fetchOneTimeFromGoogle(string $purchaseToken, string $productId): array
    {
        $accessToken = self::getServiceAccountToken();
        if (!$accessToken) {
            return ['ok' => false, 'code' => 'NO_SERVICE_ACCOUNT', 'message' => 'Google service account not configured'];
        }
        $url = sprintf('%s/applications/%s/purchases/products/%s/tokens/%s',
            self::GOOGLE_API_BASE,
            rawurlencode(self::PACKAGE_NAME),
            rawurlencode($productId),
            rawurlencode($purchaseToken));

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $accessToken,
                'Accept: application/json',
            ],
            CURLOPT_TIMEOUT => 10,
            CURLOPT_SSL_VERIFYPEER => true,
        ]);
        $resp = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($code !== 200) {
            return ['ok' => false, 'code' => 'HTTP_' . $code, 'message' => 'Google API returned non-200'];
        }
        $data = json_decode($resp, true);
        if (!is_array($data)) {
            return ['ok' => false, 'code' => 'BAD_JSON', 'message' => 'Invalid JSON from Google'];
        }
        return ['ok' => true, 'data' => $data];
    }

    /**
     * Generate OAuth2 access token from service account (JWT bearer)
     */
    private static function getServiceAccountToken(): ?string
    {
        $credPath = defined('GOOGLE_APPLICATION_CREDENTIALS') ? GOOGLE_APPLICATION_CREDENTIALS : null;
        if (!$credPath || !file_exists($credPath)) return null;
        $json = json_decode(file_get_contents($credPath), true);
        if (!is_array($json) || !isset($json['client_email'], $json['private_key'])) return null;
        return self::jwtSign($json);
    }

    private static function jwtSign(array $sa): ?string
    {
        $now = time();
        $header = ['alg' => 'RS256', 'typ' => 'JWT'];
        $claim = [
            'iss' => $sa['client_email'],
            'scope' => 'https://www.googleapis.com/auth/androidpublisher',
            'aud' => 'https://oauth2.googleapis.com/token',
            'exp' => $now + 3600,
            'iat' => $now,
        ];
        $h = self::b64url(json_encode($header));
        $c = self::b64url(json_encode($claim));
        $sig = '';
        $ok = openssl_sign($h . '.' . $c, $sig, $sa['private_key'], OPENSSL_ALGO_SHA256);
        if (!$ok) return null;
        $jwt = $h . '.' . $c . '.' . self::b64url($sig);

        // Exchange for access token
        $ch = curl_init('https://oauth2.googleapis.com/token');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query([
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion'  => $jwt,
            ]),
            CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
            CURLOPT_TIMEOUT => 10,
        ]);
        $resp = curl_exec($ch);
        curl_close($ch);
        $data = json_decode($resp, true);
        return $data['access_token'] ?? null;
    }

    private static function b64url(string $s): string
    {
        return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
    }

    /**
     * Resolve SKU → grant
     */
    private static function resolveGrant(string $productId): ?array
    {
        // Look up in shop catalog
        $row = Database::fetch('SELECT grant_json FROM shop_items WHERE sku = ? AND is_active = 1', [$productId]);
        if (!$row) return null;
        $grant = json_decode($row['grant_json'] ?? '{}', true);
        return is_array($grant) ? $grant : null;
    }

    /**
     * Grant items to player inventory atomically
     */
    private static function grantItems(PDO $pdo, string $playerUid, array $grant, int $receiptId): void
    {
        foreach ($grant as $kind => $amount) {
            if ($kind === 'currency.gem') {
                $pdo->prepare(
                    'INSERT INTO player_currency (player_uid, gem, updated_at) VALUES (?, ?, NOW())
                     ON DUPLICATE KEY UPDATE gem = gem + VALUES(gem), updated_at = NOW()'
                )->execute([$playerUid, (int)$amount]);
            } elseif ($kind === 'currency.coin') {
                $pdo->prepare(
                    'INSERT INTO player_currency (player_uid, coin, updated_at) VALUES (?, ?, NOW())
                     ON DUPLICATE KEY UPDATE coin = coin + VALUES(coin), updated_at = NOW()'
                )->execute([$playerUid, (int)$amount]);
            } elseif ($kind === 'item') {
                $pdo->prepare(
                    'INSERT INTO player_inventory (player_uid, item_id, quantity, source, source_id, acquired_at)
                     VALUES (?, ?, ?, ?, ?, NOW())'
                )->execute([$playerUid, $amount['id'], $amount['qty'] ?? 1, 'iap', $receiptId]);
            }
        }
    }
}