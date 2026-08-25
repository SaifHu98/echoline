/**
 * LiveOps Event & Quest Progression Engine for ECHO//LINE (أصداء)
 * Handles active event schedules, dynamic quest tracking, and reward claims.
 */

const { LeaderboardService } = require('./leaderboard_service');

class LiveOpsEventManager {
  constructor(initialEventsData, shopService) {
    this.events = JSON.parse(JSON.stringify(initialEventsData.events || []));
    this.shopService = shopService;
    this.leaderboardService = new LeaderboardService();
    this.userQuestProgress = new Map(); // userId -> { questId -> currentCount, claimed: Set }
  }

  getActiveEvents() {
    const now = new Date().toISOString();
    return this.events.filter(e => e.is_active && e.start_time <= now && e.end_time >= now);
  }

  createEvent(eventData) {
    this.events.push(eventData);
    return eventData;
  }

  updateEvent(eventId, updateFields) {
    const event = this.events.find(e => e.id === eventId);
    if (!event) return null;
    Object.assign(event, updateFields);
    return event;
  }

  deleteEvent(eventId) {
    const idx = this.events.findIndex(e => e.id === eventId);
    if (idx !== -1) {
      this.events.splice(idx, 1);
      return true;
    }
    return false;
  }

  recordProgress(userId, progressType, amount = 1) {
    let userProg = this.userQuestProgress.get(userId);
    if (!userProg) {
      userProg = { progress: {}, claimed: new Set() };
      this.userQuestProgress.set(userId, userProg);
    }

    const activeEvents = this.getActiveEvents();
    for (const ev of activeEvents) {
      for (const quest of ev.quests || []) {
        if (quest.target_type === progressType) {
          userProg.progress[quest.quest_id] = (userProg.progress[quest.quest_id] || 0) + amount;
        }
      }
    }
  }

  claimQuestReward(userId, questId) {
    const userProg = this.userQuestProgress.get(userId);
    if (!userProg) return { success: false, error: 'No progress recorded' };
    if (userProg.claimed.has(questId)) return { success: false, error: 'Reward already claimed' };

    let targetQuest = null;
    for (const ev of this.events) {
      targetQuest = (ev.quests || []).find(q => q.quest_id === questId);
      if (targetQuest) break;
    }

    if (!targetQuest) return { success: false, error: 'Quest not found' };

    const count = userProg.progress[questId] || 0;
    if (count < targetQuest.target_count) {
      return { success: false, error: `Quest not completed (${count}/${targetQuest.target_count})` };
    }

    userProg.claimed.add(questId);
    const { type, amount, item_id } = targetQuest.reward;

    if (type === 'chrono_shards') {
      this.shopService.creditPurchasedShards(userId, amount);
    } else if (type === 'chrono_flux') {
      const wallet = this.shopService.getWallet(userId);
      wallet.chrono_flux += amount;
    }

    return {
      success: true,
      questId,
      reward: targetQuest.reward
    };
  }
}

module.exports = {
  LiveOpsEventManager
};
