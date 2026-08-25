/**
 * Room & Lobby Manager for ECHO//LINE (أصداء)
 * Supports 4-character room codes, timeline assignment, and 60-second reconnect recovery.
 */

const { MatchScenario } = require('./simulation/scenario');
const { MessageTypes, createMessage } = require('./protocol/messages');

class Room {
  constructor(roomCode, scenarioDef) {
    this.code = roomCode;
    this.scenarioDef = scenarioDef;
    this.players = new Map(); // playerId -> { socket, timeline, ready, connected, disconnectTime }
    this.timelines = ['past', 'present', 'future'];
    this.scenario = null;
    this.state = 'lobby'; // 'lobby', 'in_progress', 'concluded'
    this.reconnectWindowMs = 60000;
  }

  addPlayer(playerId, socket) {
    // If player is reconnecting
    if (this.players.has(playerId)) {
      const p = this.players.get(playerId);
      p.socket = socket;
      p.connected = true;
      p.disconnectTime = null;
      return { success: true, isReconnect: true, timeline: p.timeline };
    }

    // New player join
    if (this.players.size >= 3) {
      return { success: false, reason: 'Room is full (max 3 players)' };
    }

    // Auto-assign first available timeline
    const takenTimelines = new Set(Array.from(this.players.values()).map(p => p.timeline));
    const available = this.timelines.find(t => !takenTimelines.has(t));

    const playerData = {
      id: playerId,
      socket,
      timeline: available,
      ready: false,
      connected: true,
      disconnectTime: null
    };

    this.players.set(playerId, playerData);
    return { success: true, isReconnect: false, timeline: available };
  }

  setPlayerTimeline(playerId, requestedTimeline) {
    if (!this.timelines.includes(requestedTimeline)) return false;
    const player = this.players.get(playerId);
    if (!player) return false;

    // Check if taken
    for (const [id, p] of this.players.entries()) {
      if (id !== playerId && p.timeline === requestedTimeline) {
        return false;
      }
    }

    player.timeline = requestedTimeline;
    return true;
  }

  setPlayerReady(playerId, isReady) {
    const player = this.players.get(playerId);
    if (player) {
      player.ready = Boolean(isReady);
    }
  }

  canStart() {
    if (this.players.size < 3) return false;
    for (const p of this.players.values()) {
      if (!p.ready || !p.connected) return false;
    }
    return true;
  }

  startMatch() {
    this.state = 'in_progress';
    this.scenario = new MatchScenario(this.scenarioDef, this.code);
    this.scenario.start();

    // Hook delta broadcasting
    this.scenario.echoEngine.onStateDelta = (deltas, echoRule, causalEvent) => {
      this.broadcast(createMessage(MessageTypes.ECHO_PROPAGATED, {
        echo_id: echoRule.id,
        loc_key: echoRule.localization_key,
        audio_cue: echoRule.audio_cue,
        visual_ripple: echoRule.visual_ripple,
        deltas,
        causal_event: causalEvent
      }));
    };

    // Hook catastrophe tick
    this.scenario.onTick = (catastropheState) => {
      this.broadcast(createMessage(MessageTypes.CATASTROPHE_UPDATE, catastropheState));
    };

    // Hook conclusion
    this.scenario.onMatchEnded = (recap) => {
      this.state = 'concluded';
      this.broadcast(createMessage(MessageTypes.MATCH_CONCLUDED, recap));
    };

    this.broadcast(createMessage(MessageTypes.MATCH_START, {
      match_id: this.code,
      scenario_id: this.scenarioDef.id,
      timelines: this.getLobbyRoster(),
      initial_state: this.scenario.echoEngine.getState()
    }));
  }

  handleDisconnect(playerId) {
    const player = this.players.get(playerId);
    if (player) {
      player.connected = false;
      player.disconnectTime = Date.now();
      this.broadcast(createMessage(MessageTypes.PLAYER_DISCONNECTED, {
        player_id: playerId,
        timeline: player.timeline,
        reconnect_window_sec: Math.floor(this.reconnectWindowMs / 1000)
      }));
    }
  }

  getLobbyRoster() {
    const roster = [];
    for (const p of this.players.values()) {
      roster.push({
        id: p.id,
        timeline: p.timeline,
        ready: p.ready,
        connected: p.connected
      });
    }
    return roster;
  }

  broadcast(message, excludePlayerId = null) {
    const payload = JSON.stringify(message);
    for (const [id, p] of this.players.entries()) {
      if (id !== excludePlayerId && p.connected && p.socket && p.socket.readyState === 1) {
        try {
          p.socket.send(payload);
        } catch (e) {
          // Socket error
        }
      }
    }
  }
}

class RoomManager {
  constructor(scenarioDef) {
    this.scenarioDef = scenarioDef;
    this.rooms = new Map(); // roomCode -> Room
  }

  generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 4; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return this.rooms.has(code) ? this.generateCode() : code;
  }

  createRoom(customCode = null) {
    const code = customCode ? customCode.toUpperCase() : this.generateCode();
    const room = new Room(code, this.scenarioDef);
    this.rooms.set(code, room);
    return room;
  }

  getRoom(code) {
    if (!code) return null;
    return this.rooms.get(code.toUpperCase());
  }

  cleanupExpiredRooms() {
    const now = Date.now();
    for (const [code, room] of this.rooms.entries()) {
      const allDisconnected = Array.from(room.players.values()).every(
        p => !p.connected && (now - (p.disconnectTime || now)) > room.reconnectWindowMs
      );
      if (room.players.size > 0 && allDisconnected) {
        this.rooms.delete(code);
      }
    }
  }
}

module.exports = {
  Room,
  RoomManager
};
