const test = require('node:test');
const assert = require('node:assert');
const { EchoLineServer } = require('../src/server');
const { MessageTypes, createMessage } = require('../src/protocol/messages');
const { TestClient } = require('./test_helper');

const TEST_PORT = 7890;

test('Multiplayer Protocol & 3-Player Session Flow', async (t) => {
  const server = new EchoLineServer(TEST_PORT);
  await server.start();

  let p1, p2, p3;

  t.after(() => {
    if (p1) p1.close();
    if (p2) p2.close();
    if (p3) p3.close();
    server.stop();
  });

  await t.test('3 players join a private room with 4-character code', async () => {
    p1 = await TestClient.connect(TEST_PORT, 'user_past');
    p2 = await TestClient.connect(TEST_PORT, 'user_present');
    p3 = await TestClient.connect(TEST_PORT, 'user_future');

    // Player 1 creates room "TIME"
    p1.send(createMessage(MessageTypes.JOIN_ROOM_REQUEST, {
      room_code: 'TIME',
      create_if_missing: true
    }, 'user_past'));

    const joinP1 = await p1.waitFor(MessageTypes.JOIN_ROOM_SUCCESS);
    assert.strictEqual(joinP1.payload.room_code, 'TIME');
    assert.strictEqual(joinP1.payload.assigned_timeline, 'past');

    // Player 2 joins "TIME"
    p2.send(createMessage(MessageTypes.JOIN_ROOM_REQUEST, {
      room_code: 'TIME'
    }, 'user_present'));

    const joinP2 = await p2.waitFor(MessageTypes.JOIN_ROOM_SUCCESS);
    assert.strictEqual(joinP2.payload.assigned_timeline, 'present');

    // Player 3 joins "TIME"
    p3.send(createMessage(MessageTypes.JOIN_ROOM_REQUEST, {
      room_code: 'TIME'
    }, 'user_future'));

    const joinP3 = await p3.waitFor(MessageTypes.JOIN_ROOM_SUCCESS);
    assert.strictEqual(joinP3.payload.assigned_timeline, 'future');
  });

  await t.test('all players ready up and match starts', async () => {
    p1.send(createMessage(MessageTypes.PLAYER_READY, { room_code: 'TIME', ready: true }, 'user_past'));
    p2.send(createMessage(MessageTypes.PLAYER_READY, { room_code: 'TIME', ready: true }, 'user_present'));
    p3.send(createMessage(MessageTypes.PLAYER_READY, { room_code: 'TIME', ready: true }, 'user_future'));

    const startP1 = await p1.waitFor(MessageTypes.MATCH_START);
    const startP2 = await p2.waitFor(MessageTypes.MATCH_START);
    const startP3 = await p3.waitFor(MessageTypes.MATCH_START);

    assert.strictEqual(startP1.payload.match_id, 'TIME');
    assert.strictEqual(startP2.payload.match_id, 'TIME');
    assert.strictEqual(startP3.payload.match_id, 'TIME');
  });

  await t.test('propagates cross-timeline actions and concludes with victory recap', async () => {
    // 1. Past: clear debris
    p1.send(createMessage(MessageTypes.PLAYER_INTENT, {
      room_code: 'TIME',
      echo_id: 'echo_clear_debris'
    }, 'user_past'));
    await p2.waitFor(MessageTypes.ECHO_PROPAGATED);

    // 2. Past: open sluice gate
    p1.send(createMessage(MessageTypes.PLAYER_INTENT, {
      room_code: 'TIME',
      echo_id: 'echo_divert_canal_water'
    }, 'user_past'));
    await p3.waitFor(MessageTypes.ECHO_PROPAGATED);

    // 3. Present: replace clock gear
    p2.send(createMessage(MessageTypes.PLAYER_INTENT, {
      room_code: 'TIME',
      echo_id: 'echo_replace_clock_gear'
    }, 'user_present'));
    await p3.waitFor(MessageTypes.ECHO_PROPAGATED);

    // 4. Future: input temporal code
    p3.send(createMessage(MessageTypes.PLAYER_INTENT, {
      room_code: 'TIME',
      echo_id: 'echo_input_temporal_code'
    }, 'user_future'));
    await p1.waitFor(MessageTypes.ECHO_PROPAGATED);

    // 5. Future: activate gate stabilizer -> concludes match
    p3.send(createMessage(MessageTypes.PLAYER_INTENT, {
      room_code: 'TIME',
      echo_id: 'echo_activate_gate_stabilizer'
    }, 'user_future'));

    const recapP1 = await p1.waitFor(MessageTypes.MATCH_CONCLUDED);
    assert.strictEqual(recapP1.payload.outcome_grade, 'major_success');
    assert.strictEqual(recapP1.payload.total_echoes, 5);
    assert.strictEqual(recapP1.payload.timeline_branches.past.length, 2);
    assert.strictEqual(recapP1.payload.timeline_branches.present.length, 1);
    assert.strictEqual(recapP1.payload.timeline_branches.future.length, 2);
  });
});
