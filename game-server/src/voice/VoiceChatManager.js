const EventEmitter = require('node:events');
const crypto = require('node:crypto');

const TURN_CONFIG_DEFAULT = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' }
  ]
};

class VoiceChatManager extends EventEmitter {
  constructor(options = {}) {
    super();
    this.rooms = new Map();
    this.max_rooms = options.max_rooms ?? 1000;
    this.max_peers_per_room = options.max_peers_per_room ?? 8;
    this.session_timeout_ms = options.session_timeout_ms ?? 30_000;
    this.turn_config = options.turn_config ?? TURN_CONFIG_DEFAULT;
    this.require_age_verified = options.require_age_verified ?? true;
    this.min_age_for_voice = options.min_age_for_voice ?? 13;
    this.metrics = {
      active_sessions: 0,
      total_sessions_created: 0,
      total_sessions_rejected_age: 0,
      total_sessions_rejected_capacity: 0,
      total_signal_messages: 0,
      total_signal_messages_dropped: 0
    };
    this._gc_interval = null;
    if (options.auto_gc !== false) {
      this._gc_interval = setInterval(() => this._gcSessions(), 5000);
    }
  }

  static forRoom(roomId) {
    if (!roomId || typeof roomId !== 'string') {
      throw new Error('VoiceChatManager.forRoom: roomId required');
    }
    return {
      roomId,
      createPeer: (peerId, ageVerified) => this.createSession.bind(this, roomId, peerId, ageVerified),
      removePeer: (peerId) => this.removeSession.bind(this, roomId, peerId),
      signal: (fromPeerId, toPeerId, payload) => this.relaySignal.bind(this, roomId, fromPeerId, toPeerId, payload)
    };
  }

  shutdown() {
    if (this._gc_interval) {
      clearInterval(this._gc_interval);
      this._gc_interval = null;
    }
    let active = 0;
    for (const room of this.rooms.values()) {
      for (const session of room.sessions.values()) {
        session.cleanup_timer && clearTimeout(session.cleanup_timer);
        active++;
      }
    }
    this.rooms.clear();
    this.metrics.active_sessions = Math.max(0, this.metrics.active_sessions - active);
  }

  _roomOrCreate(roomId) {
    if (this.rooms.has(roomId)) return this.rooms.get(roomId);
    if (this.rooms.size >= this.max_rooms) {
      this.metrics.total_sessions_rejected_capacity++;
      return null;
    }
    const room = {
      room_id: roomId,
      sessions: new Map(),
      created_at: Date.now(),
      total_signals: 0
    };
    this.rooms.set(roomId, room);
    return room;
  }

  createSession(roomId, peerId, ageVerified, options = {}) {
    if (!peerId || typeof peerId !== 'string') {
      return { ok: false, reason: 'invalid_peer_id' };
    }
    if (this.require_age_verified && !ageVerified) {
      this.metrics.total_sessions_rejected_age++;
      return { ok: false, reason: 'age_verification_required', min_age: this.min_age_for_voice };
    }
    const room = this._roomOrCreate(roomId);
    if (!room) return { ok: false, reason: 'room_capacity_exceeded' };
    if (room.sessions.size >= this.max_peers_per_room) {
      this.metrics.total_sessions_rejected_capacity++;
      return { ok: false, reason: 'room_full', max: this.max_peers_per_room };
    }
    if (room.sessions.has(peerId)) {
      return { ok: false, reason: 'peer_already_in_room' };
    }
    const session = {
      session_id: crypto.randomUUID(),
      room_id: roomId,
      peer_id: peerId,
      age_verified: !!ageVerified,
      muted: !!options.muted,
      deafened: !!options.deafened,
      created_at: Date.now(),
      last_seen_at: Date.now(),
      cleanup_timer: null
    };
    room.sessions.set(peerId, session);
    this.metrics.active_sessions++;
    this.metrics.total_sessions_created++;
    const peers = this._listPeers(room, peerId);
    this.emit('peer_joined', { room_id: roomId, peer_id: peerId, peers });
    return {
      ok: true,
      session_id: session.session_id,
      turn_config: this.turn_config,
      peers: peers.map(p => ({ peer_id: p.peer_id, muted: p.muted, deafened: p.deafened }))
    };
  }

  removeSession(roomId, peerId) {
    const room = this.rooms.get(roomId);
    if (!room) return { ok: false, reason: 'room_not_found' };
    const session = room.sessions.get(peerId);
    if (!session) return { ok: false, reason: 'peer_not_in_room' };
    if (session.cleanup_timer) clearTimeout(session.cleanup_timer);
    room.sessions.delete(peerId);
    this.metrics.active_sessions = Math.max(0, this.metrics.active_sessions - 1);
    if (room.sessions.size === 0) {
      this.rooms.delete(roomId);
    }
    this.emit('peer_left', { room_id: roomId, peer_id: peerId });
    return { ok: true };
  }

  relaySignal(roomId, fromPeerId, toPeerId, payload) {
    this.metrics.total_signal_messages++;
    if (!payload || typeof payload !== 'object') {
      this.metrics.total_signal_messages_dropped++;
      return { ok: false, reason: 'invalid_payload' };
    }
    const room = this.rooms.get(roomId);
    if (!room) {
      this.metrics.total_signal_messages_dropped++;
      return { ok: false, reason: 'room_not_found' };
    }
    if (!room.sessions.has(fromPeerId)) {
      this.metrics.total_signal_messages_dropped++;
      return { ok: false, reason: 'sender_not_in_room' };
    }
    const allowedTypes = new Set(['offer', 'answer', 'ice-candidate', 'renegotiate', 'bye']);
    if (!allowedTypes.has(payload.type)) {
      this.metrics.total_signal_messages_dropped++;
      return { ok: false, reason: 'invalid_signal_type', type: payload.type };
    }
    if (toPeerId === '*' || toPeerId === 'broadcast') {
      const delivered = [];
      for (const [pid, s] of room.sessions.entries()) {
        if (pid === fromPeerId) continue;
        delivered.push({ peer_id: pid, delivered_at: Date.now() });
      }
      room.total_signals++;
      this.emit('signal_relayed', { room_id: roomId, from: fromPeerId, to: 'broadcast', payload });
      return { ok: true, broadcast: true, delivered_count: delivered.length };
    }
    const targetSession = room.sessions.get(toPeerId);
    if (!targetSession) {
      this.metrics.total_signal_messages_dropped++;
      return { ok: false, reason: 'target_not_in_room' };
    }
    targetSession.last_seen_at = Date.now();
    room.total_signals++;
    this.emit('signal_relayed', { room_id: roomId, from: fromPeerId, to: toPeerId, payload });
    return { ok: true, broadcast: false, to: toPeerId };
  }

  setPeerState(roomId, peerId, state) {
    const room = this.rooms.get(roomId);
    if (!room) return { ok: false, reason: 'room_not_found' };
    const session = room.sessions.get(peerId);
    if (!session) return { ok: false, reason: 'peer_not_in_room' };
    if (state.muted !== undefined) session.muted = !!state.muted;
    if (state.deafened !== undefined) session.deafened = !!state.deafened;
    session.last_seen_at = Date.now();
    this.emit('peer_state_changed', { room_id: roomId, peer_id: peerId, muted: session.muted, deafened: session.deafened });
    return { ok: true, muted: session.muted, deafened: session.deafened };
  }

  getRoomState(roomId) {
    const room = this.rooms.get(roomId);
    if (!room) return null;
    return {
      room_id: roomId,
      peer_count: room.sessions.size,
      peers: this._listPeers(room, null),
      created_at: room.created_at,
      total_signals: room.total_signals
    };
  }

  getMetrics() {
    return { ...this.metrics, active_rooms: this.rooms.size };
  }

  _listPeers(room, excludePeerId) {
    const list = [];
    for (const [pid, s] of room.sessions.entries()) {
      if (pid === excludePeerId) continue;
      list.push({
        peer_id: pid,
        muted: s.muted,
        deafened: s.deafened,
        joined_at: s.created_at
      });
    }
    return list;
  }

  _gcSessions() {
    const now = Date.now();
    for (const [roomId, room] of this.rooms.entries()) {
      for (const [peerId, session] of room.sessions.entries()) {
        if (now - session.last_seen_at > this.session_timeout_ms) {
          room.sessions.delete(peerId);
          this.metrics.active_sessions = Math.max(0, this.metrics.active_sessions - 1);
          this.emit('peer_timed_out', { room_id: roomId, peer_id: peerId });
        }
      }
      if (room.sessions.size === 0) {
        this.rooms.delete(roomId);
      }
    }
  }
}

module.exports = VoiceChatManager;