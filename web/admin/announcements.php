<?php
require_once __DIR__ . '/config.php';
Auth::require();
require_once __DIR__ . '/includes/Crud.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Crud::handle('announcements', [
        ['name' => 'title', 'required' => true, 'sanitize' => true],
        ['name' => 'body', 'required' => true],
        ['name' => 'language', 'required' => true],
        ['name' => 'type', 'required' => true],
        ['name' => 'target_platform'],
        ['name' => 'target_min_version'],
        ['name' => 'is_active', 'required' => true],
        ['name' => 'start_at'],
        ['name' => 'end_at'],
    ], 'announcements.php');
    exit;
}

$pageTitle = I18n::t('announce.title');
$currentSection = 'announcements';
$announcements = Database::fetchAll('SELECT * FROM announcements ORDER BY is_active DESC, created_at DESC LIMIT 50');

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('announce.title') ?></h1>
  <button class="btn primary" onclick="openAnnForm()">+ إعلان جديد</button>
</div>

<div class="panel">
  <table class="data-table">
    <thead>
      <tr><th>العنوان</th><th>النوع</th><th>اللغة</th><th>الفترة</th><th>الحالة</th><th>التاريخ</th><th>الإجراءات</th></tr>
    </thead>
    <tbody>
      <?php foreach ($announcements as $a): ?>
        <tr>
          <td><strong><?= Security::escape($a['title']) ?></strong></td>
          <td><span class="badge"><?= Security::escape($a['type']) ?></span></td>
          <td><code><?= Security::escape($a['language']) ?></code></td>
          <td class="text-muted small">
            <?= $a['start_at'] ? substr($a['start_at'], 0, 16) : '∞' ?>
            →
            <?= $a['end_at'] ? substr($a['end_at'], 0, 16) : '∞' ?>
          </td>
          <td><?= $a['is_active'] ? '<span class="badge badge-ok">نشط</span>' : '<span class="badge">معطل</span>' ?></td>
          <td class="text-muted small"><?= Security::escape($a['created_at']) ?></td>
          <td>
            <button class="btn small" onclick='editAnn(<?= json_encode($a, JSON_HEX_APOS | JSON_HEX_QUOT) ?>)'>تعديل</button>
            <button class="btn small danger" onclick="deleteAnn(<?= $a['id'] ?>)">حذف</button>
          </td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>

<div id="ann-modal" class="modal" hidden>
  <div class="modal-content">
    <h2 id="ann-modal-title">إعلان جديد</h2>
    <form id="ann-form">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="save">
      <input type="hidden" name="id" id="ann-id">
      <div class="form-group">
        <label>العنوان *</label>
        <input type="text" name="title" id="ann-title" required>
      </div>
      <div class="form-group">
        <label>النص *</label>
        <textarea name="body" id="ann-body" rows="4" required></textarea>
      </div>
      <div class="grid-form">
        <div class="form-group">
          <label>اللغة *</label>
          <select name="language" id="ann-lang">
            <option value="en">English</option>
            <option value="ar">العربية</option>
            <option value="both">both</option>
          </select>
        </div>
        <div class="form-group">
          <label>النوع</label>
          <select name="type" id="ann-type">
            <option value="info">معلومات</option>
            <option value="warning">تحذير</option>
            <option value="maintenance">صيانة</option>
            <option value="event">فعالية</option>
            <option value="reward">مكافأة</option>
          </select>
        </div>
        <div class="form-group">
          <label>منصة مستهدفة</label>
          <select name="target_platform" id="ann-platform">
            <option value="">جميع</option>
            <option value="android">Android</option>
            <option value="ios">iOS</option>
          </select>
        </div>
        <div class="form-group">
          <label>أدنى إصدار</label>
          <input type="text" name="target_min_version" id="ann-ver" placeholder="1.0.0">
        </div>
        <div class="form-group">
          <label>تاريخ البدء</label>
          <input type="datetime-local" name="start_at" id="ann-start">
        </div>
        <div class="form-group">
          <label>تاريخ الانتهاء</label>
          <input type="datetime-local" name="end_at" id="ann-end">
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="hidden" name="is_active" value="0">
            <input type="checkbox" name="is_active" id="ann-active" value="1" checked> نشط
          </label>
        </div>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="closeAnn()">إلغاء</button>
        <button type="submit" class="btn primary">حفظ</button>
      </div>
    </form>
  </div>
</div>

<script>
function openAnnForm(a) {
  document.getElementById('ann-modal').hidden = false;
  if (a) {
    document.getElementById('ann-modal-title').textContent = 'تعديل إعلان';
    document.getElementById('ann-id').value = a.id;
    document.getElementById('ann-title').value = a.title;
    document.getElementById('ann-body').value = a.body;
    document.getElementById('ann-lang').value = a.language;
    document.getElementById('ann-type').value = a.type;
    document.getElementById('ann-platform').value = a.target_platform || '';
    document.getElementById('ann-ver').value = a.target_min_version || '';
    document.getElementById('ann-start').value = a.start_at ? a.start_at.replace(' ', 'T').substring(0, 16) : '';
    document.getElementById('ann-end').value = a.end_at ? a.end_at.replace(' ', 'T').substring(0, 16) : '';
    document.getElementById('ann-active').checked = !!a.is_active;
  } else {
    document.getElementById('ann-form').reset();
    document.getElementById('ann-id').value = '';
  }
}
function closeAnn() { document.getElementById('ann-modal').hidden = true; }
function editAnn(a) { openAnnForm(a); }

document.getElementById('ann-form').addEventListener('submit', async e => {
  e.preventDefault();
  const fd = new FormData(e.target);
  const res = await fetch('announcements.php', { method: 'POST', body: fd });
  const j = await res.json();
  if (j.success) { showToast('تم الحفظ', 'success'); setTimeout(() => location.reload(), 500); }
  else showToast(j.error, 'error');
});

async function deleteAnn(id) {
  if (!confirm('حذف الإعلان؟')) return;
  const fd = new FormData();
  fd.append('action', 'delete'); fd.append('id', id); fd.append('_token', document.getElementById('csrf-token').value);
  const res = await fetch('announcements.php', { method: 'POST', body: fd });
  const j = await res.json();
  if (j.success) { showToast('تم الحذف', 'success'); setTimeout(() => location.reload(), 500); }
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>