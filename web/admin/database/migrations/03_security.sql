-- ====================================================================
-- Security Hardening Migration (v0.2.0)
-- Adds: indexes, unique constraints, audit table, session table
-- Idempotent: safe to run multiple times
-- ====================================================================

-- ====================================================================
-- 1. admin_audit_log (new table)
-- ====================================================================
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  occurred_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  action VARCHAR(64) NOT NULL,
  context_json JSON NULL,
  admin_uid VARCHAR(64) NULL,
  session_id VARCHAR(64) NULL,
  ip_hash CHAR(16) NOT NULL,
  user_agent_hash CHAR(16) NOT NULL,
  INDEX idx_audit_occurred (occurred_at),
  INDEX idx_audit_action (action),
  INDEX idx_audit_admin (admin_uid),
  INDEX idx_audit_ip (ip_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- 2. receipt_verifications (new table)
-- ====================================================================
CREATE TABLE IF NOT EXISTS receipt_verifications (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  verified_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  purchase_token VARCHAR(512) NOT NULL,
  product_id VARCHAR(128) NOT NULL,
  player_uid VARCHAR(64) NOT NULL,
  order_id VARCHAR(64) NULL,
  purchase_state TINYINT NOT NULL DEFAULT 0,
  refund_state TINYINT NOT NULL DEFAULT 0,
  INDEX idx_receipt_player (player_uid, verified_at),
  INDEX idx_receipt_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- UNIQUE constraint to prevent replay (HASH of token since raw token is long)
ALTER TABLE receipt_verifications
  ADD COLUMN IF NOT EXISTS purchase_token_hash CHAR(64) GENERATED ALWAYS AS (SHA2(purchase_token, 256)) STORED,
  ADD UNIQUE KEY IF NOT EXISTS uniq_receipt_token (purchase_token_hash, product_id);

-- ====================================================================
-- 3. player_currency (new table) — atomic grant tracking
-- ====================================================================
CREATE TABLE IF NOT EXISTS player_currency (
  player_uid VARCHAR(64) PRIMARY KEY,
  gem INT UNSIGNED NOT NULL DEFAULT 0,
  coin INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- 4. player_inventory (new table)
-- ====================================================================
CREATE TABLE IF NOT EXISTS player_inventory (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  player_uid VARCHAR(64) NOT NULL,
  item_id VARCHAR(64) NOT NULL,
  quantity INT UNSIGNED NOT NULL DEFAULT 1,
  source VARCHAR(32) NOT NULL DEFAULT 'manual',
  source_id BIGINT UNSIGNED NULL,
  acquired_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uniq_inv_player_item (player_uid, item_id, source, source_id),
  INDEX idx_inv_player (player_uid, acquired_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- 5. Harden admins table (constraints + index for username)
-- ====================================================================
ALTER TABLE admins
  MODIFY COLUMN username VARCHAR(64) NOT NULL,
  ADD UNIQUE KEY IF NOT EXISTS uniq_admins_username (username);

-- Add 2FA columns if not exist
ALTER TABLE admins
  ADD COLUMN IF NOT EXISTS two_factor_secret VARCHAR(64) NULL,
  ADD COLUMN IF NOT EXISTS two_factor_enabled TINYINT(1) NOT NULL DEFAULT 0;

-- ====================================================================
-- 6. Idempotency keys (Game Server) — prevent replay
-- ====================================================================
CREATE TABLE IF NOT EXISTS idempotency_keys (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  player_uid VARCHAR(64) NOT NULL,
  idempotency_key VARCHAR(128) NOT NULL,
  result_json JSON NULL,
  expires_at DATETIME(3) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uniq_idem (player_uid, idempotency_key),
  INDEX idx_idem_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- 7. Sessions sessions (Admin) — server-side session table
-- ====================================================================
CREATE TABLE IF NOT EXISTS admin_sessions (
  id VARCHAR(64) PRIMARY KEY,
  admin_uid VARCHAR(64) NOT NULL,
  ip_hash CHAR(16) NOT NULL,
  user_agent_hash CHAR(16) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_seen_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  expires_at DATETIME(3) NOT NULL,
  INDEX idx_session_admin (admin_uid),
  INDEX idx_session_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- 8. CSRF tokens (server-side validation, single-use rotation)
-- ====================================================================
CREATE TABLE IF NOT EXISTS csrf_tokens (
  token_hash CHAR(64) PRIMARY KEY,
  admin_uid VARCHAR(64) NULL,
  action VARCHAR(64) NOT NULL DEFAULT 'default',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at DATETIME(3) NOT NULL,
  consumed TINYINT(1) NOT NULL DEFAULT 0,
  INDEX idx_csrf_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- 9. Hardening indexes on existing tables
-- ====================================================================

-- sales_log: query by player + time
ALTER TABLE sales_log
  ADD INDEX IF NOT EXISTS idx_sales_player_time (player_uid, occurred_at),
  ADD INDEX IF NOT EXISTS idx_sales_occurred (occurred_at);

-- players: query by status / last_seen
ALTER TABLE players
  ADD INDEX IF NOT EXISTS idx_players_status (status),
  ADD INDEX IF NOT EXISTS idx_players_last_seen (last_seen_at);

-- audit_log (old): keep name, add indexes
ALTER TABLE audit_log
  ADD INDEX IF NOT EXISTS idx_audit_old_time (occurred_at);

-- events: query by active state
ALTER TABLE events
  ADD INDEX IF NOT EXISTS idx_events_active (is_active, start_at, end_at);

-- announcements: by language + active
ALTER TABLE announcements
  ADD INDEX IF NOT EXISTS idx_ann_lang_active (language, is_active);

-- shop_items: active catalog
ALTER TABLE shop_items
  ADD INDEX IF NOT EXISTS idx_shop_active (is_active, category);

-- quests: active
ALTER TABLE quests
  ADD INDEX IF NOT EXISTS idx_quests_active (is_active);

-- ====================================================================
-- 10. STRICT SQL mode enforced in app, but add DB-level constraints
-- ====================================================================
-- No DROP/ALTER/GRANT for app user (set in GRANT statement):
-- GRANT SELECT, INSERT, UPDATE, DELETE ON echoline_db.* TO 'echoline_app'@'%';

-- ====================================================================
-- 11. Server config — strict mode (recommendation in connection string)
-- ====================================================================
-- Already set in Database.php, but also enforced at DB:
-- SET GLOBAL sql_mode = 'STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION,NO_AUTO_CREATE_USER';
-- (run once as DB admin, not by app)

-- ====================================================================
-- 12. Cleanup: rotate audit log old entries (>7 years)
-- Recommend: scheduled event (cron or DB event)
-- ====================================================================

-- ====================================================================
-- End of migration 03_security
-- ====================================================================