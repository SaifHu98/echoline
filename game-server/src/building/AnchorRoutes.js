const express = require('express');
const crypto = require('node:crypto');

class AnchorRoutes {
  constructor(anchorManager, persistence, options = {}) {
    if (!anchorManager) throw new Error('AnchorRoutes: anchorManager required');
    if (!persistence) throw new Error('AnchorRoutes: persistence required');
    this.anchorManager = anchorManager;
    this.persistence = persistence;
    this.auth_secret = options.auth_secret || process.env.AUTH_SECRET || '';
    this.rate_limit = options.rate_limit || { window_ms: 1000, max: 10 };
    this._buckets = new Map();
    this.router = express.Router();
    this._register();
  }

  static for(anchorManager, persistence, options = {}) {
    return new AnchorRoutes(anchorManager, persistence, options);
  }

  _register() {
    this.router.post('/anchors', this._rateLimit.bind(this), this._requireSigned.bind(this), this.create.bind(this));
    this.router.post('/anchors/:id/events', this._rateLimit.bind(this), this._requireSigned.bind(this), this.processEvent.bind(this));
    this.router.get('/anchors/:id', this._rateLimit.bind(this), this._requireSigned.bind(this), this.getAnchor.bind(this));
    this.router.delete('/anchors/:id', this._rateLimit.bind(this), this._requireSigned.bind(this), this.destroy.bind(this));
    this.router.get('/rooms/:roomId/anchors', this._rateLimit.bind(this), this._requireSigned.bind(this), this.listRoomAnchors.bind(this));
    this.router.get('/players/:playerId/stats', this._rateLimit.bind(this), this._requireSigned.bind(this), this.getPlayerStats.bind(this));
    this.router.get('/leaderboard', this._rateLimit.bind(this), this._requireSigned.bind(this), this.getLeaderboard.bind(this));
  }

  async create(req, res) {
    const { blueprint_id, players } = req.body || {};
    if (!blueprint_id) return res.status(400).json({ ok: false, reason: 'missing_blueprint_id' });
    if (!Array.isArray(players)) return res.status(400).json({ ok: false, reason: 'missing_players' });
    const result = this.anchorManager.createAnchor(blueprint_id, players);
    if (!result.ok) return res.status(400).json(result);
    try {
      await this.persistence.persistAnchorCreate({
        ...result.anchor,
        room_id: req.body.room_id || 'unknown'
      });
      res.status(201).json(result);
    } catch (err) {
      res.status(500).json({ ok: false, reason: 'persistence_failed', error: err.message });
    }
  }

  async processEvent(req, res) {
    const anchorId = req.params.id;
    const payload = req.body || {};
    try {
      const result = this.anchorManager.processEvent(anchorId, payload);
      const auditPayload = {
        actor_player_id: payload.player_id,
        slot_index: payload.slot_index,
        shard_id: payload.shard_id,
        event_id: payload.event_id,
        place_seq: result.place_seq,
        ok: result.ok !== false,
        reason: result.reason,
        state_before: result.ok === false ? payload._state_before : null,
        state_after: result.snapshot,
        ts: Date.now()
      };
      try {
        await this.persistence.persistAuditEvent(anchorId, payload.type || 'unknown', auditPayload);
        if (payload.type === 'place_shard' && result.ok) {
          const slot = result.snapshot?.slots?.[payload.slot_index];
          if (slot) {
            await this.persistence.persistSlotPlacement(anchorId, payload.slot_index, {
              slot_kind: slot.slot_id?.includes('core') ? 'core' : (slot.slot_id?.includes('brace') ? 'brace' : 'cap'),
              preferred_timeline: 'neutral',
              state: 'filled',
              placed_shard_id: payload.shard_id,
              place_seq: result.place_seq,
              placed_at: Date.now()
            }, payload.player_id, payload.event_id);
          }
        } else if (payload.type === 'remove_shard' && result.ok) {
          await this.persistence.persistSlotRemoval(anchorId, payload.slot_index, payload.shard_id, payload.player_id, payload.event_id);
        }
        if (result.complete) {
          await this.persistence.persistAnchorComplete(anchorId, result.snapshot, result.effects?.trigger_outcome, result.effects?.score_award);
        }
      } catch (auditErr) {
        if (auditErr.code !== 'ER_DUP_ENTRY') {
          console.error('audit persist failed:', auditErr);
        }
      }
      res.json(result);
    } catch (err) {
      res.status(500).json({ ok: false, reason: 'handler_exception', error: err.message });
    }
  }

  async getAnchor(req, res) {
    const anchorId = req.params.id;
    const snapshot = await this.persistence.getAnchorSnapshot(anchorId);
    if (!snapshot) {
      const inMemory = this.anchorManager.getAnchor(anchorId);
      if (!inMemory) return res.status(404).json({ ok: false, reason: 'not_found' });
      return res.json({ ok: true, source: 'memory', anchor: this.anchorManager.engine.serialize(inMemory) });
    }
    res.json({ ok: true, source: 'persisted', ...snapshot });
  }

  async destroy(req, res) {
    const anchorId = req.params.id;
    const ok = this.anchorManager.destroyAnchor(anchorId);
    res.json({ ok });
  }

  async listRoomAnchors(req, res) {
    const roomId = req.params.roomId;
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit) || 50));
    const rows = await this.persistence.listRecentAnchors(roomId, limit);
    res.json({ ok: true, anchors: rows });
  }

  async getPlayerStats(req, res) {
    const stats = await this.persistence.getPlayerStats(req.params.playerId);
    if (!stats) return res.status(404).json({ ok: false, reason: 'no_anchors_yet' });
    res.json({ ok: true, stats });
  }

  async getLeaderboard(req, res) {
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit) || 100));
    const rows = await this.persistence.getLeaderboard(limit);
    res.json({ ok: true, leaderboard: rows });
  }

  _requireSigned(req, res, next) {
    if (!this.auth_secret) return next();
    const signature = req.headers['x-echoline-signature'];
    const timestamp = req.headers['x-echoline-timestamp'];
    if (!signature || !timestamp) return res.status(401).json({ ok: false, reason: 'missing_signature' });
    const ageMs = Date.now() - parseInt(timestamp);
    if (ageMs > 30000 || ageMs < -30000) return res.status(401).json({ ok: false, reason: 'signature_expired' });
    const body = JSON.stringify(req.body || {});
    const expected = crypto.createHmac('sha256', this.auth_secret).update(`${timestamp}.${body}`).digest('hex');
    if (signature.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
      return res.status(401).json({ ok: false, reason: 'invalid_signature' });
    }
    next();
  }

  _rateLimit(req, res, next) {
    const key = `${req.ip}:${req.method}:${req.path}`;
    const now = Date.now();
    const bucket = this._buckets.get(key) || { tokens: this.rate_limit.max, last_refill: now };
    const elapsed = now - bucket.last_refill;
    const refilled = Math.min(this.rate_limit.max, bucket.tokens + (elapsed / this.rate_limit.window_ms) * this.rate_limit.max);
    bucket.tokens = refilled;
    bucket.last_refill = now;
    if (bucket.tokens < 1) {
      this._buckets.set(key, bucket);
      return res.status(429).json({ ok: false, reason: 'rate_limited' });
    }
    bucket.tokens -= 1;
    this._buckets.set(key, bucket);
    if (this._buckets.size > 10000) {
      const cutoff = now - this.rate_limit.window_ms * 10;
      for (const [k, v] of this._buckets.entries()) {
        if (v.last_refill < cutoff) this._buckets.delete(k);
      }
    }
    next();
  }

  static mount(app, anchorManager, persistence, options = {}) {
    const routes = AnchorRoutes.for(anchorManager, persistence, options);
    app.use('/api/v1/anchors', routes.router);
    return routes;
  }
}

module.exports = AnchorRoutes;