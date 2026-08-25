/**
 * Regional Automated Matchmaker for ECHO//LINE (أصداء)
 * Clusters players by region, matches complementary timeline roles, and creates private rooms.
 */

class MatchmakingQueue {
  constructor(roomManager) {
    this.roomManager = roomManager;
    this.queues = {
      mena: [],
      eu: [],
      na: [],
      asia: []
    };
    this.matchInterval = null;
  }

  enqueue(player) {
    const region = player.region || 'mena';
    if (!this.queues[region]) this.queues[region] = [];
    
    // Remove if already in queue
    this.dequeue(player.id);
    this.queues[region].push({
      id: player.id,
      socket: player.socket,
      rolePreference: player.rolePreference || 'any', // 'past', 'present', 'future', 'any'
      queuedAt: Date.now()
    });
  }

  dequeue(playerId) {
    for (const region in this.queues) {
      const idx = this.queues[region].findIndex(p => p.id === playerId);
      if (idx !== -1) {
        return this.queues[region].splice(idx, 1)[0];
      }
    }
    return null;
  }

  processQueues() {
    const matchesCreated = [];

    for (const region in this.queues) {
      const pool = this.queues[region];
      while (pool.length >= 3) {
        // Pop 3 players
        const trio = pool.splice(0, 3);
        const room = this.roomManager.createRoom();
        
        const timelines = ['past', 'present', 'future'];
        trio.forEach((p, idx) => {
          room.addPlayer(p.id, p.socket);
          room.setPlayerTimeline(p.id, timelines[idx]);
          room.setPlayerReady(p.id, true);
        });

        // Trigger match start automatically
        room.startMatch();
        matchesCreated.push(room.code);
      }
    }

    return matchesCreated;
  }

  start() {
    this.matchInterval = setInterval(() => this.processQueues(), 1000);
  }

  stop() {
    if (this.matchInterval) clearInterval(this.matchInterval);
  }
}

module.exports = {
  MatchmakingQueue
};
