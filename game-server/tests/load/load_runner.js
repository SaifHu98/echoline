'use strict';

/**
 * Load runner — spawn N simulated clients across M rooms
 * Measures p50/p95/p99 latency, message throughput, error rate
 * Run with: node tests/load/load_runner.js --rooms=50 --players=4 --duration=60
 *
 * Outputs: load_test_results.json
 */

const fs = require('fs');
const path = require('path');
const { io } = require('socket.io-client');

const URL = process.env.LOAD_URL || 'http://localhost:3001';
const ROOMS = parseInt(process.argv.find(a => a.startsWith('--rooms='))?.split('=')[1] || '20');
const PLAYERS = parseInt(process.argv.find(a => a.startsWith('--players='))?.split('=')[1] || '4');
const DURATION = parseInt(process.argv.find(a => a.startsWith('--duration='))?.split('=')[1] || '30');

function parseArgs() {
  const args = process.argv.slice(2);
  for (const a of args) {
    if (a.startsWith('--url=')) process.env.LOAD_URL = a.split('=')[1];
  }
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function runOnce(socket, payload, idemKey) {
  const start = Date.now();
  return new Promise(resolve => {
    const timer = setTimeout(() => resolve({ error: 'timeout', ms: 5000 }), 5000);
    socket.emit('match:interact', payload, (ack) => {
      clearTimeout(timer);
      const ms = Date.now() - start;
      resolve({ ms, ack, idemKey });
    });
  });
}

async function main() {
  parseArgs();
  console.log(`Load test: ${URL} | rooms=${ROOMS} players=${PLAYERS} duration=${DURATION}s`);
  const sockets = [];
  const roomIds = [];

  // Phase 1: Connect and create rooms
  const t0 = Date.now();
  for (let r = 0; r < ROOMS; r++) {
    const host = io(URL, { transports: ['websocket'], forceNew: true });
    sockets.push(host);
    const code = 'LOAD' + r.toString().padStart(4, '0');
    await new Promise(resolve => {
      host.on('connect', () => {
        host.emit('lobby:create', {
          playerUid: 'load_host_' + r,
          displayName: 'LoadHost' + r,
          language: 'en',
          scenarioId: 'clocktower_district',
        }, (ack) => {
          if (ack.success) roomIds.push(ack.room.code);
          resolve();
        });
      });
    });
    // Add players
    for (let p = 1; p < PLAYERS; p++) {
      const s = io(URL, { transports: ['websocket'], forceNew: true });
      sockets.push(s);
      await new Promise(resolve => {
        s.on('connect', () => {
          s.emit('lobby:join', {
            playerUid: 'load_p_' + r + '_' + p,
            displayName: 'LoadP' + p,
            language: 'en',
            roomCode: code,
          }, (ack) => resolve());
        });
      });
    }
  }
  const connectedTime = Date.now() - t0;
  console.log(`✓ ${ROOMS} rooms, ${ROOMS * PLAYERS} players connected in ${connectedTime}ms`);

  // Phase 2: Wait for all ready + start matches
  await sleep(2000);
  for (let i = 0; i < ROOMS; i++) {
    sockets[i * PLAYERS].emit('lobby:start', {}, () => {});
  }
  await sleep(2000);

  // Phase 3: Burst operations
  const ops = [];
  const startTime = Date.now();
  let errorCount = 0;
  let successCount = 0;

  for (let i = 0; i < DURATION; i++) {
    const batch = [];
    for (let j = 0; j < ROOMS * PLAYERS; j++) {
      const socket = sockets[j];
      if (!socket || !socket.connected) {
        errorCount++;
        continue;
      }
      batch.push(runOnce(socket, {
        entityId: 'courtyard_soil',
        action: 'lift_stone',
        idempotencyKey: 'load_' + i + '_' + j,
      }, 'load_' + i + '_' + j));
    }
    const results = await Promise.all(batch);
    results.forEach(r => {
      if (r.ack && r.ack.success) successCount++;
      else if (r.error) errorCount++;
    });
    ops.push(...results.map(r => r.ms));
    await sleep(50); // ~20 ops/sec/room aggregate
  }

  const totalTime = Date.now() - startTime;
  ops.sort((a, b) => a - b);
  const p50 = ops[Math.floor(ops.length * 0.5)];
  const p95 = ops[Math.floor(ops.length * 0.95)];
  const p99 = ops[Math.floor(ops.length * 0.99)];
  const max = ops[ops.length - 1];

  const results = {
    url: URL,
    rooms: ROOMS,
    players: ROOMS * PLAYERS,
    duration_sec: DURATION,
    total_ops: ops.length,
    success_count: successCount,
    error_count: errorCount,
    error_rate: errorCount / (successCount + errorCount),
    latency_ms: {
      p50, p95, p99, max, min: ops[0],
    },
    throughput_ops_per_sec: ops.length / totalTime,
  };

  console.log(JSON.stringify(results, null, 2));
  fs.writeFileSync('load_test_results.json', JSON.stringify(results, null, 2));

  // Disconnect all
  sockets.forEach(s => s.disconnect());

  // Exit with code based on threshold
  if (p99 > 500) {
    console.error('❌ p99 latency > 500ms');
    process.exit(1);
  }
  if (results.error_rate > 0.05) {
    console.error('❌ error rate > 5%');
    process.exit(1);
  }
  console.log('✅ Load test passed');
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });