<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = I18n::t('audit.title');
$currentSection = 'audit';

$action = Security::input('action', '', 'string');
$admin = (int) Security::input('admin_id', 0, 'int');

$where = '1=1';
$params = [];
if ($action) { $where .= ' AND a.action LIKE ?'; $params[] = "%{$action}%"; }
if ($admin) { $where .= ' AND a.admin_id = ?'; $params[] = $admin; }

$page = max(1, (int) Security::input('page', 1, 'int'));
$perPage = 50;
$offset = ($page - 1) * $perPage;
$total = (int) Database::fetch("SELECT COUNT(*) AS c FROM audit_log a WHERE {$where}", $params)['c'];

$logs = Database::fetchAll(
    "SELECT a.*, ad.username FROM audit_log a
     LEFT JOIN admins ad ON ad.id = a.admin_id
     WHERE {$where}
     ORDER BY a.created_at DESC LIMIT {$perPage} OFFSET {$offset}",
    $params
);

$admins = Database::fetchAll('SELECT id, username, role FROM admins ORDER BY username');

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('audit.title') ?> <span class="text-muted">(<?= number_format($total) ?>)</span></h1>
</div>

<div class="panel">
  <form method="GET" class="filter-bar">
    <input type="text" name="action" value="<?= Security::escape($action) ?>" placeholder="بحث في الإجراء">
    <select name="admin_id">
      <option value="">كل المديرين</option>
      <?php foreach ($admins as $a): ?>
        <option value="<?= $a['id'] ?>" <?= $admin === (int)$a['id'] ? 'selected' : '' ?>>
          <?= Security::escape($a['username']) ?> (<?= Security::escape($a['role']) ?>)
        </option>
      <?php endforeach; ?>
    </select>
    <button class="btn primary">تصفية</button>
  </form>

  <table class="data-table">
    <thead>
      <tr><th>#</th><th>المدير</th><th>الإجراء</th><th>الكيان</th><th>التفاصيل</th><th>IP</th><th>التاريخ</th></tr>
    </thead>
    <tbody>
      <?php foreach ($logs as $l): ?>
        <tr>
          <td>#<?= $l['id'] ?></td>
          <td><?= Security::escape($l['username'] ?? '—') ?></td>
          <td><code><?= Security::escape($l['action']) ?></code></td>
          <td class="text-muted small"><?= Security::escape(($l['entity_type'] ?? '') . ($l['entity_id'] ? ' #' . $l['entity_id'] : '')) ?></td>
          <td class="text-muted small" style="max-width:300px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">
            <?= Security::escape($l['details'] ?? '') ?>
          </td>
          <td class="text-muted small"><?= Security::escape($l['ip_address'] ?? '—') ?></td>
          <td class="text-muted small"><?= Security::escape($l['created_at']) ?></td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>

  <?php if ($total > $perPage): ?>
    <div class="pagination">
      <?php for ($i = 1; $i <= ceil($total / $perPage); $i++): ?>
        <a href="?page=<?= $i ?>&action=<?= urlencode($action) ?>&admin_id=<?= $admin ?>"
           class="btn small <?= $i === $page ? 'primary' : '' ?>"><?= $i ?></a>
      <?php endfor; ?>
    </div>
  <?php endif; ?>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>