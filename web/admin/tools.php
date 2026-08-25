<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = I18n::t('tools.title');
$currentSection = 'tools';

$message = null;
$messageType = 'success';
$stats = [];

// Get current data stats
$stats['players'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM players')['c'];
$stats['sales'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM sales_log')['c'];
$stats['analytics'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM analytics_events')['c'];
$stats['reports'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM reports')['c'];
$stats['events'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM events')['c'];
$stats['quests'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM quests')['c'];
$stats['shop'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM shop_items')['c'];
$stats['announcements'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM announcements')['c'];
$stats['admins'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM admins')['c'];
$stats['configs'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM remote_config')['c'];
$stats['scenarios'] = count(glob(__DIR__ . '/data/scenarios/*.json'));
$stats['archives'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM sales_archive')['c'];

if ($_SERVER['REQUEST_METHOD'] === 'POST' && Security::verifyCsrf(Security::input(CSRF_TOKEN_NAME))) {
    $action = Security::input('action', '', 'string');

    try {
        if ($action === 'clear_demo') {
            $deleted = 0;
            $deleted += Database::query('DELETE FROM players WHERE player_uid LIKE ?', ['uid_%'])->rowCount();
            $deleted += Database::query('DELETE FROM sales_log WHERE player_id LIKE ?', ['uid_%'])->rowCount();
            $deleted += Database::query('DELETE FROM analytics_events WHERE player_uid LIKE ?', ['uid_%'])->rowCount();
            Database::delete('events', "event_uid IN ('tournament_season_1', 'aqueduct_challenge', 'daily_double')");
            $deleted += 3;
            Audit::log(Auth::id(), 'tools.clear_demo', null, null, ['deleted' => $deleted]);
            $message = 'تم مسح البيانات التجريبية (' . $deleted . ' سجل)';
            $messageType = 'success';
        }
        elseif ($action === 'clear_players') {
            $n = Database::query('DELETE FROM players WHERE player_uid NOT LIKE ?', ['p_system'])->rowCount();
            Audit::log(Auth::id(), 'tools.clear_players', null, null, ['deleted' => $n]);
            $message = "تم حذف $n لاعب";
            $messageType = 'success';
        }
        elseif ($action === 'clear_analytics') {
            $n = Database::query('DELETE FROM analytics_events')->rowCount();
            Audit::log(Auth::id(), 'tools.clear_analytics', null, null, ['deleted' => $n]);
            $message = "تم حذف $n حدث تحليلي";
            $messageType = 'success';
        }
        elseif ($action === 'clear_reports') {
            $n = Database::query('DELETE FROM reports')->rowCount();
            Audit::log(Auth::id(), 'tools.clear_reports', null, null, ['deleted' => $n]);
            $message = "تم حذف $n بلاغ";
            $messageType = 'success';
        }
        elseif ($action === 'clear_audit') {
            $keep = Auth::id();
            $n = Database::query('DELETE FROM audit_log WHERE admin_id != ?', [$keep])->rowCount();
            Audit::log(Auth::id(), 'tools.clear_audit', null, null, ['deleted' => $n]);
            $message = "تم حذف $n سجل تدقيق قديم";
            $messageType = 'success';
        }
        elseif ($action === 'purge_all') {
            $deleted = 0;
            $deleted += Database::query('DELETE FROM players')->rowCount();
            $deleted += Database::query('DELETE FROM sales_log')->rowCount();
            $deleted += Database::query('DELETE FROM analytics_events')->rowCount();
            $deleted += Database::query('DELETE FROM reports')->rowCount();
            $deleted += Database::query('DELETE FROM events')->rowCount();
            $deleted += Database::query('DELETE FROM quests')->rowCount();
            $deleted += Database::query('DELETE FROM shop_items')->rowCount();
            $deleted += Database::query('DELETE FROM announcements')->rowCount();
            $deleted += Database::query('DELETE FROM receipt_verifications')->rowCount();
            $deleted += Database::query('DELETE FROM admin_sessions')->rowCount();
            Database::query('DELETE FROM audit_log WHERE action != ?', ['admin.login']);
            Audit::log(Auth::id(), 'tools.purge_all', null, null, ['deleted' => $deleted]);
            $message = "🚨 تم مسح كل البيانات ($deleted سجل).";
            $messageType = 'warn';
        }

        // Refresh stats
        $stats['players'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM players')['c'];
        $stats['sales'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM sales_log')['c'];
        $stats['analytics'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM analytics_events')['c'];
        $stats['reports'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM reports')['c'];
        $stats['events'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM events')['c'];
        $stats['quests'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM quests')['c'];
        $stats['shop'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM shop_items')['c'];
        $stats['announcements'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM announcements')['c'];
        $stats['archives'] = (int) Database::fetch('SELECT COUNT(*) AS c FROM sales_archive')['c'];
    } catch (\Throwable $e) {
        $message = 'خطأ: ' . $e->getMessage();
        $messageType = 'error';
    }
}

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <div>
    <h1><span class="ic">🧰</span> <?= I18n::t('tools.title') ?></h1>
    <p class="page-sub">إدارة وصيانة قاعدة البيانات</p>
  </div>
  <div class="page-header-actions">
    <a href="archive.php" class="btn gold">📦 أرشيف المبيعات</a>
  </div>
</div>

<?php if ($message): ?>
  <div class="alert <?= $messageType === 'error' ? 'error' : ($messageType === 'warn' ? 'warn' : 'success') ?>">
    <?= Security::escape($message) ?>
  </div>
<?php endif; ?>

<!-- Current state -->
<div class="panel">
  <div class="panel-header">
    <h3><span class="ic">📊</span> البيانات الحالية</h3>
  </div>
  <div class="stats-grid" style="margin-block-end: 0;">
    <div class="stat-card s-cyan">
      <div class="stat-card-head">
        <div class="stat-label">اللاعبون</div>
        <div class="stat-icon" style="background: var(--c-cyan-soft); color: var(--c-cyan);">👥</div>
      </div>
      <div class="stat-val" data-count-to="<?= $stats['players'] ?>"><?= number_format($stats['players']) ?></div>
    </div>
    <div class="stat-card s-amber">
      <div class="stat-card-head">
        <div class="stat-label">المبيعات</div>
        <div class="stat-icon" style="background: var(--c-amber-soft); color: var(--c-amber);">💰</div>
      </div>
      <div class="stat-val" data-count-to="<?= $stats['sales'] ?>"><?= number_format($stats['sales']) ?></div>
    </div>
    <div class="stat-card s-violet">
      <div class="stat-card-head">
        <div class="stat-label">التحليلات</div>
        <div class="stat-icon" style="background: var(--c-violet-soft); color: var(--c-violet);">📈</div>
      </div>
      <div class="stat-val" data-count-to="<?= $stats['analytics'] ?>"><?= number_format($stats['analytics']) ?></div>
    </div>
    <div class="stat-card s-red">
      <div class="stat-card-head">
        <div class="stat-label">البلاغات</div>
        <div class="stat-icon" style="background: var(--c-red-soft); color: var(--c-red);">🛡️</div>
      </div>
      <div class="stat-val" data-count-to="<?= $stats['reports'] ?>"><?= number_format($stats['reports']) ?></div>
    </div>
    <div class="stat-card">
      <div class="stat-card-head">
        <div class="stat-label">الفعاليات</div>
        <div class="stat-icon" style="background: rgba(0,229,255,0.15); color: var(--c-cyan);">🎯</div>
      </div>
      <div class="stat-val"><?= number_format($stats['events']) ?></div>
    </div>
    <div class="stat-card">
      <div class="stat-card-head">
        <div class="stat-label">المهمات</div>
        <div class="stat-icon" style="background: rgba(0,230,118,0.15); color: var(--c-green);">⚔️</div>
      </div>
      <div class="stat-val"><?= number_format($stats['quests']) ?></div>
    </div>
    <div class="stat-card">
      <div class="stat-card-head">
        <div class="stat-label">منتجات المتجر</div>
        <div class="stat-icon" style="background: rgba(212,175,55,0.15); color: var(--c-amber);">💎</div>
      </div>
      <div class="stat-val"><?= number_format($stats['shop']) ?></div>
    </div>
    <div class="stat-card">
      <div class="stat-card-head">
        <div class="stat-label">الإعلانات</div>
        <div class="stat-icon" style="background: rgba(144,19,254,0.15); color: var(--c-violet);">📢</div>
      </div>
      <div class="stat-val"><?= number_format($stats['announcements']) ?></div>
    </div>
    <div class="stat-card">
      <div class="stat-card-head">
        <div class="stat-label">المديرون</div>
        <div class="stat-icon" style="background: rgba(255,255,255,0.06); color: var(--c-soft);">🔐</div>
      </div>
      <div class="stat-val"><?= number_format($stats['admins']) ?></div>
    </div>
    <div class="stat-card">
      <div class="stat-card-head">
        <div class="stat-label">الإعدادات عن بعد</div>
        <div class="stat-icon" style="background: rgba(0,229,255,0.15); color: var(--c-cyan);">⚙️</div>
      </div>
      <div class="stat-val"><?= number_format($stats['configs']) ?></div>
    </div>
    <div class="stat-card">
      <div class="stat-card-head">
        <div class="stat-label">السيناريوهات</div>
        <div class="stat-icon" style="background: rgba(0,230,118,0.15); color: var(--c-green);">🗺️</div>
      </div>
      <div class="stat-val"><?= number_format($stats['scenarios']) ?></div>
    </div>
    <div class="stat-card s-amber">
      <div class="stat-card-head">
        <div class="stat-label">الأرشيفات</div>
        <div class="stat-icon" style="background: var(--c-amber-soft); color: var(--c-amber);">📦</div>
      </div>
      <div class="stat-val"><?= number_format($stats['archives']) ?></div>
    </div>
  </div>
</div>

<!-- ==== Actions ==== -->
<div class="panel">
  <div class="panel-header">
    <h3><span class="ic">🧹</span> إجراءات التنظيف</h3>
  </div>
  <p class="text-muted text-sm mb-2">كل إجراء يُسجَّل في سجل التدقيق. إجراءات التصفير تحفظ نسخة في الأرشيف قبل الحذف.</p>

  <form method="POST" style="display:flex; flex-direction:column; gap:0.75rem;">
    <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">

    <div class="action-row">
      <div>
        <strong>مسح البيانات التجريبية فقط</strong>
        <p class="text-muted text-sm">يحذف اللاعبين الافتراضيين (uid_001...005) ومبيعاتهم. يحتفظ بكل ما أنشأته.</p>
      </div>
      <button type="submit" name="action" value="clear_demo" class="btn success" onclick="return confirm('مسح البيانات التجريبية؟')">مسح</button>
    </div>

    <div class="action-row">
      <div>
        <strong>حذف كل اللاعبين</strong>
        <p class="text-muted text-sm">يحذف جميع سجلات اللاعبين. لا يحذف سجل دخولك الحالي.</p>
      </div>
      <button type="submit" name="action" value="clear_players" class="btn danger" onclick="return confirm('⚠️ حذف كل اللاعبين نهائياً؟')">حذف</button>
    </div>

    <div class="action-row">
      <div>
        <strong>حذف أحداث التحليلات</strong>
        <p class="text-muted text-sm">يحذف كل أحداث التحليلات. لا يحذف المبيعات.</p>
      </div>
      <button type="submit" name="action" value="clear_analytics" class="btn danger" onclick="return confirm('⚠️ حذف كل التحليلات؟')">حذف</button>
    </div>

    <div class="action-row">
      <div>
        <strong>حذف كل البلاغات</strong>
        <p class="text-muted text-sm">يحذف جميع بلاغات اللاعبين.</p>
      </div>
      <button type="submit" name="action" value="clear_reports" class="btn danger" onclick="return confirm('⚠️ حذف كل البلاغات؟')">حذف</button>
    </div>

    <div class="action-row">
      <div>
        <strong>تنظيف سجل التدقيق</strong>
        <p class="text-muted text-sm">يحذف السجلات القديمة (يحتفظ بسجل دخولك الحالي).</p>
      </div>
      <button type="submit" name="action" value="clear_audit" class="btn">تنظيف</button>
    </div>

    <div class="action-row danger-zone">
      <div>
        <strong style="color: var(--c-red);">🚨 مسح شامل (إعادة ضبط المصنع)</strong>
        <p class="text-muted text-sm">يحذف كل البيانات التشغيلية. يحتفظ فقط بحسابك والإعدادات. <strong>المبيعات تُحذف بدون أرشفة هنا</strong> — استخدم صفحة الأرشيف أولاً.</p>
      </div>
      <button type="submit" name="action" value="purge_all" class="btn danger" onclick="return confirm('🚨 مسح شامل؟')">مسح شامل</button>
    </div>
  </form>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>