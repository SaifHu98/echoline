<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = I18n::t('receipts.title');
$currentSection = 'receipts';

$platform = Security::input('platform', '', 'string');
$result = Security::input('result', '', 'string');

$where = '1=1';
$params = [];
if ($platform) { $where .= ' AND platform = ?'; $params[] = $platform; }
if ($result) { $where .= ' AND validation_result = ?'; $params[] = $result; }

$receipts = Database::fetchAll(
    "SELECT * FROM receipt_verifications WHERE {$where} ORDER BY created_at DESC LIMIT 100",
    $params
);

// Validation stats
$stats = Database::fetch(
    "SELECT
       COUNT(*) AS total,
       SUM(validation_result = 'valid') AS valid,
       SUM(validation_result = 'invalid') AS invalid,
       SUM(validation_result = 'duplicate') AS duplicate,
       SUM(validation_result = 'fraud') AS fraud
     FROM receipt_verifications WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)"
);

$salesStats = Database::fetch(
    "SELECT COUNT(*) AS txns, SUM(amount_usd) AS total FROM sales_log
     WHERE status = 'verified' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)"
);

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('receipts.title') ?></h1>
</div>

<div class="grid-stats">
  <div class="stat-card stat-cyan"><div class="stat-label">إجمالي التحقق (30 يوم)</div><div class="stat-val"><?= number_format($stats['total']) ?></div></div>
  <div class="stat-card stat-green"><div class="stat-label">صالح</div><div class="stat-val"><?= number_format($stats['valid']) ?></div></div>
  <div class="stat-card stat-violet"><div class="stat-label">مكرر</div><div class="stat-val"><?= number_format($stats['duplicate']) ?></div></div>
  <div class="stat-card stat-red"><div class="stat-label">احتيال/فشل</div><div class="stat-val"><?= number_format(($stats['fraud'] ?? 0) + ($stats['invalid'] ?? 0)) ?></div></div>
  <div class="stat-card stat-amber"><div class="stat-label">مبيعات مؤكدة (30 يوم)</div><div class="stat-val">$<?= number_format($salesStats['total'], 2) ?></div><div class="stat-sub"><?= number_format($salesStats['txns']) ?> معاملة</div></div>
</div>

<div class="panel">
  <form method="GET" class="filter-bar">
    <select name="platform">
      <option value="">جميع المنصات</option>
      <option value="google_play" <?= $platform === 'google_play' ? 'selected' : '' ?>>Google Play</option>
      <option value="app_store" <?= $platform === 'app_store' ? 'selected' : '' ?>>App Store</option>
      <option value="huawei" <?= $platform === 'huawei' ? 'selected' : '' ?>>Huawei</option>
      <option value="amazon" <?= $platform === 'amazon' ? 'selected' : '' ?>>Amazon</option>
    </select>
    <select name="result">
      <option value="">جميع النتائج</option>
      <option value="valid" <?= $result === 'valid' ? 'selected' : '' ?>>صالح</option>
      <option value="invalid" <?= $result === 'invalid' ? 'selected' : '' ?>>غير صالح</option>
      <option value="duplicate" <?= $result === 'duplicate' ? 'selected' : '' ?>>مكرر</option>
      <option value="fraud" <?= $result === 'fraud' ? 'selected' : '' ?>>احتيال</option>
    </select>
    <button class="btn primary">تصفية</button>
  </form>

  <table class="data-table">
    <thead>
      <tr><th>#</th><th>المنصة</th><th>المنتج</th><th>رقم المعاملة</th><th>النتيجة</th><th>الرسالة</th><th>التاريخ</th></tr>
    </thead>
    <tbody>
      <?php foreach ($receipts as $r): ?>
        <tr>
          <td>#<?= $r['id'] ?></td>
          <td><span class="badge"><?= Security::escape($r['platform']) ?></span></td>
          <td><code><?= Security::escape($r['product_id'] ?? '—') ?></code></td>
          <td><code class="small text-muted"><?= Security::escape(mb_substr($r['transaction_id'] ?? '—', 0, 30)) ?></code></td>
          <td>
            <span class="badge badge-<?= $r['validation_result'] === 'valid' ? 'ok' : ($r['validation_result'] === 'fraud' || $r['validation_result'] === 'invalid' ? 'danger' : 'pending') ?>">
              <?= Security::escape($r['validation_result']) ?>
            </span>
          </td>
          <td class="text-muted small"><?= Security::escape($r['validation_message'] ?? '') ?></td>
          <td class="text-muted small"><?= Security::escape($r['created_at']) ?></td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>