'use strict';

/**
 * Load runner — spawn N simulated clients across M rooms.
 * Measures authenticated match-state request latency and error rate.
 *
 * Run with: node tests/load/load_runner.js --rooms=50 --players=4 --duration=60
 * Outputs: load_test_results.json
 */

const fs = require('node:fs');
const { io } = require('socket.io-client');

function parseArgs() {
  const values = { url: process.env.LOAD_URL || 'http://localhost:3001', rooms: 20, players: 4, duration: 30 };
  for (const arg of process.argv.slice(2)) {
    const [key, value] = arg.split('=');
    if (key === '--url' && value) values.url = value;
    if (key === '--rooms' && value) values.rooms = Number.parseInt(value, 10);
    if (key === '--players' && value) values.players = Number.parseInt(value, 10);
    if (key === '--duration' && value) values.duration = Number.parseInt(value, 10);
  }
  if (!Number.isInteger(values.rooms) || values.rooms < 1) throw new Error('--rooms must be >= 1');
  if (!Number.isInteger(values.players) || values.players < 2 || values.players > 4) throw new Error('--players must be 2..4');
  if (!Number.isInteger(values.duration) || values.duration < 1) throw new Error('--duration must be >= 1');
  return values;
}

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

function connectSocket(url) {
  return new Promise((resolve, reject) => {
    const socket = io(url, { transports: ['websocket'], forceNew: true, timeout: 5000 });
    const fail = error => { socket.disconnect(); reject(error); };
    socket.once('connect', () => resolve(socket));
    socket.once('connect_error', fail);
  });
}

function emitAck(socket, event, payload, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    socket.timeout(timeoutMs).emit(event, payload, (error, ack) => {
      if (error) return reject(new Error(`${event} timeout`));
      resolve(ack || {});
    });
  });
}

async function runOnce(socket, payload) {
  const start = Date.now();
  try {
    const ack = await emitAck(socket, 'match:state_request', payload);
    return { ms: Date.now() - start, ack };
  } catch (error) {
    return { ms: Date.now() - start, error: error.message };
  }
}

async function main() {
  const options = parseArgs();
  console.log(`Load test: ${options.url} | rooms=${options.rooms} players=${options.players} duration=${options.duration}s`);
  const rooms = [];
  const sockets = [];
  const startedAt = Date.now();

  try {
    // Create each room, then join against the server-issued code.
    for (let r = 0; r < options.rooms; r++) {
      const host = await connectSocket(options.url);
      sockets.push(host);
      const createAck = await emitAck(host, 'lobby:create', {
        playerUid: `load_host_${r}`,
        displayName: `LoadHost${r}`,
        language: 'en',
        scenarioId: 'clocktower_district',
        maxPlayers: options.players,
      });
      if (!createAck.success || !createAck.room?.code) {
        throw new Error(`room ${r} creation failed: ${createAck.error || 'unknown error'}`);
      }
      const room = { code: createAck.room.code, players: [host] };
      for (let p = 1; p < options.players; p++) {
        const player = await connectSocket(options.url);
        sockets.push(player);
        const joinAck = await emitAck(player, 'lobby:join', {
          playerUid: `load_p_${r}_${p}`,
          displayName: `LoadP${p}`,
          language: 'en',
          roomCode: room.code,
        });
        if (!joinAck.success) throw new Error(`room ${r} player ${p} join failed: ${joinAck.error || 'unknown error'}`);
        room.players.push(player);
      }
      rooms.push(room);
    }
    console.log(`✓ ${rooms.length} rooms, ${sockets.length} players connected in ${Date.now() - startedAt}ms`);

    // Make every human ready and start using the actual host socket.
    for (const room of rooms) {
      for (const player of room.players) {
        const readyAck = await emitAck(player, 'lobby:set_ready', { ready: true });
        if (!readyAck.success) throw new Error(`ready failed in ${room.code}`);
      }
      const startAck = await emitAck(room.players[0], 'lobby:start', {});
      if (!startAck.success) throw new Error(`start failed in ${room.code}: ${startAck.error || 'unknown error'}`);
    }
    await sleep(1000);

    // Exercise the hot authenticated state path. It is non-mutating, so the
    // measurement is not polluted by puzzle precondition failures.
    const latencies = [];
    let successCount = 0;
    let errorCount = 0;
    let rejectedCount = 0;
    const testStart = Date.now();
    for (let second = 0; second < options.duration; second++) {
      const batch = [];
      for (const socket of sockets) {
        if (!socket.connected) {
          errorCount++;
          continue;
        }
        batch.push(runOnce(socket, { clientSeq: second }));
      }
      const results = await Promise.all(batch);
      for (const result of results) {
        latencies.push(result.ms);
        if (result.error) errorCount++;
        else if (result.ack?.success) successCount++;
        else { errorCount++; rejectedCount++; }
      }
      await sleep(50);
    }

    latencies.sort((a, b) => a - b);
    if (!latencies.length) throw new Error('No load operations completed');
    const percentile = ratio => latencies[Math.min(latencies.length - 1, Math.floor(latencies.length * ratio))];
    const totalTime = Date.now() - testStart;
    const results = {
      url: options.url,
      rooms: options.rooms,
      players: sockets.length,
      duration_sec: options.duration,
      total_ops: latencies.length,
      success_count: successCount,
      error_count: errorCount,
      rejected_count: rejectedCount,
      error_rate: errorCount / latencies.length,
      latency_ms: {
        p50: percentile(0.50), p95: percentile(0.95), p99: percentile(0.99),
        max: latencies[latencies.length - 1], min: latencies[0],
      },
      // Alias retained for older CI dashboards.
      p99_ms: percentile(0.99),
      throughput_ops_per_sec: latencies.length / (totalTime / 1000),
    };

    console.log(JSON.stringify(results, null, 2));
    fs.writeFileSync('load_test_results.json', JSON.stringify(results, null, 2));
    if (results.p99_ms > 500) throw new Error(`p99 latency > 500ms (${results.p99_ms}ms)`);
    if (results.error_rate > 0.05) throw new Error(`error rate > 5% (${(results.error_rate * 100).toFixed(2)}%)`);
    console.log('✅ Load test passed');
  } finally {
    sockets.forEach(socket => socket.disconnect());
  }
}

main().catch(error => {
  console.error(`❌ Load test failed: ${error.message}`);
  process.exitCode = 1;
});
