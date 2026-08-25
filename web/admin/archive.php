<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = 'أرشيف المبيعات';
$currentSection = 'tools';

$message = null;
$messageType = 'success';

// === Handle archive sales action (called from dashboard) ===
if (Security::input('action') === 'sales_archive' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    // Will be handled below
}

// === Handle form submissions ===
if ($_SERVER['REQUEST_METHOD'] === 'POST' && Security::verifyCsrf(Security::input(CSRF_TOKEN_NAME))) {
    $action = Security::input('action', '', 'string');

    if ($action === 'archive_sales') {
        try {
            $reason = Security::input('reason', '', 'string') ?: 'Admin archive';
            $periodStart = Security::input('period_start') ?: null;
            $periodEnd = Security::input('period_end') ?: null;
            $includePending = (bool) Security::input('include_pending', false, 'bool');

            $where = '1=1';
            $params = [];
            if ($periodStart) { $where .= ' AND created_at >= ?'; $params[] = $periodStart; }
            if ($periodEnd) { $where .= ' AND created_at <= ?'; $params[] = $periodEnd; }
            if (!$includePending) { $where .= " AND status = 'verified'"; }

            // Fetch all matching sales
            $sales = Database::fetchAll("SELECT * FROM sales_log WHERE {$where} ORDER BY created_at", $params);
            $totalCount = count($sales);
            $totalAmount = array_sum(array_column($sales, 'amount_usd'));
            $verified = count(array_filter($sales, fn($s) => $s['status'] === 'verified'));
            $pending = count(array_filter($sales, fn($s) => $s['status'] === 'pending'));
            $refunded = count(array_filter($sales, fn($s) => $s['status'] === 'refunded'));

            // Aggregate by platform
            $platforms = [];
            $skus = [];
            $players = [];
            foreach ($sales as $s) {
                $platforms[$s['platform']] = ($platforms[$s['platform']] ?? 0) + 1;
                $skus[$s['sku']] = ($skus[$s['sku']] ?? 0) + 1;
                $players[$s['player_id']] = ($players[$s['player_id']] ?? 0) + 1;
            }

            // Create archive entry
            $archiveUid = 'arch_' . date('Ymd_His') . '_' . substr(bin2hex(random_bytes(4)), 0, 6);
            Database::transaction(function($pdo) use ($sales, $archiveUid, $reason, $periodStart, $periodEnd, $totalCount, $totalAmount, $verified, $pending, $refunded, $platforms, $skus, $players) {
                Database::insert('sales_archive', [
                    'archive_uid' => $archiveUid,
                    'archived_by' => Auth::id(),
                    'archived_reason' => $reason,
                    'archive_period_start' => $periodStart,
                    'archive_period_end' => $periodEnd,
                    'total_records' => $totalCount,
                    'total_amount_usd' => $totalAmount,
                    'total_verified' => $verified,
                    'total_pending' => $pending,
                    'total_refunded' => $refunded,
                    'platforms_json' => json_encode($platforms, JSON_UNESCAPED_UNICODE),
                    'skus_json' => json_encode($skus, JSON_UNESCAPED_UNICODE),
                    'players_json' => json_encode(array_keys($players), JSON_UNESCAPED_UNICODE),
                    'data_json' => json_encode($sales, JSON_UNESCAPED_UNICODE),
                ]);
            });

            Audit::log(Auth::id(), 'sales.archive', 'archive', $archiveUid, [
                'records' => $totalCount,
                'amount' => $totalAmount,
                'reason' => $reason,
            ]);

            $message = "تم إنشاء الأرشيف $archiveUid ($totalCount سجل، $" . number_format($totalAmount, 2) . ")";
            $messageType = 'success';
        } catch (\Throwable $e) {
            $message = 'خطأ: ' . $e->getMessage();
            $messageType = 'error';
        }
    }
    elseif ($action === 'archive_and_reset') {
        try {
            $reason = Security::input('reason', '', 'string') ?: 'Reset by admin';
            $includePending = (bool) Security::input('include_pending', false, 'bool');

            $where = '1=1';
            $params = [];
            if (!$includePending) { $where .= " AND status = 'verified'"; }

            $sales = Database::fetchAll("SELECT * FROM sales_log WHERE {$where}", $params);
            $totalCount = count($sales);
            $totalAmount = array_sum(array_column($sales, 'amount_usd'));
            $verified = count(array_filter($sales, fn($s) => $s['status'] === 'verified'));
            $pending = count(array_filter($sales, fn($s) => $s['status'] === 'pending'));
            $refunded = count(array_filter($sales, fn($s) => $s['status'] === 'refunded'));

            $platforms = [];
            $skus = [];
            $players = [];
            foreach ($sales as $s) {
                $platforms[$s['platform']] = ($platforms[$s['platform']] ?? 0) + 1;
                $skus[$s['sku']] = ($skus[$s['sku']] ?? 0) + 1;
                $players[$s['player_id']] = ($players[$s['player_id']] ?? 0) + 1;
            }

            $archiveUid = 'arch_' . date('Ymd_His') . '_' . substr(bin2hex(random_bytes(4)), 0, 6);

            Database::transaction(function($pdo) use ($sales, $archiveUid, $reason, $totalCount, $totalAmount, $verified, $pending, $refunded, $platforms, $skus, $players, $where, $params) {
                Database::insert('sales_archive', [
                    'archive_uid' => $archiveUid,
                    'archived_by' => Auth::id(),
                    'archived_reason' => $reason,
                    'archive_period_start' => null,
                    'archive_period_end' => null,
                    'total_records' => $totalCount,
                    'total_amount_usd' => $totalAmount,
                    'total_verified' => $verified,
                    'total_pending' => $pending,
                    'total_refunded' => $refunded,
                    'platforms_json' => json_encode($platforms, JSON_UNESCAPED_UNICODE),
                    'skus_json' => json_encode($skus, JSON_UNESCAPED_UNICODE),
                    'players_json' => json_encode(array_keys($players), JSON_UNESCAPED_UNICODE),
                    'data_json' => json_encode($sales, JSON_UNESCAPED_UNICODE),
                ]);

                // Now delete the sales
                $stmt = $pdo->prepare("DELETE FROM sales_log WHERE {$where}");
                $stmt->execute($params);

                // Also clear receipt_verifications
                $pdo->query("DELETE FROM receipt_verifications WHERE created_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)");
            });

            Audit::log(Auth::id(), 'sales.archive_and_reset', 'archive', $archiveUid, [
                'records' => $totalCount,
                'amount' => $totalAmount,
                'reason' => $reason,
            ]);

            $message = "✅ تم أرشفة وتصفير $totalCount سجل بقيمة $" . number_format($totalAmount, 2) . " — الأرشيف: $archiveUid";
            $messageType = 'success';
        } catch (\Throwable $e) {
            $message = 'خطأ: ' . $e->getMessage();
            $messageType = 'error';
        }
    }
    elseif ($action === 'reset_only') {
        try {
            $count = Database::query("DELETE FROM sales_log")->rowCount();
            Database::query("DELETE FROM receipt_verifications WHERE created_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)")->rowCount();
            Audit::log(Auth::id(), 'sales.reset_no_archive', null, null, ['deleted' => $count]);
            $message = "⚠️ تم حذف $count سجل نهائياً (بدون أرشفة)";
            $messageType = 'warn';
        } catch (\Throwable $e) {
            $message = 'خطأ: ' . $e->getMessage();
            $messageType = 'error';
        }
    }
}

// === Load archives ===
$archives = Database::fetchAll(
    'SELECT a.*, ad.username FROM sales_archive a
     LEFT JOIN admins ad ON ad.id = a.archived_by
     ORDER BY a.created_at DESC LIMIT 30'
);

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <div>
    <h1><span class="ic">📦</span> أرشيف المبيعات</h1>
    <p class="page-sub">احفظ السجلات قبل التصفير، أو ارجع لأرشيفات سابقة</p>
  </div>
  <a href="tools.php" class="btn">← العودة للأدوات</a>
</div>

<?php if ($message): ?>
  <div class="alert <?= $messageType === 'error' ? 'error' : ($messageType === 'warn' ? 'warn' : 'success') ?>">
    <?= Security::escape($message) ?>
  </div>
<?php endif; ?>

<!-- ==== Archive creation form ==== -->
<div class="panel">
  <div class="panel-header">
    <h3><span class="ic">📥</span> إنشاء أرشيف جديد</h3>
  </div>

  <div class="two-col">
    <form method="POST" style="background: rgba(255,255,255,0.03); padding: 1.25rem; border-radius: var(--r-md);">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="archive_sales">

      <h4 style="margin-block-end: 0.75rem;">📋 أرشفة فقط (بدون حذف)</h4>
      <p class="text-sm text-muted mb-2">ينشئ نسخة احتياطية من المبيعات في جدول الأرشيف دون التأثير على sales_log.</p>

      <div class="form-group">
        <label class="field-label">السبب <span class="req">*</span></label>
        <input type="text" name="reason" class="input" placeholder="مثال: نهاية الموسم" required>
      </div>

      <div class="form-grid">
        <div class="form-group">
          <label class="field-label">من تاريخ</label>
          <input type="datetime-local" name="period_start" class="input">
        </div>
        <div class="form-group">
          <label class="field-label">إلى تاريخ</label>
          <input type="datetime-local" name="period_end" class="input">
        </div>
      </div>

      <label class="checkbox-row">
        <input type="checkbox" name="include_pending" value="1">
        <span>تضمين السجلات المعلقة</span>
      </label>

      <button type="submit" class="btn primary block mt-2">📥 إنشاء الأرشيف</button>
    </form>

    <form method="POST" style="background: rgba(255, 167, 38, 0.05); padding: 1.25rem; border-radius: var(--r-md); border: 1px solid rgba(255, 167, 38, 0.3);">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="archive_and_reset">

      <h4 style="margin-block-end: 0.75rem; color: var(--c-amber);">⚡ أرشفة + تصفير</h4>
      <p class="text-sm text-muted mb-2">ينشئ الأرشيف ثم يحذف السجلات. اللوحة ستبدأ من الصفر بعد ذلك.</p>

      <div class="form-group">
        <label class="field-label">السبب <span class="req">*</span></label>
        <input type="text" name="reason" class="input" placeholder="مثال: تصفير شهري" required>
      </div>

      <label class="checkbox-row">
        <input type="checkbox" name="include_pending" value="1">
        <span>تضمين السجلات المعلقة</span>
      </label>

      <button type="submit" class="btn block mt-2" style="background: var(--c-amber); color: #1a1206; font-weight: 700;" onclick="return confirm('سيتم أرشفة كل المبيعات وتصفيرها نهائياً. متابعة؟')">
        ⚡ أرشفة وتصفير
      </button>
    </form>
  </div>

  <form method="POST" style="margin-block-start: 1.25rem; padding-block-start: 1.25rem; border-block-start: 1px solid var(--b-soft);">
    <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
    <input type="hidden" name="action" value="reset_only">
    <h4 style="color: var(--c-red);">⚠️ حذف بدون أرشفة (إجراء خطير)</h4>
    <p class="text-sm text-muted mb-2">يحذف كل سجلات المبيعات والإيصالات الحديثة نهائياً بدون أرشفة. لا يمكن التراجع.</p>
    <button type="submit" class="btn danger" onclick="return confirm('🚨 حذف كل المبيعات نهائياً بدون أرشفة؟')">
      🗑️ حذف بدون أرشفة
    </button>
  </form>
</div>

<!-- ==== Archives list ==== -->
<div class="panel">
  <div class="panel-header">
    <h3><span class="ic">🗂️</span> الأرشيفات السابقة (<?= count($archives) ?>)</h3>
  </div>

  <?php if (empty($archives)): ?>
    <p class="text-muted text-center" style="padding-block: 2rem;">لا توجد أرشيفات بعد</p>
  <?php else: ?>
    <div class="table-wrap">
      <table class="data-table">
        <thead>
          <tr>
            <th>المعرّف</th>
            <th>التاريخ</th>
            <th>المؤرشف</th>
            <th>السبب</th>
            <th>السجلات</th>
            <th>المبلغ</th>
            <th>منصات</th>
            <th>إجراء</th>
          </tr>
        </thead>
        <tbody>
          <?php foreach ($archives as $a):
            $platforms = $a['platforms_json'] ? json_decode($a['platforms_json'], true) : [];
            $platformsText = [];
            foreach ($platforms as $p => $c) $platformsText[] = "$p:$c";
            ?>
            <tr>
              <td><code class="small"><?= Security::escape($a['archive_uid']) ?></code></td>
              <td class="text-sm"><?= Security::escape($a['created_at']) ?></td>
              <td><?= Security::escape($a['username'] ?? '—') ?></td>
              <td class="text-sm"><?= Security::escape($a['archived_reason'] ?? '—') ?></td>
              <td class="text-end font-bold"><?= number_format($a['total_records']) ?></td>
              <td class="text-end font-bold text-amber">$<?= number_format($a['total_amount_usd'], 2) ?></td>
              <td class="text-xs text-muted"><?= Security::escape(implode(', ', $platformsText)) ?></td>
              <td class="actions-cell">
                <a href="archive_download.php?uid=<?= urlencode($a['archive_uid']) ?>" class="btn small">⬇ JSON</a>
              </td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  <?php endif; ?>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>