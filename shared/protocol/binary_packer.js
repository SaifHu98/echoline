/**
 * High-Efficiency Binary Protocol Encoder for ECHO//LINE (أصداء)
 * Compresses WebSocket JSON messages into compact byte arrays for low-latency mobile connections.
 */

const OPCODES = {
  CONNECT: 0x01,
  JOIN_ROOM: 0x02,
  READY_TOGGLE: 0x03,
  SEND_PING: 0x04,
  SEND_MESSAGE: 0x05,
  TRIGGER_INTENT: 0x06,
  STATE_SYNC: 0x07,
  HEARTBEAT: 0x08
};

class BinaryProtocolPacker {
  /**
   * Pack a high-frequency intent message into a compact buffer
   * Format: [Opcode (1B), Timeline (1B), EntityIdLen (1B), EntityIdStr (NB), ActionLen (1B), ActionStr (NB)]
   */
  static packIntent(timeline, entityId, action) {
    const timelineCode = timeline === 'past' ? 1 : (timeline === 'present' ? 2 : 3);
    const entityBuf = Buffer.from(entityId, 'utf-8');
    const actionBuf = Buffer.from(action, 'utf-8');

    const totalLen = 1 + 1 + 1 + entityBuf.length + 1 + actionBuf.length;
    const buf = Buffer.alloc(totalLen);

    let offset = 0;
    buf.writeUInt8(OPCODES.TRIGGER_INTENT, offset++);
    buf.writeUInt8(timelineCode, offset++);
    buf.writeUInt8(entityBuf.length, offset++);
    entityBuf.copy(buf, offset);
    offset += entityBuf.length;
    buf.writeUInt8(actionBuf.length, offset++);
    actionBuf.copy(buf, offset);

    return buf;
  }

  /**
   * Unpack a binary buffer into a structured message
   */
  static unpack(buffer) {
    if (!Buffer.isBuffer(buffer) || buffer.length < 1) {
      return null;
    }

    const opcode = buffer.readUInt8(0);
    if (opcode === OPCODES.TRIGGER_INTENT) {
      let offset = 1;
      const timelineCode = buffer.readUInt8(offset++);
      const timeline = timelineCode === 1 ? 'past' : (timelineCode === 2 ? 'present' : 'future');

      const entityLen = buffer.readUInt8(offset++);
      const entityId = buffer.toString('utf-8', offset, offset + entityLen);
      offset += entityLen;

      const actionLen = buffer.readUInt8(offset++);
      const action = buffer.toString('utf-8', offset, offset + actionLen);

      return {
        type: 'TRIGGER_INTENT',
        payload: {
          timeline,
          entityId,
          action
        }
      };
    }

    return null;
  }
}

module.exports = {
  BinaryProtocolPacker,
  OPCODES
};
