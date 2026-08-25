/**
 * Protocol Opcodes & Message Builders for ECHO//LINE (أصداء)
 * Guarantees zero translated text strings over the wire.
 */

const MessageTypes = Object.freeze({
  // Lobby & Connection
  JOIN_ROOM_REQUEST: 'JOIN_ROOM_REQUEST',
  JOIN_ROOM_SUCCESS: 'JOIN_ROOM_SUCCESS',
  JOIN_ROOM_FAILED: 'JOIN_ROOM_FAILED',
  PLAYER_READY: 'PLAYER_READY',
  MATCH_START: 'MATCH_START',
  
  // Authoritative State & Gameplay
  PLAYER_INTENT: 'PLAYER_INTENT',
  INTENT_REJECTED: 'INTENT_REJECTED',
  ECHO_PROPAGATED: 'ECHO_PROPAGATED',
  STATE_DELTA: 'STATE_DELTA',
  STATE_SNAPSHOT: 'STATE_SNAPSHOT',
  
  // Communication (Zero L10n on Wire)
  SEMANTIC_PING: 'SEMANTIC_PING',
  SEMANTIC_QUICK_MSG: 'SEMANTIC_QUICK_MSG',
  
  // Catastrophe & Match Conclusion
  CATASTROPHE_UPDATE: 'CATASTROPHE_UPDATE',
  MATCH_CONCLUDED: 'MATCH_CONCLUDED',
  
  // Disconnection & Resilience
  HEARTBEAT: 'HEARTBEAT',
  HEARTBEAT_ACK: 'HEARTBEAT_ACK',
  PLAYER_DISCONNECTED: 'PLAYER_DISCONNECTED',
  PLAYER_RECONNECTED: 'PLAYER_RECONNECTED',
  RECONNECT_REQUEST: 'RECONNECT_REQUEST',
  RECONNECT_SUCCESS: 'RECONNECT_SUCCESS'
});

function createMessage(type, payload = {}, senderId = 'system', timeline = 'system', seq = 0) {
  return {
    type,
    payload,
    sender_id: senderId,
    timeline,
    seq,
    timestamp: Date.now()
  };
}

module.exports = {
  MessageTypes,
  createMessage
};
