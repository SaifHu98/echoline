<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = I18n::t('dashboard.welcome');
$currentSection = 'dashboard';

// === Stats fetching ===
$stats = [];

$stats['active_events'] = (int) Database::fetch(
    'SELECT COUNT(*) AS c FROM events WHERE is_active = 1 AND NOW() BETWEEN start_at AND end_at'
)['c'];

$stats['matches_today'] = (int) Database::fetch(
    "SELECT COUNT(*) AS c FROM analytics_events WHERE event_name = 'match_completed' AND DATE(created_at) = CURDATE()"
)['c'];

$stats['revenue_today'] = (float) Database::fetch(
    "SELECT COALESCE(SUM(amount_usd), 0) AS s FROM sales_log WHERE status = 'verified' AND DATE(created_at) = CURDATE()"
)['s'];

$stats['revenue_month'] = (float) Database::fetch(
    "SELECT COALESCE(SUM(amount_usd), 0) AS s FROM sales_log WHERE status = 'verified' AND YEAR(created_at) = YEAR(NOW()) AND MONTH(created_at) = MONTH(NOW())"
)['s'];

$stats['revenue_lifetime'] = (float) Database::fetch(
    "SELECT COALESCE(SUM(amount_usd), 0) AS s FROM sales_log WHERE status = 'verified'"
)['s'];

$stats['total_players'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM players')['c'];
$stats['players_online'] = (int) Database::fetch(
    "SELECT COUNT(*) AS c FROM players WHERE last_login_at >= DATE_SUB(NOW(), INTERVAL 5 MINUTE)"
)['c'];

// Retention
$stats['retention_7d'] = 0;
$totalOld = (int) Database::fetch(
    "SELECT COUNT(*) AS c FROM players WHERE last_login_at >= DATE_SUB(NOW(), INTERVAL 8 DAY) AND last_login_at <= DATE_SUB(NOW(), INTERVAL 7 DAY)"
)['c'];
$returned = (int) Database::fetch(
    "SELECT COUNT(*) AS c FROM players WHERE last_login_at >= DATE_SUB(NOW(), INTERVAL 8 DAY) AND last_login_at <= DATE_SUB(NOW(), INTERVAL 7 DAY) AND last_login_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)"
)['c'];
if ($totalOld > 0) {
    $stats['retention_7d'] = round(($returned / $totalOld) * 100, 1);
}

// Today vs yesterday revenue (trend)
$stats['revenue_yesterday'] = (float) Database::fetch(
    "SELECT COALESCE(SUM(amount_usd), 0) AS s FROM sales_log WHERE status = 'verified' AND DATE(created_at) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)"
)['s'];
$stats['revenue_trend'] = $stats['revenue_yesterday'] > 0
    ? round((($stats['revenue_today'] - $stats['revenue_yesterday']) / $stats['revenue_yesterday']) * 100, 1)
    : ($stats['revenue_today'] > 0 ? 100 : 0);

$stats['open_reports'] = (int) Database::fetch("SELECT COUNT(*) AS c FROM reports WHERE status = 'open'")['c'];
$stats['pending_receipts'] = (int) Database::fetch("SELECT COUNT(*) AS c FROM receipt_verifications WHERE validation_result IN ('pending','error')")['c'];

$scenarioFiles = glob(__DIR__ . '/data/scenarios/*.json');
$stats['total_scenarios'] = count($scenarioFiles);

// === Recent data ===
$recentSales = Database::fetchAll(
    'SELECT s.*, p.display_name FROM sales_log s
     LEFT JOIN players p ON p.player_uid = s.player_id
     ORDER BY s.created_at DESC LIMIT 8'
);

$upcomingEvents = Database::fetchAll(
    'SELECT * FROM events WHERE end_at >= NOW() ORDER BY is_featured DESC, start_at ASC LIMIT 5'
);

$recentActivity = Database::fetchAll(
    "SELECT a.*, ad.username FROM audit_log a
     LEFT JOIN admins ad ON ad.id = a.admin_id
     ORDER BY a.created_at DESC LIMIT 8"
);

// === Top scenarios ===
$topScenarios = Database::fetchAll(
    "SELECT JSON_UNQUOTE(JSON_EXTRACT(event_data, '$.scenario')) AS scenario,
            COUNT(*) AS plays
     FROM analytics_events
     WHERE event_name = 'match_completed' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
       AND JSON_EXTRACT(event_data, '$.scenario') IS NOT NULL
     GROUP BY scenario ORDER BY plays DESC LIMIT 5"
);

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <div>
    <h1><span class="ic">👋</span> <?= I18n::t('dashboard.welcome') ?></h1>
    <p class="page-sub"><?= I18n::t('dashboard.subtitle') ?> · <?= date('D, d M Y · H:i') ?></p>
  </div>
  <div class="page-header-actions">
    <a href="analytics.php" class="btn">📊 <?= I18n::t('menu.analytics') ?></a>
    <a href="events.php" class="btn primary">+ <?= I18n::t('events.create') ?></a>
  </div>
</div>

<!-- ==== Top stats ==== -->
<div class="stats-grid">
  <div class="stat-card s-cyan">
    <div class="stat-card-head">
      <div class="stat-label"><?= I18n::t('dashboard.players_online') ?></div>
      <div class="stat-icon" style="background: var(--c-cyan-soft); color: var(--c-cyan);">👥</div>
    </div>
    <div class="stat-val" data-count-to="<?= $stats['players_online'] ?>">0</div>
    <div class="stat-sub">إجمالي مسجلين: <?= number_format($stats['total_players']) ?></div>
  </div>

  <div class="stat-card s-green">
    <div class="stat-card-head">
      <div class="stat-label"><?= I18n::t('dashboard.matches_today') ?></div>
      <div class="stat-icon" style="background: var(--c-green-soft); color: var(--c-green);">🎮</div>
    </div>
    <div class="stat-val" data-count-to="<?= $stats['matches_today'] ?>">0</div>
    <div class="stat-sub">منذ منتصف الليل</div>
  </div>

  <div class="stat-card s-amber">
    <div class="stat-card-head">
      <div class="stat-label"><?= I18n::t('dashboard.revenue_today') ?></div>
      <div class="stat-icon" style="background: var(--c-amber-soft); color: var(--c-amber);">💰</div>
    </div>
    <div class="stat-val" data-count-to="<?= number_format($stats['revenue_today'], 2, '.', '') ?>">0</div>
    <div class="stat-sub">
      <?php if ($stats['revenue_trend'] != 0): ?>
        <span class="stat-trend <?= $stats['revenue_trend'] >= 0 ? 'up' : 'down' ?>">
          <?= $stats['revenue_trend'] >= 0 ? '↑' : '↓' ?> <?= abs($stats['revenue_trend']) ?>%
        </span>
        عن أمس
      <?php endif; ?>
    </div>
  </div>

  <div class="stat-card s-violet">
    <div class="stat-card-head">
      <div class="stat-label"><?= I18n::t('dashboard.events.active') ?></div>
      <div class="stat-icon" style="background: var(--c-violet-soft); color: var(--c-violet);">🎯</div>
    </div>
    <div class="stat-val" data-count-to="<?= $stats['active_events'] ?>">0</div>
    <div class="stat-sub">فعاليات جارية الآن</div>
  </div>

  <div class="stat-card s-green">
    <div class="stat-card-head">
      <div class="stat-label"><?= I18n::t('dashboard.revenue_month') ?></div>
      <div class="stat-icon" style="background: var(--c-green-soft); color: var(--c-green);">📈</div>
    </div>
    <div class="stat-val" data-count-to="<?= number_format($stats['revenue_month'], 2, '.', '') ?>">0</div>
    <div class="stat-sub">إجمالي الشهر الحالي</div>
  </div>

  <div class="stat-card s-amber">
    <div class="stat-card-head">
      <div class="stat-label">إجمالي الأرباح</div>
      <div class="stat-icon" style="background: var(--c-amber-soft); color: var(--c-amber);">💎</div>
    </div>
    <div class="stat-val" data-count-to="<?= number_format($stats['revenue_lifetime'], 2, '.', '') ?>">0</div>
    <div class="stat-sub">منذ بداية التشغيل</div>
  </div>

  <div class="stat-card s-copper">
    <div class="stat-card-head">
      <div class="stat-label"><?= I18n::t('dashboard.retention_7d') ?></div>
      <div class="stat-icon" style="background: rgba(184, 115, 51, 0.15); color: var(--c-copper);">🔄</div>
    </div>
    <div class="stat-val" data-count-to="<?= $stats['retention_7d'] ?>">0</div>
    <div class="stat-sub">لاعبين عائدين بعد 7 أيام</div>
  </div>

  <div class="stat-card s-red">
    <div class="stat-card-head">
      <div class="stat-label"><?= I18n::t('dashboard.open_reports') ?></div>
      <div class="stat-icon" style="background: var(--c-red-soft); color: var(--c-red);">🛡️</div>
    </div>
    <div class="stat-val" data-count-to="<?= $stats['open_reports'] ?>">0</div>
    <div class="stat-sub"><a href="reports.php">معالجة البلاغات ←</a></div>
  </div>
</div>

<!-- ==== Two-column area: events + sales ==== -->
<div class="two-col">
  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">📅</span> <?= I18n::t('dashboard.upcoming_events') ?></h3>
      <a href="events.php" class="btn small primary">+ <?= I18n::t('events.create') ?></a>
    </div>
    <?php if (empty($upcomingEvents)): ?>
      <p class="text-muted text-center" style="padding-block: 1.5rem;"><?= I18n::t('events.no_events') ?></p>
    <?php else: ?>
    <div class="table-wrap">
      <table class="data-table">
        <thead>
          <tr><th><?= I18n::t('events.title_key') ?></th><th><?= I18n::t('events.type') ?></th><th>الفترة</th><th><?= I18n::t('common.status') ?></th></tr>
        </thead>
        <tbody>
          <?php foreach ($upcomingEvents as $e): ?>
            <tr>
              <td>
                <strong><?= Security::escape(I18n::t($e['title_key'])) ?></strong>
                <?php if ($e['is_featured']): ?><span class="badge featured">⭐</span><?php endif; ?>
              </td>
              <td><span class="badge violet"><?= Security::escape(I18n::t('type.' . $e['event_type'])) ?></span></td>
              <td class="text-muted text-sm">
                <?= Security::escape(substr($e['start_at'], 5, 11)) ?> →
                <?= Security::escape(substr($e['end_at'], 5, 11)) ?>
              </td>
              <td>
                <?php if ($e['is_active'] && strtotime($e['start_at']) <= time() && strtotime($e['end_at']) >= time()): ?>
                  <span class="badge ok"><?= I18n::t('events.active') ?></span>
                <?php elseif (strtotime($e['start_at']) > time()): ?>
                  <span class="badge warn"><?= I18n::t('events.upcoming') ?></span>
                <?php else: ?>
                  <span class="badge"><?= I18n::t('events.ended') ?></span>
                <?php endif; ?>
              </td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
    <?php endif; ?>
  </div>

  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">💰</span> <?= I18n::t('dashboard.recent_sales') ?></h3>
      <div class="flex gap-1">
        <a href="tools.php?action=sales_archive" class="btn small">📦 الأرشيف</a>
        <a href="receipts.php" class="btn small"><?= I18n::t('dashboard.view_all') ?></a>
      </div>
    </div>
    <?php if (empty($recentSales)): ?>
      <p class="text-muted text-center" style="padding-block: 1.5rem;"><?= I18n::t('dashboard.no_sales') ?></p>
    <?php else: ?>
    <div class="table-wrap">
      <table class="data-table">
        <thead><tr><th>اللاعب</th><th>SKU</th><th>المبلغ</th><th><?= I18n::t('common.status') ?></th></tr></thead>
        <tbody>
          <?php foreach ($recentSales as $s): ?>
            <tr>
              <td><?= Security::escape($s['display_name'] ?? $s['player_id']) ?></td>
              <td><code class="small"><?= Security::escape($s['sku']) ?></code></td>
              <td class="font-bold text-amber">$<?= number_format($s['amount_usd'], 2) ?></td>
              <td>
                <?php
                $badgeClass = match($s['status']) {
                    'verified' => 'ok',
                    'pending' => 'warn',
                    'refunded', 'fraud' => 'danger',
                    default => ''
                };
                ?>
                <span class="badge <?= $badgeClass ?>"><?= Security::escape(I18n::t('status.' . $s['status'])) ?></span>
              </td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
    <?php endif; ?>
  </div>
</div>

<!-- ==== Top scenarios + recent activity ==== -->
<div class="two-col">
  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">🏆</span> <?= I18n::t('dashboard.top_scenario') ?></h3>
      <a href="analytics.php" class="btn small"><?= I18n::t('dashboard.view_all') ?></a>
    </div>
    <?php if (empty($topScenarios)): ?>
      <p class="text-muted text-center" style="padding-block: 1.5rem;"><?= I18n::t('analytics.no_data') ?></p>
    <?php else: foreach ($topScenarios as $i => $s): ?>
      <div style="display:flex; align-items:center; gap:0.85rem; padding-block:0.5rem; border-block-end: 1px solid var(--b-soft);">
        <div style="inline-size:32px; block-size:32px; border-radius:50%; background: var(--c-amber-soft); color: var(--c-amber); display:flex; align-items:center; justify-content:center; font-weight:900;">
          <?= $i + 1 ?>
        </div>
        <div style="flex:1; min-inline-size:0;">
          <div class="font-bold"><?= Security::escape(I18n::t('scenario.' . $s['scenario'] . '.name')) ?></div>
          <div class="text-sm text-muted"><?= Security::escape($s['scenario']) ?></div>
        </div>
        <div class="text-end">
          <div class="font-bold text-cyan"><?= number_format($s['plays']) ?></div>
          <div class="text-xs text-muted">مباراة</div>
        </div>
      </div>
    <?php endforeach; endif; ?>
  </div>

  <div class="panel">
    <div class="panel-header">
      <h3><span class="ic">⚡</span> <?= I18n::t('dashboard.recent_activity') ?></h3>
      <a href="audit.php" class="btn small"><?= I18n::t('dashboard.view_all') ?></a>
    </div>
    <?php if (empty($recentActivity)): ?>
      <p class="text-muted text-center" style="padding-block: 1.5rem;">لا يوجد نشاط حديث</p>
    <?php else: foreach ($recentActivity as $a): ?>
      <div style="display:flex; align-items:center; gap:0.75rem; padding-block:0.5rem; border-block-end: 1px solid var(--b-soft);">
        <div style="inline-size:32px; block-size:32px; border-radius:50%; background: rgba(0,229,255,0.1); color: var(--c-cyan); display:flex; align-items:center; justify-content:center;">
          🔧
        </div>
        <div style="flex:1; min-inline-size:0;">
          <div class="text-sm"><strong><?= Security::escape($a['username'] ?? '—') ?></strong> · <code class="small"><?= Security::escape($a['action']) ?></code></div>
          <div class="text-xs text-muted"><?= Security::escape($a['created_at']) ?></div>
        </div>
      </div>
    <?php endforeach; endif; ?>
  </div>
</div>

<!-- ==== System status row ==== -->
<div class="panel">
  <div class="panel-header">
    <h3><span class="ic">🔌</span> حالة النظام والتكامل مع اللعبة</h3>
    <a href="tools.php" class="btn small">إعدادات متقدمة</a>
  </div>
  <div class="stats-grid" style="margin-block-end: 0;">
    <div class="stat-card s-green" style="padding-block: 1rem;">
      <div class="stat-card-head">
        <div class="stat-label">API العامة</div>
        <div class="stat-icon" style="background: var(--c-green-soft); color: var(--c-green);">✓</div>
      </div>
      <div class="stat-status up"><?= I18n::t('dashboard.online') ?></div>
      <div class="stat-sub">api.php يستجيب للطلبات</div>
    </div>
    <div class="stat-card s-cyan" style="padding-block: 1rem;">
      <div class="stat-card-head">
        <div class="stat-label">السيناريوهات</div>
        <div class="stat-icon" style="background: var(--c-cyan-soft); color: var(--c-cyan);">🗺️</div>
      </div>
      <div class="stat-val" data-count-to="<?= $stats['total_scenarios'] ?>">0</div>
      <div class="stat-sub">ملفات JSON جاهزة للعبة</div>
    </div>
    <div class="stat-card s-amber" style="padding-block: 1rem;">
      <div class="stat-card-head">
        <div class="stat-label">الإيصالات المعلقة</div>
        <div class="stat-icon" style="background: var(--c-amber-soft); color: var(--c-amber);">🧾</div>
      </div>
      <div class="stat-val" data-count-to="<?= $stats['pending_receipts'] ?>">0</div>
      <div class="stat-sub">تحتاج تحقق</div>
    </div>
    <div class="stat-card <?= FEATURE_MAINTENANCE_MODE ? 's-red' : 's-green' ?>" style="padding-block: 1rem;">
      <div class="stat-card-head">
        <div class="stat-label"><?= I18n::t('dashboard.system_status') ?></div>
        <div class="stat-icon" style="background: rgba(255,82,82,0.15); color: var(--c-red);">⚙</div>
      </div>
      <div class="stat-status <?= FEATURE_MAINTENANCE_MODE ? 'down' : 'up' ?>">
        <?= FEATURE_MAINTENANCE_MODE ? I18n::t('dashboard.maintenance') : I18n::t('dashboard.online') ?>
      </div>
      <div class="stat-sub">v<?= APP_VERSION ?> · <?= APP_ENV ?></div>
    </div>
  </div>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>