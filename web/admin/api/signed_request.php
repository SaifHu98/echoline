<?php
/**
 * SignedRequest — HMAC verification for server-to-server API
 * ===========================================================
 * Used for:
 *  - Game Server → Admin (config refresh, receipt verification result)
 *  - Webhook handlers (Google Play RTDN, Stripe, etc.)
 *
 * Required headers:
 *   X-ECHO-Timestamp: unix epoch seconds
 *   X-ECHO-Nonce: 32-char hex (single-use within 10 min)
 *   X-ECHO-Signature: hex HMAC-SHA256 of canonical request
 *
 * Canonical string:
 *   <METHOD>\n<PATH>\n<TIMESTAMP>\n<NONCE>\n<SHA256(BODY)>
 */

final class SignedRequest
{
    public static function verify(string $method, string $path, string $rawBody, ?string $secret = null): array
    {
        $headers = self::collectHeaders();
        $ts = $headers['echo-timestamp'] ?? null;
        $nonce = $headers['echo-nonce'] ?? null;
        $sig = $headers['echo-signature'] ?? null;

        if (!$ts || !$nonce || !$sig) {
            Security::audit('signed_request_missing_headers', ['path' => $path]);
            return ['ok' => false, 'code' => 'MISSING_HEADERS', 'message' => 'Missing signature headers'];
        }

        // 1) Timestamp window (±5 min)
        $tsInt = (int)$ts;
        if (abs(time() - $tsInt) > Security::REPLAY_WINDOW_SEC) {
            Security::audit('signed_request_timestamp_expired', ['ts' => $ts, 'path' => $path]);
            return ['ok' => false, 'code' => 'TIMESTAMP_EXPIRED', 'message' => 'Timestamp outside ±5min window'];
        }

        // 2) Nonce uniqueness
        if (!Security::nonceSeen($nonce)) {
            Security::audit('signed_request_nonce_replay', ['nonce_prefix' => substr($nonce, 0, 8), 'path' => $path]);
            return ['ok' => false, 'code' => 'NONCE_REPLAYED', 'message' => 'Nonce already used'];
        }

        // 3) Signature
        $bodyHash = hash('sha256', $rawBody);
        $canonical = strtoupper($method) . "\n" . $path . "\n" . $ts . "\n" . $nonce . "\n" . $bodyHash;
        $expected = hash_hmac('sha256', $canonical, $secret ?? API_SHARED_SECRET);
        if (!hash_equals($expected, $sig)) {
            Security::audit('signed_request_bad_signature', ['path' => $path, 'method' => $method]);
            return ['ok' => false, 'code' => 'BAD_SIGNATURE', 'message' => 'HMAC signature mismatch'];
        }

        return ['ok' => true, 'timestamp' => $tsInt, 'nonce' => $nonce];
    }

    public static function sign(string $method, string $path, string $rawBody, ?string $secret = null): array
    {
        $ts = (string)time();
        $nonce = Security::generateNonce();
        $bodyHash = hash('sha256', $rawBody);
        $canonical = strtoupper($method) . "\n" . $path . "\n" . $ts . "\n" . $nonce . "\n" . $bodyHash;
        $sig = hash_hmac('sha256', $canonical, $secret ?? API_SHARED_SECRET);
        return [
            'X-ECHO-Timestamp' => $ts,
            'X-ECHO-Nonce'      => $nonce,
            'X-ECHO-Signature'  => $sig,
        ];
    }

    private static function collectHeaders(): array
    {
        $out = [];
        foreach ($_SERVER as $k => $v) {
            if (strpos($k, 'HTTP_') === 0) {
                $name = strtolower(str_replace('_', '-', substr($k, 5)));
                $out[$name] = $v;
            }
        }
        return $out;
    }
}