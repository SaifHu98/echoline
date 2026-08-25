/**
 * ECHO//LINE — Authoritative Game Server
 * --------------------------------------
 * Hosts real-time multiplayer matches across timelines.
 * Runs the echo engine, validates actions, and broadcasts authoritative state.
 * Designed for deployment on Render.com free tier.
 */

'use strict';

const path = require('path');
const fs = require('fs');
const http = require('http');
const express = require('express');
const { Server } = require('socket.io');
const cors = require('cors');
const compression = require('compression');
const helmet = require('helmet');
const pino = require('pino');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: process.env.NODE_ENV === 'production' ? undefined : {
    target: 'pino-pretty',
    options: { colorize: true, translateTime: 'SYS:HH:MM:ss' },
  },
});

const RoomManager = require('./rooms/RoomManager');
const AdminBridge = require('./admin-bridge/AdminBridge');
const MatchMaker = require('./rooms/MatchMaker');

const PORT = parseInt(process.env.PORT || '3000', 10);
const NODE_ENV = process.env.NODE_ENV || 'development';

// ----- Bootstrap -----
const app = express();
app.disable('x-powered-by');
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
}));
app.use(compression());
app.use(cors({
  origin: (process.env.ALLOWED_ORIGINS || '*').split(','),
  credentials: true,
}));
app.use(express.json({ limit: '64kb' }));

// Health endpoint for Render
app.get('/', (req, res) => res.json({
  name: 'ECHO//LINE Game Server',
  version: '1.0.0',
  status: 'ok',
  uptime: Math.floor(process.uptime()),
  rooms: roomManager ? roomManager.roomCount() : 0,
  players: roomManager ? roomManager.playerCount() : 0,
  timestamp: Date.now(),
}));

app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Stats endpoint (for monitoring)
app.get('/stats', (req, res) => {
  if (!roomManager) return res.json({ status: 'starting' });
  res.json(roomManager.stats());
});

// Public HTTP API used by Godot client (and as fallback to Socket.IO)
// These mirror the Hostinger Admin API endpoints so the game can use either
app.get('/api/config', async (req, res) => {
  await adminBridge.refreshIfStale();
  res.json({ success: true, data: adminBridge.getConfig() });
});

app.get('/api/shop', async (req, res) => {
  await adminBridge.refreshIfStale();
  res.json({ success: true, data: { items: adminBridge.getShopItems() } });
});

app.get('/api/events', async (req, res) => {
  await adminBridge.refreshIfStale();
  res.json({ success: true, data: { events: adminBridge.getActiveEvents() } });
});

app.get('/api/quests', async (req, res) => {
  await adminBridge.refreshIfStale();
  res.json({ success: true, data: { quests: adminBridge.getActiveQuests() } });
});

app.get('/api/announcements', async (req, res) => {
  await adminBridge.refreshIfStale();
  const lang = req.query.lang || '';
  res.json({ success: true, data: { announcements: adminBridge.getAnnouncements(lang) } });
});

app.get('/api/scenarios', (req, res) => {
  const list = [];
  for (const [id, data] of scenarios) {
    list.push({
      id,
      name_key: data.name_key,
      description_key: data.description_key,
      supported_timelines: data.supported_timelines,
      duration_seconds: data.catastrophe?.duration_seconds || 600,
    });
  }
  res.json({ success: true, data: { scenarios: list } });
});

app.get('/api/scenario', (req, res) => {
  const id = req.query.id || '';
  if (!id || !scenarios.has(id)) return res.status(404).json({ success: false, error: 'Not found' });
  res.json({ success: true, data: { scenario: scenarios.get(id) } });
});

app.get('/api/i18n', (req, res) => {
  const lang = req.query.lang || 'en';
  const file = path.join(__dirname, '..', '..', 'shared', 'localization', `${lang}.json`);
  if (!fs.existsSync(file)) return res.json({ success: true, data: { catalog: {}, locale: 'en' } });
  try {
    const catalog = JSON.parse(fs.readFileSync(file, 'utf-8'));
    res.json({ success: true, data: { catalog, locale: lang, count: Object.keys(catalog).length } });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// ----- HTTP + Socket.IO server -----
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: (process.env.ALLOWED_ORIGINS || '*').split(','),
    methods: ['GET', 'POST'],
    credentials: true,
  },
  pingInterval: 25000,
  pingTimeout: 60000,
  maxHttpBufferSize: 64 * 1024,
  perMessageDeflate: true,
});

// ----- Load scenarios from disk -----
const scenariosDir = path.join(__dirname, '..', '..', 'shared', 'scenario_definitions');
const scenarios = new Map();
function loadScenarios() {
  if (!fs.existsSync(scenariosDir)) {
    logger.warn({ dir: scenariosDir }, 'Scenarios dir missing');
    return;
  }
  for (const file of fs.readdirSync(scenariosDir)) {
    if (!file.endsWith('.json')) continue;
    try {
      const data = JSON.parse(fs.readFileSync(path.join(scenariosDir, file), 'utf-8'));
      scenarios.set(data.id, data);
      logger.info({ scenario: data.id, echos: data.echo_rules?.length }, 'Loaded scenario');
    } catch (e) {
      logger.error({ file, err: e.message }, 'Failed to load scenario');
    }
  }
}

// ----- Core systems -----
let roomManager, matchMaker, adminBridge;

function bootstrap() {
  loadScenarios();

  adminBridge = new AdminBridge({
    baseUrl: process.env.ADMIN_API_URL || '',
    apiKey: process.env.ADMIN_API_KEY || '',
    logger,
  });

  roomManager = new RoomManager({
    logger,
    scenarios,
    maxRooms: parseInt(process.env.MAX_ROOMS || '200', 10),
    maxPlayersPerRoom: parseInt(process.env.MAX_PLAYERS_PER_ROOM || '4', 10),
    matchDurationSeconds: parseInt(process.env.MATCH_DURATION_SECONDS || '600', 10),
    disconnectGraceSeconds: parseInt(process.env.DISCONNECT_GRACE_SECONDS || '30', 10),
    adminBridge,
    io,
  });

  matchMaker = new MatchMaker({
    logger,
    roomManager,
    scenarios,
  });

  // Wire socket.io handlers
  io.on('connection', (socket) => handleConnection(socket));

  // Periodic maintenance (cleanup stale rooms, refresh config)
  setInterval(() => {
    roomManager.tick();
    adminBridge.refreshIfStale();
  }, 5000);

  server.listen(PORT, () => {
    logger.info({ port: PORT, env: NODE_ENV }, 'ECHO//LINE Game Server listening');
  });
}

// ----- Socket.io connection handler -----
function handleConnection(socket) {
  const remote = socket.handshake.address;
  logger.debug({ socketId: socket.id, ip: remote }, 'Client connected');

  let session = null; // { playerId, roomId }

  // ---- Lobby events ----
  socket.on('lobby:create', (payload, ack) => {
    try {
      const { playerUid, displayName, language, scenarioId, timeline } = sanitize(payload);
      if (!playerUid || !displayName) return ackError(ack, 'Missing player info');

      const created = roomManager.createRoom({
        hostSocketId: socket.id,
        hostUid: playerUid,
        hostName: displayName,
        hostLanguage: language || 'en',
        scenarioId: scenarioId || 'clocktower_district',
      });
      const room = created.room;
      session = { playerId: playerUid, roomId: room.id };
      socket.join(room.id);
      ack({ success: true, room: room.publicState() });
      broadcastRoom(room.id);
    } catch (e) {
      logger.error({ err: e.message }, 'lobby:create error');
      ackError(ack, e.message);
    }
  });

  socket.on('lobby:join', (payload, ack) => {
    try {
      const { playerUid, displayName, language, roomCode, timeline } = sanitize(payload);
      if (!roomCode || !playerUid) return ackError(ack, 'Missing room code or player info');

      const room = roomManager.findRoomByCode(roomCode);
      if (!room) return ackError(ack, 'Room not found', 'ROOM_NOT_FOUND');
      if (room.isFull()) return ackError(ack, 'Room is full', 'ROOM_FULL');
      if (room.hasStarted) return ackError(ack, 'Match already started', 'MATCH_STARTED');

      const result = room.addPlayer({
        socketId: socket.id,
        uid: playerUid,
        displayName,
        language: language || 'en',
      });
      session = { playerId: playerUid, roomId: room.id };
      socket.join(room.id);
      ack({ success: true, room: room.publicState(), assignedTimeline: result.timeline });
      broadcastRoom(room.id);
    } catch (e) {
      ackError(ack, e.message);
    }
  });

  socket.on('lobby:leave', (payload, ack) => {
    try {
      if (!session) return ack?.({ success: true });
      const room = roomManager.getRoom(session.roomId);
      if (room) {
        room.removePlayer(session.playerId);
        broadcastRoom(room.id);
        if (room.isEmpty()) roomManager.destroyRoom(room.id);
      }
      socket.leave(session.roomId);
      session = null;
      ack?.({ success: true });
    } catch (e) {
      ackError(ack, e.message);
    }
  });

  socket.on('lobby:select_timeline', (payload, ack) => {
    try {
      const room = requireSessionRoom(socket, session);
      const { timeline } = sanitize(payload);
      const result = room.assignTimeline(session.playerId, timeline);
      if (!result.success) return ackError(ack, result.error);
      ack({ success: true, timeline });
      broadcastRoom(room.id);
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('lobby:set_ready', (payload, ack) => {
    try {
      const room = requireSessionRoom(socket, session);
      const { ready } = sanitize(payload);
      room.setReady(session.playerId, !!ready);
      ack({ success: true });
      broadcastRoom(room.id);
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('lobby:start', (payload, ack) => {
    try {
      const room = requireSessionRoom(socket, session);
      if (!room.isHost(session.playerId)) return ackError(ack, 'Only host can start');
      if (!room.canStart()) return ackError(ack, 'Not all players ready');
      room.startMatch();
      ack({ success: true });
      broadcastRoom(room.id);
      // After brief delay, push initial scenario state to each player
      setTimeout(() => {
        for (const p of room.players) {
          const s = io.sockets.sockets.get(p.socketId);
          if (s) s.emit('match:started', room.playerView(p.uid));
        }
      }, 600);
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('lobby:fill_with_bots', (payload, ack) => {
    try {
      const room = requireSessionRoom(socket, session);
      if (!room.isHost(session.playerId)) return ackError(ack, 'Only host can fill bots');
      room.fillWithBots();
      ack({ success: true });
      broadcastRoom(room.id);
    } catch (e) { ackError(ack, e.message); }
  });

  // ---- Match events ----
  socket.on('match:interact', (payload, ack) => {
    try {
      const room = requireSessionRoom(socket, session);
      if (!room.hasStarted) return ackError(ack, 'Match not started');
      const { entityId, action } = sanitize(payload);
      const result = room.handleInteraction(session.playerId, entityId, action);
      if (!result.success) return ackError(ack, result.error);
      ack({ success: true });
      // Broadcast updated state to all players in room
      for (const p of room.players) {
        const s = io.sockets.sockets.get(p.socketId);
        if (s) s.emit('match:state', room.playerView(p.uid));
      }
      // If match ended, send conclusion
      if (room.outcome) {
        for (const p of room.players) {
          const s = io.sockets.sockets.get(p.socketId);
          if (s) s.emit('match:ended', room.outcome);
        }
      }
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('match:quick_message', (payload, ack) => {
    try {
      const room = requireSessionRoom(socket, session);
      const { intent, code, data } = sanitize(payload);
      const player = room.getPlayer(session.playerId);
      if (!player) return ackError(ack, 'Player not in room');
      const msg = {
        from: { uid: player.uid, name: player.displayName, timeline: player.timeline, language: player.language },
        intent, code, data,
        ts: Date.now(),
        seq: room.nextSeq(),
      };
      room.recordEvent('quick_message', msg);
      // Translate per recipient language on client side; just send intent + sender lang
      io.to(room.id).emit('match:chat', msg);
      ack?.({ success: true, seq: msg.seq });
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('match:ping', (payload, ack) => {
    try {
      const room = requireSessionRoom(socket, session);
      const { type, x, y, targetId } = sanitize(payload);
      const player = room.getPlayer(session.playerId);
      if (!player) return ackError(ack, 'Player not in room');
      const ping = {
        from: player.uid,
        fromName: player.displayName,
        fromTimeline: player.timeline,
        type: type || 'location',
        x, y, targetId,
        seq: room.nextSeq(),
        ts: Date.now(),
      };
      io.to(room.id).emit('match:ping', ping);
      ack?.({ success: true });
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('match:move', (payload, ack) => {
    try {
      const room = requireSessionRoom(socket, session);
      const { x, y, dir } = sanitize(payload);
      if (typeof x !== 'number' || typeof y !== 'number') return ackError(ack, 'Invalid position');
      room.updatePlayerPosition(session.playerId, x, y, dir);
      // Position broadcast is frequent — throttle
      ack?.({ success: true });
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('match:state_request', (payload, ack) => {
    try {
      const room = requireSessionRoom(socket, session);
      ack({ success: true, state: room.playerView(session.playerId) });
    } catch (e) { ackError(ack, e.message); }
  });

  // ---- Disconnect ----
  socket.on('disconnect', (reason) => {
    logger.debug({ socketId: socket.id, reason }, 'Disconnected');
    if (!session) return;
    const room = roomManager.getRoom(session.roomId);
    if (!room) return;
    room.markDisconnected(session.playerId, reason);
    broadcastRoom(room.id);

    // After grace period, remove player
    setTimeout(() => {
      const r = roomManager.getRoom(session.roomId);
      if (!r) return;
      const p = r.getPlayer(session.playerId);
      if (p && p.disconnected && Date.now() - p.disconnectTime > parseInt(process.env.DISCONNECT_GRACE_SECONDS || '30', 10) * 1000) {
        r.removePlayer(session.playerId);
        broadcastRoom(r.id);
        if (r.isEmpty()) roomManager.destroyRoom(r.id);
      }
    }, (parseInt(process.env.DISCONNECT_GRACE_SECONDS || '30', 10) + 1) * 1000);
  });

  // ---- Helpers ----
  function requireSessionRoom(socket, session) {
    if (!session) throw new Error('No active session');
    const room = roomManager.getRoom(session.roomId);
    if (!room) throw new Error('Room not found');
    return room;
  }

  function broadcastRoom(roomId) {
    const room = roomManager.getRoom(roomId);
    if (!room) return;
    io.to(roomId).emit('lobby:update', room.publicState());
  }

  function ackError(ack, message, code) {
    if (typeof ack === 'function') ack({ success: false, error: message, code });
  }

  function sanitize(payload) {
    if (!payload || typeof payload !== 'object') return {};
    const out = {};
    for (const k of Object.keys(payload)) {
      const v = payload[k];
      if (typeof v === 'string') out[k] = v.substring(0, 200);
      else if (typeof v === 'number' || typeof v === 'boolean') out[k] = v;
      else if (Array.isArray(v)) out[k] = v.slice(0, 50);
    }
    return out;
  }
}

// ----- Start -----
try {
  bootstrap();
} catch (err) {
  logger.fatal({ err: err.message, stack: err.stack }, 'Bootstrap failed');
  process.exit(1);
}

// ----- Graceful shutdown -----
process.on('SIGTERM', () => {
  logger.info('SIGTERM — shutting down');
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10000);
});

process.on('unhandledRejection', (reason) => {
  logger.error({ reason: reason?.message || reason }, 'Unhandled rejection');
});

module.exports = { io, app, server };