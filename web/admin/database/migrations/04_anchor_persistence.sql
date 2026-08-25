-- ====================================================================
-- ECHO//LINE — Building System Persistence
-- Migration 04: anchor persistence (anchors, anchor_slots, anchor_audit)
-- Target: MySQL 8.0+
-- Idempotent: safe to re-run
-- ====================================================================

-- --------------------------------------------------------------------
-- anchors: persisted anchor state (snapshot for replay + analytics)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `anchors` (
  `anchor_id`            VARCHAR(36)   NOT NULL  COMMENT 'UUID v4 from game server',
  `room_id`              VARCHAR(64)   NOT NULL  COMMENT 'Match/room identifier',
  `blueprint_id`         VARCHAR(64)   NOT NULL  COMMENT 'e.g. echo_triad_anchor, support_wall',
  `state`                ENUM('in_progress','complete','abandoned','expired')  NOT NULL  DEFAULT 'in_progress',
  `progress`             DECIMAL(4,3)  NOT NULL  DEFAULT 0  COMMENT '0.000 to 1.000',
  `cooperation_count`    TINYINT       NOT NULL  DEFAULT 0,
  `started_at`           BIGINT        NOT NULL  COMMENT 'Unix ms when anchor started',
  `deadline_at`          BIGINT        NOT NULL  COMMENT 'Unix ms deadline for completion',
  `completed_at`         BIGINT        NULL     COMMENT 'Unix ms when state became complete',
  `place_seq`            INT           NOT NULL  DEFAULT 0  COMMENT 'Monotonic event counter',
  `state_hash`           CHAR(64)      NOT NULL  DEFAULT ''  COMMENT 'SHA256 for reconciliation',
  `final_outcome`        VARCHAR(64)   NULL     COMMENT 'e.g. perfect_testament',
  `score_award`          INT           NOT NULL  DEFAULT 0,
  `metadata_json`        JSON          NULL     COMMENT 'Optional custom metadata',
  `created_at`           TIMESTAMP     NOT NULL  DEFAULT CURRENT_TIMESTAMP,
  `updated_at`           TIMESTAMP     NOT NULL  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`anchor_id`),
  KEY `idx_anchors_room_started`      (`room_id`, `started_at` DESC),
  KEY `idx_anchors_blueprint_state`   (`blueprint_id`, `state`),
  KEY `idx_anchors_state_updated`     (`state`, `updated_at` DESC),
  KEY `idx_anchors_completed_at`      (`completed_at`),
  KEY `idx_anchors_cooperation`       (`cooperation_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Persisted anchor state (snapshot for replay + analytics)';

-- --------------------------------------------------------------------
-- anchor_slots: per-slot placement history with idempotency keys
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `anchor_slots` (
  `slot_id`              VARCHAR(64)   NOT NULL  COMMENT 'UUID from event log',
  `anchor_id`            VARCHAR(36)   NOT NULL,
  `slot_index`           INT           NOT NULL,
  `slot_kind`            VARCHAR(32)   NOT NULL  COMMENT 'e.g. core, brace, cap, marker',
  `preferred_timeline`   ENUM('past','present','future','neutral')  NOT NULL DEFAULT 'neutral',
  `state`                ENUM('empty','filled','reserved')  NOT NULL DEFAULT 'empty',
  `placed_shard_id`      VARCHAR(64)   NULL     COMMENT 'Shard catalog id when filled',
  `filled_by_player_id`  VARCHAR(64)   NULL,
  `place_seq`            INT           NOT NULL  DEFAULT 0,
  `placed_at`            BIGINT        NULL     COMMENT 'Unix ms when placed',
  `removed_at`           BIGINT        NULL     COMMENT 'Unix ms when reverted',
  `idem_key`             VARCHAR(96)   NULL     COMMENT 'Client idempotency key (UNIQUE for filled state)',
  `created_at`           TIMESTAMP     NOT NULL  DEFAULT CURRENT_TIMESTAMP,
  `updated_at`           TIMESTAMP     NOT NULL  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`slot_id`),
  KEY `idx_anchor_slots_anchor_idx`   (`anchor_id`, `slot_index`),
  KEY `idx_anchor_slots_player`       (`filled_by_player_id`),
  KEY `idx_anchor_slots_state`        (`state`),
  UNIQUE KEY `uq_anchor_slots_idem_filled` (`idem_key`, `anchor_id`, `slot_index`),
  CONSTRAINT `fk_anchor_slots_anchor`
    FOREIGN KEY (`anchor_id`) REFERENCES `anchors` (`anchor_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Per-slot placement history with idempotency';

-- --------------------------------------------------------------------
-- anchor_audit: append-only audit trail of all anchor events
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `anchor_audit` (
  `audit_id`             BIGINT        NOT NULL  AUTO_INCREMENT,
  `anchor_id`            VARCHAR(36)   NOT NULL,
  `event_type`           VARCHAR(32)   NOT NULL  COMMENT 'create|place_shard|remove_shard|complete|abort',
  `actor_player_id`      VARCHAR(64)   NULL,
  `slot_index`           INT           NULL,
  `shard_id`             VARCHAR(64)   NULL,
  `event_id`             VARCHAR(96)   NULL     COMMENT 'Client-supplied idempotency key',
  `place_seq`            INT           NOT NULL  DEFAULT 0,
  `ok`                   TINYINT(1)    NOT NULL  DEFAULT 1,
  `reason`               VARCHAR(64)   NULL,
  `state_before_json`    JSON          NULL,
  `state_after_json`     JSON          NULL,
  `ts`                   BIGINT        NOT NULL  COMMENT 'Unix ms',
  `received_at`          TIMESTAMP(3)  NOT NULL  DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`audit_id`),
  KEY `idx_anchor_audit_anchor_ts`    (`anchor_id`, `ts` DESC),
  KEY `idx_anchor_audit_event_type`   (`event_type`),
  KEY `idx_anchor_audit_idem`         (`event_id`, `anchor_id`),
  KEY `idx_anchor_audit_actor`        (`actor_player_id`),
  UNIQUE KEY `uq_anchor_audit_idem`   (`event_id`, `anchor_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Append-only audit trail of all anchor events';

-- --------------------------------------------------------------------
-- shard_inventory: per-player shard holdings (per room + persistent)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `shard_inventory` (
  `inventory_id`         BIGINT        NOT NULL  AUTO_INCREMENT,
  `player_id`            VARCHAR(64)   NOT NULL,
  `room_id`              VARCHAR(64)   NULL     COMMENT 'NULL = persistent across rooms',
  `shard_id`             VARCHAR(64)   NOT NULL,
  `count`                INT           NOT NULL  DEFAULT 0,
  `conversion_count`     INT           NOT NULL  DEFAULT 0  COMMENT 'Cumulative dupes converted',
  `first_acquired_at`    TIMESTAMP     NOT NULL  DEFAULT CURRENT_TIMESTAMP,
  `updated_at`           TIMESTAMP     NOT NULL  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`inventory_id`),
  UNIQUE KEY `uq_shard_inventory_player_shard_room` (`player_id`, `shard_id`, `room_id`),
  KEY `idx_shard_inventory_player`    (`player_id`),
  KEY `idx_shard_inventory_shard`     (`shard_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Per-player shard holdings (per room or persistent)';

-- --------------------------------------------------------------------
-- player_anchor_stats: per-player aggregated anchor completion stats
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `player_anchor_stats` (
  `player_id`            VARCHAR(64)   NOT NULL,
  `total_started`        INT           NOT NULL  DEFAULT 0,
  `total_completed`      INT           NOT NULL  DEFAULT 0,
  `total_abandoned`      INT           NOT NULL  DEFAULT 0,
  `total_perfect`        INT           NOT NULL  DEFAULT 0  COMMENT 'perfect_testament outcomes',
  `total_score`          INT           NOT NULL  DEFAULT 0,
  `total_shards_placed`  INT           NOT NULL  DEFAULT 0,
  `longest_anchor_secs`  INT           NOT NULL  DEFAULT 0,
  `first_anchor_at`      TIMESTAMP     NULL,
  `last_anchor_at`       TIMESTAMP     NULL,
  `updated_at`           TIMESTAMP     NOT NULL  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Per-player aggregated anchor completion stats';

-- --------------------------------------------------------------------
-- Seed: initialize stats for existing players (idempotent)
-- --------------------------------------------------------------------
INSERT IGNORE INTO `player_anchor_stats` (`player_id`) SELECT `player_id` FROM `players`;

-- --------------------------------------------------------------------
-- View: anchor_overview (admin dashboard)
-- --------------------------------------------------------------------
CREATE OR REPLACE VIEW `v_anchor_overview` AS
SELECT
  a.anchor_id,
  a.room_id,
  a.blueprint_id,
  a.state,
  a.progress,
  a.cooperation_count,
  a.score_award,
  a.final_outcome,
  a.started_at,
  a.completed_at,
  a.updated_at,
  TIMESTAMPDIFF(SECOND, FROM_UNIXTIME(a.started_at / 1000), COALESCE(FROM_UNIXTIME(a.completed_at / 1000), NOW())) AS duration_secs,
  (SELECT COUNT(*) FROM anchor_slots WHERE anchor_id = a.anchor_id AND state = 'filled') AS slots_filled,
  (SELECT COUNT(*) FROM anchor_slots WHERE anchor_id = a.anchor_id) AS slots_total
FROM anchors a;

-- --------------------------------------------------------------------
-- View: player_leaderboard (top builders)
-- --------------------------------------------------------------------
CREATE OR REPLACE VIEW `v_player_leaderboard` AS
SELECT
  p.player_id,
  p.display_name,
  p.avatar_url,
  pas.total_completed,
  pas.total_perfect,
  pas.total_score,
  pas.total_shards_placed,
  pas.longest_anchor_secs,
  pas.last_anchor_at
FROM players p
LEFT JOIN player_anchor_stats pas ON p.player_id = pas.player_id
WHERE pas.total_completed > 0
ORDER BY pas.total_score DESC, pas.total_completed DESC;