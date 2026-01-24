// Theme manager: centralize theme switching, init, persistence
(function(){
  const root = document.documentElement;
  const THEME_KEY = 'theme';

  function ensureCSS() {
    console.info('[ThemeManager] ensureCSS invoked');
    if (document.getElementById('theme-tokens')) return;
    const style = document.createElement('style');
    style.id = 'theme-tokens';
    style.textContent = `
:root { --bg:#ffffff; --surface:#ffffff; --text:#1f2937; --muted:#6b7280; --card:#ffffff; }
[data-theme="dark"] { --bg:#0b0f14; --surface:#141923; --text:#e5e7eb; --muted:#9ca3af; --card:#171b24; }
html, body { background: var(--bg); color: var(--text); }
[data-theme="dark"] * { color: var(--text) !important; }
[data-theme="dark"] svg { fill: var(--text) !important; }
    `;
    document.head.appendChild(style);
  }

  function apply(mode) {
    console.info('[ThemeManager] apply', mode);
    root.setAttribute('data-theme', mode);
    const badge = document.getElementById('theme-diagnostic');
    if (badge) badge.textContent = 'Theme: ' + mode;
  }

  function load() {
    console.info('[ThemeManager] load check');
    let mode = 'light';
    try {
      const saved = localStorage.getItem(THEME_KEY);
      if (saved === 'dark' || saved === 'light') {
        mode = saved;
      } else if (typeof window.matchMedia === 'function') {
        mode = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      }
    } catch (e) {
      if (typeof window.matchMedia === 'function') {
        mode = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      }
    }
    apply(mode);
    return mode;
  }

  function ensureDiagnosticBadge() {
    if (document.getElementById('theme-diagnostic')) return;
    const badge = document.createElement('div');
    badge.id = 'theme-diagnostic';
    badge.style.position = 'fixed';
    badge.style.bottom = '12px';
    badge.style.right = '12px';
    badge.style.background = 'rgba(0,0,0,0.6)';
    badge.style.color = '#fff';
    badge.style.padding = '6px 10px';
    badge.style.borderRadius = '8px';
    badge.style.fontFamily = 'monospace';
    badge.style.fontSize = '12px';
    badge.style.zIndex = '9999';
    badge.textContent = 'Theme: unknown';
    document.body.appendChild(badge);
  }

  function init() {
    console.info('[ThemeManager] init invoked');
    ensureCSS();
    ensureDiagnosticBadge();
    if (!root.getAttribute('data-theme')) load();
    const t = root.getAttribute('data-theme') || 'none';
    console.info('[ThemeManager] initial theme:', t);
  }

  function bindSystemThemeListener() {
    try {
      const mql = window.matchMedia('(prefers-color-scheme: dark)');
      const handler = (e) => {
        const saved = (typeof localStorage !== 'undefined') ? localStorage.getItem(THEME_KEY) : null;
        if (!saved) {
          const mode = e.matches ? 'dark' : 'light';
          apply(mode);
        }
      };
      if (mql.addEventListener) mql.addEventListener('change', handler);
      else if (mql.addListener) mql.addListener(handler);
    } catch (e) {
      // ignore
    }
  }

  window.setTheme = function(mode) {
    if (!['light','dark'].includes(mode)) return;
    try { localStorage.setItem(THEME_KEY, mode); } catch (e) { }
    console.info('[ThemeManager] setTheme called with', mode);
    apply(mode);
  };

  // Simple getter for testing
  window.getTheme = function() { return document.documentElement.getAttribute('data-theme'); };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => { init(); bindSystemThemeListener(); });
  } else {
    init(); bindSystemThemeListener();
  }
})();
