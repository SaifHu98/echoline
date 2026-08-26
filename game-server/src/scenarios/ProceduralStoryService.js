/**
 * ProceduralStoryService — server-side narrative generator (Node.js)
 * --------------------------------------------------------------------------
 * Mirrors the GDScript ProceduralStoryEngine but lives on the authoritative
 * server so:
 *   - All players in a room receive the SAME manifest (deterministic).
 *   - The server can persist the manifest for replay / cheat-detection.
 *   - The server picks the seed; clients never re-seed.
 *
 * The deterministic xorshift32 implementation is byte-for-byte identical to
 * the GDScript version (client/story/story_seeded_rng.gd). Both clients and
 * server can produce identical manifests from the same seed — that's the
 * foundation of cross-platform determinism.
 *
 * Author: Saif Huq
 * License: MIT
 */
'use strict';

const crypto = require('crypto');

class SeededRNG {
  constructor(seed = 0) {
    this._state = seed === 0 ? 1 : (seed >>> 0);
    this._seed = seed;
    this._callCount = 0;
  }

  setSeed(seed) {
    this._seed = seed;
    this._state = seed === 0 ? 1 : (seed >>> 0);
    this._callCount = 0;
  }

  getSeed() { return this._seed; }

  _nextU32() {
    let x = this._state >>> 0;
    x ^= (x << 13) >>> 0;
    x = x >>> 17;
    x ^= (x << 5) >>> 0;
    x = x >>> 0;
    this._state = x >>> 0;
    this._callCount += 1;
    return x >>> 0;
  }

  randInt(minV, maxV) {
    if (maxV < minV) return minV;
    const range = maxV - minV + 1;
    return minV + ((this._nextU32() % range) >>> 0);
  }

  randFloat(minV = 0, maxV = 1) {
    return minV + (this._nextU32() / 4294967295) * (maxV - minV);
  }

  randIndex(arraySize) {
    if (arraySize <= 0) return 0;
    const raw = this._nextU32();
    const threshold = -arraySize % arraySize;
    let n = raw;
    while (n < threshold) {
      n = this._nextU32();
    }
    return n % arraySize;
  }

  pick(arr) {
    if (!arr || arr.length === 0) return null;
    return arr[this.randIndex(arr.length)];
  }

  pickWeighted(weights) {
    const keys = Object.keys(weights);
    if (keys.length === 0) return null;
    let total = 0;
    for (const k of keys) total += Number(weights[k]);
    if (total <= 0) return keys[this.randIndex(keys.length)];
    let r = this.randFloat(0, total);
    let cumulative = 0;
    for (const k of keys) {
      cumulative += Number(weights[k]);
      if (r <= cumulative) return k;
    }
    return keys[keys.length - 1];
  }

  shuffle(arr) {
    const copy = arr.slice();
    for (let i = copy.length - 1; i > 0; i--) {
      const j = this.randIndex(i + 1);
      [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy;
  }

  shortId() {
    return ('00000000' + (this._seed >>> 0).toString(16)).slice(-8);
  }
}

/**
 * Narrative templates — same data as client/story/narrative_template_bank.gd
 * In production, load these from JSON files in shared/scenarios/narrative/.
 */
const TIMELINE_FLAVOR = {
  past: {
    items: ['memory shards', 'rune stones', 'lanterns', 'scrolls', 'flowers'],
    structures: ['courtyard wall', 'archive wing', 'garden path', 'tower foundation'],
    objects: ['memory shard', "scribe's lamp", "hollow king's crown"],
    enemies: ['stone guardians', 'hollow knights', 'memory wraiths'],
  },
  present: {
    items: ['gears', 'neon shards', 'time stamps', 'radio frequencies', 'memory chips'],
    structures: ['clockwork mechanism', 'tower office', 'neon grid', 'temporal cable'],
    objects: ['largest gear', 'neon signal', 'temporal broadcast'],
    enemies: ['rogue mechanics', 'temporal smugglers', 'neon wraiths'],
  },
  future: {
    items: ['quantum shards', 'energy crystals', 'holographic fragments', 'signal pulses'],
    structures: ['crystal grid', 'omega anchor', 'signal satellite', 'reality lattice'],
    objects: ['omega anchor', 'crystal core', "reality merchant's table"],
    enemies: ['rift echoes', 'crystal wraiths', 'timeline parasites'],
  },
};

const MISSION_TYPES = {
  collect: { baseCount: { past: 5, present: 8, future: 6 }, baseTime: 180, rewardPerUnit: 1 },
  defend: { baseWaves: { past: 3, present: 4, future: 5 }, rewardPerWave: 5 },
  build: { baseCount: { past: 4, present: 6, future: 5 }, rewardPerUnit: 3 },
  rescue: { baseCount: { past: 1, present: 2, future: 1 }, rewardPerUnit: 8 },
};

function fillPlaceholders(text, vars) {
  if (!text) return '';
  let result = String(text);
  for (const k of Object.keys(vars)) {
    result = result.split('{' + k + '}').join(String(vars[k]));
  }
  return result;
}

function pickTemplate(rng, timeline, difficulty, moodFilter = []) {
  const templates = NarrativeBank.getTemplatesForTimeline(timeline);
  let pool = templates.filter(t => {
    const range = t.difficulty_range || [1, 5];
    return difficulty >= range[0] && difficulty <= range[1];
  });
  if (moodFilter.length > 0) {
    pool = pool.filter(t => (t.mood || []).some(m => moodFilter.includes(m)));
  }
  if (pool.length === 0) pool = templates;
  return rng.pick(pool);
}

const NarrativeBank = {
  getTemplatesForTimeline(timeline) {
    if (timeline === 'past') return PAST_TEMPLATES;
    if (timeline === 'present') return PRESENT_TEMPLATES;
    if (timeline === 'future') return FUTURE_TEMPLATES;
    return [];
  },
};

// In a real production setup these would be loaded from shared JSON files.
// Here we ship representative templates — the full 24 are in the GDScript bank.
const PAST_TEMPLATES = [
  {
    id: 'past_courtyard_siege',
    title: { en: 'The Siege of the Courtyard', ar: 'حصاة الفناء' },
    mood: ['tension', 'sacrifice'],
    difficulty_range: [1, 3],
    hooks: [{ en: 'Stone guardians stir in the courtyard.' }],
    endings: [{ en: 'The courtyard stands. {winner} carries the song of stone.' }],
  },
  {
    id: 'past_archive_forgotten',
    title: { en: 'The Archive of Forgotten Names', ar: 'أرشيف الأسماء المنسية' },
    mood: ['mystery', 'discovery'],
    difficulty_range: [1, 2],
    hooks: [{ en: 'An archivist offers you a memory in exchange for a name.' }],
    endings: [{ en: 'Your name is added to the archive. {winner} decides if it is true.' }],
  },
];
const PRESENT_TEMPLATES = [
  {
    id: 'present_clock_shop_break_in',
    title: { en: 'The Clock Shop Break-In', ar: 'اقتحام متجر الساعات' },
    mood: ['tension', 'urgency'],
    difficulty_range: [1, 3],
    hooks: [{ en: 'Someone has stolen the shop\'s largest gear.' }],
    endings: [{ en: '{winner} returns the final gear. The clock ticks once more.' }],
  },
  {
    id: 'present_temporal_market',
    title: { en: 'The Temporal Market', ar: 'السوق الزمني' },
    mood: ['discovery', 'trade'],
    difficulty_range: [2, 4],
    hooks: [{ en: 'A market appears at midnight in an empty alley.' }],
    endings: [{ en: '{winner} closes the market. The alley is empty by dawn.' }],
  },
];
const FUTURE_TEMPLATES = [
  {
    id: 'future_quantum_drift',
    title: { en: 'The Quantum Drift', ar: 'الانجراف الكمي' },
    mood: ['mystery', 'urgency'],
    difficulty_range: [1, 3],
    hooks: [{ en: 'Reality stutters. A second you appears in the corridor.' }],
    endings: [{ en: '{winner} collapses the rifts. The other yous vanish.' }],
  },
  {
    id: 'future_omega_anchor',
    title: { en: 'The Omega Anchor', ar: 'المرساة أوميغا' },
    mood: ['sacrifice', 'triumph'],
    difficulty_range: [3, 5],
    hooks: [{ en: 'The last anchor in the timeline begins to crack.' }],
    endings: [{ en: '{winner} stays. The timeline holds.' }],
  },
];

/**
 * ProceduralStoryService — generates and persists story manifests.
 */
class ProceduralStoryService {
  constructor({ logger = null } = {}) {
    this.logger = logger || console;
    this._manifests = new Map();
  }

  generate({ timeline = 'present', difficulty = 1, playerCount = 2, locale = 'en', seedOverride = 0 }) {
    const rng = new SeededRNG(seedOverride || this._generateSeed(timeline, difficulty, playerCount));
    const template = pickTemplate(rng, timeline, difficulty, []);
    const hook = rng.pick(template.hooks || []);
    const ending = rng.pick(template.endings || []);
    const flavor = TIMELINE_FLAVOR[timeline] || TIMELINE_FLAVOR.present;
    const missions = this._generateMissions(rng, timeline, difficulty, playerCount);
    const layout = this._generateLayout(rng, timeline, difficulty, playerCount);
    const placeholders = this._makePlaceholders(rng, playerCount, missions[0]?.values?.count || 5);
    const manifest = {
      version: '1.0',
      seed: rng.getSeed(),
      short_id: rng.shortId(),
      template_id: template.id,
      timeline,
      difficulty,
      player_count: playerCount,
      locale,
      title: template.title?.[locale] || template.title?.en || '',
      mood: template.mood || [],
      hook: fillPlaceholders(hook?.[locale] || hook?.en || '', placeholders),
      ending: fillPlaceholders(ending?.[locale] || ending?.en || '', placeholders),
      missions,
      layout,
      estimated_duration_minutes: 12 + difficulty * 4 + playerCount * 2,
      completion_credits: 30 + difficulty * 15,
      completion_shards: 3 + difficulty * 2,
    };
    return manifest;
  }

  _generateMissions(rng, timeline, difficulty, playerCount) {
    const count = Math.max(3, Math.min(5, 3 + Math.floor((difficulty - 1) * 0.5) + Math.floor(playerCount * 0.5)));
    const types = Object.keys(MISSION_TYPES);
    const missions = [];
    for (let i = 0; i < count; i++) {
      const type = rng.pick(types);
      const t = MISSION_TYPES[type];
      const baseCount = (t.baseCount || t.baseWaves)[timeline];
      const cnt = Math.round(baseCount * (1 + (difficulty - 1) * 0.25) * (0.8 + (playerCount - 1) * 0.13));
      missions.push({
        index: i,
        type,
        description: `${type}: ${cnt} units in ${timeline}`,
        values: { count: cnt, timeline },
        reward_shards: cnt * (t.rewardPerUnit || t.rewardPerWave) * difficulty,
        difficulty,
        timeline,
      });
    }
    return missions;
  }

  _generateLayout(rng, timeline, difficulty, playerCount) {
    const themes = ['open', 'corridor', 'vertical', 'arena'];
    const theme = rng.pick(themes);
    const spawnPoints = [];
    for (let i = 0; i < playerCount; i++) {
      const angle = (Math.PI * 2 * i) / playerCount;
      const radius = 30 + rng.randFloat(0, 10);
      spawnPoints.push({
        player_index: i,
        position: { x: Math.cos(angle) * radius, y: 0, z: Math.sin(angle) * radius },
        facing_angle: angle + Math.PI,
      });
    }
    return {
      theme,
      scene_id: `res://scenes/timelines/${timeline}/${theme}_default.tscn`,
      spawn_points: spawnPoints,
      anchor_locations: [],
      hazard_zones: [],
      shard_pickups: [],
      lighting: {},
      difficulty,
      player_count: playerCount,
    };
  }

  _generateSeed(timeline, difficulty, playerCount) {
    const ts = Math.floor(Date.now() / 1000);
    const r = Math.floor(Math.random() * 1_000_000);
    return ts ^ r ^ (playerCount * 1009 + difficulty * 31 + this._hashString(timeline));
  }

  _hashString(s) {
    let h = 0;
    for (let i = 0; i < s.length; i++) {
      h = ((h << 5) - h + s.charCodeAt(i)) | 0;
    }
    return h;
  }

  _makePlaceholders(rng, playerCount, shardTarget) {
    return {
      player_count: playerCount,
      winner: '{winner}',
      shard_target: shardTarget,
      rune_count: rng.randInt(3, 7),
      lantern_count: rng.randInt(5, 12),
      flower_count: rng.randInt(4, 10),
      scroll_count: rng.randInt(2, 5),
      floor_count: rng.randInt(5, 12),
      noble_count: rng.randInt(3, 8),
      torch_count: rng.randInt(4, 10),
      gear_count: rng.randInt(3, 8),
      merchant_count: rng.randInt(2, 6),
      district_count: rng.randInt(2, 5),
      ally_count: rng.randInt(1, 4),
      passenger_count: rng.randInt(3, 8),
      room_count: rng.randInt(2, 6),
      broadcast_count: rng.randInt(2, 5),
      memory_count: rng.randInt(3, 8),
      rift_count: rng.randInt(2, 6),
      energy_count: rng.randInt(50, 200),
      crystal_count: rng.randInt(3, 7),
      cable_count: rng.randInt(2, 5),
      leak_count: rng.randInt(2, 5),
      satellite_count: rng.randInt(3, 7),
      truth_count: rng.randInt(1, 4),
    };
  }

  // === Persistence ===

  storeForRoom(roomId, manifest) {
    this._manifests.set(roomId, manifest);
  }

  loadForRoom(roomId) {
    return this._manifests.get(roomId);
  }
}

module.exports = {
  ProceduralStoryService,
  SeededRNG,
  pickTemplate,
  fillPlaceholders,
};
