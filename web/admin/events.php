<?php
require_once __DIR__ . '/config.php';
Auth::require();

require_once __DIR__ . '/includes/Crud.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Crud::handle('events', [
        ['name' => 'event_uid', 'required' => true, 'sanitize' => true],
        ['name' => 'title_key', 'required' => true, 'sanitize' => true],
        ['name' => 'description_key', 'sanitize' => true],
        ['name' => 'event_type'],
        ['name' => 'scenario_id'],
        ['name' => 'start_at'],
        ['name' => 'end_at'],
        ['name' => 'is_active', 'required' => true],
        ['name' => 'is_featured', 'required' => true],
        ['name' => 'reward_currency', 'required' => true],
        ['name' => 'reward_xp', 'required' => true],
        ['name' => 'reward_cosmetic_id', 'sanitize' => true],
        ['name' => 'config_json', 'json' => true],
        ['name' => 'banner_image'],
    ], 'events.php');
    exit;
}

$pageTitle = I18n::t('events.title');
$currentSection = 'events';

$events = Database::fetchAll(
    'SELECT e.*,
            (SELECT COUNT(*) FROM analytics_events WHERE event_name = e.event_uid) AS plays
     FROM events e
     ORDER BY e.is_active DESC, e.start_at DESC'
);

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('events.title') ?></h1>
  <button class="btn primary" onclick="openEventForm()">+ <?= I18n::t('events.create') ?></button>
</div>

<div class="panel">
  <table class="data-table">
    <thead>
      <tr>
        <th>المعرّف</th>
        <th><?= I18n::t('events.title_key') ?></th>
        <th><?= I18n::t('events.type') ?></th>
        <th><?= I18n::t('events.scenario') ?></th>
        <th>من</th>
        <th>إلى</th>
        <th>المكافآت</th>
        <th>مرات اللعب</th>
        <th>الحالة</th>
        <th><?= I18n::t('common.actions') ?></th>
      </tr>
    </thead>
    <tbody>
      <?php foreach ($events as $e): ?>
        <tr>
          <td><code><?= Security::escape($e['event_uid']) ?></code></td>
          <td><strong><?= Security::escape($e['title_key']) ?></strong></td>
          <td><span class="badge"><?= Security::escape($e['event_type']) ?></span></td>
          <td><?= Security::escape($e['scenario_id']) ?></td>
          <td class="text-muted small"><?= Security::escape($e['start_at']) ?></td>
          <td class="text-muted small"><?= Security::escape($e['end_at']) ?></td>
          <td>
            <span class="text-amber">💎 <?= $e['reward_currency'] ?></span>
            <span class="text-cyan">⭐ <?= $e['reward_xp'] ?></span>
          </td>
          <td><?= number_format($e['plays']) ?></td>
          <td>
            <?php if ($e['is_active']): ?>
              <span class="badge badge-ok">نشط</span>
            <?php else: ?>
              <span class="badge">معطل</span>
            <?php endif; ?>
            <?php if ($e['is_featured']): ?>
              <span class="badge featured">⭐ مميز</span>
            <?php endif; ?>
          </td>
          <td>
            <button class="btn small" onclick='editEvent(<?= json_encode($e, JSON_HEX_APOS | JSON_HEX_QUOT) ?>)'>تعديل</button>
            <button class="btn small danger" onclick="deleteEvent(<?= $e['id'] ?>)">حذف</button>
          </td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>

<!-- Modal Form -->
<div id="event-modal" class="modal" hidden>
  <div class="modal-content">
    <h2 id="modal-title"><?= I18n::t('events.create') ?></h2>
    <form id="event-form">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="save">
      <input type="hidden" name="id" id="event-id">

      <div class="grid-form">
        <div class="form-group">
          <label><?= I18n::t('events.event_uid') ?> *</label>
          <input type="text" name="event_uid" id="ev-uid" required pattern="[a-z0-9_]+">
        </div>
        <div class="form-group">
          <label><?= I18n::t('events.title_key') ?> *</label>
          <input type="text" name="title_key" id="ev-title" required placeholder="liveops.event.title">
        </div>
        <div class="form-group">
          <label><?= I18n::t('events.desc_key') ?></label>
          <input type="text" name="description_key" id="ev-desc" placeholder="liveops.event.desc">
        </div>
        <div class="form-group">
          <label><?= I18n::t('events.type') ?></label>
          <select name="event_type" id="ev-type">
            <option value="tournament">بطولة</option>
            <option value="seasonal_quest">مهمة موسمية</option>
            <option value="chronal_expedition">استكشاف زمني</option>
            <option value="limited_challenge">تحدي محدود</option>
            <option value="community_event">فعالية مجتمعية</option>
          </select>
        </div>
        <div class="form-group">
          <label><?= I18n::t('events.scenario') ?></label>
          <select name="scenario_id" id="ev-scenario">
            <option value="clocktower_district">حي برج الساعة</option>
            <option value="subterranean_vaults">السراديب السفلية</option>
            <option value="sunken_aqueduct">القناة المائية الغارقة</option>
            <option value="chrono_observatory">مرصد الزمن الفلكي</option>
            <option value="shattered_bastion">الحصن الممزق</option>
          </select>
        </div>
        <div class="form-group">
          <label><?= I18n::t('events.start') ?></label>
          <input type="datetime-local" name="start_at" id="ev-start" required>
        </div>
        <div class="form-group">
          <label><?= I18n::t('events.end') ?></label>
          <input type="datetime-local" name="end_at" id="ev-end" required>
        </div>
        <div class="form-group">
          <label>مكافأة عملات</label>
          <input type="number" name="reward_currency" id="ev-curr" value="0" min="0">
        </div>
        <div class="form-group">
          <label>مكافأة خبرة</label>
          <input type="number" name="reward_xp" id="ev-xp" value="0" min="0">
        </div>
        <div class="form-group">
          <label>معرّف تجميلي</label>
          <input type="text" name="reward_cosmetic_id" id="ev-cosmetic" placeholder="frame_aureate">
        </div>
        <div class="form-group full">
          <label>إعدادات متقدمة (JSON)</label>
          <textarea name="config_json" id="ev-config" rows="3" placeholder='{"difficulty": "hard"}'></textarea>
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="hidden" name="is_active" value="0">
            <input type="checkbox" name="is_active" id="ev-active" value="1" checked>
            <?= I18n::t('common.active') ?>
          </label>
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="hidden" name="is_featured" value="0">
            <input type="checkbox" name="is_featured" id="ev-featured" value="1">
            <?= I18n::t('events.featured') ?>
          </label>
        </div>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="closeEventForm()"><?= I18n::t('common.cancel') ?></button>
        <button type="submit" class="btn primary"><?= I18n::t('common.save') ?></button>
      </div>
    </form>
  </div>
</div>

<script>
function openEventForm(ev) {
  const modal = document.getElementById('event-modal');
  modal.hidden = false;
  if (ev) {
    document.getElementById('modal-title').textContent = 'تعديل: ' + ev.event_uid;
    document.getElementById('event-id').value = ev.id;
    document.getElementById('ev-uid').value = ev.event_uid;
    document.getElementById('ev-uid').readOnly = true;
    document.getElementById('ev-title').value = ev.title_key;
    document.getElementById('ev-desc').value = ev.description_key || '';
    document.getElementById('ev-type').value = ev.event_type;
    document.getElementById('ev-scenario').value = ev.scenario_id;
    document.getElementById('ev-start').value = ev.start_at.replace(' ', 'T').substring(0, 16);
    document.getElementById('ev-end').value = ev.end_at.replace(' ', 'T').substring(0, 16);
    document.getElementById('ev-curr').value = ev.reward_currency;
    document.getElementById('ev-xp').value = ev.reward_xp;
    document.getElementById('ev-cosmetic').value = ev.reward_cosmetic_id || '';
    document.getElementById('ev-config').value = ev.config_json || '';
    document.getElementById('ev-active').checked = !!ev.is_active;
    document.getElementById('ev-featured').checked = !!ev.is_featured;
  } else {
    document.getElementById('event-form').reset();
    document.getElementById('event-id').value = '';
    document.getElementById('modal-title').textContent = '<?= I18n::t('events.create') ?>';
    document.getElementById('ev-uid').readOnly = false;
  }
}
function closeEventForm() { document.getElementById('event-modal').hidden = true; }
function editEvent(ev) { openEventForm(ev); }

document.getElementById('event-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  const res = await fetch('events.php', { method: 'POST', body: fd, headers: { 'X-CSRF-Token': fd.get('_token') } });
  const json = await res.json();
  if (json.success) { showToast('تم الحفظ', 'success'); setTimeout(() => location.reload(), 800); }
  else showToast(json.error || 'خطأ', 'error');
});

async function deleteEvent(id) {
  if (!confirm('هل أنت متأكد من حذف هذه الفعالية؟')) return;
  const fd = new FormData();
  fd.append('action', 'delete');
  fd.append('id', id);
  fd.append('_token', document.getElementById('csrf-token').value);
  const res = await fetch('events.php', { method: 'POST', body: fd });
  const json = await res.json();
  if (json.success) { showToast('تم الحذف', 'success'); setTimeout(() => location.reload(), 500); }
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>