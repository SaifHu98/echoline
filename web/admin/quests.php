<?php
require_once __DIR__ . '/config.php';
Auth::require();
require_once __DIR__ . '/includes/Crud.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Crud::handle('quests', [
        ['name' => 'quest_uid', 'required' => true, 'sanitize' => true],
        ['name' => 'title_key', 'required' => true, 'sanitize' => true],
        ['name' => 'description_key', 'sanitize' => true],
        ['name' => 'quest_type'],
        ['name' => 'objective_type'],
        ['name' => 'objective_target', 'required' => true],
        ['name' => 'objective_metadata', 'json' => true],
        ['name' => 'scenario_id'],
        ['name' => 'timeline_filter'],
        ['name' => 'reward_currency', 'required' => true],
        ['name' => 'reward_xp', 'required' => true],
        ['name' => 'reward_cosmetic_id'],
        ['name' => 'is_repeatable', 'required' => true],
        ['name' => 'is_active', 'required' => true],
        ['name' => 'start_at'],
        ['name' => 'end_at'],
        ['name' => 'sort_order', 'required' => true],
    ], 'quests.php');
    exit;
}

$pageTitle = I18n::t('quests.title');
$currentSection = 'quests';
$quests = Database::fetchAll('SELECT * FROM quests ORDER BY is_active DESC, sort_order ASC');

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('quests.title') ?></h1>
  <button class="btn primary" onclick="openQuestForm()">+ <?= I18n::t('quests.create') ?></button>
</div>

<div class="panel">
  <table class="data-table">
    <thead>
      <tr>
        <th>المعرّف</th><th>العنوان</th><th>النوع</th><th>الهدف</th>
        <th>المكافأة</th><th>مجدول</th><th>الحالة</th><th><?= I18n::t('common.actions') ?></th>
      </tr>
    </thead>
    <tbody>
      <?php foreach ($quests as $q): ?>
        <tr>
          <td><code><?= Security::escape($q['quest_uid']) ?></code></td>
          <td><strong><?= Security::escape($q['title_key']) ?></strong></td>
          <td><span class="badge"><?= Security::escape($q['quest_type']) ?></span></td>
          <td><?= Security::escape($q['objective_type']) ?> ×<?= $q['objective_target'] ?></td>
          <td><span class="text-amber">💎 <?= $q['reward_currency'] ?></span> <span class="text-cyan">⭐ <?= $q['reward_xp'] ?></span></td>
          <td class="text-muted small">
            <?= $q['start_at'] ? Security::escape(substr($q['start_at'], 0, 10)) : '—' ?>
            →
            <?= $q['end_at'] ? Security::escape(substr($q['end_at'], 0, 10)) : '∞' ?>
          </td>
          <td>
            <?php if ($q['is_active']): ?><span class="badge badge-ok">نشط</span><?php else: ?><span class="badge">معطل</span><?php endif; ?>
            <?php if ($q['is_repeatable']): ?><span class="badge repeat">مكررة</span><?php endif; ?>
          </td>
          <td>
            <button class="btn small" onclick='editQuest(<?= json_encode($q, JSON_HEX_APOS | JSON_HEX_QUOT) ?>)'>تعديل</button>
            <button class="btn small danger" onclick="deleteQuest(<?= $q['id'] ?>)">حذف</button>
          </td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>

<div id="quest-modal" class="modal" hidden>
  <div class="modal-content">
    <h2 id="quest-modal-title"><?= I18n::t('quests.create') ?></h2>
    <form id="quest-form">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="save">
      <input type="hidden" name="id" id="quest-id">
      <div class="grid-form">
        <div class="form-group">
          <label><?= I18n::t('quests.quest_uid') ?> *</label>
          <input type="text" name="quest_uid" id="q-uid" required pattern="[a-z0-9_]+">
        </div>
        <div class="form-group">
          <label><?= I18n::t('events.title_key') ?> *</label>
          <input type="text" name="title_key" id="q-title" required placeholder="quest.daily.match.title">
        </div>
        <div class="form-group">
          <label><?= I18n::t('events.desc_key') ?></label>
          <input type="text" name="description_key" id="q-desc">
        </div>
        <div class="form-group">
          <label><?= I18n::t('quests.objective_type') ?></label>
          <select name="objective_type" id="q-otype">
            <option value="win_match">ربح مباراة</option>
            <option value="complete_scenario">إكمال سيناريو</option>
            <option value="trigger_echo">إطلاق صدى</option>
            <option value="play_timeline">لعب خط زمني</option>
            <option value="communicate">التواصل</option>
            <option value="match_count">عدد المباريات</option>
            <option value="time_played">وقت اللعب</option>
            <option value="collect_item">جمع عنصر</option>
            <option value="reach_outcome">تحقيق نتيجة</option>
          </select>
        </div>
        <div class="form-group">
          <label>نوع المهمة</label>
          <select name="quest_type" id="q-type">
            <option value="daily">يومية</option>
            <option value="weekly">أسبوعية</option>
            <option value="seasonal">موسمية</option>
            <option value="story">قصة</option>
            <option value="challenge">تحدي</option>
            <option value="tutorial">تعليمي</option>
          </select>
        </div>
        <div class="form-group">
          <label><?= I18n::t('quests.target') ?></label>
          <input type="number" name="objective_target" id="q-target" value="1" min="1">
        </div>
        <div class="form-group">
          <label>السيناريو</label>
          <select name="scenario_id" id="q-scenario">
            <option value="">— أي —</option>
            <option value="clocktower_district">حي برج الساعة</option>
            <option value="subterranean_vaults">السراديب</option>
            <option value="sunken_aqueduct">القناة الغارقة</option>
          </select>
        </div>
        <div class="form-group">
          <label>الخط الزمني</label>
          <select name="timeline_filter" id="q-tl">
            <option value="">— أي —</option>
            <option value="past">past</option>
            <option value="present">present</option>
            <option value="future">future</option>
          </select>
        </div>
        <div class="form-group">
          <label>عملات</label>
          <input type="number" name="reward_currency" id="q-curr" value="0" min="0">
        </div>
        <div class="form-group">
          <label>خبرة</label>
          <input type="number" name="reward_xp" id="q-xp" value="0" min="0">
        </div>
        <div class="form-group">
          <label>ترتيب</label>
          <input type="number" name="sort_order" id="q-order" value="0">
        </div>
        <div class="form-group">
          <label>تاريخ البدء</label>
          <input type="datetime-local" name="start_at" id="q-start">
        </div>
        <div class="form-group">
          <label>تاريخ الانتهاء</label>
          <input type="datetime-local" name="end_at" id="q-end">
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="hidden" name="is_active" value="0">
            <input type="checkbox" name="is_active" id="q-active" value="1" checked> <?= I18n::t('common.active') ?>
          </label>
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="hidden" name="is_repeatable" value="0">
            <input type="checkbox" name="is_repeatable" id="q-repeat" value="1"> قابلة للتكرار
          </label>
        </div>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="closeQuestForm()"><?= I18n::t('common.cancel') ?></button>
        <button type="submit" class="btn primary"><?= I18n::t('common.save') ?></button>
      </div>
    </form>
  </div>
</div>

<script>
function openQuestForm(q) {
  const m = document.getElementById('quest-modal'); m.hidden = false;
  if (q) {
    document.getElementById('quest-modal-title').textContent = 'تعديل: ' + q.quest_uid;
    document.getElementById('quest-id').value = q.id;
    document.getElementById('q-uid').value = q.quest_uid;
    document.getElementById('q-uid').readOnly = true;
    document.getElementById('q-title').value = q.title_key;
    document.getElementById('q-desc').value = q.description_key || '';
    document.getElementById('q-otype').value = q.objective_type;
    document.getElementById('q-type').value = q.quest_type;
    document.getElementById('q-target').value = q.objective_target;
    document.getElementById('q-scenario').value = q.scenario_id || '';
    document.getElementById('q-tl').value = q.timeline_filter || '';
    document.getElementById('q-curr').value = q.reward_currency;
    document.getElementById('q-xp').value = q.reward_xp;
    document.getElementById('q-order').value = q.sort_order;
    document.getElementById('q-start').value = q.start_at ? q.start_at.replace(' ', 'T').substring(0, 16) : '';
    document.getElementById('q-end').value = q.end_at ? q.end_at.replace(' ', 'T').substring(0, 16) : '';
    document.getElementById('q-active').checked = !!q.is_active;
    document.getElementById('q-repeat').checked = !!q.is_repeatable;
  } else {
    document.getElementById('quest-form').reset();
    document.getElementById('quest-id').value = '';
    document.getElementById('quest-modal-title').textContent = '<?= I18n::t('quests.create') ?>';
    document.getElementById('q-uid').readOnly = false;
  }
}
function closeQuestForm() { document.getElementById('quest-modal').hidden = true; }
function editQuest(q) { openQuestForm(q); }

document.getElementById('quest-form').addEventListener('submit', async e => {
  e.preventDefault();
  const fd = new FormData(e.target);
  const res = await fetch('quests.php', { method: 'POST', body: fd });
  const j = await res.json();
  if (j.success) { showToast('تم الحفظ', 'success'); setTimeout(() => location.reload(), 600); }
  else showToast(j.error || 'خطأ', 'error');
});

async function deleteQuest(id) {
  if (!confirm('حذف المهمة؟')) return;
  const fd = new FormData();
  fd.append('action', 'delete'); fd.append('id', id); fd.append('_token', document.getElementById('csrf-token').value);
  const res = await fetch('quests.php', { method: 'POST', body: fd });
  const j = await res.json();
  if (j.success) { showToast('تم الحذف', 'success'); setTimeout(() => location.reload(), 500); }
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>