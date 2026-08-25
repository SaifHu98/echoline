/**
 * Tournament & Leaderboard Service for ECHO//LINE (أصداء)
 * Computes rankings, assigns seasonal tiers, and calculates reward distributions.
 */

class LeaderboardService {
  constructor() {
    this.leaderboards = new Map(); // eventId -> Array of { userId, displayName, score, timestamp }
  }

  submitScore(eventId, userId, displayName, score) {
    if (!this.leaderboards.has(eventId)) {
      this.leaderboards.set(eventId, []);
    }

    const board = this.leaderboards.get(eventId);
    const existing = board.find(entry => entry.userId === userId);

    if (existing) {
      if (score < existing.score) {
        existing.score = score; // Lower time is better
        existing.timestamp = Date.now();
      }
    } else {
      board.push({
        userId,
        displayName,
        score,
        timestamp: Date.now()
      });
    }

    // Sort ascending by time (lower completion time is higher rank)
    board.sort((a, b) => a.score - b.score);
  }

  getRankings(eventId, limit = 50) {
    const board = this.leaderboards.get(eventId) || [];
    return board.slice(0, limit).map((entry, idx) => ({
      rank: idx + 1,
      userId: entry.userId,
      displayName: entry.displayName,
      score: entry.score,
      timestamp: entry.timestamp
    }));
  }

  getUserRank(eventId, userId) {
    const board = this.leaderboards.get(eventId) || [];
    const idx = board.findIndex(e => e.userId === userId);
    if (idx === -1) return null;
    return {
      rank: idx + 1,
      score: board[idx].score
    };
  }
}

module.exports = {
  LeaderboardService
};
