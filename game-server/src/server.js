/**
 * ECHO//LINE — Authoritative Game Server
 * --------------------------------------
 * Hosts real-time multiplayer matches across timelines.
 * v2.0 — EchoEngine حتمي، idempotency، snapshots، reconciliation.
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

// ----- HTTP endpoints -----
let roomManager, adminBridge;
const scenarios = new Map();

app.get('/', (req, res) => res.json({
  name: 'ECHO//LINE Game Server',
  version: '2.0.0',
  status: 'ok',
  uptime: Math.floor(process.uptime()),
  rooms: roomManager ? roomManager.roomCount() : 0,
  players: roomManager ? roomManager.playerCount() : 0,
  timestamp: Date.now(),
}));

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.get('/stats', (req, res) => {
  if (!roomManager) return res.json({ status: 'starting' });
  res.json(roomManager.stats());
});

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
      duration_minutes: data.duration_minutes,
      tutorial_required: !!data.tutorial_required,
    });
  }
  res.json({ success: true, data: { scenarios: list } });
});

app.get('/api/rooms', (req, res) => {
  if (!roomManager) return res.json({ success: true, data: { rooms: [] } });
  const language = req.query.lang || 'en';
  const rooms = roomManager.listPublicRooms({ language, includeFull: false, includeStarted: false });
  res.json({ success: true, data: { rooms, count: rooms.length } });
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
function loadScenarios() {
  if (!fs.existsSync(scenariosDir)) {
    logger.warn({ dir: scenariosDir }, 'Scenarios dir missing');
    return;
  }
  for (const file of fs.readdirSync(scenariosDir)) {
    if (!file.endsWith('.json')) continue;
    try {
      const data = JSON.parse(fs.readFileSync(path.join(scenariosDir, file), 'utf-8'));
      // Validate scenario
      if (!data.id || !data.echo_rules || !Array.isArray(data.echo_rules)) {
        logger.warn({ file }, 'Scenario missing required fields');
        continue;
      }
      scenarios.set(data.id, data);
      logger.info({ scenario: data.id, echos: data.echo_rules.length }, 'Loaded scenario');
    } catch (e) {
      logger.error({ file, err: e.message }, 'Failed to load scenario');
    }
  }
}

// ----- Core systems -----
let matchMaker;

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

  // Periodic maintenance (cleanup stale rooms, refresh config, tick scheduled effects)
  setInterval(() => {
    roomManager.tick();
    adminBridge.refreshIfStale();
  }, 5000);

  server.listen(PORT, () => {
    logger.info({ port: PORT, env: NODE_ENV }, 'ECHO//LINE Game Server v2.0 listening');
  });
}

// ----- Socket.io connection handler -----
function handleConnection(socket) {
  const remote = socket.handshake.address;
  logger.debug({ socketId: socket.id, ip: remote }, 'Client connected');

  let session = null; // { playerId, roomId, lastClientSeq }

  // ---- Lobby events ----
  socket.on('lobby:list_rooms', (payload, ack) => {
    try {
      const rooms = roomManager.listPublicRooms({
        language: payload?.language || 'en',
        includeFull: false,
        includeStarted: false
      });
      ack?.({ success: true, rooms, count: rooms.length });
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('lobby:create', (payload, ack) => {
    try {
      const { playerUid, displayName, language, scenarioId, difficulty, seed } = sanitize(payload);
      if (!playerUid || !displayName) return ackError(ack, 'Missing player info', 'BAD_REQUEST');

      const created = roomManager.createRoom({
        hostSocketId: socket.id,
        hostUid: playerUid,
        hostName: displayName,
        hostLanguage: language || 'en',
        scenarioId: scenarioId || 'clocktower_district',
        difficulty: difficulty || 1,
        locale: language || 'en',
        seedOverride: seed || 0,
      });
      const room = created.room;
      session = { playerId: playerUid, roomId: room.id, lastClientSeq: 0 };
      socket.join(room.id);
      ack({ success: true, room: room.publicState(), storyManifest: created.storyManifest });
      broadcastRoom(room.id);
    } catch (e) {
      logger.error({ err: e.message }, 'lobby:create error');
      ackError(ack, e.message);
    }
  });

  // New event: fetch the procedural story manifest for a room (used on
  // reconnect / late-join so the player sees the same story as everyone else).
  socket.on('lobby:get_story', (payload, ack) => {
    try {
      const { roomId } = sanitize(payload);
      const manifest = roomManager.getStoryManifest(roomId);
      if (!manifest) return ackError(ack, 'Story manifest not found', 'NOT_FOUND');
      ack?.({ success: true, manifest });
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('lobby:join', (payload, ack) => {
    try {
      const { playerUid, displayName, language, roomCode } = sanitize(payload);
      if (!roomCode || !playerUid) return ackError(ack, 'Missing room code or player info', 'BAD_REQUEST');

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
      session = { playerId: playerUid, roomId: room.id, lastClientSeq: 0 };
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
      const room = requireSessionRoom();
      const { timeline } = sanitize(payload);
      const result = room.assignTimeline(session.playerId, timeline);
      if (!result.success) return ackError(ack, result.error, result.code);
      ack({ success: true, timeline });
      broadcastRoom(room.id);
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('lobby:set_ready', (payload, ack) => {
    try {
      const room = requireSessionRoom();
      const { ready } = sanitize(payload);
      room.setReady(session.playerId, !!ready);
      ack({ success: true });
      broadcastRoom(room.id);
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('lobby:start', (payload, ack) => {
    try {
      const room = requireSessionRoom();
      if (!room.isHost(session.playerId)) return ackError(ack, 'Only host can start', 'NOT_HOST');
      if (!room.canStart()) return ackError(ack, 'Not all players ready', 'NOT_READY');
      room.startMatch();
      ack({ success: true });
      broadcastRoom(room.id);
      setTimeout(() => {
        for (const p of room.players) {
          const s = io.sockets.sockets.get(p.socketId);
          if (s) {
            s.emit('match:started', room.playerView(p.uid));
            s.emit('match:intro', room.scenario.intro || null);
          }
        }
      }, 600);
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('lobby:fill_with_bots', (payload, ack) => {
    try {
      const room = requireSessionRoom();
      if (!room.isHost(session.playerId)) return ackError(ack, 'Only host can fill bots', 'NOT_HOST');
      room.fillWithBots();
      ack({ success: true });
      broadcastRoom(room.id);
    } catch (e) { ackError(ack, e.message); }
  });

  // ---- Match events ----
  socket.on('match:interact', (payload, ack) => {
    try {
      const room = requireSessionRoom();
      if (!room.hasStarted) return ackError(ack, 'Match not started', 'NOT_STARTED');
      const { entityId, action, idempotencyKey, ruleId, clientSeq } = sanitize(payload);
      const result = room.handleInteraction(session.playerId, { entityId, action, idempotencyKey, ruleId, clientSeq });
      if (!result.success && !result.replayed) {
        return ackError(ack, result.error, result.code, result);
      }
      ack({ success: true, ...result });
      // Send personalized state to each player
      broadcastMatchState(room);
      if (room.outcome) broadcastMatchEnded(room);
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('match:quick_message', (payload, ack) => {
    try {
      const room = requireSessionRoom();
      const { intent, code, data } = sanitize(payload);
      const msg = room.handleQuickMessage(session.playerId, { intent, code, data });
      if (!msg) return ackError(ack, 'Player not in room', 'NO_PLAYER');
      io.to(room.id).emit('match:chat', msg);
      ack?.({ success: true, id: msg.id, seq: msg.seq });
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('match:ping', (payload, ack) => {
    try {
      const room = requireSessionRoom();
      const { type, x, y, targetId } = sanitize(payload);
      const ping = room.handlePing(session.playerId, { type, x, y, targetId });
      if (!ping) return ackError(ack, 'Player not in room', 'NO_PLAYER');
      io.to(room.id).emit('match:ping', ping);
      ack?.({ success: true });
    } catch (e) { ackError(ack, e.message); }
  });

  socket.on('match:state_request', (payload, ack) => {
    try {
      const room = requireSessionRoom();
      ack({ success: true, state: room.playerView(session.playerId) });
    } catch (e) { ackError(ack, e.message); }
  });

  // Reconnection — يحمل نفس الـ uid
  socket.on('match:reconnect', (payload, ack) => {
    try {
      const { playerUid, lastClientSeq = 0 } = sanitize(payload);
      const room = roomManager.findPlayerRoom(playerUid);
      if (!room) return ackError(ack, 'No active match', 'NO_MATCH');
      const result = room.reconnectPlayer({ uid: playerUid, newSocketId: socket.id });
      if (!result.success) return ackError(ack, result.error, result.code);
      session = { playerId: playerUid, roomId: room.id, lastClientSeq };
      socket.join(room.id);
      // ابعث الأحداث المفقودة
      const missed = room.eventLog.filter(e => e.seq > lastClientSeq);
      ack({
        success: true,
        reconnected: true,
        view: result.view,
        missedEvents: missed,
        currentSeq: room.seqCounter,
        snapshot: result.snapshot,
      });
      broadcastRoom(room.id);
    } catch (e) { ackError(ack, e.message); }
  });

  // Hints تدريجية
  socket.on('match:hint', (payload, ack) => {
    try {
      const room = requireSessionRoom();
      const { ruleId } = sanitize(payload);
      const result = room.requestHint(session.playerId, ruleId);
      if (!result.success) return ackError(ack, result.error, 'HINT_FAIL');
      ack({ success: true, level: result.level, hint: result.hint, maxLevel: result.maxLevel });
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

    setTimeout(() => {
      const r = roomManager.getRoom(session.roomId);
      if (!r) return;
      const p = r.getPlayer(session.playerId);
      if (p && p.disconnected && Date.now() - p.disconnectTime > room.disconnectGraceSeconds) {
        r.removePlayer(session.playerId);
        broadcastRoom(r.id);
        if (r.isEmpty()) roomManager.destroyRoom(r.id);
      }
    }, room.disconnectGraceSeconds + 1000);
  });

  // ---- Helpers ----
  function requireSessionRoom() {
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

  function broadcastMatchState(room) {
    for (const p of room.players) {
      const s = io.sockets.sockets.get(p.socketId);
      if (s) s.emit('match:state', room.playerView(p.uid));
    }
  }

  function broadcastMatchEnded(room) {
    if (!room.outcome) return;
    for (const p of room.players) {
      const s = io.sockets.sockets.get(p.socketId);
      if (s) {
        s.emit('match:ended', {
          ...room.outcome,
          causalLog: room.outcome.causalLog,
          yourPlayedEchoes: room.getPlayer(p.uid)?.playedEchoes || [],
        });
      }
    }
  }

  function ackError(ack, message, code, extra) {
    if (typeof ack === 'function') {
      const out = { success: false, error: message, code };
      if (extra) Object.assign(out, extra);
      ack(out);
    }
  }

  function sanitize(payload) {
    if (!payload || typeof payload !== 'object') return {};
    const out = {};
    for (const k of Object.keys(payload)) {
      const v = payload[k];
      if (typeof v === 'string') out[k] = v.substring(0, 256);
      else if (typeof v === 'number' || typeof v === 'boolean') out[k] = v;
      else if (Array.isArray(v)) out[k] = v.slice(0, 50);
      else if (v && typeof v === 'object') out[k] = v;
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
