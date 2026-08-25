/**
 * MatchMaker — quick matchmaking into public rooms
 * (Currently optional; private rooms work via lobby:create/join)
 */
'use strict';

class MatchMaker {
  constructor({ logger, roomManager, scenarios }) {
    this.logger = logger;
    this.roomManager = roomManager;
    this.scenarios = scenarios;
    this.queue = []; // [{socketId, uid, displayName, language, scenarioId, joinedAt}]
    this.queueByScenario = new Map();
  }

  enqueue(socketId, uid, displayName, language, scenarioId) {
    const entry = { socketId, uid, displayName, language, scenarioId, joinedAt: Date.now() };
    this.queue.push(entry);
    if (!this.queueByScenario.has(scenarioId)) this.queueByScenario.set(scenarioId, []);
    this.queueByScenario.get(scenarioId).push(entry);
    this.tryMatch(scenarioId);
    return { queued: true };
  }

  dequeue(socketId) {
    this.queue = this.queue.filter(e => e.socketId !== socketId);
    for (const [k, list] of this.queueByScenario) {
      this.queueByScenario.set(k, list.filter(e => e.socketId !== socketId));
    }
  }

  tryMatch(scenarioId) {
    const list = this.queueByScenario.get(scenarioId);
    if (!list || list.length < 2) return;
    // Greedy: pair first two
    const [a, b] = list.splice(0, 2);
    // Caller is expected to emit 'match:found' on both sockets
    this.logger.info({ scenarioId, pair: [a.uid, b.uid] }, 'Match found');
    return { players: [a, b], scenarioId };
  }
}

module.exports = MatchMaker;