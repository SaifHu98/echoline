<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = 'إدارة نظام الصدى الزمني';
$currentSection = 'echo';

// Load all scenarios and their echo rules
$scenarioDir = __DIR__ . '/data/scenarios';
$allEchos = [];

foreach (glob($scenarioDir . '/*.json') as $file) {
    $scenario = json_decode(file_get_contents($file), true);
    if (!$scenario || empty($scenario['echo_rules'])) continue;
    $scenarioId = basename($file, '.json');
    foreach ($scenario['echo_rules'] as $rule) {
        $allEchos[] = array_merge($rule, ['_scenario' => $scenarioId]);
    }
}

// Sort by source_timeline then by id
usort($allEchos, function($a, $b) {
    $c = strcmp($a['_scenario'] ?? '', $b['_scenario'] ?? '');
    if ($c !== 0) return $c;
    return strcmp($a['source_timeline'] ?? '', $b['source_timeline'] ?? '');
});

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1>نظام الصدى الزمني (Temporal Echo System)</h1>
  <div class="page-sub"><?= count($allEchos) ?> قاعدة صدى عبر <?= count(glob($scenarioDir . '/*.json')) ?> سيناريو</div>
</div>

<div class="grid-3col">
  <?php
  $bySource = [];
  foreach ($allEchos as $e) {
      $key = ($e['_scenario'] ?? '') . ' / ' . ($e['source_timeline'] ?? 'unknown');
      $bySource[$key][] = $e;
  }
  foreach ($bySource as $key => $rules): ?>
    <div class="panel">
      <h3><?= Security::escape($key) ?></h3>
      <div class="echo-list">
        <?php foreach ($rules as $r): ?>
          <div class="echo-item">
            <div class="echo-id"><code><?= Security::escape($r['id']) ?></code></div>
            <div class="echo-trigger">
              <strong><?= Security::escape($r['trigger_action'] ?? '?') ?></strong>
              <span class="text-muted">على <?= Security::escape($r['source_entity'] ?? '?') ?></span>
            </div>
            <div class="echo-effects">
              <?php foreach (($r['effects'] ?? []) as $eff): ?>
                <div class="effect">
                  <span class="badge badge-<?= Security::escape($eff['target_timeline'] ?? '') ?>"><?= Security::escape($eff['target_timeline'] ?? '') ?></span>
                  <span class="mono"><?= Security::escape($eff['entity'] ?? '') ?>.<?= Security::escape($eff['property'] ?? '') ?></span>
                  → <code><?= Security::escape(json_encode($eff['value'] ?? '')) ?></code>
                  <?php if (!empty($eff['propagation_delay_ms'])): ?>
                    <span class="text-muted small">+<?= $eff['propagation_delay_ms'] ?>ms</span>
                  <?php endif; ?>
                </div>
              <?php endforeach; ?>
            </div>
            <?php if (!empty($r['preconditions'])): ?>
              <div class="echo-pre small text-muted">
                شروط: <?= count($r['preconditions']) ?>
              </div>
            <?php endif; ?>
            <div class="echo-meta small">
              أولوية: <?= $r['conflict_priority'] ?? 50 ?>
              <?= !empty($r['reversible']) ? '• قابل للعكس' : '• غير قابل للعكس' ?>
            </div>
          </div>
        <?php endforeach; ?>
      </div>
    </div>
  <?php endforeach; ?>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>