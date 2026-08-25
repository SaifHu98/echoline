<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = I18n::t('menu.localization');
$currentSection = 'localization';

$locale = Security::input('locale', 'en', 'string');
$search = Security::input('q', '', 'string');

$enFile = __DIR__ . '/data/i18n/en.json';
$arFile = __DIR__ . '/data/i18n/ar.json';

if (!is_dir(__DIR__ . '/data/i18n')) @mkdir(__DIR__ . '/data/i18n', 0755, true);
if (!file_exists($enFile)) file_put_contents($enFile, json_encode([], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
if (!file_exists($arFile)) file_put_contents($arFile, json_encode([], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));

$en = json_decode(file_get_contents($enFile), true) ?: [];
$ar = json_decode(file_get_contents($arFile), true) ?: [];

$message = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && Security::verifyCsrf(Security::input(CSRF_TOKEN_NAME))) {
    $action = Security::input('action');
    try {
        if ($action === 'save') {
            $keys = $_POST['key'] ?? [];
            $values = $_POST['value'] ?? [];
            $targetFile = $locale === 'ar' ? $arFile : $enFile;
            $data = $locale === 'ar' ? $ar : $en;
            $newData = [];
            foreach ($keys as $i => $k) {
                $k = trim($k);
                if (empty($k)) continue;
                $newData[$k] = $values[$i] ?? '';
            }
            file_put_contents($targetFile, json_encode($newData, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
            Audit::log(Auth::id(), 'i18n.save', 'locale', $locale, ['count' => count($newData)]);
            $message = 'تم حفظ الترجمة (' . count($newData) . ' مفتاح)';
            if ($locale === 'ar') $ar = $newData; else $en = $newData;
        } elseif ($action === 'add') {
            $newKey = Security::input('new_key', '', 'string');
            $enVal = Security::input('new_value_en', '', 'string');
            $arVal = Security::input('new_value_ar', '', 'string');
            if (!preg_match('/^[a-z0-9_.]+$/', $newKey)) {
                throw new InvalidArgumentException('مفتاح غير صالح. استخدم a-z, 0-9, _, .');
            }
            $en[$newKey] = $enVal;
            $ar[$newKey] = $arVal;
            file_put_contents($enFile, json_encode($en, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
            file_put_contents($arFile, json_encode($ar, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
            Audit::log(Auth::id(), 'i18n.add_key', 'locale', $newKey);
            $message = 'تمت إضافة المفتاح: ' . $newKey;
        }
    } catch (\Throwable $e) {
        $message = $e->getMessage();
    }
}

// Build merged key list
$allKeys = array_unique(array_merge(array_keys($en), array_keys($ar)));
sort($allKeys);

if ($search) {
    $allKeys = array_filter($allKeys, function($k) use ($en, $ar, $search) {
        return stripos($k, $search) !== false ||
               stripos($en[$k] ?? '', $search) !== false ||
               stripos($ar[$k] ?? '', $search) !== false;
    });
}

$stats = [
    'total' => count($allKeys),
    'translated_ar' => count(array_filter($allKeys, fn($k) => !empty($ar[$k]))),
    'missing_ar' => count(array_filter($allKeys, fn($k) => empty($ar[$k]))),
];

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1>إدارة الترجمة والتوطين (Localization)</h1>
</div>

<?php if ($message): ?>
  <div class="alert alert-info"><?= Security::escape($message) ?></div>
<?php endif; ?>

<div class="grid-stats">
  <div class="stat-card stat-cyan"><div class="stat-label">إجمالي المفاتيح</div><div class="stat-val"><?= $stats['total'] ?></div></div>
  <div class="stat-card stat-green"><div class="stat-label">مترجم للعربية</div><div class="stat-val"><?= $stats['translated_ar'] ?></div></div>
  <div class="stat-card stat-amber"><div class="stat-label">ينقصه عربي</div><div class="stat-val"><?= $stats['missing_ar'] ?></div></div>
  <div class="stat-card"><div class="stat-label">نسبة الإكمال</div><div class="stat-val"><?= $stats['total'] > 0 ? round($stats['translated_ar'] / $stats['total'] * 100, 1) : 0 ?>%</div></div>
</div>

<div class="panel">
  <form method="GET" class="filter-bar">
    <input type="text" name="q" value="<?= Security::escape($search) ?>" placeholder="بحث في المفاتيح أو القيم">
    <select name="locale">
      <option value="en" <?= $locale === 'en' ? 'selected' : '' ?>>English</option>
      <option value="ar" <?= $locale === 'ar' ? 'selected' : '' ?>>العربية</option>
    </select>
    <button class="btn primary">تصفية</button>
  </form>

  <button class="btn" onclick="document.getElementById('add-modal').hidden=false">+ مفتاح جديد</button>

  <form method="POST" id="i18n-form">
    <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
    <input type="hidden" name="action" value="save">
    <input type="hidden" name="locale" value="<?= Security::escape($locale) ?>">

    <table class="data-table">
      <thead>
        <tr><th style="width:25%">المفتاح (Key)</th><th>القيمة (<?= $locale === 'ar' ? 'العربية' : 'English' ?>)</th><th>EN</th><th>AR</th></tr>
      </thead>
      <tbody>
        <?php foreach ($allKeys as $key): ?>
          <tr>
            <td><code><?= Security::escape($key) ?></code>
              <input type="hidden" name="key[]" value="<?= Security::escape($key) ?>">
            </td>
            <td><input type="text" name="value[]" value="<?= Security::escape($locale === 'ar' ? ($ar[$key] ?? '') : ($en[$key] ?? '')) ?>" style="inline-size:100%"></td>
            <td class="text-muted small" style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap"><?= Security::escape($en[$key] ?? '') ?></td>
            <td class="text-muted small" dir="rtl" style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap"><?= Security::escape($ar[$key] ?? '') ?></td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
    <button type="submit" class="btn primary large" style="margin-block-start:1rem">حفظ كل التغييرات</button>
  </form>
</div>

<div id="add-modal" class="modal" hidden>
  <div class="modal-content">
    <h2>إضافة مفتاح ترجمة جديد</h2>
    <form method="POST">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="add">
      <div class="form-group">
        <label>المفتاح (key)</label>
        <input type="text" name="new_key" required pattern="[a-z0-9_.]+" placeholder="menu.play">
      </div>
      <div class="form-group">
        <label>الإنجليزية</label>
        <input type="text" name="new_value_en" required>
      </div>
      <div class="form-group">
        <label>العربية</label>
        <input type="text" name="new_value_ar" required dir="rtl">
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="this.closest('.modal').hidden=true">إلغاء</button>
        <button type="submit" class="btn primary">إضافة</button>
      </div>
    </form>
  </div>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>