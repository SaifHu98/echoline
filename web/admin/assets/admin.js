/* ============================================================
   ECHO//LINE — Admin Panel Client JS v2.0
   ============================================================ */
(function () {
  'use strict';

  // Toast notifications
  const host = document.createElement('div');
  host.className = 'toast-host';
  document.body.appendChild(host);

  window.showToast = function (msg, type = 'info') {
    const el = document.createElement('div');
    el.className = 'toast-client ' + type;
    el.textContent = msg;
    host.appendChild(el);
    setTimeout(() => {
      el.classList.add('fade-out');
      setTimeout(() => el.remove(), 300);
    }, 2800);
  };

  // Close sidebar on outside click (mobile)
  document.addEventListener('click', (e) => {
    const sidebar = document.getElementById('app-sidebar');
    const toggle = document.querySelector('.sidebar-toggle');
    if (!sidebar || !toggle) return;
    if (window.innerWidth > 1024) return;
    if (sidebar.classList.contains('open') &&
        !sidebar.contains(e.target) &&
        !toggle.contains(e.target)) {
      sidebar.classList.remove('open');
    }
  });

  // Auto-dismiss alerts after 5s
  document.querySelectorAll('.alert, .flash').forEach(el => {
    setTimeout(() => {
      el.style.transition = 'opacity 0.4s, transform 0.4s';
      el.style.opacity = '0';
      el.style.transform = 'translateY(-10px)';
      setTimeout(() => el.remove(), 500);
    }, 6000);
  });

  // Animate stat values counting up
  document.querySelectorAll('.stat-val[data-count-to]').forEach(el => {
    const target = parseFloat(el.dataset.countTo);
    if (isNaN(target)) return;
    const duration = 800;
    const start = performance.now();
    const startVal = 0;
    const step = (now) => {
      const progress = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      const value = startVal + (target - startVal) * eased;
      el.textContent = Number.isInteger(target)
        ? Math.floor(value).toLocaleString()
        : value.toFixed(target % 1 === 0 ? 0 : 2);
      if (progress < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  });

  // Smooth scroll to top after form submit
  if (window.location.search.includes('saved') || window.location.search.includes('error')) {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
})();