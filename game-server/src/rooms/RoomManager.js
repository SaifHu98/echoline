/**
 * RoomManager — orchestrates all active game rooms
 */
'use strict';

const crypto = require('crypto');
const Room = require('./Room');

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

  createRoom({ hostSocketId, hostUid, hostName, hostLanguage, scenarioId }) {
    if (this.rooms.size >= this.maxRooms) {
      throw new Error('Server is at capacity');
    }
    const scenario = this.scenarios.get(scenarioId) || this.scenarios.get('clocktower_district');
    if (!scenario) throw new Error('No scenarios available');

    const id = 'r_' + crypto.randomBytes(8).toString('hex');
    const code = this.generateRoomCode();
    const room = new Room({
      id, code,
      scenario,
      hostUid,
      maxPlayers: this.maxPlayersPerRoom,
      matchDurationSeconds: this.matchDurationSeconds,
      disconnectGraceSeconds: this.disconnectGraceSeconds,
      logger: this.logger,
    });

    room.addPlayer({
      socketId: hostSocketId,
      uid: hostUid,
      displayName: hostName,
      language: hostLanguage,
      isHost: true,
    });

    this.rooms.set(id, room);
    this.codeIndex.set(code, id);
    this.logger.info({ roomId: id, code, host: hostName }, 'Room created');
    return { room, roomId: id };
  }

  findRoomByCode(code) {
    const id = this.codeIndex.get(code);
    if (!id) return null;
    return this.rooms.get(id);
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
}

module.exports = RoomManager;