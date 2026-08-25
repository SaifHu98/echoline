<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = I18n::t('analytics.title');
$currentSection = 'analytics';

// === Analytics queries ===
$daily = Database::fetchAll(
    "SELECT DATE(created_at) AS day, COUNT(*) AS matches
     FROM analytics_events
     WHERE event_name = 'match_completed' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
     GROUP BY DATE(created_at) ORDER BY day"
);

$byOutcome = Database::fetchAll(
    "SELECT JSON_UNQUOTE(JSON_EXTRACT(event_data, '$.outcome')) AS outcome, COUNT(*) AS c
     FROM analytics_events
     WHERE event_name = 'match_completed' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
     GROUP BY outcome"
);

$byScenario = Database::fetchAll(
    "SELECT JSON_UNQUOTE(JSON_EXTRACT(event_data, '$.scenario')) AS scenario, COUNT(*) AS c
     FROM analytics_events
     WHERE event_name = 'match_completed' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
       AND JSON_EXTRACT(event_data, '$.scenario') IS NOT NULL
     GROUP BY scenario ORDER BY c DESC LIMIT 10"
);

$byTimeline = Database::fetchAll(
    "SELECT JSON_UNQUOTE(JSON_EXTRACT(event_data, '$.timeline')) AS tl, COUNT(*) AS c
     FROM analytics_events
     WHERE event_name = 'play_timeline' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
     GROUP BY tl"
);

$byEvent = Database::fetchAll(
    "SELECT event_name, COUNT(*) AS c
     FROM analytics_events
     WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
     GROUP BY event_name ORDER BY c DESC LIMIT 10"
);

$topCountries = Database::fetchAll(
    "SELECT country_code, COUNT(DISTINCT player_uid) AS c
     FROM analytics_events
     WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) AND country_code IS NOT NULL
     GROUP BY country_code ORDER BY c DESC LIMIT 10"
);

$byPlatform = Database::fetchAll(
    "SELECT platform, COUNT(DISTINCT player_uid) AS c
     FROM analytics_events
     WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) AND platform IS NOT NULL
     GROUP BY platform ORDER BY c DESC"
);

// KPIs
$totalMatches = array_sum(array_column($daily, 'matches'));
$avgDaily = count($daily) > 0 ? round($totalMatches / count($daily), 1) : 0;
$uniquePlayers = (int) Database::fetch(
    "SELECT COUNT(DISTINCT player_uid) AS c FROM analytics_events WHERE player_uid IS NOT NULL AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)"
)['c'];
$totalEvents = (int) Database::fetch(
    "SELECT COUNT(*) AS c FROM analytics_events WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)"
)['c'];

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <div>
    <h1><span class="ic">📈</span> <?= I18n::t('analytics.title') ?></h1>
    <p class="page-sub"><?= I18n::t('analytics.subtitle') ?> · <?= date('Y-m-d H:i') ?></p>
  </div>
  <div class="page-header-actions">
    <button class="btn" onclick="window.print()">🖨️ طباعة</button>
    <button class="btn primary" onclick="exportCSV()">⬇ تصدير CSV</button>
  </div>
</div>

<!-- ==== KPI row ==== -->
<div class="stats-grid">
  <div class="stat-card s-cyan">
    <div class="stat-card-head">
      <div class="stat-label">إجمالي المباريات (30 يوم)</div>
      <div class="stat-icon" style="background: var(--c-cyan-soft); color: var(--c-cyan);">🎮</div>
    </div>
    <div class="stat-val" data-count-to="<?= $totalMatches ?>"><?= number_format($totalMatches) ?></div>
    <div class="stat-sub">المعدل اليومي: <?= $avgDaily ?></div>
  </div>
  <div class="stat-card s-green">
    <div class="stat-card-head">
      <div class="stat-label">لاعبين فريدين</div>
      <div class="stat-icon" style="background: var(--c-green-soft); color: var(--c-green);">👤</div>
    </div>
    <div class="stat-val" data-count-to="<?= $uniquePlayers ?>"><?= number_format($uniquePlayers) ?></div>
    <div class="stat-sub">شاركوا في أحداث</div>
  </div>
  <div class="stat-card s-violet">
    <div class="stat-card-head">
      <div class="stat-label">إجمالي الأحداث</div>
      <div class="stat-icon" style="background: var(--c-violet-soft); color: var(--c-violet);">⚡</div>
    </div>
    <div class="stat-val" data-count-to="<?= $totalEvents ?>"><?= number_format($totalEvents) ?></div>
    <div class="stat-sub">من كل الأنواع</div>
  </div>
  <div class="stat-card s-amber">
    <div class="stat-card-head">
      <div class="stat-label">النتائج المختلفة</div>
      <div class="stat-icon" style="background: var(--c-amber-soft); color: var(--c-amber);">🏆</div>
    </div>
    <div class="stat-val"><?= count($byOutcome) ?></div>
    <div class="stat-sub">أنواع نتائج تم تسجيلها</div>
  </div>
</div>

<!-- ==== Charts ==== -->
<div class="two-col">
  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">📅</span> <?= I18n::t('analytics.matches_daily') ?></h3>
      <span class="text-sm text-muted">آخر 30 يوم</span>
    </div>
    <?php if (empty($daily)): ?>
      <p class="text-muted text-center" style="padding-block: 2rem;"><?= I18n::t('analytics.no_data') ?></p>
    <?php else: ?>
      <canvas id="dailyChart" style="inline-size: 100%; block-size: 280px;"></canvas>
    <?php endif; ?>
  </div>

  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">🏆</span> <?= I18n::t('analytics.outcome_distribution') ?></h3>
    </div>
    <?php if (empty($byOutcome)): ?>
      <p class="text-muted text-center" style="padding-block: 2rem;"><?= I18n::t('analytics.no_data') ?></p>
    <?php else: ?>
      <canvas id="outcomeChart" style="inline-size: 100%; block-size: 280px;"></canvas>
    <?php endif; ?>
  </div>
</div>

<div class="two-col">
  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">🗺️</span> <?= I18n::t('analytics.top_scenarios') ?></h3>
    </div>
    <?php if (empty($byScenario)): ?>
      <p class="text-muted text-center" style="padding-block: 2rem;"><?= I18n::t('analytics.no_data') ?></p>
    <?php else: ?>
      <canvas id="scenarioChart" style="inline-size: 100%; block-size: 280px;"></canvas>
    <?php endif; ?>
  </div>

  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">⏳</span> <?= I18n::t('analytics.timeline_distribution') ?></h3>
    </div>
    <?php if (empty($byTimeline)): ?>
      <p class="text-muted text-center" style="padding-block: 2rem;"><?= I18n::t('analytics.no_data') ?></p>
    <?php else: ?>
      <canvas id="timelineChart" style="inline-size: 100%; block-size: 280px;"></canvas>
    <?php endif; ?>
  </div>
</div>

<div class="two-col">
  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">📊</span> توزيع الأحداث</h3>
    </div>
    <?php if (empty($byEvent)): ?>
      <p class="text-muted text-center" style="padding-block: 2rem;"><?= I18n::t('analytics.no_data') ?></p>
    <?php else: ?>
      <canvas id="eventChart" style="inline-size: 100%; block-size: 280px;"></canvas>
    <?php endif; ?>
  </div>

  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">🌐</span> المنصات والدول</h3>
    </div>
    <div class="two-col" style="margin-block-end: 0;">
      <div>
        <h4 class="text-sm text-muted mb-1">المنصات</h4>
        <?php if (empty($byPlatform)): ?>
          <p class="text-muted text-sm">لا توجد بيانات</p>
        <?php else: foreach ($byPlatform as $p): ?>
          <div style="display:flex; justify-content:space-between; padding-block: 0.4rem; border-block-end: 1px solid var(--b-soft);">
            <span><?= Security::escape($p['platform']) ?></span>
            <strong class="text-cyan"><?= number_format($p['c']) ?></strong>
          </div>
        <?php endforeach; endif; ?>
      </div>
      <div>
        <h4 class="text-sm text-muted mb-1">أعلى الدول</h4>
        <?php if (empty($topCountries)): ?>
          <p class="text-muted text-sm">لا توجد بيانات</p>
        <?php else: foreach ($topCountries as $c): ?>
          <div style="display:flex; justify-content:space-between; padding-block: 0.4rem; border-block-end: 1px solid var(--b-soft);">
            <span><code><?= Security::escape($c['country_code']) ?></code></span>
            <strong class="text-cyan"><?= number_format($c['c']) ?></strong>
          </div>
        <?php endforeach; endif; ?>
      </div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<script>
const COLORS = {
  cyan: '#00E5FF', amber: '#D4AF37', green: '#00E676', violet: '#9013FE',
  red: '#FF5252', copper: '#B87333', pink: '#FF80AB'
};
const TEXT_COLOR = '#B8C2D1';
const GRID_COLOR = 'rgba(255,255,255,0.05)';

function chartOpts(extra = {}) {
  return {
    responsive: true, maintainAspectRatio: false,
    plugins: { legend: { labels: { color: TEXT_COLOR, font: { family: 'Cairo' } } } },
    scales: {
      x: { ticks: { color: TEXT_COLOR }, grid: { color: GRID_COLOR } },
      y: { ticks: { color: TEXT_COLOR }, grid: { color: GRID_COLOR }, beginAtZero: true }
    },
    ...extra
  };
}

const dailyData = <?= json_encode($daily) ?>;
if (dailyData.length) {
  new Chart(document.getElementById('dailyChart'), {
    type: 'line',
    data: {
      labels: dailyData.map(d => d.day.substring(5)),
      datasets: [{
        label: 'مباريات',
        data: dailyData.map(d => parseInt(d.matches)),
        borderColor: COLORS.cyan,
        backgroundColor: 'rgba(0,229,255,0.1)',
        tension: 0.35, fill: true, pointRadius: 4, pointBackgroundColor: COLORS.cyan
      }]
    },
    options: chartOpts()
  });
}

const outcomeData = <?= json_encode($byOutcome) ?>;
if (outcomeData.length) {
  new Chart(document.getElementById('outcomeChart'), {
    type: 'doughnut',
    data: {
      labels: outcomeData.map(d => d.outcome),
      datasets: [{
        data: outcomeData.map(d => parseInt(d.c)),
        backgroundColor: [COLORS.green, COLORS.amber, COLORS.copper, COLORS.red, COLORS.violet]
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { position: 'right', labels: { color: TEXT_COLOR, font: { family: 'Cairo' } } } }
    }
  });
}

const scenarioData = <?= json_encode($byScenario) ?>;
if (scenarioData.length) {
  new Chart(document.getElementById('scenarioChart'), {
    type: 'bar',
    data: {
      labels: scenarioData.map(d => d.scenario),
      datasets: [{ label: 'مباريات', data: scenarioData.map(d => parseInt(d.c)), backgroundColor: COLORS.amber }]
    },
    options: chartOpts({ indexAxis: 'y' })
  });
}

const timelineData = <?= json_encode($byTimeline) ?>;
if (timelineData.length) {
  new Chart(document.getElementById('timelineChart'), {
    type: 'polarArea',
    data: {
      labels: timelineData.map(d => d.tl),
      datasets: [{
        data: timelineData.map(d => parseInt(d.c)),
        backgroundColor: [COLORS.amber + 'AA', COLORS.cyan + 'AA', COLORS.violet + 'AA']
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { labels: { color: TEXT_COLOR, font: { family: 'Cairo' } } } },
      scales: { r: { ticks: { color: TEXT_COLOR, backdropColor: 'transparent' }, grid: { color: GRID_COLOR } } }
    }
  });
}

const eventData = <?= json_encode($byEvent) ?>;
if (eventData.length) {
  new Chart(document.getElementById('eventChart'), {
    type: 'bar',
    data: {
      labels: eventData.map(d => d.event_name),
      datasets: [{ label: 'عدد', data: eventData.map(d => parseInt(d.c)), backgroundColor: COLORS.violet }]
    },
    options: chartOpts()
  });
}

function exportCSV() {
  let csv = 'period,matches\n';
  dailyData.forEach(d => csv += d.day + ',' + d.matches + '\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = 'analytics_daily_matches.csv'; a.click();
  URL.revokeObjectURL(url);
  showToast('تم التصدير ✓', 'success');
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>