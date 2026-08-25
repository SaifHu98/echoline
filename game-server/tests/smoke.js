/* Quick smoke test for the game server */
const { io } = require('socket.io-client');
const URL = process.argv[2] || 'http://localhost:3000';

async function delay(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  console.log('Connecting to', URL);

  // Player A
  const sockA = io(URL, { transports: ['websocket'] });
  await new Promise(r => sockA.on('connect', r));
  console.log('A connected:', sockA.id);

  sockA.emit('lobby:create', {
    playerUid: 'player_a',
    displayName: 'Alice',
    language: 'en',
    scenarioId: 'clocktower_district',
  }, (ack) => {
    console.log('A create:', ack);
    if (!ack.success) return;
    const code = ack.room.code;
    console.log('Room code:', code);

    // Player B joins
    const sockB = io(URL, { transports: ['websocket'] });
    sockB.on('connect', () => {
      console.log('B connected');
      sockB.emit('lobby:join', {
        playerUid: 'player_b',
        displayName: 'Bob',
        language: 'ar',
        roomCode: code,
        timeline: 'future',
      }, (ack2) => {
        console.log('B join:', JSON.stringify(ack2).substring(0, 200));
      });
    });

    // Wait then try to interact
    setTimeout(async () => {
      // A picks past, B picks present
      sockA.emit('lobby:select_timeline', { timeline: 'past' }, (a) => console.log('A timeline:', a));
      sockB.emit('lobby:select_timeline', { timeline: 'present' }, (a) => console.log('B timeline:', a));

      sockA.emit('lobby:set_ready', { ready: true }, (a) => console.log('A ready:', a));
      sockB.emit('lobby:set_ready', { ready: true }, (a) => console.log('B ready:', a));

      await delay(300);
      sockA.emit('lobby:start', {}, (a) => console.log('A start:', a));

      // Listen for match:started
      sockA.on('match:started', (s) => console.log('A got match:started. scenario=', s?.scenarioId, ' you.timeline=', s?.you?.timeline));
      sockA.on('match:state', (s) => console.log('A got match:state. timer=', s?.state?.system?.catastrophe_timer_ms, ' stability=', s?.state?.system?.stability));
      sockA.on('match:chat', (m) => console.log('A got chat:', m.intent, 'from', m.from.timeline));
      sockA.on('lobby:update', (s) => console.log('A got lobby update: players=', s.players.length));

      // Wait for match:started
      await delay(1500);

      // A sends a quick message
      sockA.emit('match:quick_message', { intent: 'REQUEST_WATER_FLOW' });
      await delay(500);

      // A tries to clear debris (echo action)
      sockA.emit('match:interact', { entityId: 'canal_debris', action: 'clear_debris' }, (r) => {
        console.log('A interact:', r.success ? 'OK' : 'FAIL', r.error || '');
      });

      await delay(800);

      // B sends ping
      sockB.emit('match:ping', { type: 'location', x: 100, y: 100 });

      await delay(500);

      sockA.disconnect();
      sockB.disconnect();
      console.log('Test complete');
      process.exit(0);
    }, 500);
  });
}

main().catch(e => { console.error(e); process.exit(1); });

setTimeout(() => { console.log('Test timeout'); process.exit(1); }, 12000);