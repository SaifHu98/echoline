<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = I18n::t('reports.title');
$currentSection = 'reports';

$statusFilter = Security::input('status', 'open', 'string');

$where = '1=1';
$params = [];
if ($statusFilter && in_array($statusFilter, ['open', 'investigating', 'resolved', 'dismissed'], true)) {
    $where .= ' AND r.status = ?';
    $params[] = $statusFilter;
}

$reports = Database::fetchAll(
    "SELECT r.*, p1.display_name AS reporter_name, p2.display_name AS target_name
     FROM reports r
     LEFT JOIN players p1 ON p1.player_uid = r.reporter_uid
     LEFT JOIN players p2 ON p2.player_uid = r.target_uid
     WHERE {$where}
     ORDER BY r.created_at DESC LIMIT 100",
    $params
);

if ($_SERVER['REQUEST_METHOD'] === 'POST' && Security::verifyCsrf(Security::input(CSRF_TOKEN_NAME))) {
    $reportId = (int) Security::input('report_id', 0, 'int');
    $status = Security::input('new_status', '', 'string');
    $note = Security::input('note', '', 'string');
    if ($reportId && in_array($status, ['investigating', 'resolved', 'dismissed'], true)) {
        Database::update('reports', [
            'status' => $status,
            'resolution_note' => $note,
            'handled_by' => Auth::id(),
            'resolved_at' => $status !== 'investigating' ? date('Y-m-d H:i:s') : null,
        ], 'id = ?', [$reportId]);
        Audit::log(Auth::id(), 'report.' . $status, 'report', (string) $reportId, ['note' => $note]);
        Response::redirect('reports.php?status=' . $statusFilter);
    }
}

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('reports.title') ?></h1>
  <div class="filter-pills">
    <a href="?status=open" class="pill <?= $statusFilter === 'open' ? 'active' : '' ?>">مفتوحة</a>
    <a href="?status=investigating" class="pill <?= $statusFilter === 'investigating' ? 'active' : '' ?>">قيد التحقيق</a>
    <a href="?status=resolved" class="pill <?= $statusFilter === 'resolved' ? 'active' : '' ?>">محلولة</a>
    <a href="?status=dismissed" class="pill <?= $statusFilter === 'dismissed' ? 'active' : '' ?>">مرفوضة</a>
  </div>
</div>

<div class="panel">
  <table class="data-table">
    <thead>
      <tr><th>#</th><th>المُبلِغ</th><th>المُبلَّغ عنه</th><th>السبب</th><th>الوصف</th><th>المباراة</th><th>التاريخ</th><th>الحالة</th><th>إجراء</th></tr>
    </thead>
    <tbody>
      <?php if (empty($reports)): ?>
        <tr><td colspan="9" class="text-center text-muted">لا توجد بلاغات</td></tr>
      <?php else: foreach ($reports as $r): ?>
        <tr>
          <td>#<?= $r['id'] ?></td>
          <td><?= Security::escape($r['reporter_name'] ?? $r['reporter_uid']) ?></td>
          <td><?= Security::escape($r['target_name'] ?? $r['target_uid']) ?></td>
          <td><span class="badge"><?= Security::escape($r['reason']) ?></span></td>
          <td class="text-muted small"><?= Security::escape(mb_substr($r['description'] ?? '', 0, 80)) ?></td>
          <td class="text-muted small"><?= Security::escape($r['match_id'] ?? '—') ?></td>
          <td class="text-muted small"><?= Security::escape($r['created_at']) ?></td>
          <td><span class="badge badge-<?= $r['status'] === 'resolved' ? 'ok' : ($r['status'] === 'dismissed' ? 'pending' : 'warn') ?>"><?= Security::escape($r['status']) ?></span></td>
          <td>
            <button class="btn small" onclick='handleReport(<?= json_encode($r, JSON_HEX_APOS | JSON_HEX_QUOT) ?>)'>معالجة</button>
          </td>
        </tr>
      <?php endforeach; endif; ?>
    </tbody>
  </table>
</div>

<div id="report-modal" class="modal" hidden>
  <div class="modal-content">
    <h2>معالجة البلاغ #<span id="report-id-display"></span></h2>
    <div id="report-details"></div>
    <form method="POST">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="report_id" id="rpt-id">
      <div class="form-group">
        <label>الإجراء</label>
        <select name="new_status">
          <option value="investigating">قيد التحقيق</option>
          <option value="resolved">محلول + حظر اللاعب</option>
          <option value="dismissed">مرفوض</option>
        </select>
      </div>
      <div class="form-group">
        <label>ملاحظة المعالجة</label>
        <textarea name="note" rows="3" required></textarea>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="document.getElementById('report-modal').hidden=true">إلغاء</button>
        <button type="submit" class="btn primary">حفظ</button>
      </div>
    </form>
  </div>
</div>

<script>
function handleReport(r) {
  document.getElementById('report-modal').hidden = false;
  document.getElementById('report-id-display').textContent = r.id;
  document.getElementById('rpt-id').value = r.id;
  document.getElementById('report-details').innerHTML = `
    <div class="report-meta">
      <p><strong>السبب:</strong> ${r.reason}</p>
      <p><strong>الوصف:</strong> ${r.description || '—'}</p>
      <p><strong>المباراة:</strong> ${r.match_id || '—'}</p>
      <p><strong>التاريخ:</strong> ${r.created_at}</p>
    </div>
  `;
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>