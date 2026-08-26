/**
 * RoomManager — orchestrates all active game rooms
 */
'use strict';

const crypto = require('crypto');
const Room = require('./Room');
const { ProceduralStoryService } = require('../scenarios/ProceduralStoryService');

class RoomManager {
  constructor({ logger, scenarios, maxRooms, maxPlayersPerRoom, matchDurationSeconds, disconnectGraceSeconds, adminBridge, io }) {
    this.logger = logger;
    this.scenarios = scenarios;
    this.maxRooms = maxRooms;
    this.maxPlayersPerRoom = maxPlayersPerRoom;
    this.matchDurationSeconds = matchDurationSeconds;
    this.disconnectGraceSeconds = disconnectGraceSeconds;
    this.adminBridge = adminBridge;
    this.io = io;

    this.rooms = new Map(); // id → Room
    this.codeIndex = new Map(); // code → roomId
    // Procedural story generator: gives every room a unique, deterministic
    // narrative + missions + layout. Stored per-room so reconnects can
    // re-fetch the manifest.
    this.storyService = new ProceduralStoryService({ logger });
  }

  generateRoomCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code;
    do {
      code = '';
      for (let i = 0; i < 6; i++) {
        code += alphabet[crypto.randomInt(0, alphabet.length)];
      }
    } while (this.codeIndex.has(code));
    return code;
  }

  createRoom({ hostSocketId, hostUid, hostName, hostLanguage, scenarioId, difficulty = 1, locale = 'en', seedOverride = 0 }) {
    if (this.rooms.size >= this.maxRooms) {
      throw new Error('Server is at capacity');
    }
    const scenario = this.scenarios.get(scenarioId) || this.scenarios.get('clocktower_district');
    if (!scenario) throw new Error('No scenarios available');

    const id = 'r_' + crypto.randomBytes(8).toString('hex');
    const code = this.generateRoomCode();
    // Generate the procedural story manifest BEFORE creating the Room so the
    // Room can stash it for replays.
    const storyManifest = this.storyService.generate({
      timeline: scenario.timeline || 'present',
      difficulty,
      playerCount: this.maxPlayersPerRoom,
      locale,
      seedOverride,
    });
    const room = new Room({
      id, code,
      scenario,
      hostUid,
      maxPlayers: this.maxPlayersPerRoom,
      matchDurationSeconds: this.matchDurationSeconds,
      disconnectGraceSeconds: this.disconnectGraceSeconds,
      logger: this.logger,
    });
    // Stash the procedural story manifest on the room so it can be sent to
    // every connecting player.
    room.storyManifest = storyManifest;
    this.storyService.storeForRoom(id, storyManifest);

    room.addPlayer({
      socketId: hostSocketId,
      uid: hostUid,
      displayName: hostName,
      language: hostLanguage,
      isHost: true,
    });

    this.rooms.set(id, room);
    this.codeIndex.set(code, id);
    this.logger.info({ roomId: id, code, host: hostName, seed: storyManifest.seed, short_id: storyManifest.short_id }, 'Room created');
    return { room, roomId: id, storyManifest };
  }

  /**
   * Retrieve the procedural story manifest for a room (re-fetch on reconnect).
   */
  getStoryManifest(roomId) {
    return this.storyService.loadForRoom(roomId);
  }

  findRoomByCode(code) {
    const id = this.codeIndex.get(code);
    if (!id) return null;
    return this.rooms.get(id);
  }

  /**
   * ابحث عن الغرفة التي يوجد فيها اللاعب (بغض النظر عن الاتصال).
   * مفيد لإعادة الاتصال — لا يحتاج رمز الغرفة.
   */
  findPlayerRoom(uid) {
    for (const [id, room] of this.rooms) {
      if (room.players.find(p => p.uid === uid)) return room;
    }
    return null;
  }

  getRoom(id) {
    return this.rooms.get(id);
  }

  destroyRoom(id) {
    const room = this.rooms.get(id);
    if (!room) return;
    this.rooms.delete(id);
    this.codeIndex.delete(room.code);
    this.logger.info({ roomId: id, code: room.code }, 'Room destroyed');
  }

  tick() {
    const now = Date.now();
    for (const [id, room] of this.rooms) {
      room.tick(now);
      if (room.shouldCleanup()) {
        this.destroyRoom(id);
      }
    }
  }

  roomCount() { return this.rooms.size; }
  playerCount() {
    let total = 0;
    for (const r of this.rooms) total += r[1].players.length;
    return total;
  }

  stats() {
    return {
      rooms: this.rooms.size,
      players: this.playerCount(),
      scenarios: this.scenarios.size,
      uptime: Math.floor(process.uptime()),
      timestamp: Date.now(),
    };
  }

  /**
   * List all open rooms (lobby state, before match starts).
   * Returns minimal public info for the lobby browser UI.
   * Excludes private rooms and rooms that are full or have started.
   */
  listPublicRooms(options = {}) {
    const includeFull = options.includeFull || false;
    const includeStarted = options.includeStarted || false;
    const language = options.language || 'en';
    const out = [];
    for (const room of this.rooms.values()) {
      if (!includeStarted && room.hasStarted) continue;
      if (!includeFull && room.isFull()) continue;
      const playersInfo = (room.players || []).map(p => ({
        uid: p.uid,
        displayName: p.displayName,
        timeline: p.timeline || '',
        isReady: !!p.isReady,
        isBot: !!p.isBot,
        disconnected: !!p.disconnected
      }));
      out.push({
        id: room.id,
        code: room.code,
        scenarioId: room.scenario?.id || 'clocktower_district',
        scenarioName: room.scenario?.name || 'Clocktower District',
        language,
        hostName: room.hostName || 'Host',
        playerCount: playersInfo.length,
        maxPlayers: room.maxPlayers || 4,
        status: this._roomStatus(room),
        isPrivate: !!room.isPrivate,
        createdAt: room.createdAt || Date.now(),
        players: playersInfo,
        age_seconds: Math.floor((Date.now() - (room.createdAt || Date.now())) / 1000)
      });
    }
    return out.sort((a, b) => a.createdAt - b.createdAt);
  }

  _roomStatus(room) {
    if (room.hasStarted) return 'in_progress';
    if (room.isFull()) return 'full';
    const allReady = room.players && room.players.length > 0 && room.players.every(p => p.isReady);
    if (allReady) return 'ready';
    return 'open';
  }
}

module.exports = RoomManager;