<?php
require_once __DIR__ . '/config.php';
Auth::requireRole('superadmin');

$pageTitle = I18n::t('admins.title');
$currentSection = 'admins';

$message = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST' && Security::verifyCsrf(Security::input(CSRF_TOKEN_NAME))) {
    $action = Security::input('action');
    try {
        if ($action === 'create') {
            $username = Security::input('username', '', 'string');
            $email = Security::input('email', '', 'string');
            $password = Security::input('password', '', 'string');
            $role = Security::input('role', 'editor', 'string');
            Auth::createAdmin($username, $email, $password, $role);
            Audit::log(Auth::id(), 'admin.create', 'admin', $username);
            $message = 'تم إضافة المدير';
        } elseif ($action === 'reset') {
            $adminId = (int) Security::input('admin_id', 0, 'int');
            $password = Security::input('password', '', 'string');
            Auth::changePassword($adminId, $password);
            Audit::log(Auth::id(), 'admin.password_reset', 'admin', (string) $adminId);
            $message = 'تم تغيير كلمة المرور';
        } elseif ($action === 'toggle') {
            $adminId = (int) Security::input('admin_id', 0, 'int');
            $current = Database::fetch('SELECT is_active FROM admins WHERE id = ?', [$adminId]);
            Database::update('admins', ['is_active' => $current['is_active'] ? 0 : 1], 'id = ?', [$adminId]);
            Audit::log(Auth::id(), 'admin.toggle', 'admin', (string) $adminId);
            $message = 'تم تحديث الحالة';
        }
    } catch (\Throwable $e) {
        $message = $e->getMessage();
    }
}

$admins = Database::fetchAll('SELECT id, username, email, role, is_active, last_login, created_at FROM admins ORDER BY created_at');

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('admins.title') ?></h1>
  <button class="btn primary" onclick="document.getElementById('new-admin-modal').hidden=false">+ مدير جديد</button>
</div>

<?php if ($message): ?>
  <div class="alert alert-info"><?= Security::escape($message) ?></div>
<?php endif; ?>

<div class="panel">
  <table class="data-table">
    <thead>
      <tr><th>#</th><th>اسم المستخدم</th><th>البريد</th><th>الدور</th><th>الحالة</th><th>آخر دخول</th><th>الإجراءات</th></tr>
    </thead>
    <tbody>
      <?php foreach ($admins as $a): ?>
        <tr>
          <td>#<?= $a['id'] ?></td>
          <td><strong><?= Security::escape($a['username']) ?></strong></td>
          <td><?= Security::escape($a['email']) ?></td>
          <td><span class="badge"><?= Security::escape($a['role']) ?></span></td>
          <td>
            <?php if ($a['is_active']): ?><span class="badge badge-ok">نشط</span><?php else: ?><span class="badge danger">معطل</span><?php endif; ?>
          </td>
          <td class="text-muted small"><?= $a['last_login'] ? Security::escape($a['last_login']) : '—' ?></td>
          <td>
            <button class="btn small" onclick="resetPwd(<?= $a['id'] ?>, '<?= Security::escape($a['username']) ?>')">إعادة تعيين كلمة المرور</button>
            <button class="btn small <?= $a['is_active'] ? 'danger' : 'success' ?>" onclick="toggleAdmin(<?= $a['id'] ?>)">
              <?= $a['is_active'] ? 'تعطيل' : 'تفعيل' ?>
            </button>
          </td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>

<div id="new-admin-modal" class="modal" hidden>
  <div class="modal-content">
    <h2>مدير جديد</h2>
    <form method="POST">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="create">
      <div class="form-group">
        <label>اسم المستخدم *</label>
        <input type="text" name="username" required pattern="[a-zA-Z0-9_]+" minlength="3">
      </div>
      <div class="form-group">
        <label>البريد الإلكتروني *</label>
        <input type="email" name="email" required>
      </div>
      <div class="form-group">
        <label>كلمة المرور * (8 أحرف على الأقل)</label>
        <input type="password" name="password" required minlength="8">
      </div>
      <div class="form-group">
        <label>الدور *</label>
        <select name="role">
          <option value="viewer">مشاهد</option>
          <option value="support">دعم</option>
          <option value="editor">محرر</option>
          <option value="superadmin">مدير عام</option>
        </select>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="this.closest('.modal').hidden=true">إلغاء</button>
        <button type="submit" class="btn primary">إضافة</button>
      </div>
    </form>
  </div>
</div>

<div id="reset-modal" class="modal" hidden>
  <div class="modal-content">
    <h2>إعادة تعيين كلمة المرور: <span id="reset-name"></span></h2>
    <form method="POST">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="reset">
      <input type="hidden" name="admin_id" id="reset-admin-id">
      <div class="form-group">
        <label>كلمة المرور الجديدة</label>
        <input type="password" name="password" required minlength="8">
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="this.closest('.modal').hidden=true">إلغاء</button>
        <button type="submit" class="btn primary">تغيير</button>
      </div>
    </form>
  </div>
</div>

<script>
function resetPwd(id, name) {
  document.getElementById('reset-modal').hidden = false;
  document.getElementById('reset-admin-id').value = id;
  document.getElementById('reset-name').textContent = name;
}

function toggleAdmin(id) {
  const f = document.createElement('form');
  f.method = 'POST';
  f.innerHTML = `<input name="_token" value="${document.getElementById('csrf-token').value}">
                 <input name="action" value="toggle">
                 <input name="admin_id" value="${id}">`;
  document.body.appendChild(f); f.submit();
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>