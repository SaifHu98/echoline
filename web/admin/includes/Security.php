<?php
/**
 * Security: CSRF, XSS, sanitization, rate limiting
 */
class Security
{
    public static function startSession(): void
    {
        if (session_status() === PHP_SESSION_NONE) {
            session_name(SESSION_NAME);
            session_set_cookie_params([
                'lifetime' => SESSION_LIFETIME,
                'path' => '/',
                'secure' => APP_ENV === 'production',
                'httponly' => true,
                'samesite' => 'Lax',
            ]);
            session_start();
        }
    }

    public static function csrfToken(): string
    {
        self::startSession();
        if (empty($_SESSION[CSRF_TOKEN_NAME])) {
            $_SESSION[CSRF_TOKEN_NAME] = bin2hex(random_bytes(32));
        }
        return $_SESSION[CSRF_TOKEN_NAME];
    }

    public static function verifyCsrf(?string $token): bool
    {
        self::startSession();
        if (empty($token) || empty($_SESSION[CSRF_TOKEN_NAME])) return false;
        return hash_equals($_SESSION[CSRF_TOKEN_NAME], $token);
    }

    public static function input(string $key, $default = null, ?string $type = null)
    {
        $sources = [$_GET, $_POST, $_REQUEST];
        foreach ($sources as $source) {
            if (isset($source[$key])) {
                $value = $source[$key];
                if ($type === 'int') return (int) $value;
                if ($type === 'float') return (float) $value;
                if ($type === 'bool') return in_array($value, ['1', 'true', 'yes', 'on'], true);
                if ($type === 'email') return filter_var($value, FILTER_SANITIZE_EMAIL);
                if ($type === 'string') return self::sanitizeString((string) $value);
                return $value;
            }
        }
        return $default;
    }

    public static function sanitizeString(string $value): string
    {
        return htmlspecialchars(strip_tags(trim($value)), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    public static function escape(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    public static function jsonInput(): array
    {
        $raw = file_get_contents('php://input');
        if (empty($raw)) return [];
        $data = json_decode($raw, true);
        return is_array($data) ? $data : [];
    }

    public static function clientIp(): string
    {
        foreach (['HTTP_X_FORWARDED_FOR', 'HTTP_X_REAL_IP', 'REMOTE_ADDR'] as $key) {
            if (!empty($_SERVER[$key])) {
                return explode(',', $_SERVER[$key])[0];
            }
        }
        return '0.0.0.0';
    }

    public static function hashPassword(string $password): string
    {
        return password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
    }

    public static function verifyPassword(string $password, string $hash): bool
    {
        return password_verify($password, $hash);
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

    /**
     * Rate limiting بسيط باستخدام ملف cache
     */
    public static function rateLimit(string $action, int $maxAttempts, int $windowSeconds): bool
    {
        $key = sys_get_temp_dir() . '/echoline_rl_' . md5(Security::clientIp() . $action);
        $now = time();
        $data = ['count' => 0, 'reset' => $now + $windowSeconds];

        if (file_exists($key)) {
            $raw = @file_get_contents($key);
            $stored = $raw ? @json_decode($raw, true) : null;
            if (is_array($stored) && $stored['reset'] > $now) {
                $data = $stored;
            }
        }

        if ($data['reset'] <= $now) {
            $data = ['count' => 0, 'reset' => $now + $windowSeconds];
        }

        $data['count']++;
        @file_put_contents($key, json_encode($data), LOCK_EX);

        return $data['count'] <= $maxAttempts;
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
}