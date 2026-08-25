<?php
/**
 * Security — Hardened central security utilities for Admin Panel
 * ===============================================================
 * - Session with secure cookies + IP binding
 * - CSRF tokens (per-action, rotated)
 * - password_hash / password_verify (bcrypt cost 12)
 * - Path traversal protection (basename + allowlist)
 * - HMAC signing for API requests
 * - Install lockout
 * - Rate limiter (file-based)
 * - Generic sanitization (XSS-safe)
 */

final class Security
{
    const CSRF_TOKEN_BYTES = 32;
    const SESSION_BITS = 256;
    const PASSWORD_MIN_LENGTH = 12;
    const HMAC_ALG = 'sha256';
    const REPLAY_WINDOW_SEC = 300;  // ±5 min
    const NONCE_TTL_SEC = 600;       // 10 min

    /** @var string|null cached install lock path */
    private static ?string $installLockPath = null;

    // ====================================================================
    // Session
    // ====================================================================

    public static function startSession(): void
    {
        if (session_status() === PHP_SESSION_ACTIVE) return;

        $secure = (APP_ENV === 'production');
        $params = [
            'lifetime' => SESSION_LIFETIME,
            'path'     => '/',
            'secure'   => $secure,
            'httponly' => true,
            'samesite' => 'Lax',
        ];
        if (defined('SESSION_COOKIE_DOMAIN') && SESSION_COOKIE_DOMAIN) {
            $params['domain'] = SESSION_COOKIE_DOMAIN;
        }

        session_name(SESSION_NAME);
        session_set_cookie_params($params);

        // Strict session mode (rejects uninitialized session ids)
        ini_set('session.use_strict_mode', '1');
        ini_set('session.cookie_httponly', '1');
        ini_set('session.cookie_samesite', 'Lax');
        if ($secure) ini_set('session.cookie_secure', '1');

        session_start();

        // Idle timeout
        if (isset($_SESSION['last_activity_ts'])) {
            if (time() - (int)$_SESSION['last_activity_ts'] > SESSION_IDLE_TIMEOUT) {
                self::destroySession();
                session_start();
            }
        }
        $_SESSION['last_activity_ts'] = time();

        // Absolute timeout
        if (isset($_SESSION['started_ts']) && (time() - (int)$_SESSION['started_ts']) > SESSION_ABSOLUTE_TIMEOUT) {
            self::destroySession();
            session_start();
        }
        if (!isset($_SESSION['started_ts'])) {
            $_SESSION['started_ts'] = time();
        }

        // IP binding (warn but don't logout on mismatch)
        $currentIp = self::clientIp();
        if (isset($_SESSION['bound_ip_hash']) && $_SESSION['bound_ip_hash'] !== hash('sha256', $currentIp . (defined('SESSION_IP_SALT') ? SESSION_IP_SALT : ''))) {
            self::audit('session_ip_changed', ['old_hash' => substr($_SESSION['bound_ip_hash'], 0, 8), 'new_hash' => substr(hash('sha256', $currentIp), 0, 8)]);
            // Soft re-bind
        }
        $_SESSION['bound_ip_hash'] = hash('sha256', $currentIp . (defined('SESSION_IP_SALT') ? SESSION_IP_SALT : ''));
    }

    public static function destroySession(): void
    {
        if (session_status() === PHP_SESSION_ACTIVE) {
            $_SESSION = [];
            if (ini_get('session.use_cookies')) {
                $params = session_get_cookie_params();
                setcookie(session_name(), '', time() - 42000,
                    $params['path'], $params['domain'] ?? '', $params['secure'], $params['httponly']);
            }
            session_destroy();
        }
    }

    /**
     * Regenerate session ID — call on login or privilege change
     */
    public static function rotateSessionId(): void
    {
        if (session_status() === PHP_SESSION_ACTIVE) {
            session_regenerate_id(true);
        }
    }

    // ====================================================================
    // CSRF
    // ====================================================================

    public static function csrfToken(string $action = 'default'): string
    {
        self::startSession();
        $sessionKey = CSRF_TOKEN_NAME . '_' . $action;
        if (empty($_SESSION[$sessionKey])) {
            $_SESSION[$sessionKey] = bin2hex(random_bytes(self::CSRF_TOKEN_BYTES));
        }
        return $_SESSION[$sessionKey];
    }

    public static function verifyCsrf(?string $token, string $action = 'default'): bool
    {
        self::startSession();
        if (empty($token)) return false;
        $sessionKey = CSRF_TOKEN_NAME . '_' . $action;
        $stored = $_SESSION[$sessionKey] ?? '';
        if (empty($stored)) return false;
        // Constant-time compare
        if (hash_equals($stored, $token)) {
            // Single-use: rotate after successful verify
            $_SESSION[$sessionKey] = bin2hex(random_bytes(self::CSRF_TOKEN_BYTES));
            return true;
        }
        return false;
    }

    public static function requireCsrf(string $action = 'default'): void
    {
        $token = $_POST[CSRF_TOKEN_NAME] ?? $_SERVER['HTTP_X_CSRF_TOKEN'] ?? null;
        if (!self::verifyCsrf($token, $action)) {
            self::audit('csrf_failed', ['action' => $action]);
            Response::error('Invalid CSRF token', 403, 'CSRF_INVALID');
            exit;
        }
    }

    // ====================================================================
    // Password
    // ====================================================================

    public static function hashPassword(string $password): string
    {
        if (strlen($password) < self::PASSWORD_MIN_LENGTH) {
            throw new InvalidArgumentException('Password too short');
        }
        return password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
    }

    public static function verifyPassword(string $password, string $hash): bool
    {
        return password_verify($password, $hash);
    }

    public static function needsRehash(string $hash): bool
    {
        return password_needs_rehash($hash, PASSWORD_BCRYPT, ['cost' => 12]);
    }

    // ====================================================================
    // Input
    // ====================================================================

    public static function input(string $key, $default = null, ?string $type = null)
    {
        foreach ([$_GET, $_POST] as $source) {
            if (isset($source[$key])) {
                $value = $source[$key];
                if ($type === 'int')   return (int) $value;
                if ($type === 'float') return (float) $value;
                if ($type === 'bool')  return in_array($value, ['1', 'true', 'yes', 'on'], true);
                if ($type === 'email') return filter_var($value, FILTER_SANITIZE_EMAIL);
                if ($type === 'string') return self::sanitizeString((string) $value);
                if ($type === 'id')    return self::sanitizeId((string) $value);
                return $value;
            }
        }
        return $default;
    }

    public static function sanitizeString(string $value): string
    {
        return htmlspecialchars(strip_tags(trim($value)), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    public static function sanitizeId(string $value): string
    {
        // Whitelist: a-z, A-Z, 0-9, underscore, dash
        $cleaned = preg_replace('/[^a-zA-Z0-9_\-]/', '', $value);
        return substr($cleaned ?? '', 0, 64);
    }

    public static function escape(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    public static function escapeAttr(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    public static function jsonInput(): array
    {
        $raw = file_get_contents('php://input');
        if (empty($raw)) return [];
        if (strlen($raw) > 64 * 1024) {
            throw new RuntimeException('Payload too large');
        }
        $data = json_decode($raw, true);
        if (!is_array($data)) throw new RuntimeException('Invalid JSON');
        return $data;
    }

    public static function clientIp(): string
    {
        // Use REMOTE_ADDR only — X-Forwarded-For can be spoofed unless behind trusted proxy
        $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
        return preg_replace('/[^0-9a-fA-F:.]/', '', $ip) ?: '0.0.0.0';
    }

    public static function hashIp(string $ip): string
    {
        $salt = defined('LOG_IP_SALT') ? LOG_IP_SALT : 'default-salt';
        return substr(hash('sha256', $ip . $salt), 0, 16);
    }

    public static function userAgentHash(): string
    {
        $ua = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
        return substr(hash('sha256', $ua), 0, 16);
    }

    public static function isValidUtf8(string $value): bool
    {
        return mb_check_encoding($value, 'UTF-8');
    }

    public static function truncateForLog(string $value, int $max = 255): string
    {
        if (mb_strlen($value) > $max) {
            return mb_substr($value, 0, $max - 3) . '...';
        }
        return $value;
    }

    // ====================================================================
    // Path traversal protection
    // ====================================================================

    /**
     * Safe path join — rejects "..", absolute paths, null bytes
     * Only allows files matching the allowlist pattern
     */
    public static function safePath(string $baseDir, string $userPath, string $allowedPattern = '/^[a-zA-Z0-9_\-\/.]+\.[a-z]{1,5}$/'): ?string
    {
        // Strip null bytes
        if (strpos($userPath, "\0") !== false) return null;
        // Reject backslash (Windows path injection)
        if (strpos($userPath, '\\') !== false) return null;
        // Reject absolute paths
        if (strpos($userPath, '://') !== false) return null;

        $basename = basename($userPath);
        if ($basename !== $userPath && strpos($userPath, '/') !== strlen($userPath) - 1) {
            // Has subdirectories — only single-level allowed
            if (substr_count($userPath, '/') > 1) return null;
        }
        // Validate pattern
        if (!preg_match($allowedPattern, $basename)) return null;

        $resolved = realpath($baseDir . '/' . $basename);
        if ($resolved === false) return null;
        $baseReal = realpath($baseDir);
        if ($baseReal === false) return null;
        // Ensure resolved is inside baseDir (no symlink escape)
        if (strpos($resolved, $baseReal) !== 0) return null;
        return $resolved;
    }

    // ====================================================================
    // HMAC signing (server-to-server API)
    // ====================================================================

    public static function hmacSign(array $payload, ?string $secret = null): string
    {
        $secret = $secret ?? (defined('API_SHARED_SECRET') ? API_SHARED_SECRET : '');
        if (empty($secret)) throw new RuntimeException('No API secret configured');
        ksort($payload);
        $canonical = http_build_query($payload);
        return hash_hmac(self::HMAC_ALG, $canonical, $secret);
    }

    public static function hmacVerify(array $payload, string $providedSig, ?string $secret = null): bool
    {
        $expected = self::hmacSign($payload, $secret);
        return hash_equals($expected, $providedSig);
    }

    /**
     * Verify a signed API request: timestamp + nonce + signature
     */
    public static function verifySignedRequest(array $params, string $providedSig, string $providedTs, string $providedNonce, ?string $secret = null): array
    {
        // 1) Timestamp window
        $now = time();
        $ts = (int) $providedTs;
        if (abs($now - $ts) > self::REPLAY_WINDOW_SEC) {
            return ['ok' => false, 'code' => 'TIMESTAMP_EXPIRED', 'message' => 'Timestamp outside ±5min window'];
        }
        // 2) Nonce uniqueness (caller passes the cache check)
        if (!self::nonceSeen($providedNonce)) {
            return ['ok' => false, 'code' => 'NONCE_REPLAYED', 'message' => 'Nonce already used'];
        }
        // 3) Signature
        $payload = [
            'method' => $params['method'] ?? '',
            'path'   => $params['path'] ?? '',
            'ts'     => $providedTs,
            'nonce'  => $providedNonce,
            'body'   => $params['body'] ?? '',
        ];
        if (!self::hmacVerify($payload, $providedSig, $secret)) {
            return ['ok' => false, 'code' => 'BAD_SIGNATURE', 'message' => 'HMAC mismatch'];
        }
        return ['ok' => true];
    }

    /**
     * Track used nonces in a temp file with TTL
     * Returns true if nonce is fresh, false if replayed
     */
    public static function nonceSeen(string $nonce): bool
    {
        if (strlen($nonce) > 128 || !preg_match('/^[a-zA-Z0-9_\-]+$/', $nonce)) {
            return false;  // reject malformed nonces
        }
        $cacheFile = sys_get_temp_dir() . '/echoline_nonces.json';
        $now = time();
        $data = [];
        if (file_exists($cacheFile)) {
            $raw = @file_get_contents($cacheFile);
            $decoded = $raw ? json_decode($raw, true) : null;
            if (is_array($decoded)) $data = $decoded;
        }
        // GC: drop expired
        foreach ($data as $k => $entry) {
            if ($entry['exp'] < $now) unset($data[$k]);
        }
        if (isset($data[$nonce])) return false;  // replay
        $data[$nonce] = ['ts' => $now, 'exp' => $now + self::NONCE_TTL_SEC];
        @file_put_contents($cacheFile, json_encode($data), LOCK_EX);
        return true;
    }

    public static function generateNonce(): string
    {
        return bin2hex(random_bytes(16));
    }

    // ====================================================================
    // Rate limiting (file-based, no Redis dependency)
    // ====================================================================

    /**
     * @return bool true if allowed, false if rate-limited
     */
    public static function rateLimit(string $action, int $maxAttempts, int $windowSeconds, ?string $bucket = null): bool
    {
        $key = $bucket ?? self::clientIp();
        $name = sys_get_temp_dir() . '/echoline_rl_' . md5($action . '|' . $key);
        $now = time();

        $data = ['count' => 0, 'reset' => $now + $windowSeconds];
        if (file_exists($name)) {
            $raw = @file_get_contents($name);
            $stored = $raw ? @json_decode($raw, true) : null;
            if (is_array($stored) && isset($stored['reset']) && $stored['reset'] > $now) {
                $data = $stored;
            }
        }
        if (!isset($data['reset']) || $data['reset'] <= $now) {
            $data = ['count' => 0, 'reset' => $now + $windowSeconds];
        }
        $data['count']++;
        @file_put_contents($name, json_encode($data), LOCK_EX);
        return $data['count'] <= $maxAttempts;
    }

    // ====================================================================
    // Install lockout
    // ====================================================================

    public static function installLockPath(): string
    {
        if (self::$installLockPath !== null) return self::$installLockPath;
        self::$installLockPath = dirname(__DIR__, 2) . '/.install.lock';
        return self::$installLockPath;
    }

    public static function isInstalled(): bool
    {
        $lock = self::installLockPath();
        if (!file_exists($lock)) return false;
        // Verify lock signature
        $content = @file_get_contents($lock);
        if (!$content) return false;
        $expected = self::expectedInstallSignature();
        return hash_equals($expected, $content);
    }

    public static function markInstalled(): void
    {
        $lock = self::installLockPath();
        @file_put_contents($lock, self::expectedInstallSignature(), LOCK_EX);
        @chmod($lock, 0600);
    }

    private static function expectedInstallSignature(): string
    {
        // HMAC of the DB password (or install secret) — only the original installer knows it
        $secret = defined('DB_PASS') ? DB_PASS : (defined('INSTALL_LOCK_SECRET') ? INSTALL_LOCK_SECRET : 'default');
        return hash_hmac('sha256', 'ECHO//LINE_INSTALLED', $secret);
    }

    // ====================================================================
    // Audit logging
    // ====================================================================

    public static function audit(string $action, array $context = []): void
    {
        try {
            $stmt = Database::getInstance()->prepare(
                'INSERT INTO admin_audit_log
                 (action, context_json, admin_uid, session_id, ip_hash, user_agent_hash, occurred_at)
                 VALUES (?, ?, ?, ?, ?, ?, NOW())'
            );
            $sessionId = session_id() ?: '';
            $adminUid = $_SESSION['admin_uid'] ?? '';
            $stmt->execute([
                $action,
                json_encode(self::redactContext($context)),
                $adminUid,
                substr($sessionId, 0, 32),
                self::hashIp(self::clientIp()),
                self::userAgentHash(),
            ]);
        } catch (\Throwable $e) {
            // Fallback to error_log if DB is down
            error_log('[AUDIT_FAIL] ' . $action . ' ' . json_encode($context) . ' err=' . $e->getMessage());
        }
    }

    private static function redactContext(array $ctx): array
    {
        $banned = ['password', 'token', 'secret', 'api_key', 'csrf', 'cookie'];
        $out = [];
        foreach ($ctx as $k => $v) {
            $isBanned = false;
            foreach ($banned as $b) {
                if (stripos($k, $b) !== false) { $isBanned = true; break; }
            }
            $out[$k] = $isBanned ? '[REDACTED]' : (is_scalar($v) ? self::truncateForLog((string)$v) : $v);
        }
        return $out;
    }

    public static function generateCode(int $length = 6): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $code = '';
        for ($i = 0; $i < $length; $i++) {
            $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
        }
        return $code;
    }
}