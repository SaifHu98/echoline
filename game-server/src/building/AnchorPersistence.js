const crypto = require('node:crypto');

class AnchorPersistence {
  constructor(pool, options = {}) {
    if (!pool) {
      throw new Error('AnchorPersistence: pool required');
    }
    this.pool = pool;
    this.write_buffer = [];
    this.flush_interval_ms = options.flush_interval_ms ?? 2000;
    this.max_buffer_size = options.max_buffer_size ?? 200;
    this.metrics = {
      persisted_anchors: 0,
      persisted_slots: 0,
      persisted_audit: 0,
      buffer_flushes: 0,
      buffer_failures: 0
    };
    this._flush_interval = null;
    if (options.auto_flush !== false) {
      this._flush_interval = setInterval(() => this.flush().catch(() => {}), this.flush_interval_ms);
      this._flush_interval.unref?.();
    }
  }

  static forPool(pool, options = {}) {
    return new AnchorPersistence(pool, options);
  }

  shutdown() {
    if (this._flush_interval) {
      clearInterval(this._flush_interval);
      this._flush_interval = null;
    }
  }

  async persistAnchorCreate(anchor) {
    if (!anchor || !anchor.anchor_id) {
      throw new Error('AnchorPersistence: invalid anchor');
    }
    const sql = `
      INSERT INTO anchors (
        anchor_id, room_id, blueprint_id, state, progress, cooperation_count,
        started_at, deadline_at, place_seq, state_hash, metadata_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        state = VALUES(state),
        progress = VALUES(progress),
        place_seq = VALUES(place_seq),
        state_hash = VALUES(state_hash),
        updated_at = CURRENT_TIMESTAMP
    `;
    const params = [
      anchor.anchor_id,
      anchor.room_id || '',
      anchor.blueprint_id,
      anchor.state || 'in_progress',
      anchor.progress ?? 0,
      anchor.cooperation_count ?? 0,
      anchor.started_at ?? Date.now(),
      anchor.deadline_at ?? Date.now(),
      anchor.place_seq ?? 0,
      anchor.state_hash || this.computeHash(anchor),
      anchor.metadata ? JSON.stringify(anchor.metadata) : null
    ];
    await this.pool.execute(sql, params);
    this.metrics.persisted_anchors++;
    return { ok: true };
  }

  async persistSlotPlacement(anchorId, slotIndex, slot, actorPlayerId, idemKey) {
    if (!anchorId || !slot) {
      throw new Error('AnchorPersistence: anchorId + slot required');
    }
    const sql = `
      INSERT INTO anchor_slots (
        slot_id, anchor_id, slot_index, slot_kind, preferred_timeline,
        state, placed_shard_id, filled_by_player_id, place_seq,
        placed_at, idem_key
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        state = VALUES(state),
        placed_shard_id = VALUES(placed_shard_id),
        filled_by_player_id = VALUES(filled_by_player_id),
        place_seq = VALUES(place_seq),
        placed_at = VALUES(placed_at)
    `;
    const params = [
      `${anchorId}:${slotIndex}`,
      anchorId,
      slotIndex,
      slot.slot_kind || 'core',
      slot.preferred_timeline || 'neutral',
      slot.state || 'filled',
      slot.placed_shard_id || null,
      actorPlayerId || null,
      slot.place_seq ?? 0,
      slot.placed_at ?? Date.now(),
      idemKey || null
    ];
    await this.pool.execute(sql, params);
    this.metrics.persisted_slots++;
    return { ok: true };
  }

  async persistSlotRemoval(anchorId, slotIndex, prevShardId, actorPlayerId, idemKey) {
    const sql = `
      UPDATE anchor_slots
      SET state = 'empty',
          placed_shard_id = NULL,
          filled_by_player_id = NULL,
          place_seq = ?,
          placed_at = NULL,
          removed_at = ?,
          idem_key = ?
      WHERE anchor_id = ? AND slot_index = ?
    `;
    const params = [
      0,
      Date.now(),
      idemKey || null,
      anchorId,
      slotIndex
    ];
    await this.pool.execute(sql, params);
    this.metrics.persisted_slots++;
    return { ok: true };
  }

  async persistAnchorComplete(anchorId, finalState, outcome, scoreAward) {
    const sql = `
      UPDATE anchors
      SET state = 'complete',
          progress = 1.000,
          final_outcome = ?,
          score_award = ?,
          completed_at = ?
      WHERE anchor_id = ?
    `;
    const params = [
      outcome || null,
      scoreAward ?? 0,
      Date.now(),
      anchorId
    ];
    await this.pool.execute(sql, params);
    await this._updatePlayerStats(anchorId);
    return { ok: true };
  }

  async persistAuditEvent(anchorId, eventType, payload) {
    if (!anchorId || !eventType) {
      throw new Error('AnchorPersistence: anchorId + eventType required');
    }
    const sql = `
      INSERT IGNORE INTO anchor_audit (
        anchor_id, event_type, actor_player_id, slot_index, shard_id,
        event_id, place_seq, ok, reason, state_before_json, state_after_json, ts
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    const params = [
      anchorId,
      eventType,
      payload.actor_player_id || null,
      payload.slot_index ?? null,
      payload.shard_id || null,
      payload.event_id || null,
      payload.place_seq ?? 0,
      payload.ok ? 1 : 0,
      payload.reason || null,
      payload.state_before ? JSON.stringify(payload.state_before) : null,
      payload.state_after ? JSON.stringify(payload.state_after) : null,
      payload.ts ?? Date.now()
    ];
    await this.pool.execute(sql, params);
    this.metrics.persisted_audit++;
    return { ok: true };
  }

  async getAnchorSnapshot(anchorId) {
    const sql = `SELECT * FROM anchors WHERE anchor_id = ? LIMIT 1`;
    const [rows] = await this.pool.execute(sql, [anchorId]);
    if (!rows.length) return null;
    const slotsSql = `SELECT * FROM anchor_slots WHERE anchor_id = ? ORDER BY slot_index ASC`;
    const [slots] = await this.pool.execute(slotsSql, [anchorId]);
    return { anchor: rows[0], slots };
  }

  async listRecentAnchors(roomId, limit = 50) {
    const sql = `
      SELECT * FROM anchors
      WHERE room_id = ?
      ORDER BY started_at DESC
      LIMIT ?
    `;
    const [rows] = await this.pool.execute(sql, [roomId, limit]);
    return rows;
  }

  async getPlayerStats(playerId) {
    const sql = `SELECT * FROM player_anchor_stats WHERE player_id = ? LIMIT 1`;
    const [rows] = await this.pool.execute(sql, [playerId]);
    return rows[0] || null;
  }

  async getLeaderboard(limit = 100) {
    const sql = `SELECT * FROM v_player_leaderboard LIMIT ?`;
    const [rows] = await this.pool.execute(sql, [limit]);
    return rows;
  }

  computeHash(anchor) {
    const canonical = JSON.stringify({
      aid: anchor.anchor_id,
      slots: (anchor.slots || []).map(s => ({
        slot_id: s.slot_id,
        placed: s.placed_shard,
        seq: s.place_seq || 0
      })),
      seq: anchor.place_seq || 0
    });
    return crypto.createHash('sha256').update(canonical).digest('hex');
  }

  async _updatePlayerStats(anchorId) {
    const sql = `
      INSERT INTO player_anchor_stats (player_id, total_completed, total_score, last_anchor_at)
      SELECT
        als.filled_by_player_id,
        1,
        a.score_award,
        CURRENT_TIMESTAMP
      FROM anchor_slots als
      JOIN anchors a ON a.anchor_id = als.anchor_id
      WHERE a.anchor_id = ? AND a.state = 'complete' AND als.filled_by_player_id IS NOT NULL
      GROUP BY als.filled_by_player_id, a.score_award
      ON DUPLICATE KEY UPDATE
        total_completed = total_completed + 1,
        total_score = total_score + VALUES(total_score),
        last_anchor_at = VALUES(last_anchor_at)
    `;
    await this.pool.execute(sql, [anchorId]);
  }

  bufferWrite(op) {
    if (this.write_buffer.length >= this.max_buffer_size) {
      this.metrics.buffer_failures++;
      return false;
    }
    this.write_buffer.push(op);
    return true;
  }

  async flush() {
    if (this.write_buffer.length === 0) return { flushed: 0 };
    const ops = this.write_buffer.splice(0);
    try {
      await this.pool.execute('START TRANSACTION');
      for (const op of ops) {
        await op();
      }
      await this.pool.execute('COMMIT');
      this.metrics.buffer_flushes++;
      return { flushed: ops.length };
    } catch (err) {
      await this.pool.execute('ROLLBACK');
      this.metrics.buffer_failures++;
      throw err;
    }
  }

  getMetrics() {
    return {
      ...this.metrics,
      buffer_size: this.write_buffer.length
    };
  }
}

module.exports = AnchorPersistence;