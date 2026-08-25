const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

class ShardEngine {
  constructor(catalog, options = {}) {
    if (!catalog || !catalog.shards) {
      throw new Error('ShardEngine: invalid catalog');
    }
    this.catalog = catalog;
    this.rules = catalog.rules || {};
    this.shards = new Map();
    for (const [id, def] of Object.entries(catalog.shards)) {
      this.shards.set(id, { ...def });
    }
    this.drop_rate_base = options.drop_rate_base ?? this.rules.drop_rate_base ?? 0.35;
    this.cooperation_bonus = options.cooperation_bonus ?? this.rules.cooperation_bonus ?? 0.15;
    this.drop_rate_cap = options.drop_rate_cap ?? this.rules.drop_rate_cap ?? 1.0;
    this.duplicate_conversion = options.duplicate_conversion ?? this.rules.duplicate_conversion ?? 3;
  }

  static loadFromFile(filePath) {
    const raw = fs.readFileSync(filePath, 'utf8');
    const catalog = JSON.parse(raw);
    return new ShardEngine(catalog);
  }

  getShard(id) {
    return this.shards.get(id) || null;
  }

  listShards() {
    return Array.from(this.shards.values());
  }

  listShardsForSlot(slot) {
    if (!slot.valid_shards) return [];
    return slot.valid_shards
      .map(id => this.shards.get(id))
      .filter(s => s !== undefined);
  }

  computeDropRate(shardId, options = {}) {
    const shard = this.shards.get(shardId);
    if (!shard) return 0;
    let rate = shard.drop_rate ?? this.drop_rate_base;
    if (options.cooperation_count && options.cooperation_count >= 2) {
      rate += this.cooperation_bonus * (options.cooperation_count - 1);
    }
    if (options.rare_unlock && shard.tier === 'rare') {
      rate = Math.min(rate + 0.25, this.drop_rate_cap);
    }
    if (options.legendary_match && shard.tier === 'legendary') {
      rate = Math.min(rate + 0.1, this.drop_rate_cap);
    }
    return Math.min(Math.max(rate, 0), this.drop_rate_cap);
  }

  rollDrop(trigger, context = {}, rng = Math.random) {
    if (!Array.isArray(context.players) || context.players.length === 0) {
      throw new Error('ShardEngine.rollDrop: players required');
    }
    const candidates = this.listShards().filter(s =>
      Array.isArray(s.drop_sources) && s.drop_sources.includes(trigger)
    );
    if (candidates.length === 0) return [];

    const cooperation_count = context.players.filter(p => p.online !== false).length;
    const drops = [];
    for (const shard of candidates) {
      const rate = this.computeDropRate(shard.id, {
        cooperation_count,
        rare_unlock: context.rare_unlock,
        legendary_match: context.legendary_match
      });
      if (rng() <= rate) {
        drops.push({
          shard_id: shard.id,
          timeline: shard.timeline,
          tier: shard.tier,
          weight: shard.weight,
          drop_id: crypto.randomUUID(),
          drop_ts: context.now || Date.now(),
          source: trigger
        });
      }
    }
    return drops;
  }

  convertDuplicates(inventory) {
    if (!inventory || typeof inventory !== 'object') {
      throw new Error('ShardEngine.convertDuplicates: invalid inventory');
    }
    const events = [];
    for (const [shardId, count] of Object.entries(inventory)) {
      const owned = Math.floor(count);
      const conversions = Math.floor(owned / this.duplicate_conversion);
      if (conversions > 0) {
        const remaining = owned - (conversions * this.duplicate_conversion);
        inventory[shardId] = remaining;
        events.push({
          shard_id: shardId,
          converted_count: conversions,
          new_count: remaining,
          conversion_id: crypto.randomUUID(),
          ts: Date.now()
        });
      }
    }
    return events;
  }

  assignToInventory(inventory, drops) {
    if (!inventory || typeof inventory !== 'object') {
      throw new Error('ShardEngine.assignToInventory: invalid inventory');
    }
    const added = [];
    for (const drop of drops) {
      if (!this.shards.has(drop.shard_id)) continue;
      inventory[drop.shard_id] = (inventory[drop.shard_id] || 0) + 1;
      added.push({
        shard_id: drop.shard_id,
        drop_id: drop.drop_id,
        new_count: inventory[drop.shard_id]
      });
    }
    return added;
  }

  validateForSlot(inventory, slot) {
    if (!slot || !Array.isArray(slot.valid_shards)) {
      return { ok: false, reason: 'invalid_slot' };
    }
    const candidates = slot.valid_shards
      .filter(id => (inventory[id] || 0) >= 1)
      .map(id => this.shards.get(id))
      .filter(s => s !== undefined);
    if (candidates.length === 0) {
      return { ok: false, reason: 'no_shards_available', required: slot.valid_shards };
    }
    return {
      ok: true,
      candidates: candidates.map(s => ({
        id: s.id,
        tier: s.tier,
        timeline: s.timeline,
        weight: s.weight,
        preferred_match: s.timeline === slot.preferred_timeline
      }))
    };
  }
}

module.exports = ShardEngine;