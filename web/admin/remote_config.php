<?php
require_once __DIR__ . '/config.php';
Auth::require();

require_once __DIR__ . '/includes/Crud.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Crud::handle('remote_config', [
        ['name' => 'config_key', 'required' => true, 'sanitize' => true],
        ['name' => 'config_value', 'required' => true, 'json' => true],
        ['name' => 'description'],
        ['name' => 'category'],
        ['name' => 'is_active', 'required' => true],
    ], 'config.php');
    exit;
}

$pageTitle = I18n::t('config.title');
$currentSection = 'config';
$configs = Database::fetchAll('SELECT * FROM remote_config ORDER BY category, config_key');

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('config.title') ?></h1>
  <button class="btn primary" onclick="openConfigForm()">+ إعداد جديد</button>
</div>

<div class="panel">
  <p class="text-muted">اللعبة تقرأ هذه الإعدادات عند الإقلاع. يمكنك تعديلها دون إصدار تحديث.</p>
  <table class="data-table">
    <thead>
      <tr><th>الفئة</th><th>المفتاح</th><th>القيمة</th><th>الوصف</th><th>الحالة</th><th>الإجراءات</th></tr>
    </thead>
    <tbody>
      <?php foreach ($configs as $c): ?>
        <tr>
          <td><span class="badge"><?= Security::escape($c['category']) ?></span></td>
          <td><code><?= Security::escape($c['config_key']) ?></code></td>
          <td><code class="json-val"><?= Security::escape(mb_strimwidth($c['config_value'] ?? '', 0, 80, '...')) ?></code></td>
          <td class="text-muted"><?= Security::escape($c['description'] ?? '') ?></td>
          <td>
            <?php if ($c['is_active']): ?><span class="badge badge-ok">نشط</span><?php else: ?><span class="badge">معطل</span><?php endif; ?>
          </td>
          <td>
            <button class="btn small" onclick='editCfg(<?= json_encode($c, JSON_HEX_APOS | JSON_HEX_QUOT) ?>)'>تعديل</button>
            <button class="btn small danger" onclick="deleteCfg(<?= $c['id'] ?>)">حذف</button>
          </td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>

<div id="cfg-modal" class="modal" hidden>
  <div class="modal-content">
    <h2 id="cfg-modal-title">إعداد جديد</h2>
    <form id="cfg-form">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="save">
      <input type="hidden" name="id" id="cfg-id">
      <div class="form-group">
        <label><?= I18n::t('config.key') ?> *</label>
        <input type="text" name="config_key" id="cfg-key" required pattern="[a-z0-9_.]+">
      </div>
      <div class="form-group">
        <label><?= I18n::t('config.value') ?> *</label>
        <textarea name="config_value" id="cfg-val" rows="6" required></textarea>
      </div>
      <div class="form-group">
        <label>الوصف</label>
        <input type="text" name="description" id="cfg-desc">
      </div>
      <div class="form-group">
        <label><?= I18n::t('config.category') ?></label>
        <select name="category" id="cfg-cat">
          <option value="general">general</option>
          <option value="gameplay">gameplay</option>
          <option value="echo_system">echo_system</option>
          <option value="catastrophe">catastrophe</option>
          <option value="shop">shop</option>
          <option value="liveops">liveops</option>
          <option value="system">system</option>
          <option value="localization">localization</option>
        </select>
      </div>
      <div class="form-group">
        <label class="checkbox-label">
          <input type="hidden" name="is_active" value="0">
          <input type="checkbox" name="is_active" id="cfg-active" value="1" checked> <?= I18n::t('common.active') ?>
        </label>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="closeCfgForm()">إلغاء</button>
        <button type="submit" class="btn primary">حفظ</button>
      </div>
    </form>
  </div>
</div>

<script>
function openConfigForm(c) {
  document.getElementById('cfg-modal').hidden = false;
  if (c) {
    document.getElementById('cfg-modal-title').textContent = 'تعديل: ' + c.config_key;
    document.getElementById('cfg-id').value = c.id;
    document.getElementById('cfg-key').value = c.config_key;
    document.getElementById('cfg-key').readOnly = true;
    document.getElementById('cfg-val').value = c.config_value;
    document.getElementById('cfg-desc').value = c.description || '';
    document.getElementById('cfg-cat').value = c.category;
    document.getElementById('cfg-active').checked = !!c.is_active;
  } else {
    document.getElementById('cfg-form').reset();
    document.getElementById('cfg-id').value = '';
    document.getElementById('cfg-key').readOnly = false;
  }
}
function closeCfgForm() { document.getElementById('cfg-modal').hidden = true; }
function editCfg(c) { openConfigForm(c); }

document.getElementById('cfg-form').addEventListener('submit', async e => {
  e.preventDefault();
  try { JSON.parse(document.getElementById('cfg-val').value); }
  catch (err) { return showToast('JSON غير صالح: ' + err.message, 'error'); }
  const fd = new FormData(e.target);
  const res = await fetch('remote_config.php', { method: 'POST', body: fd });
  const j = await res.json();
  if (j.success) { showToast('تم الحفظ', 'success'); setTimeout(() => location.reload(), 600); }
  else showToast(j.error, 'error');
});

async function deleteCfg(id) {
  if (!confirm('حذف؟')) return;
  const fd = new FormData();
  fd.append('action', 'delete'); fd.append('id', id); fd.append('_token', document.getElementById('csrf-token').value);
  const res = await fetch('remote_config.php', { method: 'POST', body: fd });
  const j = await res.json();
  if (j.success) { showToast('تم الحذف', 'success'); setTimeout(() => location.reload(), 500); }
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>