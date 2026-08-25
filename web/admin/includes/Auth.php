<?php
/**
 * Auth — Authentication & RBAC for Admin Panel
 * ==============================================
 * - bcrypt password verification
 * - Session rotation on login & on privilege change
 * - RBAC: superadmin, editor, viewer
 * - Login rate limiting (per-IP + per-username)
 * - 2FA stub for superadmin (TOTP-ready)
 */

final class Auth
{
    const ROLE_SUPERADMIN = 'superadmin';
    const ROLE_EDITOR     = 'editor';
    const ROLE_VIEWER     = 'viewer';

    const ROLE_RANK = [
        self::ROLE_VIEWER     => 1,
        self::ROLE_EDITOR     => 2,
        self::ROLE_SUPERADMIN => 3,
    ];

    const PERMISSIONS = [
        self::ROLE_VIEWER     => ['view'],
        self::ROLE_EDITOR     => ['view', 'edit', 'publish'],
        self::ROLE_SUPERADMIN => ['view', 'edit', 'publish', 'delete', 'admin', 'audit', 'install'],
    ];

    const IDLE_TIMEOUT_SEC = 3600;      // 1h
    const ABSOLUTE_TIMEOUT_SEC = 8 * 3600;  // 8h
    const MAX_LOGIN_ATTEMPTS = 5;
    const LOGIN_LOCKOUT_SEC = 900;  // 15 min after 5 fails

    /**
     * Attempt login. Returns array with success/failure + reason.
     * Always rotates session on success.
     */
    public static function login(string $username, string $password): array
    {
        Security::startSession();

        $ip = Security::clientIp();
        $bucket = 'login:ip:' . $ip;
        if (!Security::rateLimit('login_ip', self::MAX_LOGIN_ATTEMPTS * 4, 900, $bucket)) {
            Security::audit('login_lockout_ip', ['ip_hash' => Security::hashIp($ip)]);
            return ['success' => false, 'code' => 'TOO_MANY_ATTEMPTS', 'message' => 'IP temporarily locked. Try again in 15 minutes.'];
        }

        $stmt = Database::getInstance()->prepare(
            'SELECT id, username, password_hash, role, two_factor_secret, is_locked, locked_until, failed_attempts
             FROM admins WHERE username = ? LIMIT 1'
        );
        $stmt->execute([$username]);
        $row = $stmt->fetch();
        if (!$row) {
            Security::rateLimit('login_username', self::MAX_LOGIN_ATTEMPTS, self::LOGIN_LOCKOUT_SEC, 'login:user:' . $username);
            Security::audit('login_failed_no_user', ['username_hash' => substr(hash('sha256', $username), 0, 12)]);
            return ['success' => false, 'code' => 'BAD_CREDENTIALS', 'message' => 'Invalid username or password'];
        }

        if ($row['is_locked'] && strtotime($row['locked_until'] ?? '1970-01-01') > time()) {
            Security::audit('login_blocked_locked', ['admin_id' => $row['id']]);
            return ['success' => false, 'code' => 'ACCOUNT_LOCKED', 'message' => 'Account is temporarily locked'];
        }

        if (!Security::verifyPassword($password, $row['password_hash'])) {
            $fails = (int)$row['failed_attempts'] + 1;
            $lockUntil = null;
            $locked = 0;
            if ($fails >= self::MAX_LOGIN_ATTEMPTS) {
                $locked = 1;
                $lockUntil = date('Y-m-d H:i:s', time() + self::LOGIN_LOCKOUT_SEC);
            }
            Database::query(
                'UPDATE admins SET failed_attempts = ?, is_locked = ?, locked_until = ? WHERE id = ?',
                [$fails, $locked, $lockUntil, $row['id']]
            );
            Security::audit('login_failed_wrong_password', [
                'admin_id' => $row['id'],
                'failed_attempts' => $fails,
            ]);
            return ['success' => false, 'code' => 'BAD_CREDENTIALS', 'message' => 'Invalid username or password'];
        }

        // Optional: rehash if cost increased
        if (Security::needsRehash($row['password_hash'])) {
            $newHash = Security::hashPassword($password);
            Database::query('UPDATE admins SET password_hash = ? WHERE id = ?', [$newHash, $row['id']]);
        }

        // Success — rotate session
        Security::rotateSessionId();
        Security::destroySession();
        Security::startSession();

        $_SESSION['admin_uid']      = $row['id'];
        $_SESSION['admin_username'] = $row['username'];
        $_SESSION['admin_role']     = $row['role'];
        $_SESSION['logged_in_at']   = time();
        $_SESSION['last_activity']  = time();

        // Reset failure count
        Database::query('UPDATE admins SET failed_attempts = 0, is_locked = 0, locked_until = NULL WHERE id = ?', [$row['id']]);

        Security::audit('login_success', ['admin_id' => $row['id'], 'role' => $row['role']]);

        return ['success' => true, 'requires_2fa' => ($row['role'] === self::ROLE_SUPERADMIN && !empty($row['two_factor_secret'])), 'role' => $row['role']];
    }

    public static function logout(): void
    {
        Security::startSession();
        $uid = $_SESSION['admin_uid'] ?? null;
        if ($uid) Security::audit('logout', ['admin_id' => $uid]);
        Security::destroySession();
    }

    public static function isLoggedIn(): bool
    {
        Security::startSession();
        if (empty($_SESSION['admin_uid'])) return false;
        if (!isset($_SESSION['logged_in_at'])) return false;
        if (time() - (int)$_SESSION['logged_in_at'] > self::ABSOLUTE_TIMEOUT_SEC) {
            self::logout();
            return false;
        }
        if (isset($_SESSION['last_activity']) && (time() - (int)$_SESSION['last_activity']) > self::IDLE_TIMEOUT_SEC) {
            self::logout();
            return false;
        }
        $_SESSION['last_activity'] = time();
        return true;
    }

    public static function currentRole(): ?string
    {
        Security::startSession();
        return $_SESSION['admin_role'] ?? null;
    }

    public static function requireLogin(): void
    {
        if (!self::isLoggedIn()) {
            $base = defined('ADMIN_BASE') ? ADMIN_BASE : '/admin/';
            header('Location: ' . $base . 'login.php');
            exit;
        }
    }

    public static function requirePermission(string $permission): void
    {
        self::requireLogin();
        $role = self::currentRole();
        $allowed = self::PERMISSIONS[$role] ?? [];
        if (!in_array($permission, $allowed, true)) {
            Security::audit('permission_denied', ['permission' => $permission, 'role' => $role]);
            Response::error('Permission denied', 403, 'PERMISSION_DENIED');
            exit;
        }
    }

    public static function requireRole(string $requiredRole): void
    {
        self::requireLogin();
        $role = self::currentRole();
        if ((self::ROLE_RANK[$role] ?? 0) < (self::ROLE_RANK[$requiredRole] ?? 0)) {
            Security::audit('role_denied', ['required' => $requiredRole, 'actual' => $role]);
            Response::error('Insufficient privileges', 403, 'ROLE_DENIED');
            exit;
        }
    }

    public static function currentAdminId(): ?int
    {
        Security::startSession();
        return isset($_SESSION['admin_uid']) ? (int)$_SESSION['admin_uid'] : null;
    }

    /**
     * On privilege change (e.g., role updated), force re-auth
     */
    public static function requireReauth(): void
    {
        self::logout();
        $base = defined('ADMIN_BASE') ? ADMIN_BASE : '/admin/';
        header('Location: ' . $base . 'login.php?reauth=1');
        exit;
    }
}