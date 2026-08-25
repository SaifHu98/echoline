<?php
/**
 * Authentication & Authorization
 */
class Auth
{
    public static function login(string $username, string $password): bool
    {
        Security::startSession();

        // Rate limit
        if (!Security::rateLimit('login', LOGIN_MAX_ATTEMPTS, LOGIN_LOCKOUT_MINUTES * 60)) {
            throw new RuntimeException(I18n::t('login.locked'));
        }

        $admin = Database::fetch(
            'SELECT id, username, email, password_hash, role, is_active FROM admins WHERE username = ? LIMIT 1',
            [$username]
        );

        if (!$admin || !$admin['is_active']) {
            throw new RuntimeException(I18n::t('login.invalid'));
        }

        if (!Security::verifyPassword($password, $admin['password_hash'])) {
            throw new RuntimeException(I18n::t('login.invalid'));
        }

        // Regenerate session ID to prevent fixation
        session_regenerate_id(true);

        $_SESSION['admin'] = [
            'id' => (int) $admin['id'],
            'username' => $admin['username'],
            'email' => $admin['email'],
            'role' => $admin['role'],
            'login_at' => time(),
        ];

        // Update last login
        Database::update('admins', [
            'last_login' => date('Y-m-d H:i:s'),
            'last_ip' => Security::clientIp(),
        ], 'id = ?', [$admin['id']]);

        Audit::log((int) $admin['id'], 'admin.login', null, null, null);

        return true;
    }

    public static function logout(): void
    {
        Security::startSession();
        if (self::check()) {
            Audit::log(self::id(), 'admin.logout', null, null, null);
        }
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(session_name(), '', time() - 42000,
                $params['path'], $params['domain'],
                $params['secure'], $params['httponly']);
        }
        session_destroy();
    }

    public static function check(): bool
    {
        Security::startSession();
        return !empty($_SESSION['admin']);
    }

    public static function id(): ?int
    {
        Security::startSession();
        return $_SESSION['admin']['id'] ?? null;
    }

    public static function user(): ?array
    {
        Security::startSession();
        return $_SESSION['admin'] ?? null;
    }

    public static function role(): ?string
    {
        Security::startSession();
        return $_SESSION['admin']['role'] ?? null;
    }

    public static function require(): void
    {
        if (!self::check()) {
            Response::redirect('login.php');
        }
    }

    public static function requireRole(string ...$roles): void
    {
        self::require();
        $current = self::role();
        if (!$current || !in_array($current, $roles, true)) {
            Response::error(I18n::t('error.unauthorized'), 403);
        }
    }

    public static function createAdmin(string $username, string $email, string $password, string $role = 'editor'): int
    {
        if (strlen($password) < PASSWORD_MIN_LENGTH) {
            throw new InvalidArgumentException('Password too short');
        }
        $existing = Database::fetch('SELECT id FROM admins WHERE username = ?', [$username]);
        if ($existing) {
            throw new RuntimeException('Username already exists');
        }
        return Database::insert('admins', [
            'username' => $username,
            'email' => $email,
            'password_hash' => Security::hashPassword($password),
            'role' => $role,
        ]);
    }

    public static function changePassword(int $adminId, string $newPassword): void
    {
        if (strlen($newPassword) < PASSWORD_MIN_LENGTH) {
            throw new InvalidArgumentException('Password too short');
        }
        Database::update('admins', [
            'password_hash' => Security::hashPassword($newPassword),
        ], 'id = ?', [$adminId]);
    }
}