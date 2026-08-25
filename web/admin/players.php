<?php
require_once __DIR__ . '/config.php';
Auth::require();

$pageTitle = I18n::t('players.title');
$currentSection = 'players';

$search = Security::input('q', '', 'string');
$status = Security::input('status', '', 'string');

$where = '1=1';
$params = [];
if ($search) {
    $where .= ' AND (display_name LIKE ? OR player_uid LIKE ? OR email LIKE ?)';
    $params[] = "%{$search}%";
    $params[] = "%{$search}%";
    $params[] = "%{$search}%";
}
if ($status === 'banned') {
    $where .= ' AND is_banned = 1';
} elseif ($status === 'active') {
    $where .= ' AND is_banned = 0 AND last_login_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)';
}

$page = max(1, (int) Security::input('page', 1, 'int'));
$perPage = 25;
$offset = ($page - 1) * $perPage;

$total = (int) Database::fetch("SELECT COUNT(*) AS c FROM players WHERE {$where}", $params)['c'];
$players = Database::fetchAll(
    "SELECT * FROM players WHERE {$where} ORDER BY created_at DESC LIMIT {$perPage} OFFSET {$offset}",
    $params
);

// Ban/Unban action
$message = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST' && Security::verifyCsrf(Security::input(CSRF_TOKEN_NAME))) {
    $action = Security::input('action');
    $pid = Security::input('player_uid', '', 'string');

    if ($action === 'ban' && $pid) {
        $reason = Security::input('reason', '', 'string');
        $days = (int) Security::input('days', 0, 'int');
        $expires = $days > 0 ? date('Y-m-d H:i:s', time() + $days * 86400) : null;
        Database::update('players', [
            'is_banned' => 1,
            'ban_reason' => $reason,
            'ban_expires_at' => $expires,
        ], 'player_uid = ?', [$pid]);
        Audit::log(Auth::id(), 'player.ban', 'player', $pid, ['reason' => $reason, 'days' => $days]);
        $message = 'تم حظر اللاعب';
    } elseif ($action === 'unban' && $pid) {
        Database::update('players', [
            'is_banned' => 0,
            'ban_reason' => null,
            'ban_expires_at' => null,
        ], 'player_uid = ?', [$pid]);
        Audit::log(Auth::id(), 'player.unban', 'player', $pid);
        $message = 'تم رفع الحظر';
    } elseif ($action === 'grant' && $pid) {
        $currency = (int) Security::input('currency', 0, 'int');
        $xp = (int) Security::input('xp', 0, 'int');
        Database::query('UPDATE players SET currency_premium = currency_premium + ?, xp = xp + ? WHERE player_uid = ?',
            [$currency, $xp, $pid]);
        Audit::log(Auth::id(), 'player.grant', 'player', $pid, ['currency' => $currency, 'xp' => $xp]);
        $message = 'تم منح المكافآت';
    }
}

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('players.title') ?> <span class="text-muted">(<?= number_format($total) ?>)</span></h1>
</div>

<?php if ($message): ?>
  <div class="alert alert-success"><?= Security::escape($message) ?></div>
<?php endif; ?>

<div class="panel">
  <form method="GET" class="filter-bar">
    <input type="text" name="q" value="<?= Security::escape($search) ?>" placeholder="<?= I18n::t('players.search') ?>">
    <select name="status">
      <option value="">جميع الحالات</option>
      <option value="active" <?= $status === 'active' ? 'selected' : '' ?>>نشط (آخر 7 أيام)</option>
      <option value="banned" <?= $status === 'banned' ? 'selected' : '' ?>>محظور</option>
    </select>
    <button class="btn primary">بحث</button>
  </form>

  <table class="data-table">
    <thead>
      <tr>
        <th>الاسم</th><th>المعرّف</th><th>المنصة</th><th>المستوى</th>
        <th>العملات</th><th>المباريات</th><th>الحالة</th><th>آخر دخول</th><th>الإجراءات</th>
      </tr>
    </thead>
    <tbody>
      <?php foreach ($players as $p): ?>
        <tr>
          <td>
            <strong><?= Security::escape($p['display_name']) ?></strong>
            <?php if ($p['is_muted']): ?><span class="badge warn">🔇</span><?php endif; ?>
          </td>
          <td><code class="small"><?= Security::escape($p['player_uid']) ?></code></td>
          <td><span class="badge"><?= Security::escape($p['platform']) ?></span></td>
          <td><span class="text-cyan">Lv.<?= $p['level'] ?></span> <span class="text-muted small"><?= number_format($p['xp']) ?> XP</span></td>
          <td>
            <span class="text-amber">💎 <?= number_format($p['currency_premium']) ?></span><br>
            <span class="text-soft">🪙 <?= number_format($p['currency_soft']) ?></span>
          </td>
          <td>
            <?= $p['matches_played'] ?><br>
            <span class="text-green small">فاز: <?= $p['matches_won'] ?></span>
          </td>
          <td>
            <?php if ($p['is_banned']): ?>
              <span class="badge danger">محظور</span>
              <?php if ($p['ban_expires_at']): ?>
                <small class="text-muted">حتى <?= substr($p['ban_expires_at'], 0, 10) ?></small>
              <?php endif; ?>
            <?php else: ?>
              <span class="badge badge-ok">نشط</span>
            <?php endif; ?>
          </td>
          <td class="text-muted small"><?= $p['last_login_at'] ? Security::escape(substr($p['last_login_at'], 0, 16)) : '—' ?></td>
          <td>
            <button class="btn small" onclick='grantPlayer(<?= json_encode($p, JSON_HEX_APOS | JSON_HEX_QUOT) ?>)'>منح</button>
            <?php if ($p['is_banned']): ?>
              <button class="btn small success" onclick='unbanPlayer(<?= json_encode($p['player_uid']) ?>)'>رفع الحظر</button>
            <?php else: ?>
              <button class="btn small danger" onclick='banPlayer(<?= json_encode($p, JSON_HEX_APOS | JSON_HEX_QUOT) ?>)'>حظر</button>
            <?php endif; ?>
          </td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>

  <?php if ($total > $perPage): ?>
    <div class="pagination">
      <?php for ($i = 1; $i <= ceil($total / $perPage); $i++): ?>
        <a href="?page=<?= $i ?>&q=<?= urlencode($search) ?>&status=<?= urlencode($status) ?>"
           class="btn small <?= $i === $page ? 'primary' : '' ?>"><?= $i ?></a>
      <?php endfor; ?>
    </div>
  <?php endif; ?>
</div>

<!-- Ban modal -->
<div id="ban-modal" class="modal" hidden>
  <div class="modal-content">
    <h2>حظر لاعب</h2>
    <form method="POST" id="ban-form">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="ban">
      <input type="hidden" name="player_uid" id="ban-uid">
      <div class="form-group">
        <label>السبب</label>
        <textarea name="reason" id="ban-reason" required rows="3"></textarea>
      </div>
      <div class="form-group">
        <label>مدة الحظر (بالأيام، 0 = دائم)</label>
        <input type="number" name="days" id="ban-days" value="7" min="0">
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="document.getElementById('ban-modal').hidden=true">إلغاء</button>
        <button type="submit" class="btn danger">تأكيد الحظر</button>
      </div>
    </form>
  </div>
</div>

<!-- Grant modal -->
<div id="grant-modal" class="modal" hidden>
  <div class="modal-content">
    <h2>منح مكافآت</h2>
    <form method="POST" id="grant-form">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="grant">
      <input type="hidden" name="player_uid" id="grant-uid">
      <div class="form-group">
        <label>اللاعب: <strong id="grant-name"></strong></label>
      </div>
      <div class="form-group">
        <label>شظايا الزمن (💎)</label>
        <input type="number" name="currency" id="grant-curr" value="100" min="0">
      </div>
      <div class="form-group">
        <label>خبرة (XP)</label>
        <input type="number" name="xp" id="grant-xp" value="500" min="0">
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="document.getElementById('grant-modal').hidden=true">إلغاء</button>
        <button type="submit" class="btn primary">منح</button>
      </div>
    </form>
  </div>
</div>

<script>
function banPlayer(p) {
  document.getElementById('ban-modal').hidden = false;
  document.getElementById('ban-uid').value = p.player_uid;
  document.getElementById('ban-reason').value = '';
}
function unbanPlayer(uid) {
  if (!confirm('رفع الحظر؟')) return;
  const f = document.createElement('form');
  f.method = 'POST';
  f.innerHTML = `<input name="_token" value="${document.getElementById('csrf-token').value}">
                 <input name="action" value="unban"><input name="player_uid" value="${uid}">`;
  document.body.appendChild(f); f.submit();
}
function grantPlayer(p) {
  document.getElementById('grant-modal').hidden = false;
  document.getElementById('grant-uid').value = p.player_uid;
  document.getElementById('grant-name').textContent = p.display_name;
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>