const test = require('node:test');
const assert = require('node:assert');
const { EchoLineServer } = require('../src/server');
const { MessageTypes, createMessage } = require('../src/protocol/messages');
const { TestClient } = require('./test_helper');

const TEST_PORT = 7891;

test('Disconnection and State Recovery Flow', async (t) => {
  const server = new EchoLineServer(TEST_PORT);
  await server.start();

  let p1, p2, p3, p1Reconnect;

  t.after(() => {
    if (p1) p1.close();
    if (p2) p2.close();
    if (p3) p3.close();
    if (p1Reconnect) p1Reconnect.close();
    server.stop();
  });

  await t.test('handles unexpected client drop and seamless reconnect snapshot', async () => {
    p1 = await TestClient.connect(TEST_PORT, 'p_past');
    p2 = await TestClient.connect(TEST_PORT, 'p_present');
    p3 = await TestClient.connect(TEST_PORT, 'p_future');

    // Join room
    p1.send(createMessage(MessageTypes.JOIN_ROOM_REQUEST, { room_code: 'SYNC', create_if_missing: true }, 'p_past'));
    await p1.waitFor(MessageTypes.JOIN_ROOM_SUCCESS);

    p2.send(createMessage(MessageTypes.JOIN_ROOM_REQUEST, { room_code: 'SYNC' }, 'p_present'));
    await p2.waitFor(MessageTypes.JOIN_ROOM_SUCCESS);

    p3.send(createMessage(MessageTypes.JOIN_ROOM_REQUEST, { room_code: 'SYNC' }, 'p_future'));
    await p3.waitFor(MessageTypes.JOIN_ROOM_SUCCESS);

    // Ready and start
    p1.send(createMessage(MessageTypes.PLAYER_READY, { room_code: 'SYNC', ready: true }, 'p_past'));
    p2.send(createMessage(MessageTypes.PLAYER_READY, { room_code: 'SYNC', ready: true }, 'p_present'));
    p3.send(createMessage(MessageTypes.PLAYER_READY, { room_code: 'SYNC', ready: true }, 'p_future'));

    await p1.waitFor(MessageTypes.MATCH_START);

    // 1 action performed
    p1.send(createMessage(MessageTypes.PLAYER_INTENT, { room_code: 'SYNC', echo_id: 'echo_clear_debris' }, 'p_past'));
    await p2.waitFor(MessageTypes.ECHO_PROPAGATED);

    // P1 abruptly disconnects
    p1.close();

    const disconnectNotice = await p2.waitFor(MessageTypes.PLAYER_DISCONNECTED);
    assert.strictEqual(disconnectNotice.payload.player_id, 'p_past');
    assert.strictEqual(disconnectNotice.payload.timeline, 'past');

    // P1 reconnects within grace window
    p1Reconnect = await TestClient.connect(TEST_PORT, 'p_past');
    p1Reconnect.send(createMessage(MessageTypes.JOIN_ROOM_REQUEST, { room_code: 'SYNC' }, 'p_past'));

    const joinSuccess = await p1Reconnect.waitFor(MessageTypes.JOIN_ROOM_SUCCESS);
    assert.strictEqual(joinSuccess.payload.is_reconnect, true);
    assert.strictEqual(joinSuccess.payload.assigned_timeline, 'past');

    const snapshot = await p1Reconnect.waitFor(MessageTypes.STATE_SNAPSHOT);
    assert.strictEqual(snapshot.payload.state.past.canal_debris.state, 'cleared');
    assert.strictEqual(snapshot.payload.causal_history.length, 1);
  });
});
