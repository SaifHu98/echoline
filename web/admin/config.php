<?php
/**
 * ECHO//LINE — Admin Panel Configuration
 * ----------------------------------------
 * عدّل هذا الملف حسب بيانات Hostinger الخاصة بك
 * Edit this file according to your Hostinger credentials
 */

// ============================================================
// DATABASE (MySQL — Hostinger)
// ============================================================
define('DB_HOST', 'localhost');                    // عادة localhost على Hostinger
define('DB_NAME', 'u123456789_echoline');           // غيّرها لاسم قاعدة بياناتك
define('DB_USER', 'u123456789_admin');              // غيّرها لمستخدم قاعدة البيانات
define('DB_PASS', 'YourSecurePassword123!');       // غيّرها لكلمة المرور
define('DB_CHARSET', 'utf8mb4');

// ============================================================
// APP CONFIG
// ============================================================
define('APP_NAME', 'ECHO//LINE — أصداء');
define('APP_VERSION', '1.0.0');
define('APP_ENV', 'production');                    // 'development' or 'production'
define('APP_TIMEZONE', 'UTC');
define('APP_LOCALE', 'ar');                          // 'en' or 'ar'

date_default_timezone_set(APP_TIMEZONE);

// ============================================================
// SECURITY
// ============================================================
define('SESSION_NAME', 'ECHOLINE_ADMIN');
define('SESSION_LIFETIME', 7200);                    // 2 hours
define('CSRF_TOKEN_NAME', '_token');
define('PASSWORD_MIN_LENGTH', 8);
define('LOGIN_MAX_ATTEMPTS', 5);
define('LOGIN_LOCKOUT_MINUTES', 15);

// مفاتيح استلام webhook من Google Play / App Store
define('GOOGLE_PLAY_PACKAGE_NAME', 'com.ecouni.echoline');
define('GOOGLE_PLAY_KEY_FILE', __DIR__ . '/keys/google-play-key.json');
define('APP_SHARED_SECRET', '');                     // Apple App Store shared secret

// ============================================================
// API KEYS
// ============================================================
define('GOOGLE_ANALYTICS_PROPERTY_ID', '');
define('FIREBASE_CREDENTIALS_FILE', __DIR__ . '/keys/firebase-credentials.json');

// ============================================================
// FEATURE FLAGS
// ============================================================
define('FEATURE_MAINTENANCE_MODE', false);
define('FEATURE_SHOP_ENABLED', true);
define('FEATURE_LIVEOPS_ENABLED', true);

// ============================================================
// ERROR LOGGING
// ============================================================
if (APP_ENV === 'development') {
    error_reporting(E_ALL);
    ini_set('display_errors', '1');
} else {
    error_reporting(E_ALL & ~E_DEPRECATED & ~E_STRICT);
    ini_set('display_errors', '0');
    ini_set('log_errors', '1');
    ini_set('error_log', __DIR__ . '/logs/error.log');
}

// ============================================================
// AUTOLOADER
// ============================================================
spl_autoload_register(function ($class) {
    $file = __DIR__ . '/includes/' . str_replace('\\', '/', $class) . '.php';
    if (file_exists($file)) require_once $file;
});

// ============================================================
// INITIALIZE
// ============================================================
require_once __DIR__ . '/includes/Database.php';
require_once __DIR__ . '/includes/Security.php';
require_once __DIR__ . '/includes/I18n.php';
require_once __DIR__ . '/includes/Auth.php';
require_once __DIR__ . '/includes/Audit.php';
require_once __DIR__ . '/includes/Response.php';

I18n::init(APP_LOCALE);