'use strict';

/**
 * FeatureFlags — runtime feature toggles
 * ======================================
 * Allows gradual rollout of new features
 * Each flag has:
 *  - stable default (off in production, on in dev)
 *  - percentage rollout (0-100)
 *  - allowlist of UIDs (for testing)
 *  - kill switch (force off regardless of percentage)
 */

const FLAGS = {
  // v1.0 — initial release flags
  ENABLE_ECHO_TRAIL_VFX: { default: true, rollout: 100, allowlist: [] },
  ENABLE_AI_BOTS: { default: true, rollout: 100, allowlist: [] },
  ENABLE_QUICK_CHAT: { default: true, rollout: 100, allowlist: [] },
  ENABLE_VOICE_CHAT: { default: false, rollout: 0, allowlist: [] },
  ENABLE_NEW_TUTORIAL: { default: false, rollout: 10, allowlist: ['qa_user_1', 'qa_user_2'] },
  ENABLE_RANKED_MATCH: { default: false, rollout: 0, allowlist: [] },
  ENABLE_RECEIPT_V2: { default: true, rollout: 100, allowlist: [] },
  ENABLE_DARK_MODE: { default: false, rollout: 50, allowlist: [] },
};

class FeatureFlags {
  constructor(env = process.env) {
    this.env = env;
    this.overrides = new Map();
    // Emergency kill switches from env
    this.kills = (env.ECHO_KILL_FLAGS || '').split(',').filter(Boolean);
  }

  /**
   * Check if a flag is enabled for a given UID
   */
  isEnabled(flagName, uid = null) {
    if (this.kills.includes(flagName)) return false;
    if (this.overrides.has(flagName)) return this.overrides.get(flagName);

    const flag = FLAGS[flagName];
    if (!flag) return false;

    // Allowlist always passes
    if (uid && flag.allowlist.includes(uid)) return true;

    // Percentage rollout (deterministic hash-based)
    if (flag.rollout >= 100) return flag.default;
    if (flag.rollout <= 0) return false;

    // Hash-based bucketing
    if (!uid) return false;
    const hash = this._hash(`${flagName}:${uid}`);
    return (hash % 100) < flag.rollout;
  }

  _hash(str) {
    let h = 0;
    for (let i = 0; i < str.length; i++) {
      h = ((h << 5) - h + str.charCodeAt(i)) | 0;
    }
    return Math.abs(h);
  }

  /**
   * Override a flag (e.g., for staging)
   */
  override(flagName, value) {
    this.overrides.set(flagName, value);
  }

  /**
   * Set rollout percentage at runtime
   */
  setRollout(flagName, percent) {
    if (FLAGS[flagName]) {
      FLAGS[flagName].rollout = percent;
    }
  }

  /**
   * Get snapshot for telemetry/debug
   */
  snapshot() {
    const out = {};
    for (const name of Object.keys(FLAGS)) {
      out[name] = {
        enabled: this.isEnabled(name),
        rollout: FLAGS[name].rollout,
        default: FLAGS[name].default,
      };
    }
    return out;
  }
}

module.exports = { FeatureFlags, FLAGS };