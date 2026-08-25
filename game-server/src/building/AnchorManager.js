const crypto = require('crypto');

class AnchorManager {
  constructor(anchorEngine, roomId, logger = null) {
    if (!anchorEngine) {
      throw new Error('AnchorManager: anchorEngine required');
    }
    if (!roomId) {
      throw new Error('AnchorManager: roomId required');
    }
    this.engine = anchorEngine;
    this.roomId = roomId;
    this.anchors = new Map();
    this.event_log = [];
    this.logger = logger;
    this.handlers = new Map();
    this._registerDefaultHandlers();
  }

  _registerDefaultHandlers() {
    this.handlers.set('place_shard', (anchor, payload) => this._handlePlaceShard(anchor, payload));
    this.handlers.set('remove_shard', (anchor, payload) => this._handleRemoveShard(anchor, payload));
  }

  registerHandler(eventType, handler) {
    this.handlers.set(eventType, handler);
  }

  createAnchor(blueprintId, players, options = {}) {
    const result = this.engine.createAnchor(blueprintId, players, options);
    if (!result.ok) {
      this._log('warn', 'createAnchor_rejected', { blueprint: blueprintId, reason: result.reason });
      return result;
    }
    const anchor = result.anchor;
    this.anchors.set(anchor.anchor_id, anchor);
    this.event_log.push({
      event_id: crypto.randomUUID(),
      ts: Date.now(),
      type: 'create',
      anchor_id: anchor.anchor_id,
      blueprint_id: anchor.blueprint_id,
      players: anchor.players.length
    });
    this._log('info', 'anchor_created', { anchor_id: anchor.anchor_id, blueprint: blueprintId });
    return { ok: true, anchor: this.engine.serialize(anchor) };
  }

  getAnchor(anchorId) {
    return this.anchors.get(anchorId) || null;
  }

  listAnchors() {
    return Array.from(this.anchors.keys());
  }

  processEvent(anchorId, payload) {
    if (!payload || typeof payload !== 'object') {
      return { ok: false, reason: 'invalid_payload' };
    }
    const anchor = this.anchors.get(anchorId);
    if (!anchor) {
      return { ok: false, reason: 'anchor_not_found' };
    }
    const eventType = payload.type;
    if (!eventType) {
      return { ok: false, reason: 'missing_event_type' };
    }
    const handler = this.handlers.get(eventType);
    if (!handler) {
      return { ok: false, reason: 'unknown_event_type', event_type: eventType };
    }
    const isIdempotent = payload.event_id != null;
    if (isIdempotent) {
      const existing = this.event_log.find(e => e.event_id === payload.event_id);
      if (existing && existing.result) {
        return {
          ok: true,
          idempotent: true,
          result: existing.result,
          snapshot: existing.snapshot,
          place_seq: existing.result.place_seq
        };
      }
    }
    let result;
    try {
      result = handler(anchor, payload);
    } catch (err) {
      this._log('error', 'handler_exception', { err: err.message });
      return { ok: false, reason: 'handler_exception' };
    }
    const snapshot = this.engine.serialize(anchor);
    const entry = {
      event_id: payload.event_id || crypto.randomUUID(),
      ts: Date.now(),
      type: eventType,
      anchor_id: anchorId,
      seq: anchor.place_seq,
      result: { ok: result.ok, reason: result.reason, place_seq: result.place_seq },
      snapshot
    };
    this.event_log.push(entry);
    if (this.event_log.length > 500) {
      this.event_log.splice(0, this.event_log.length - 500);
    }
    if (anchor.state === 'complete') {
      const effects = this.engine.getCompletionEffects(anchor);
      return { ok: true, complete: true, effects, snapshot, place_seq: anchor.place_seq };
    }
    return { ok: result.ok, reason: result.reason, snapshot, place_seq: anchor.place_seq };
  }

  _handlePlaceShard(anchor, payload) {
    const slotIndex = payload.slot_index;
    const shardId = payload.shard_id;
    const playerId = payload.player_id || payload.player;
    if (typeof slotIndex !== 'number' || slotIndex < 0) {
      return { ok: false, reason: 'invalid_slot_index' };
    }
    if (!shardId || typeof shardId !== 'string') {
      return { ok: false, reason: 'missing_shard_id' };
    }
    if (!playerId) {
      return { ok: false, reason: 'missing_player_id' };
    }
    return this.engine.placeShard(anchor, slotIndex, playerId, shardId, payload);
  }

  _handleRemoveShard(anchor, payload) {
    const slotIndex = payload.slot_index;
    const playerId = payload.player_id || payload.player;
    if (typeof slotIndex !== 'number' || slotIndex < 0) {
      return { ok: false, reason: 'invalid_slot_index' };
    }
    if (!playerId) {
      return { ok: false, reason: 'missing_player_id' };
    }
    return this.engine.removeShard(anchor, slotIndex, playerId, payload);
  }

  syncStateTo(anchorId) {
    const anchor = this.anchors.get(anchorId);
    if (!anchor) return null;
    return {
      anchor_id: anchorId,
      place_seq: anchor.place_seq,
      slots: anchor.slots.map(s => ({
        slot_id: s.slot_id,
        state: s.state,
        placed_shard: s.placed_shard,
        filled_by: s.filled_by,
        place_seq: s.place_seq
      })),
      progress: anchor.state === 'complete' ? 1.0 : (anchor.progress || 0),
      state: anchor.state
    };
  }

  hashState(anchorId) {
    const anchor = this.anchors.get(anchorId);
    if (!anchor) return null;
    return this.engine.hashState(anchor);
  }

  destroyAnchor(anchorId) {
    const anchor = this.anchors.get(anchorId);
    if (!anchor) return false;
    this.anchors.delete(anchorId);
    this.event_log.push({
      event_id: crypto.randomUUID(),
      ts: Date.now(),
      type: 'destroy',
      anchor_id: anchorId
    });
    return true;
  }

  _log(level, msg, meta) {
    if (this.logger && typeof this.logger[level] === 'function') {
      this.logger[level](msg, { room: this.roomId, ...meta });
    }
  }
}

module.exports = AnchorManager;