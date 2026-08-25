const fs = require('fs');
const crypto = require('crypto');

class AnchorEngine {
  constructor(blueprints, shardEngine) {
    if (!blueprints || !blueprints.anchors) {
      throw new Error('AnchorEngine: invalid blueprints');
    }
    if (!shardEngine) {
      throw new Error('AnchorEngine: shardEngine required');
    }
    this.blueprints = blueprints;
    this.shardEngine = shardEngine;
    this.anchors = new Map();
    for (const [id, def] of Object.entries(blueprints.anchors)) {
      this.anchors.set(id, { ...def });
    }
  }

  static loadFromFile(blueprintsPath, shardEngine) {
    const raw = fs.readFileSync(blueprintsPath, 'utf8');
    const blueprints = JSON.parse(raw);
    return new AnchorEngine(blueprints, shardEngine);
  }

  getBlueprint(id) {
    return this.anchors.get(id) || null;
  }

  listBlueprints() {
    return Array.from(this.anchors.values());
  }

  createAnchor(blueprintId, players, options = {}) {
    const bp = this.anchors.get(blueprintId);
    if (!bp) {
      return { ok: false, reason: 'unknown_blueprint' };
    }
    if (!Array.isArray(players) || players.length === 0) {
      return { ok: false, reason: 'no_players' };
    }
    if (players.length > bp.max_players) {
      return { ok: false, reason: 'too_many_players', max: bp.max_players };
    }
    if (bp.cooperation_required && players.length < bp.min_players_building) {
      return {
        ok: false,
        reason: 'insufficient_players',
        min: bp.min_players_building,
        got: players.length
      };
    }
    const anchor_id = options.anchor_id || crypto.randomUUID();
    const slots = bp.slots.map(s => ({
      ...s,
      state: 'empty',
      filled_by: null,
      placed_shard: null,
      placed_at: null,
      place_seq: null
    }));
    const owner_index_required = bp.slots
      .map((s, i) => s.owner_index_required !== undefined ? { i, owner: s.owner_index_required } : null)
      .filter(x => x !== null);
    const owner_map = {};
    for (const { i, owner } of owner_index_required) {
      if (owner < players.length) {
        owner_map[i] = owner;
      }
    }
    return {
      ok: true,
      anchor: {
        anchor_id,
        blueprint_id: blueprintId,
        state: 'in_progress',
        progress: 0,
        players: players.map(p => ({ id: p.id, name: p.name || p.id, timeline: p.timeline || null })),
        owner_map,
        slots,
        started_at: options.now || Date.now(),
        deadline_at: (options.now || Date.now()) + (bp.completion_time_seconds * 1000),
        completion_effects: bp.completion_effects,
        cooperation_count: players.length
      }
    };
  }

  placeShard(anchor, slotIndex, playerId, shardId, options = {}) {
    if (!anchor || anchor.state !== 'in_progress') {
      return { ok: false, reason: 'anchor_not_in_progress' };
    }
    if (slotIndex < 0 || slotIndex >= anchor.slots.length) {
      return { ok: false, reason: 'invalid_slot_index' };
    }
    const slot = anchor.slots[slotIndex];
    if (slot.state !== 'empty') {
      return { ok: false, reason: 'slot_already_filled' };
    }
    const bp = this.anchors.get(anchor.blueprint_id);
    if (slot.owner_index_required !== undefined) {
      const requiredOwnerIdx = slot.owner_index_required;
      const ownerPlayerId = anchor.players[requiredOwnerIdx]?.id;
      if (ownerPlayerId && ownerPlayerId !== playerId) {
        return { ok: false, reason: 'wrong_owner', required_owner: ownerPlayerId };
      }
    }
    if (Array.isArray(slot.valid_shards) && !slot.valid_shards.includes(shardId)) {
      return { ok: false, reason: 'invalid_shard_for_slot', required: slot.valid_shards };
    }
    const shard = this.shardEngine.getShard(shardId);
    if (!shard) {
      return { ok: false, reason: 'unknown_shard' };
    }
    const place_seq = (anchor.place_seq || 0) + 1;
    anchor.place_seq = place_seq;
    slot.state = 'filled';
    slot.filled_by = playerId;
    slot.placed_shard = shardId;
    slot.placed_at = options.now || Date.now();
    slot.place_seq = place_seq;
    const filledCount = anchor.slots.filter(s => s.state === 'filled').length;
    anchor.progress = filledCount / anchor.slots.length;
    if (filledCount === anchor.slots.length) {
      anchor.state = 'complete';
      anchor.completed_at = options.now || Date.now();
      anchor.final_progress = 1.0;
    }
    return {
      ok: true,
      slot: slot.slot_id,
      filled_by: playerId,
      shard_id: shardId,
      progress: anchor.progress,
      complete: anchor.state === 'complete',
      place_seq
    };
  }

  removeShard(anchor, slotIndex, playerId, options = {}) {
    if (!anchor || anchor.state !== 'in_progress') {
      return { ok: false, reason: 'anchor_not_in_progress' };
    }
    if (slotIndex < 0 || slotIndex >= anchor.slots.length) {
      return { ok: false, reason: 'invalid_slot_index' };
    }
    const slot = anchor.slots[slotIndex];
    if (slot.state !== 'filled') {
      return { ok: false, reason: 'slot_not_filled' };
    }
    if (slot.owner_index_required !== undefined) {
      const ownerPlayerId = anchor.players[slot.owner_index_required]?.id;
      if (ownerPlayerId && ownerPlayerId !== playerId) {
        return { ok: false, reason: 'wrong_owner' };
      }
    }
    slot.state = 'empty';
    const previousShard = slot.placed_shard;
    slot.filled_by = null;
    slot.placed_shard = null;
    slot.placed_at = null;
    slot.place_seq = null;
    const filledCount = anchor.slots.filter(s => s.state === 'filled').length;
    anchor.progress = filledCount / anchor.slots.length;
    return {
      ok: true,
      slot: slot.slot_id,
      removed_shard: previousShard,
      progress: anchor.progress,
      complete: false
    };
  }

  getCompletionEffects(anchor) {
    if (!anchor || anchor.state !== 'complete') return null;
    return anchor.completion_effects || null;
  }

  serialize(anchor) {
    return {
      anchor_id: anchor.anchor_id,
      blueprint_id: anchor.blueprint_id,
      state: anchor.state,
      progress: anchor.progress,
      players: anchor.players,
      slots: anchor.slots.map(s => ({
        slot_id: s.slot_id,
        state: s.state,
        placed_shard: s.placed_shard,
        filled_by: s.filled_by,
        place_seq: s.place_seq
      })),
      started_at: anchor.started_at,
      completed_at: anchor.completed_at,
      deadline_at: anchor.deadline_at,
      cooperation_count: anchor.cooperation_count,
      final_progress: anchor.final_progress
    };
  }

  hashState(anchor) {
    const canonical = JSON.stringify({
      aid: anchor.anchor_id,
      slots: anchor.slots.map(s => ({
        slot_id: s.slot_id,
        placed: s.placed_shard,
        seq: s.place_seq || 0
      })),
      seq: anchor.place_seq || 0
    });
    return crypto.createHash('sha256').update(canonical).digest('hex');
  }
}

module.exports = AnchorEngine;