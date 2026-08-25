/**
 * AdminBridge — fetches remote config / events / quests from Hostinger admin
 * Caches results to reduce calls; refreshes every 60s.
 */
'use strict';

class AdminBridge {
  constructor({ baseUrl, apiKey, logger }) {
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
    this.logger = logger;
    this.cache = {
      config: null,
      events: null,
      quests: null,
      shop: null,
      announcements: null,
    };
    this.lastFetch = 0;
    this.cacheTTL = 60 * 1000;
  }

  async refreshIfStale() {
    if (Date.now() - this.lastFetch < this.cacheTTL) return;
    await this.refresh();
  }

  async refresh() {
    if (!this.baseUrl) {
      // No admin URL — use built-in defaults
      this.cache = { config: this._defaultConfig(), events: [], quests: [], shop: [], announcements: [] };
      this.lastFetch = Date.now();
      return;
    }
    try {
      const [config, events, quests, shop, announcements] = await Promise.all([
        this._fetch('config'),
        this._fetch('events'),
        this._fetch('quests'),
        this._fetch('shop'),
        this._fetch('announcements'),
      ]);
      this.cache = { config, events, quests, shop, announcements };
      this.lastFetch = Date.now();
      this.logger.info({ host: this.baseUrl }, 'Admin bridge refreshed');
    } catch (e) {
      this.logger.warn({ err: e.message }, 'Admin bridge refresh failed; using cache');
    }
  }

  async _fetch(action) {
    const url = `${this.baseUrl}?action=${action}${this.apiKey ? '&key=' + this.apiKey : ''}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) throw new Error(`${action} HTTP ${res.status}`);
    const json = await res.json();
    if (!json.success) throw new Error(`${action} returned error`);
    return json.data;
  }

  getConfig() { return this.cache.config || this._defaultConfig(); }
  getActiveEvents() { return (this.cache.events?.events || []).filter(e => e.seconds_remaining > 0); }
  getActiveQuests() { return this.cache.quests?.quests || []; }
  getShopItems() { return this.cache.shop?.items || []; }
  getAnnouncements(lang) {
    const list = this.cache.announcements?.announcements || [];
    return list.filter(a => !lang || a.language === lang || a.language === 'both');
  }

  _defaultConfig() {
    return {
      match: { duration_seconds: { value: 600 } },
      match_min_players: { value: 2 },
      match_max_players: { value: 4 },
      echo: { propagation_speed: { value: 1.0 } },
      catastrophe: { starting_stability: { value: 100 } },
      shop: { shards_bonus_active: { value: true, multiplier: 1.5 } },
      maintenance: { enabled: { value: false } },
      allowed_languages: { value: ['en', 'ar'] },
      version: '1.0.0',
    };
  }
}

module.exports = AdminBridge;