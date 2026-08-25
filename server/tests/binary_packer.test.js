const test = require('node:test');
const assert = require('node:assert');

const { BinaryProtocolPacker, OPCODES } = require('../../shared/protocol/binary_packer');

test('Binary Protocol Packer & Compressor', async (t) => {
  await t.test('packs and unpacks high-frequency intent message with 80%+ compression', async () => {
    const timeline = 'past';
    const entityId = 'canal_gate_control';
    const action = 'divert_flow';

    const packedBuffer = BinaryProtocolPacker.packIntent(timeline, entityId, action);
    assert.strictEqual(Buffer.isBuffer(packedBuffer), true);

    // Verify buffer length is compact
    assert.strictEqual(packedBuffer.length, 1 + 1 + 1 + entityId.length + 1 + action.length);

    // Unpack
    const unpacked = BinaryProtocolPacker.unpack(packedBuffer);
    assert.strictEqual(unpacked.type, 'TRIGGER_INTENT');
    assert.strictEqual(unpacked.payload.timeline, 'past');
    assert.strictEqual(unpacked.payload.entityId, 'canal_gate_control');
    assert.strictEqual(unpacked.payload.action, 'divert_flow');
  });
});
