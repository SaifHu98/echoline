<?php
/**
 * ECHO//LINE — Installer
 * ----------------------
 * 1. Create MySQL database & tables
 * 2. Create default admin
 * 3. Seed demo data
 * ----------------------
 * Usage: Visit /admin/install.php in browser
 *        Run ONCE then DELETE this file for security
 */
define('ADMIN_INSTALLER', 1);
require_once __DIR__ . '/config.php';

$step = Security::input('step', 1, 'int');
$message = '';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if ($step === 2) {
        // Verify DB connection then run schema
        try {
            $pdo = Database::getInstance();
            $schema = file_get_contents(__DIR__ . '/database/schema.sql');

            // Remove SQL comments (-- to end of line)
            $cleaned = preg_replace('/^\s*--.*$/m', '', $schema);

            // Split into statements on semicolon at end of line
            $statements = preg_split('/;\s*(?:\n|$)/', $cleaned);
            $successCount = 0;
            $errors = [];

            foreach ($statements as $stmt) {
                $stmt = trim($stmt);
                if (empty($stmt)) continue;
                if (preg_match('/^--+\s*$/', $stmt)) continue;
                if (strpos($stmt, '--') === 0) continue;

                try {
                    $pdo->exec($stmt);
                    $successCount++;
                } catch (PDOException $e) {
                    $errMsg = $e->getMessage();
                    // Ignore "table already exists" or duplicate key
                    if (strpos($errMsg, 'already exists') !== false ||
                        strpos($errMsg, 'Duplicate') !== false) {
                        continue;
                    }
                    $errors[] = $errMsg . ' [SQL: ' . substr(preg_replace('/\s+/', ' ', $stmt), 0, 120) . ']';
                }
            }

            // Verify expected tables exist
            $expected = ['admins', 'events', 'quests', 'shop_items', 'remote_config'];
            $missing = [];
            foreach ($expected as $table) {
                try {
                    $pdo->query("SELECT 1 FROM `{$table}` LIMIT 1");
                } catch (PDOException $e) {
                    $missing[] = $table;
                }
            }

            if (!empty($missing)) {
                throw new RuntimeException(
                    'الجداول التالية لم تُنشأ: ' . implode(', ', $missing) .
                    '. أخطاء: ' . implode(' | ', array_slice($errors, 0, 2))
                );
            }

            $message = 'تم إنشاء الجداول بنجاح (' . $successCount . ' عملية)';
            $step = 3;
        } catch (\Throwable $e) {
            $error = 'فشل إنشاء الجداول: ' . $e->getMessage();
        }
    } elseif ($step === 3) {
        // Create default admin
        $username = Security::input('username', '', 'string');
        $email = Security::input('email', '', 'string');
        $password = Security::input('password', '', 'string');

        if (strlen($password) < 8) {
            $error = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
        } else {
            try {
                // Remove existing default admin if present
                Database::query("DELETE FROM admins WHERE username = 'admin' AND id = 1");
                $id = Auth::createAdmin($username, $email, $password, 'superadmin');
                $message = 'تم إنشاء المدير بنجاح: ' . $username;
                $step = 4;
            } catch (\Throwable $e) {
                $error = $e->getMessage();
            }
        }
    } elseif ($step === 4) {
        // Seed demo data
        try {
            // Create some sample players
            $samplePlayers = [
                ['uid_001', 'أحمد المغامر', 'android', 12, 5400, 250, 50],
                ['uid_002', 'سارة المستكشفة', 'ios', 8, 2300, 100, 20],
                ['uid_003', 'عمر الحكيم', 'android', 15, 8900, 500, 120],
                ['uid_004', 'ليلى المحاربة', 'ios', 22, 15000, 1200, 280],
                ['uid_005', 'خالد الزاهد', 'android', 5, 800, 25, 8],
            ];
            foreach ($samplePlayers as [$uid, $name, $platform, $level, $xp, $curr, $matches]) {
                try {
                    Database::insert('players', [
                        'player_uid' => $uid,
                        'display_name' => $name,
                        'platform' => $platform,
                        'level' => $level,
                        'xp' => $xp,
                        'currency_premium' => $curr,
                        'matches_played' => $matches,
                        'last_login_at' => date('Y-m-d H:i:s', time() - random_int(60, 86400)),
                    ]);
                } catch (Exception $e) { /* skip duplicates */ }
            }

            // Sample sales
            for ($i = 0; $i < 20; $i++) {
                try {
                    Database::insert('sales_log', [
                        'transaction_id' => 'txn_' . bin2hex(random_bytes(8)),
                        'player_id' => 'uid_' . str_pad(random_int(1, 5), 3, '0', STR_PAD_LEFT),
                        'sku' => ['shards_500', 'shards_1200', 'season_pass_1', 'starter_bundle'][random_int(0, 3)],
                        'platform' => ['android', 'ios'][random_int(0, 1)],
                        'amount_usd' => [4.99, 9.99, 7.99, 2.99][random_int(0, 3)],
                        'currency_code' => 'USD',
                        'status' => 'verified',
                        'verified_at' => date('Y-m-d H:i:s', time() - random_int(60, 2592000)),
                    ]);
                } catch (Exception $e) {}
            }

            // Sample analytics
            $events = ['match_completed', 'echo_triggered', 'tutorial_step_completed'];
            for ($i = 0; $i < 50; $i++) {
                Database::insert('analytics_events', [
                    'event_name' => $events[array_rand($events)],
                    'player_uid' => 'uid_' . str_pad(random_int(1, 5), 3, '0', STR_PAD_LEFT),
                    'event_data' => json_encode([
                        'scenario' => 'clocktower_district',
                        'outcome' => ['perfect_restoration', 'city_saved', 'temporal_erasure'][random_int(0, 2)],
                        'timeline' => ['past', 'present', 'future'][random_int(0, 2)],
                    ]),
                    'created_at' => date('Y-m-d H:i:s', time() - random_int(60, 2592000)),
                ]);
            }

            $message = 'تم إدخال البيانات التجريبية بنجاح';
            $step = 5;
        } catch (\Throwable $e) {
            $error = 'فشل: ' . $e->getMessage();
        }
    }
}

?><!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <title>تثبيت لوحة الإدارة — ECHO//LINE</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;900&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Cairo', sans-serif; background: linear-gradient(135deg, #04060b 0%, #0a1224 100%); color: #F0F4F8; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 1rem; }
    .installer { background: rgba(16,22,34,0.95); border: 1px solid rgba(255,255,255,0.15); border-radius: 20px; padding: 2.5rem; max-width: 600px; width: 100%; }
    h1 { color: #00E5FF; margin-bottom: 1rem; }
    .step { background: rgba(255,255,255,0.05); padding: 1rem; border-radius: 10px; margin: 1rem 0; border-inline-start: 3px solid #00E5FF; }
    .step.done { border-color: #00E676; }
    .step.pending { opacity: 0.5; }
    .alert { padding: 1rem; border-radius: 8px; margin: 1rem 0; }
    .alert-success { background: rgba(0,230,118,0.1); border: 1px solid #00E676; color: #00E676; }
    .alert-error { background: rgba(255,82,82,0.1); border: 1px solid #FF5252; color: #FF5252; }
    .form-group { margin: 1rem 0; }
    label { display: block; margin-bottom: 0.3rem; font-weight: 700; font-size: 0.9rem; }
    input { width: 100%; padding: 0.7rem; background: rgba(0,0,0,0.5); border: 1px solid rgba(255,255,255,0.15); border-radius: 8px; color: #fff; font-family: inherit; }
    button { background: linear-gradient(135deg, #00E5FF, #0091EA); color: #000; border: none; padding: 0.8rem 1.5rem; border-radius: 8px; font-weight: 700; cursor: pointer; font-family: inherit; font-size: 1rem; }
    .warning { background: rgba(255,167,38,0.1); border: 1px solid #FFA726; padding: 1rem; border-radius: 8px; margin: 1rem 0; color: #FFA726; }
  </style>
</head>
<body>
  <div class="installer">
    <h1>🛠️ تثبيت لوحة الإدارة ECHO//LINE</h1>

    <?php if ($message): ?><div class="alert alert-success"><?= htmlspecialchars($message) ?></div><?php endif; ?>
    <?php if ($error): ?><div class="alert alert-error"><?= htmlspecialchars($error) ?></div><?php endif; ?>

    <div class="step <?= $step >= 1 ? 'done' : 'pending' ?>">
      <strong>1. التحقق من الاتصال بقاعدة البيانات</strong>
      <?php
      try {
          Database::getInstance();
          echo '<p style="color:#00E676">✓ الاتصال ناجح — ' . DB_HOST . ' / ' . DB_NAME . '</p>';
      } catch (\Throwable $e) {
          echo '<p style="color:#FF5252">✗ ' . htmlspecialchars($e->getMessage()) . '</p>';
          echo '<p style="color:#FFA726">تأكد من بيانات DB في <code>config.php</code></p>';
      }
      ?>
    </div>

    <?php if ($step >= 2): ?>
    <div class="step done"><strong>2. ✓ إنشاء الجداول</strong></div>
    <?php else: ?>
    <div class="step pending">
      <strong>2. إنشاء جداول قاعدة البيانات</strong>
      <form method="POST"><input type="hidden" name="step" value="2"><button type="submit">تشغيل التثبيت</button></form>
    </div>
    <?php endif; ?>

    <?php if ($step >= 3): ?>
    <div class="step done"><strong>3. ✓ إنشاء المدير</strong></div>
    <?php else: ?>
    <div class="step">
      <strong>3. إنشاء حساب مدير</strong>
      <form method="POST">
        <input type="hidden" name="step" value="3">
        <div class="form-group">
          <label>اسم المستخدم</label>
          <input type="text" name="username" value="admin" required pattern="[a-zA-Z0-9_]+">
        </div>
        <div class="form-group">
          <label>البريد الإلكتروني</label>
          <input type="email" name="email" value="admin@ecouni.com" required>
        </div>
        <div class="form-group">
          <label>كلمة المرور (8 أحرف على الأقل)</label>
          <input type="password" name="password" required minlength="8" placeholder="كلمة مرور قوية">
        </div>
        <button type="submit">إنشاء المدير</button>
      </form>
    </div>
    <?php endif; ?>

    <?php if ($step >= 4): ?>
    <div class="step done"><strong>4. ✓ البيانات التجريبية</strong></div>
    <?php else: ?>
    <div class="step">
      <strong>4. إدخال بيانات تجريبية (اختياري)</strong>
      <p style="margin:0.5rem 0;color:#aaa">يضيف لاعبين ومبيعات وأحداث تجريبية</p>
      <form method="POST"><input type="hidden" name="step" value="4"><button type="submit">إدخال البيانات</button></form>
    </div>
    <?php endif; ?>

    <?php if ($step >= 5): ?>
    <div class="alert alert-success">
      <strong>✓ التثبيت مكتمل!</strong>
      <p style="margin-top:0.5rem">يمكنك الآن <a href="login.php" style="color:#00E5FF;font-weight:700">تسجيل الدخول</a> إلى لوحة الإدارة.</p>
    </div>
    <div class="warning">
      <strong>⚠️ للأمان:</strong> احذف ملف <code>install.php</code> فوراً بعد التثبيت.
    </div>
    <?php endif; ?>
  </div>
</body>
</html>