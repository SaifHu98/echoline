<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = 'إدارة الخرائط والسيناريوهات';
$currentSection = 'scenarios';

$scenarioDir = __DIR__ . '/data/scenarios';
if (!is_dir($scenarioDir)) @mkdir($scenarioDir, 0755, true);

// Handle actions
$message = null;
$messageType = 'success';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!Security::verifyCsrf(Security::input(CSRF_TOKEN_NAME))) {
        Response::error(I18n::t('error.csrf'), 403);
    }

    $action = Security::input('action');

    if ($action === 'save') {
        $id = Security::input('scenario_id', null, 'string');
        $content = $_POST['content'] ?? '';
        $file = $scenarioDir . '/' . preg_replace('/[^a-z0-9_]/', '', $id) . '.json';

        $json = json_decode($content, true);
        if ($json === null) {
            $message = 'JSON غير صالح: ' . json_last_error_msg();
            $messageType = 'error';
        } else {
            // Validate
            if (empty($json['id']) || empty($json['supported_timelines'])) {
                $message = 'الحقول المطلوبة مفقودة (id, supported_timelines)';
                $messageType = 'error';
            } else {
                file_put_contents($file, json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
                Audit::log(Auth::id(), 'scenario.save', 'scenario', $id, ['size' => strlen($content)]);
                $message = 'تم حفظ السيناريو';
            }
        }
    }

    if ($action === 'delete') {
        $id = Security::input('scenario_id', null, 'string');
        $file = $scenarioDir . '/' . preg_replace('/[^a-z0-9_]/', '', $id) . '.json';
        if (file_exists($file)) {
            unlink($file);
            Audit::log(Auth::id(), 'scenario.delete', 'scenario', $id);
            $message = 'تم حذف السيناريو';
        }
    }
}

$scenarios = [];
foreach (glob($scenarioDir . '/*.json') as $file) {
    $content = file_get_contents($file);
    $data = json_decode($content, true);
    $scenarios[basename($file, '.json')] = [
        'file' => basename($file),
        'size' => filesize($file),
        'modified' => filemtime($file),
        'data' => $data,
    ];
}

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1>إدارة الخرائط والسيناريوهات</h1>
  <button class="btn primary" onclick="createScenario()">+ سيناريو جديد</button>
</div>

<?php if ($message): ?>
  <div class="alert alert-<?= $messageType ?>"><?= Security::escape($message) ?></div>
<?php endif; ?>

<div class="grid-2col">
  <div class="panel">
    <h3>السيناريوهات المحفوظة</h3>
    <table class="data-table">
      <thead>
        <tr><th>المعرّف</th><th>الاسم</th><th>الخطوط الزمنية</th><th>الصدى</th><th>الحجم</th><th>آخر تعديل</th><th>الإجراءات</th></tr>
      </thead>
      <tbody>
        <?php foreach ($scenarios as $id => $s): ?>
          <tr>
            <td><code><?= Security::escape($id) ?></code></td>
            <td><strong><?= Security::escape($s['data']['name_key'] ?? '—') ?></strong></td>
            <td>
              <?php foreach (($s['data']['supported_timelines'] ?? []) as $tl): ?>
                <span class="badge badge-<?= $tl ?>"><?= $tl ?></span>
              <?php endforeach; ?>
            </td>
            <td><?= count($s['data']['echo_rules'] ?? []) ?> قاعدة</td>
            <td class="text-muted small"><?= number_format($s['size'] / 1024, 1) ?> KB</td>
            <td class="text-muted small"><?= date('Y-m-d H:i', $s['modified']) ?></td>
            <td>
              <button class="btn small" onclick='editScenario(<?= json_encode($id, JSON_HEX_QUOT) ?>)'>تعديل</button>
              <button class="btn small danger" onclick="deleteScenario('<?= Security::escape($id) ?>')">حذف</button>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>

  <div class="panel">
    <h3 id="editor-title">محرر JSON</h3>
    <form method="POST" id="editor-form">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="save">
      <div class="form-group">
        <label>اسم الملف (المعرّف)</label>
        <input type="text" name="scenario_id" id="scenario-id" pattern="[a-z0-9_]+" required>
      </div>
      <div class="form-group">
        <label>محتوى JSON</label>
        <textarea name="content" id="editor" rows="20" class="code-editor"></textarea>
      </div>
      <div class="form-actions">
        <button type="button" class="btn" onclick="formatJson()">تنسيق</button>
        <button type="button" class="btn" onclick="validateJson()">تحقق</button>
        <button type="submit" class="btn primary">حفظ</button>
      </div>
    </form>
  </div>
</div>

<script>
const SCENARIOS = <?= json_encode(array_map(fn($s) => json_encode($s['data'], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE), $scenarios), JSON_HEX_QUOT) ?>;

function editScenario(id) {
  document.getElementById('scenario-id').value = id;
  document.getElementById('scenario-id').readOnly = true;
  document.getElementById('editor').value = SCENARIOS[id];
  document.getElementById('editor-title').textContent = 'تعديل: ' + id;
}

function createScenario() {
  document.getElementById('scenario-id').value = '';
  document.getElementById('scenario-id').readOnly = false;
  document.getElementById('editor').value = JSON.stringify({
    id: '',
    name_key: 'scenario.new.name',
    description_key: 'scenario.new.desc',
    supported_timelines: ['past', 'present', 'future'],
    catastrophe: { id: 'new_catastrophe', duration_seconds: 600, stages: [] },
    timelines_initial_state: { past: {}, present: {}, future: {} },
    echo_rules: [],
    win_conditions: [],
    loss_conditions: []
  }, null, 2);
  document.getElementById('editor-title').textContent = 'سيناريو جديد';
}

function formatJson() {
  try {
    const j = JSON.parse(document.getElementById('editor').value);
    document.getElementById('editor').value = JSON.stringify(j, null, 2);
    showToast('تم التنسيق', 'success');
  } catch (e) {
    showToast('JSON غير صالح: ' + e.message, 'error');
  }
}

function validateJson() {
  try {
    const j = JSON.parse(document.getElementById('editor').value);
    if (!j.id || !j.supported_timelines) {
      showToast('الحقول المطلوبة مفقودة', 'error');
      return;
    }
    showToast('JSON صالح ✓', 'success');
  } catch (e) {
    showToast('JSON غير صالح: ' + e.message, 'error');
  }
}

function deleteScenario(id) {
  if (!confirm('حذف ' + id + '؟')) return;
  const form = document.createElement('form');
  form.method = 'POST';
  form.innerHTML = `
    <input name="_token" value="${document.getElementById('csrf-token').value}">
    <input name="action" value="delete">
    <input name="scenario_id" value="${id}">
  `;
  document.body.appendChild(form);
  form.submit();
}

// Auto-format on paste
document.getElementById('editor').addEventListener('paste', function(e) {
  setTimeout(() => {
    try {
      const j = JSON.parse(this.value);
      this.value = JSON.stringify(j, null, 2);
    } catch (e) {}
  }, 100);
});
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>