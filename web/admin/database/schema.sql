-- ============================================================
-- ECHO//LINE — لوحة الإدارة (Admin Panel)
-- قاعدة البيانات — متوافقة مع Hostinger MySQL
-- ============================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";
SET NAMES utf8mb4;

-- -----------------------------------------------------
-- 1. المديرون (Administrators)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `admins` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(64) NOT NULL UNIQUE,
  `email` VARCHAR(128) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `role` ENUM('superadmin','editor','viewer','support') NOT NULL DEFAULT 'editor',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `last_login` DATETIME NULL,
  `last_ip` VARCHAR(45) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_role` (`role`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 2. الفعاليات والبطولات (LiveOps Events)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `events` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `event_uid` VARCHAR(64) NOT NULL UNIQUE,
  `title_key` VARCHAR(128) NOT NULL,
  `description_key` VARCHAR(128) NULL,
  `event_type` ENUM('tournament','seasonal_quest','chronal_expedition','limited_challenge','community_event') NOT NULL DEFAULT 'tournament',
  `scenario_id` VARCHAR(64) NOT NULL DEFAULT 'clocktower_district',
  `start_at` DATETIME NOT NULL,
  `end_at` DATETIME NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `is_featured` TINYINT(1) NOT NULL DEFAULT 0,
  `reward_currency` INT UNSIGNED NOT NULL DEFAULT 0,
  `reward_xp` INT UNSIGNED NOT NULL DEFAULT 0,
  `reward_cosmetic_id` VARCHAR(64) NULL,
  `config_json` JSON NULL,
  `banner_image` VARCHAR(255) NULL,
  `created_by` INT UNSIGNED NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_active_dates` (`is_active`, `start_at`, `end_at`),
  KEY `idx_scenario` (`scenario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 3. المهمات والتحديات (Quests / Missions)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `quests` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `quest_uid` VARCHAR(64) NOT NULL UNIQUE,
  `title_key` VARCHAR(128) NOT NULL,
  `description_key` VARCHAR(128) NULL,
  `quest_type` ENUM('daily','weekly','seasonal','story','challenge','tutorial') NOT NULL DEFAULT 'daily',
  `objective_type` ENUM('win_match','complete_scenario','trigger_echo','play_timeline','communicate','match_count','time_played','collect_item','reach_outcome') NOT NULL DEFAULT 'win_match',
  `objective_target` INT UNSIGNED NOT NULL DEFAULT 1,
  `objective_metadata` JSON NULL,
  `scenario_id` VARCHAR(64) NULL,
  `timeline_filter` VARCHAR(32) NULL,
  `reward_currency` INT UNSIGNED NOT NULL DEFAULT 0,
  `reward_xp` INT UNSIGNED NOT NULL DEFAULT 0,
  `reward_cosmetic_id` VARCHAR(64) NULL,
  `is_repeatable` TINYINT(1) NOT NULL DEFAULT 0,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `start_at` DATETIME NULL,
  `end_at` DATETIME NULL,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_active_type` (`is_active`, `quest_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 4. المتجر والمدفوعات (Shop & IAP Catalog)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `shop_items` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `sku` VARCHAR(96) NOT NULL UNIQUE,
  `google_play_sku` VARCHAR(128) NULL,
  `app_store_sku` VARCHAR(128) NULL,
  `name_key` VARCHAR(128) NOT NULL,
  `description_key` VARCHAR(128) NULL,
  `category` ENUM('currency','cosmetic','pass','bundle','expansion','consumable','boost') NOT NULL DEFAULT 'currency',
  `price_usd` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `currency_amount` INT UNSIGNED NULL,
  `bonus_percent` INT UNSIGNED NOT NULL DEFAULT 0,
  `cosmetic_id` VARCHAR(64) NULL,
  `inventory_json` JSON NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `is_featured` TINYINT(1) NOT NULL DEFAULT 0,
  `is_limited` TINYINT(1) NOT NULL DEFAULT 0,
  `max_purchases` INT UNSIGNED NULL,
  `sort_order` INT NOT NULL DEFAULT 0,
  `image_url` VARCHAR(255) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_active_featured` (`is_active`, `is_featured`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 5. سجل المبيعات (Sales Log)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `sales_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `transaction_id` VARCHAR(128) NOT NULL,
  `player_id` VARCHAR(64) NOT NULL,
  `sku` VARCHAR(96) NOT NULL,
  `platform` ENUM('android','ios','web','steam','other') NOT NULL DEFAULT 'android',
  `amount_usd` DECIMAL(10,2) NOT NULL,
  `currency_code` VARCHAR(8) NOT NULL DEFAULT 'USD',
  `status` ENUM('pending','verified','refunded','fraudulent','failed') NOT NULL DEFAULT 'pending',
  `verification_data` JSON NULL,
  `verified_at` DATETIME NULL,
  `ip_address` VARCHAR(45) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_transaction` (`transaction_id`, `platform`),
  KEY `idx_player` (`player_id`),
  KEY `idx_status_date` (`status`, `created_at`),
  KEY `idx_sku_date` (`sku`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 6. اللاعبين (Players Registry)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `players` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_uid` VARCHAR(64) NOT NULL UNIQUE,
  `display_name` VARCHAR(48) NOT NULL,
  `email` VARCHAR(128) NULL,
  `platform` ENUM('android','ios','web','steam') NOT NULL DEFAULT 'android',
  `platform_id` VARCHAR(255) NULL,
  `level` INT UNSIGNED NOT NULL DEFAULT 1,
  `xp` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `currency_soft` INT UNSIGNED NOT NULL DEFAULT 0,
  `currency_premium` INT UNSIGNED NOT NULL DEFAULT 0,
  `preferred_language` VARCHAR(8) NOT NULL DEFAULT 'en',
  `country_code` VARCHAR(8) NULL,
  `is_banned` TINYINT(1) NOT NULL DEFAULT 0,
  `is_muted` TINYINT(1) NOT NULL DEFAULT 0,
  `ban_reason` VARCHAR(255) NULL,
  `ban_expires_at` DATETIME NULL,
  `last_login_at` DATETIME NULL,
  `total_playtime_minutes` INT UNSIGNED NOT NULL DEFAULT 0,
  `matches_played` INT UNSIGNED NOT NULL DEFAULT 0,
  `matches_won` INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_display_name` (`display_name`),
  KEY `idx_banned` (`is_banned`),
  KEY `idx_platform` (`platform`),
  KEY `idx_level` (`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 7. سجل البلاغات (Reports & Moderation)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reports` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `reporter_uid` VARCHAR(64) NOT NULL,
  `target_uid` VARCHAR(64) NOT NULL,
  `match_id` VARCHAR(64) NULL,
  `reason` ENUM('cheating','harassment','inappropriate_name','griefing','spam','other') NOT NULL,
  `description` TEXT NULL,
  `status` ENUM('open','investigating','resolved','dismissed') NOT NULL DEFAULT 'open',
  `resolution_note` TEXT NULL,
  `handled_by` INT UNSIGNED NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`),
  KEY `idx_target` (`target_uid`),
  KEY `idx_reporter` (`reporter_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 8. سجل الإعدادات عن بُعد (Remote Config)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `remote_config` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key` VARCHAR(96) NOT NULL UNIQUE,
  `config_value` JSON NOT NULL,
  `description` VARCHAR(255) NULL,
  `category` VARCHAR(32) NOT NULL DEFAULT 'general',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `updated_by` INT UNSIGNED NULL,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_category_active` (`category`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 9. سجل النشاط الإداري (Admin Audit Log)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `audit_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id` INT UNSIGNED NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  `entity_type` VARCHAR(32) NULL,
  `entity_id` VARCHAR(64) NULL,
  `details` JSON NULL,
  `ip_address` VARCHAR(45) NULL,
  `user_agent` VARCHAR(255) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_admin_date` (`admin_id`, `created_at`),
  KEY `idx_entity` (`entity_type`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 10. الجلسات الإدارية (Admin Sessions)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_sessions` (
  `id` VARCHAR(128) NOT NULL,
  `admin_id` INT UNSIGNED NOT NULL,
  `ip_address` VARCHAR(45) NOT NULL,
  `user_agent` VARCHAR(255) NULL,
  `payload` TEXT NULL,
  `last_activity` INT UNSIGNED NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_admin` (`admin_id`),
  KEY `idx_last_activity` (`last_activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 11. سجل مطابقة الإيصالات (Receipt Validation)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `receipt_verifications` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `platform` ENUM('google_play','app_store','huawei','amazon','stripe') NOT NULL,
  `receipt_data` TEXT NOT NULL,
  `transaction_id` VARCHAR(128) NULL,
  `product_id` VARCHAR(128) NULL,
  `validation_result` ENUM('valid','invalid','duplicate','error','fraud') NOT NULL,
  `validation_message` VARCHAR(255) NULL,
  `raw_response` JSON NULL,
  `player_uid` VARCHAR(64) NULL,
  `ip_address` VARCHAR(45) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_result_date` (`validation_result`, `created_at`),
  KEY `idx_player` (`player_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 12. الإعلانات والإشعارات (Announcements)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `announcements` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(128) NOT NULL,
  `body` TEXT NOT NULL,
  `language` VARCHAR(8) NOT NULL DEFAULT 'en',
  `type` ENUM('info','warning','maintenance','event','reward') NOT NULL DEFAULT 'info',
  `target_platform` VARCHAR(32) NULL,
  `target_min_version` VARCHAR(32) NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `start_at` DATETIME NULL,
  `end_at` DATETIME NULL,
  `created_by` INT UNSIGNED NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_active_dates` (`is_active`, `start_at`, `end_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 14. أرشيف المبيعات (Sales Archive — when admin resets revenue)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `sales_archive` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `archive_uid` VARCHAR(64) NOT NULL,
  `archived_by` INT UNSIGNED NULL,
  `archived_reason` VARCHAR(255) NULL,
  `archive_period_start` DATETIME NULL,
  `archive_period_end` DATETIME NULL,
  `total_records` INT UNSIGNED NOT NULL DEFAULT 0,
  `total_amount_usd` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `total_verified` INT UNSIGNED NOT NULL DEFAULT 0,
  `total_pending` INT UNSIGNED NOT NULL DEFAULT 0,
  `total_refunded` INT UNSIGNED NOT NULL DEFAULT 0,
  `platforms_json` JSON NULL,
  `skus_json` JSON NULL,
  `players_json` JSON NULL,
  `data_json` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`archive_uid`),
  KEY `idx_date` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 15. أرشيف الفعاليات المنتهية (Events Archive)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `events_archive` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `archive_uid` VARCHAR(64) NOT NULL,
  `archived_by` INT UNSIGNED NULL,
  `original_event_uid` VARCHAR(64) NOT NULL,
  `title_key` VARCHAR(128) NOT NULL,
  `event_type` VARCHAR(32) NOT NULL,
  `scenario_id` VARCHAR(64) NULL,
  `starts_at` DATETIME NULL,
  `ends_at` DATETIME NULL,
  `total_plays` INT UNSIGNED NOT NULL DEFAULT 0,
  `data_json` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`archive_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- 13. سجل تحليلات اللعبة (Analytics Events)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `analytics_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_uid` VARCHAR(64) NULL,
  `event_name` VARCHAR(64) NOT NULL,
  `event_data` JSON NULL,
  `session_id` VARCHAR(64) NULL,
  `app_version` VARCHAR(32) NULL,
  `platform` VARCHAR(16) NULL,
  `country_code` VARCHAR(8) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_event_date` (`event_name`, `created_at`),
  KEY `idx_player` (`player_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- إدخال بيانات تجريبية (Seed Data)
-- -----------------------------------------------------
INSERT IGNORE INTO `admins` (`id`, `username`, `email`, `password_hash`, `role`) VALUES
(1, 'admin', 'admin@ecouni.com', '$2y$10$YourHashHereWillBeReplacedByInstallScript', 'superadmin');

INSERT IGNORE INTO `remote_config` (`config_key`, `config_value`, `description`, `category`) VALUES
('match.duration_seconds', '{"value": 600}', 'مدة المباراة بالثواني', 'gameplay'),
('match.min_players', '{"value": 2}', 'أقل عدد لاعبين', 'gameplay'),
('match.max_players', '{"value": 4}', 'أقصى عدد لاعبين', 'gameplay'),
('echo.propagation_speed', '{"value": 1.0}', 'سرعة انتشار الصدى', 'echo_system'),
('catastrophe.starting_stability', '{"value": 100}', 'الاستقرار الابتدائي', 'catastrophe'),
('shop.shards_bonus_active', '{"value": true, "multiplier": 1.5}', 'مكافأة الشظايا', 'shop'),
('maintenance.enabled', '{"value": false}', 'وضع الصيانة', 'system'),
('maintenance.message_key', '{"value": "maintenance.scheduled"}', 'رسالة الصيانة', 'system'),
('featured_event', '{"value": "tournament_season_1"}', 'الفعالية المميزة', 'liveops'),
('allowed_languages', '{"value": ["en", "ar"]}', 'اللغات المسموحة', 'localization');

INSERT IGNORE INTO `shop_items` (`sku`, `google_play_sku`, `name_key`, `description_key`, `category`, `price_usd`, `currency_amount`, `bonus_percent`, `is_featured`, `sort_order`) VALUES
('shards_500', 'com.ecouni.echoline.shards500', 'shop.shards500.name', 'shop.shards500.desc', 'currency', 4.99, 500, 0, 1, 10),
('shards_1200', 'com.ecouni.echoline.shards1200', 'shop.shards1200.name', 'shop.shards1200.desc', 'currency', 9.99, 1200, 20, 1, 20),
('shards_3000', 'com.ecouni.echoline.shards3000', 'shop.shards3000.name', 'shop.shards3000.desc', 'currency', 19.99, 3000, 35, 0, 30),
('season_pass_1', 'com.ecouni.echoline.season1pass', 'shop.season1pass.name', 'shop.season1pass.desc', 'pass', 7.99, 0, 0, 1, 40),
('starter_bundle', 'com.ecouni.echoline.starter', 'shop.starter.name', 'shop.starter.desc', 'bundle', 2.99, 800, 60, 0, 5),
('chronicle_pack', 'com.ecouni.echoline.chronicle', 'shop.chronicle.name', 'shop.chronicle.desc', 'bundle', 14.99, 0, 0, 0, 50);

INSERT IGNORE INTO `events` (`event_uid`, `title_key`, `description_key`, `event_type`, `scenario_id`, `start_at`, `end_at`, `is_active`, `is_featured`, `reward_currency`, `reward_xp`) VALUES
('tournament_season_1', 'liveops.season1.title', 'liveops.season1.desc', 'tournament', 'clocktower_district', '2026-08-01 00:00:00', '2026-09-30 23:59:59', 1, 1, 500, 1000),
('aqueduct_challenge', 'liveops.aqueduct.title', 'liveops.aqueduct.desc', 'chronal_expedition', 'sunken_aqueduct', '2026-08-15 00:00:00', '2026-09-15 23:59:59', 1, 0, 300, 500),
('daily_double', 'liveops.daily.title', 'liveops.daily.desc', 'seasonal_quest', 'clocktower_district', '2026-08-01 00:00:00', '2026-12-31 23:59:59', 1, 0, 50, 100);

INSERT IGNORE INTO `quests` (`quest_uid`, `title_key`, `description_key`, `quest_type`, `objective_type`, `objective_target`, `reward_currency`, `reward_xp`, `sort_order`) VALUES
('q_daily_match', 'quest.daily.match.title', 'quest.daily.match.desc', 'daily', 'match_count', 1, 25, 50, 10),
('q_daily_echo', 'quest.daily.echo.title', 'quest.daily.echo.desc', 'daily', 'trigger_echo', 3, 25, 50, 20),
('q_daily_communicate', 'quest.daily.communicate.title', 'quest.daily.communicate.desc', 'daily', 'communicate', 5, 15, 30, 30),
('q_weekly_perfect', 'quest.weekly.perfect.title', 'quest.weekly.perfect.desc', 'weekly', 'reach_outcome', 1, 100, 200, 10),
('q_weekly_timelines', 'quest.weekly.timelines.title', 'quest.weekly.timelines.desc', 'weekly', 'play_timeline', 3, 75, 150, 20),
('q_story_first_echo', 'quest.story.first.title', 'quest.story.first.desc', 'story', 'trigger_echo', 1, 50, 100, 10),
('q_story_rescue', 'quest.story.rescue.title', 'quest.story.rescue.desc', 'story', 'reach_outcome', 1, 200, 500, 20);

INSERT IGNORE INTO `announcements` (`title`, `body`, `language`, `type`, `is_active`) VALUES
('Welcome to ECHO//LINE', 'The temporal gate awaits. Begin your journey across timelines.', 'en', 'info', 1),
('مرحباً بك في أصداء', 'البوابة الزمنية بانتظارك. ابدأ رحلتك عبر الخطوط الزمنية.', 'ar', 'info', 1);