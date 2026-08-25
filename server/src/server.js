/**
 * Authoritative Multiplayer WebSocket Game Server for ECHO//LINE (أصداء)
 */

const { WebSocketServer } = require('ws');
const path = require('path');
const fs = require('fs');
const { RoomManager } = require('./room_manager');
const { MessageTypes, createMessage } = require('./protocol/messages');
const { RateLimiter, validateIncomingMessage, sanitizeString } = require('./protocol/validator');

// Load scenario definition
const scenarioPath = path.join(__dirname, '../../shared/scenario_definitions/clocktower_district.json');
const scenarioDef = JSON.parse(fs.readFileSync(scenarioPath, 'utf-8'));

class EchoLineServer {
  constructor(port = 7777) {
    this.port = port;
    this.roomManager = new RoomManager(scenarioDef);
    this.rateLimiter = new RateLimiter(30, 10);
    this.wss = null;
    this.tickInterval = null;
  }

  start() {
    return new Promise((resolve) => {
      this.wss = new WebSocketServer({ port: this.port }, () => {
        console.log(`[ECHO//LINE Server] Authoritative simulation running on ws://localhost:${this.port}`);
        
        // Start simulation loop (every 500ms)
        this.tickInterval = setInterval(() => {
          for (const room of this.roomManager.rooms.values()) {
            if (room.state === 'in_progress' && room.scenario) {
              room.scenario.tick(500);
            }
          }
          this.roomManager.cleanupExpiredRooms();
        }, 500);

        resolve(this);
      });

      this.wss.on('connection', (socket) => {
        let currentRoom = null;
        let currentUserId = null;

        socket.on('message', (data) => {
          const { valid, message, error } = validateIncomingMessage(data);
          if (!valid) {
            socket.send(JSON.stringify(createMessage('ERROR', { error })));
            return;
          }

          const senderId = sanitizeString(message.sender_id || 'anon');
          if (!this.rateLimiter.check(senderId)) {
            socket.send(JSON.stringify(createMessage('RATE_LIMITED', { reason: 'Too many requests' })));
            return;
          }

          this.handleClientMessage(socket, message, senderId, (room, uid) => {
            currentRoom = room;
            currentUserId = uid;
          });
        });

        socket.on('close', () => {
          if (currentRoom && currentUserId) {
            currentRoom.handleDisconnect(currentUserId);
          }
          if (currentUserId) {
            this.rateLimiter.cleanup(currentUserId);
          }
        });
      });
    });
  }

  handleClientMessage(socket, msg, senderId, setContext) {
    const { type, payload } = msg;

    switch (type) {
      case MessageTypes.JOIN_ROOM_REQUEST: {
        const roomCode = sanitizeString(payload.room_code || '').toUpperCase();
        let room = this.roomManager.getRoom(roomCode);
        if (!room) {
          if (payload.create_if_missing) {
            room = this.roomManager.createRoom(roomCode.length === 4 ? roomCode : null);
          } else {
            socket.send(JSON.stringify(createMessage(MessageTypes.JOIN_ROOM_FAILED, {
              reason: 'Room not found'
            })));
            return;
          }
        }

        const joinRes = room.addPlayer(senderId, socket);
        if (!joinRes.success) {
          socket.send(JSON.stringify(createMessage(MessageTypes.JOIN_ROOM_FAILED, {
            reason: joinRes.reason
          })));
          return;
        }

        setContext(room, senderId);

        socket.send(JSON.stringify(createMessage(MessageTypes.JOIN_ROOM_SUCCESS, {
          room_code: room.code,
          assigned_timeline: joinRes.timeline,
          is_reconnect: joinRes.isReconnect,
          roster: room.getLobbyRoster(),
          scenario_id: room.scenarioDef.id
        })));

        room.broadcast(createMessage('LOBBY_UPDATE', {
          roster: room.getLobbyRoster()
        }), senderId);

        // If match in progress and reconnecting, send current state snapshot
        if (room.state === 'in_progress' && joinRes.isReconnect) {
          socket.send(JSON.stringify(createMessage(MessageTypes.STATE_SNAPSHOT, {
            state: room.scenario.echoEngine.getState(),
            catastrophe: {
              remaining_ms: room.scenario.remainingMs,
              stage: room.scenario.currentStage
            },
            causal_history: room.scenario.echoEngine.getCausalHistory()
          })));
        }
        break;
      }

      case MessageTypes.PLAYER_READY: {
        const roomCode = sanitizeString(payload.room_code || '');
        const room = this.roomManager.getRoom(roomCode);
        if (!room) return;

        if (payload.timeline) {
          room.setPlayerTimeline(senderId, payload.timeline);
        }
        room.setPlayerReady(senderId, payload.ready);

        room.broadcast(createMessage('LOBBY_UPDATE', {
          roster: room.getLobbyRoster()
        }));

        if (room.canStart()) {
          room.startMatch();
        }
        break;
      }

      case MessageTypes.PLAYER_INTENT: {
        const roomCode = sanitizeString(payload.room_code || '');
        const room = this.roomManager.getRoom(roomCode);
        if (!room || room.state !== 'in_progress') return;

        const player = room.players.get(senderId);
        if (!player) return;

        const result = room.scenario.handlePlayerIntent(
          payload.echo_id,
          player.timeline,
          senderId
        );

        if (!result.success) {
          socket.send(JSON.stringify(createMessage(MessageTypes.INTENT_REJECTED, {
            echo_id: payload.echo_id,
            reason: result.reason
          })));
        }
        break;
      }

      case MessageTypes.SEMANTIC_PING: {
        const roomCode = sanitizeString(payload.room_code || '');
        const room = this.roomManager.getRoom(roomCode);
        if (!room) return;

        const player = room.players.get(senderId);
        room.broadcast(createMessage(MessageTypes.SEMANTIC_PING, {
          ping_id: sanitizeString(payload.ping_id),
          timeline: player ? player.timeline : 'past',
          world_pos: payload.world_pos || { x: 0, y: 0, z: 0 },
          entity_id: sanitizeString(payload.entity_id || '')
        }));
        break;
      }

      case MessageTypes.SEMANTIC_QUICK_MSG: {
        const roomCode = sanitizeString(payload.room_code || '');
        const room = this.roomManager.getRoom(roomCode);
        if (!room) return;

        const player = room.players.get(senderId);
        room.broadcast(createMessage(MessageTypes.SEMANTIC_QUICK_MSG, {
          intent_id: sanitizeString(payload.intent_id),
          timeline: player ? player.timeline : 'past',
          args: payload.args || {}
        }));
        break;
      }

      case MessageTypes.HEARTBEAT: {
        socket.send(JSON.stringify(createMessage(MessageTypes.HEARTBEAT_ACK, { client_time: payload.client_time })));
        break;
      }
    }
  }

  stop() {
    if (this.tickInterval) clearInterval(this.tickInterval);
    if (this.wss) this.wss.close();
  }
}

// Direct execution entrypoint
if (require.main === module) {
  const port = process.env.PORT || 7777;
  const server = new EchoLineServer(port);
  server.start();
}

module.exports = {
  EchoLineServer
};
