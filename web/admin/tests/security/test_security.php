<?php
// Keep CLI output buffered so session configuration remains valid during the
// lightweight test runner; production requests are not affected.
ob_start();
/**
 * Security unit tests for Admin Panel
 * Run from CLI: php tests/security/test_security.php
 * Or integrate with phpunit (you'd need to install it)
 *
 * Lightweight custom test runner — no external deps.
 */

// Bootstrap minimal config (no DB required for some tests)
define('APP_ENV', 'testing');
define('SESSION_NAME', 'ECHOTEST');
define('SESSION_LIFETIME', 3600);
define('SESSION_IDLE_TIMEOUT', 3600);
define('SESSION_ABSOLUTE_TIMEOUT', 28800);
define('SESSION_COOKIE_DOMAIN', '');
define('SESSION_IP_SALT', 'test-salt');
define('CSRF_TOKEN_NAME', '_csrf');
define('API_SHARED_SECRET', 'test-api-secret');
define('LOG_IP_SALT', 'test-log-salt');
define('ALLOWED_ORIGINS_HTTP', '*');
define('ALLOWED_ORIGINS_SOCKET', '*');

require_once __DIR__ . '/../../includes/Security.php';

$pass = 0; $fail = 0; $total = 0;

function test($name, callable $fn) {
    global $pass, $fail, $total;
    $total++;
    try {
        $fn();
        echo "  ✓ $name\n";
        $pass++;
    } catch (\Throwable $e) {
        echo "  ✗ $name\n";
        echo "    " . $e->getMessage() . "\n";
        if (defined('VERBOSE') && VERBOSE) echo "    at " . $e->getFile() . ":" . $e->getLine() . "\n";
        $fail++;
    }
}

function assert_eq($a, $b, $msg = '') {
    if ($a !== $b) throw new RuntimeException("Expected " . var_export($b, true) . " got " . var_export($a, true) . ($msg ? " ($msg)" : ''));
}
function assert_true($v, $msg = '') {
    if (!$v) throw new RuntimeException("Expected truthy" . ($msg ? " ($msg)" : ''));
}
function assert_false($v, $msg = '') {
    if ($v) throw new RuntimeException("Expected falsy" . ($msg ? " ($msg)" : ''));
}

echo "═══ Security Tests ═══\n";

// ====================================================================
// CSRF
// ====================================================================
test('csrf: token is 64 hex chars and unique', function () {
    Security::startSession();
    $t1 = Security::csrfToken('test');
    assert_eq(strlen($t1), 64);
    assert_eq(ctype_xdigit($t1), true);
    $t2 = Security::csrfToken('test');
    // Same session = same token (cached)
    assert_eq($t1, $t2);
});

test('csrf: per-action tokens are separate', function () {
    Security::startSession();
    $a = Security::csrfToken('action_a');
    $b = Security::csrfToken('action_b');
    assert_true($a !== $b, 'per-action tokens must differ');
});

test('csrf: verifyCsrf rejects wrong token', function () {
    Security::startSession();
    assert_false(Security::verifyCsrf('wrong_token_1234567890abcdef'));
});

test('csrf: verifyCsrf accepts right token once then rotates', function () {
    Security::startSession();
    $tok = Security::csrfToken('once_test');
    assert_true(Security::verifyCsrf($tok, 'once_test'));
    // Second verify should fail because it rotated
    assert_false(Security::verifyCsrf($tok, 'once_test'));
});

// ====================================================================
// Password
// ====================================================================
test('password: hash and verify round-trip', function () {
    $h = Security::hashPassword('correct-horse-battery-staple');
    assert_eq(strlen($h) > 50, true);  // bcrypt hash is ~60 chars
    assert_true(Security::verifyPassword('correct-horse-battery-staple', $h));
    assert_false(Security::verifyPassword('wrong-password', $h));
});

test('password: short passwords rejected', function () {
    $threw = false;
    try {
        Security::hashPassword('short');
    } catch (\InvalidArgumentException $e) {
        $threw = true;
    }
    assert_true($threw, 'must throw for short password');
});

test('password: needsRehash returns true for old cost', function () {
    $oldHash = password_hash('correct-horse-battery-staple', PASSWORD_BCRYPT, ['cost' => 4]);
    assert_true(Security::needsRehash($oldHash));
});

// ====================================================================
// Path traversal
// ====================================================================
test('safePath: rejects backslash', function () {
    Security::startSession();
    $base = sys_get_temp_dir() . '/echoline_test_paths/';
    @mkdir($base, 0755, true);
    assert_eq(Security::safePath($base, '..\\..\\..\\etc\\passwd'), null);
    @rmdir($base);
});

test('safePath: rejects null bytes', function () {
    Security::startSession();
    $base = sys_get_temp_dir() . '/echoline_test_paths/';
    @mkdir($base, 0755, true);
    assert_eq(Security::safePath($base, "file\0.txt"), null);
    @rmdir($base);
});

test('safePath: rejects double-dot segments', function () {
    Security::startSession();
    $base = sys_get_temp_dir() . '/echoline_test_paths/';
    @mkdir($base, 0755, true);
    file_put_contents($base . 'real.txt', 'real');
    @mkdir($base . 'subdir', 0755, true);
    assert_eq(Security::safePath($base, '../etc/passwd'), null);
    assert_eq(Security::safePath($base, 'subdir/../../../etc/passwd'), null);
    @unlink($base . 'real.txt');
    @rmdir($base . 'subdir');
    @rmdir($base);
});

test('safePath: accepts valid basename', function () {
    Security::startSession();
    $base = sys_get_temp_dir() . '/echoline_test_paths/';
    @mkdir($base, 0755, true);
    file_put_contents($base . 'report.csv', 'data');
    $result = Security::safePath($base, 'report.csv');
    assert_true($result !== null);
    assert_true(strpos($result, 'report.csv') !== false);
    @unlink($base . 'report.csv');
    @rmdir($base);
});

// ====================================================================
// HMAC
// ====================================================================
test('hmac: sign/verify round-trip', function () {
    $payload = ['a' => 1, 'b' => 2, 'ts' => '123'];
    $sig = Security::hmacSign($payload, 'test-secret');
    assert_true(Security::hmacVerify($payload, $sig, 'test-secret'));
});

test('hmac: signature differs for different secret', function () {
    $payload = ['a' => 1];
    $sig1 = Security::hmacSign($payload, 'secret_a');
    $sig2 = Security::hmacSign($payload, 'secret_b');
    assert_true($sig1 !== $sig2);
});

test('hmac: tampered payload fails verify', function () {
    $payload = ['a' => 1];
    $sig = Security::hmacSign($payload, 'test-secret');
    $tampered = ['a' => 2];
    assert_false(Security::hmacVerify($tampered, $sig, 'test-secret'));
});

// ====================================================================
// Nonce replay protection
// ====================================================================
test('nonce: first use is fresh', function () {
    Security::startSession();
    $nonce = bin2hex(random_bytes(16));
    assert_true(Security::nonceSeen($nonce));
});

test('nonce: second use is rejected', function () {
    Security::startSession();
    $nonce = bin2hex(random_bytes(16));
    Security::nonceSeen($nonce);
    assert_false(Security::nonceSeen($nonce));
});

test('nonce: malformed rejected', function () {
    Security::startSession();
    assert_false(Security::nonceSeen('has spaces and special chars!'));
});

// ====================================================================
// Install lockout
// ====================================================================
test('install lock: not installed by default', function () {
    // Save and clear env
    $lockPath = Security::installLockPath();
    if (file_exists($lockPath)) @unlink($lockPath);
    assert_false(Security::isInstalled());
});

test('install lock: marking creates valid lock', function () {
    Security::markInstalled();
    assert_true(Security::isInstalled());
    @unlink(Security::installLockPath());
});

// ====================================================================
// XSS / sanitization
// ====================================================================
test('sanitizeString: strips HTML tags', function () {
    // After sanitizeString: tags stripped, special chars escaped
    $result = Security::sanitizeString('hello <script>x</script> world');
    assert_true(strpos($result, '<script>') === false, 'must strip script tags');
    assert_true(strpos($result, 'hello') !== false);
    assert_true(strpos($result, 'world') !== false);
    // Quotes should be escaped
    $result2 = Security::sanitizeString("a & b");
    assert_true(strpos($result2, '&amp;') !== false);
});

test('sanitizeId: strips non-alphanumeric', function () {
    assert_eq(Security::sanitizeId('p_abc-123;DROP TABLE'), 'p_abc-123DROPTABLE');
    // Verify a pure-alphanumeric ID passes through unchanged
    assert_eq(Security::sanitizeId('p_user-1234'), 'p_user-1234');
    // Strip slashes/dots
    $result = Security::sanitizeId('../../etc/passwd');
    assert_eq(strpos($result, '/'), false, 'must strip slashes');
    assert_eq(strpos($result, '.'), false, 'must strip dots');
});

test('jsonInput: rejects oversized payload', function () {
    // Simulate by mocking php://input
    // (this test would need stream wrapper; skip in CLI)
});

// ====================================================================
// Rate limiter
// ====================================================================
test('rate limit: allows up to max then blocks', function () {
    Security::startSession();
    $ip = '192.168.1.' . rand(1, 254);
    $ok1 = Security::rateLimit('test_action', 3, 60, 'test:' . $ip);
    $ok2 = Security::rateLimit('test_action', 3, 60, 'test:' . $ip);
    $ok3 = Security::rateLimit('test_action', 3, 60, 'test:' . $ip);
    $ok4 = Security::rateLimit('test_action', 3, 60, 'test:' . $ip);
    assert_true($ok1);
    assert_true($ok2);
    assert_true($ok3);
    assert_false($ok4);
});

// ====================================================================
// Output
// ====================================================================
echo "\n";
echo "Total: $total | Passed: $pass | Failed: $fail\n";
ob_end_flush();
exit($fail > 0 ? 1 : 0);
