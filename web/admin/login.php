<?php
require_once __DIR__ . '/config.php';
Security::startSession();

if (Auth::check()) {
    Response::redirect('dashboard.php');
}

$error = null;
$username = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    $token = $_POST[CSRF_TOKEN_NAME] ?? '';

    if (!Security::verifyCsrf($token)) {
        $error = I18n::t('error.csrf');
    } else {
        try {
            Auth::login($username, $password);
            Response::redirect('dashboard.php');
        } catch (\Throwable $e) {
            $error = $e->getMessage();
        }
    }
}

$csrfToken = Security::csrfToken();
?><!DOCTYPE html>
<html lang="<?= I18n::locale() ?>" dir="<?= I18n::direction() ?>">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="theme-color" content="#04060B">
  <title><?= I18n::t('login.title') ?></title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;900&family=Outfit:wght@400;600;700;900&family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="assets/login.css">
</head>
<body class="login-page">

  <!-- Animated background -->
  <div class="bg-orbs" aria-hidden="true">
    <div class="orb orb-1"></div>
    <div class="orb orb-2"></div>
    <div class="orb orb-3"></div>
    <div class="grid-pattern"></div>
  </div>

  <main class="login-wrap">
    <div class="login-card" data-animate="rise">

      <!-- Logo -->
      <div class="logo-zone">
        <div class="logo-mark">
          <svg viewBox="0 0 64 64" width="56" height="56" aria-hidden="true">
            <defs>
              <linearGradient id="lg1" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stop-color="#00E5FF"/>
                <stop offset="100%" stop-color="#D4AF37"/>
              </linearGradient>
              <linearGradient id="lg2" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stop-color="#9013FE"/>
                <stop offset="100%" stop-color="#00E5FF"/>
              </linearGradient>
            </defs>
            <path fill="url(#lg1)" d="M32 2 L60 32 L32 62 L4 32 Z"/>
            <path fill="url(#lg2)" d="M32 14 L48 32 L32 50 L16 32 Z"/>
            <circle cx="32" cy="32" r="4" fill="#fff"/>
          </svg>
        </div>
        <h1 class="brand-title">
          <span class="t-en">ECHO//LINE</span>
          <span class="t-ar">أصداء</span>
        </h1>
        <p class="brand-tag" data-i18n="app.subtitle">Echoes Across Time</p>
      </div>

      <!-- Error -->
      <?php if ($error): ?>
        <div class="alert" role="alert">
          <span class="alert-ic">⚠</span>
          <span><?= Security::escape($error) ?></span>
        </div>
      <?php endif; ?>

      <!-- Form -->
      <form method="POST" class="login-form" autocomplete="on" novalidate>
        <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= $csrfToken ?>">

        <div class="field">
          <label for="username"><?= I18n::t('login.username') ?></label>
          <div class="input-shell">
            <svg class="input-ic" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></svg>
            <input
              type="text"
              id="username"
              name="username"
              required
              autofocus
              autocomplete="username"
              spellcheck="false"
              value="<?= Security::escape($username) ?>"
              placeholder="<?= I18n::t('login.username') ?>"
            >
          </div>
        </div>

        <div class="field">
          <label for="password"><?= I18n::t('login.password') ?></label>
          <div class="input-shell">
            <svg class="input-ic" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 1 1 8 0v4"/></svg>
            <input
              type="password"
              id="password"
              name="password"
              required
              autocomplete="current-password"
              placeholder="••••••••"
            >
            <button type="button" class="toggle-pwd" aria-label="show password" data-target="password">
              <svg class="eye-on" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/></svg>
              <svg class="eye-off" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 17.5A9.4 9.4 0 0 1 12 19c-7 0-11-7-11-7a18 18 0 0 1 4.06-5.06M9.9 4.5A9.5 9.5 0 0 1 12 4c7 0 11 7 11 7a18 18 0 0 1-2.16 3.19M14.12 14.12A3 3 0 1 1 9.88 9.88"/><line x1="2" y1="2" x2="22" y2="22"/></svg>
            </button>
          </div>
        </div>

        <button type="submit" class="btn-submit">
          <span><?= I18n::t('login.submit') ?></span>
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
        </button>
      </form>

      <!-- Security badge -->
      <div class="security">
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2 4 6v6c0 5 3.5 9 8 10 4.5-1 8-5 8-10V6z"/></svg>
        <span>Secure session · CSRF protected · bcrypt</span>
      </div>
    </div>

    <footer class="login-foot">
      <span>ECHO//LINE · LiveOps Console · v<?= APP_VERSION ?></span>
    </footer>
  </main>

  <script>
    // Password show/hide
    document.querySelectorAll('.toggle-pwd').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.target;
        const input = document.getElementById(id);
        if (!input) return;
        const showing = input.type === 'text';
        input.type = showing ? 'password' : 'text';
        btn.classList.toggle('showing', !showing);
      });
    });

    // Card rise animation
    const card = document.querySelector('[data-animate="rise"]');
    if (card) {
      requestAnimationFrame(() => card.classList.add('in'));
    }
  </script>
</body>
</html>