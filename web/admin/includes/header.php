<?php
/**
 * Header layout — used by all admin pages
 * Modern v2.0 with full RTL support via CSS grid
 */
if (!defined('ADMIN_INCLUDED')) define('ADMIN_INCLUDED', 1);

require_once __DIR__ . '/../config.php';
Security::startSession();

$pageTitle = $pageTitle ?? I18n::t('dashboard.welcome');
$currentSection = $currentSection ?? 'dashboard';
$csrfToken = Security::csrfToken();

// Get unread counts for badges
$unreadReports = 0;
$openReports = 0;
try {
    $unreadReports = (int) Database::fetch("SELECT COUNT(*) AS c FROM reports WHERE status = 'open'")['c'];
    $openReports = $unreadReports;
} catch (\Throwable $e) {}

// Active events count
$activeEventsCount = 0;
try {
    $activeEventsCount = (int) Database::fetch(
        "SELECT COUNT(*) AS c FROM events WHERE is_active = 1 AND NOW() BETWEEN start_at AND end_at"
    )['c'];
} catch (\Throwable $e) {}

// Players online count
$playersOnline = 0;
try {
    $playersOnline = (int) Database::fetch(
        "SELECT COUNT(*) AS c FROM players WHERE last_login_at >= DATE_SUB(NOW(), INTERVAL 5 MINUTE)"
    )['c'];
} catch (\Throwable $e) {}
?>
<!DOCTYPE html>
<html lang="<?= I18n::locale() ?>" dir="<?= I18n::direction() ?>">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="theme-color" content="#04060B">
  <title><?= Security::escape($pageTitle) ?> — <?= APP_NAME ?></title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;900&family=Outfit:wght@400;600;700;900&family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="assets/admin.css?v=2">
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Cpath fill='%2300E5FF' d='M32 2 L60 32 L32 62 L4 32 Z'/%3E%3Cpath fill='%23D4AF37' d='M32 14 L48 32 L32 50 L16 32 Z'/%3E%3C/svg%3E">
</head>
<body>

<?php if (Auth::check()): ?>
<div id="app-shell">

  <!-- ============ SIDEBAR ============ -->
  <aside id="app-sidebar">

    <div class="sidebar-brand">
      <div class="brand-logo"></div>
      <div>
        <div class="brand-name">ECHO//LINE</div>
        <div class="brand-sub"><?= I18n::t('app.subtitle') ?></div>
      </div>
    </div>

    <nav class="nav-section">

      <div class="nav-section-title"><?= I18n::t('menu.dashboard') ?></div>
      <ul class="nav-list">
        <li>
          <a href="dashboard.php" class="nav-item <?= $currentSection === 'dashboard' ? 'active' : '' ?>">
            <span class="ic">📊</span>
            <span><?= I18n::t('menu.dashboard') ?></span>
          </a>
        </li>
        <li>
          <a href="analytics.php" class="nav-item <?= $currentSection === 'analytics' ? 'active' : '' ?>">
            <span class="ic">📈</span>
            <span><?= I18n::t('menu.analytics') ?></span>
          </a>
        </li>
      </ul>

      <div class="nav-section-title"><?= I18n::t('events.title') ?></div>
      <ul class="nav-list">
        <li>
          <a href="events.php" class="nav-item <?= $currentSection === 'events' ? 'active' : '' ?>">
            <span class="ic">🎯</span>
            <span><?= I18n::t('menu.events') ?></span>
            <?php if ($activeEventsCount > 0): ?>
              <span class="badge-num"><?= $activeEventsCount ?></span>
            <?php endif; ?>
          </a>
        </li>
        <li>
          <a href="quests.php" class="nav-item <?= $currentSection === 'quests' ? 'active' : '' ?>">
            <span class="ic">⚔️</span>
            <span><?= I18n::t('menu.quests') ?></span>
          </a>
        </li>
        <li>
          <a href="announcements.php" class="nav-item <?= $currentSection === 'announcements' ? 'active' : '' ?>">
            <span class="ic">📢</span>
            <span><?= I18n::t('menu.announcements') ?></span>
          </a>
        </li>
      </ul>

      <div class="nav-section-title"><?= I18n::t('shop.title') ?></div>
      <ul class="nav-list">
        <li>
          <a href="shop.php" class="nav-item <?= $currentSection === 'shop' ? 'active' : '' ?>">
            <span class="ic">💎</span>
            <span><?= I18n::t('menu.shop') ?></span>
          </a>
        </li>
        <li>
          <a href="scenarios.php" class="nav-item <?= $currentSection === 'scenarios' ? 'active' : '' ?>">
            <span class="ic">🗺️</span>
            <span><?= I18n::t('menu.scenarios') ?></span>
          </a>
        </li>
        <li>
          <a href="echo_system.php" class="nav-item <?= $currentSection === 'echo' ? 'active' : '' ?>">
            <span class="ic">🌀</span>
            <span><?= I18n::t('menu.echo') ?></span>
          </a>
        </li>
      </ul>

      <div class="nav-section-title"><?= I18n::t('players.title') ?></div>
      <ul class="nav-list">
        <li>
          <a href="players.php" class="nav-item <?= $currentSection === 'players' ? 'active' : '' ?>">
            <span class="ic">👥</span>
            <span><?= I18n::t('menu.players') ?></span>
          </a>
        </li>
        <li>
          <a href="reports.php" class="nav-item <?= $currentSection === 'reports' ? 'active' : '' ?>">
            <span class="ic">🛡️</span>
            <span><?= I18n::t('menu.reports') ?></span>
            <?php if ($unreadReports > 0): ?>
              <span class="badge-num"><?= $unreadReports ?></span>
            <?php endif; ?>
          </a>
        </li>
        <li>
          <a href="receipts.php" class="nav-item <?= $currentSection === 'receipts' ? 'active' : '' ?>">
            <span class="ic">🧾</span>
            <span><?= I18n::t('menu.receipts') ?></span>
          </a>
        </li>
      </ul>

      <div class="nav-section-title"><?= I18n::t('config.title') ?></div>
      <ul class="nav-list">
        <li>
          <a href="remote_config.php" class="nav-item <?= $currentSection === 'config' ? 'active' : '' ?>">
            <span class="ic">⚙️</span>
            <span><?= I18n::t('menu.config') ?></span>
          </a>
        </li>
        <li>
          <a href="localization.php" class="nav-item <?= $currentSection === 'localization' ? 'active' : '' ?>">
            <span class="ic">🌍</span>
            <span><?= I18n::t('menu.localization') ?></span>
          </a>
        </li>
      </ul>

      <div class="nav-section-title"><?= I18n::t('tools.title') ?></div>
      <ul class="nav-list">
        <li>
          <a href="tools.php" class="nav-item <?= $currentSection === 'tools' ? 'active' : '' ?>">
            <span class="ic">🧰</span>
            <span><?= I18n::t('menu.tools') ?></span>
          </a>
        </li>
        <li>
          <a href="audit.php" class="nav-item <?= $currentSection === 'audit' ? 'active' : '' ?>">
            <span class="ic">📜</span>
            <span><?= I18n::t('menu.audit') ?></span>
          </a>
        </li>
        <?php if (Auth::role() === 'superadmin'): ?>
        <li>
          <a href="admins.php" class="nav-item <?= $currentSection === 'admins' ? 'active' : '' ?>">
            <span class="ic">🔐</span>
            <span><?= I18n::t('menu.admins') ?></span>
          </a>
        </li>
        <?php endif; ?>
      </ul>

    </nav>

    <div class="sidebar-foot">
      <div class="user-chip" style="margin-block-end: 0.5rem; inline-size: 100%; justify-content: flex-start;">
        <div class="user-avatar"><?= mb_strtoupper(mb_substr(Auth::user()['username'] ?? '?', 0, 1)) ?></div>
        <div style="flex:1; min-inline-size:0;">
          <div class="user-name" style="overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">
            <?= Security::escape(Auth::user()['username'] ?? '') ?>
          </div>
          <div class="user-role"><?= Security::escape(Auth::role() ?? '') ?></div>
        </div>
      </div>
      <a href="logout.php" class="btn ghost block">
        <span class="ic">🚪</span>
        <span><?= I18n::t('common.logout') ?></span>
      </a>
    </div>

  </aside>

  <!-- ============ HEADER ============ -->
  <header id="app-header">
    <button class="sidebar-toggle" onclick="document.getElementById('app-sidebar').classList.toggle('open')" aria-label="Menu">☰</button>

    <div class="header-tools">
      <span class="badge cyan" style="font-size: 0.78rem;">
        <span class="badge dot" style="background: var(--c-green);"></span>
        <span style="margin-inline-start: 0.4rem;"><?= $playersOnline ?> <?= I18n::t('dashboard.players_online') ?></span>
      </span>
    </div>

    <div class="header-tools">
      <?php if ($openReports > 0): ?>
      <a href="reports.php" class="header-action-btn" title="<?= I18n::t('reports.open') ?>">
        🔔
        <span class="dot"></span>
      </a>
      <?php endif; ?>
      <div class="user-chip">
        <div class="user-avatar"><?= mb_strtoupper(mb_substr(Auth::user()['username'] ?? '?', 0, 1)) ?></div>
        <div>
          <div class="user-name"><?= Security::escape(Auth::user()['username'] ?? '') ?></div>
          <div class="user-role"><?= Security::escape(Auth::role() ?? '') ?></div>
        </div>
      </div>
    </div>
  </header>

  <!-- ============ MAIN ============ -->
  <main id="app-main">
    <?php if (!empty($flashMessage)): ?>
      <div class="flash flash-<?= Security::escape($flashType ?? 'info') ?>">
        <?= Security::escape($flashMessage) ?>
      </div>
    <?php endif; ?>

<?php else: ?>
<!-- Login page uses its own layout; do nothing -->
<?php endif; ?>
