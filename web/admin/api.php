<?php
/**
 * ECHO//LINE — Public Game API
 * ------------------------------
 * Used by the mobile Godot client (and the in-browser web version)
 * All endpoints return JSON. Rate-limited per IP.
 *
 * Endpoints:
 *   GET  /api.php?action=config           — Remote config (gameplay tunables)
 *   GET  /api.php?action=shop             — Shop catalog
 *   GET  /api.php?action=events           — Active events/tournaments
 *   GET  /api.php?action=quests           — Active quests
 *   GET  /api.php?action=announcements    — Active announcements
 *   GET  /api.php?action=scenarios        — Available scenarios list
 *   GET  /api.php?action=scenario&id=xxx  — Scenario JSON
 *   POST /api.php?action=analytics        — Send analytics event
 *   POST /api.php?action=receipt          — Validate IAP receipt
 *   POST /api.php?action=report           — Submit player report
 *   POST /api.php?action=login            — Register/login player (guest)
 *   POST /api.php?action=heartbeat        — Player heartbeat
 */

require_once __DIR__ . '/config.php';
Response::setCors(['*']);

$rateKey = $_SERVER['REQUEST_URI'] ?? '/';
if (!Security::rateLimit('api_' . md5($rateKey), 120, 60)) {
    Response::error('Rate limit exceeded', 429);
}

$action = Security::input('action', '', 'string');

try {
    switch ($action) {
        case 'config': api_config(); break;
        case 'shop': api_shop(); break;
        case 'events': api_events(); break;
        case 'quests': api_quests(); break;
        case 'announcements': api_announcements(); break;
        case 'scenarios': api_scenarios_list(); break;
        case 'scenario': api_scenario(); break;
        case 'analytics': api_analytics(); break;
        case 'receipt': api_receipt(); break;
        case 'report': api_report(); break;
        case 'login': api_login(); break;
        case 'heartbeat': api_heartbeat(); break;
        case 'i18n': api_i18n(); break;
        default: Response::error('Unknown action', 400, ['available' => ['config','shop','events','quests','announcements','scenarios','scenario','analytics','receipt','report','login','heartbeat','i18n']]);
    }
} catch (\Throwable $e) {
    error_log('[API] ' . $action . ': ' . $e->getMessage());
    if (APP_ENV === 'development') {
        Response::error('Internal error: ' . $e->getMessage(), 500);
    } else {
        Response::error('Internal error', 500);
    }
}

// =============================================================
// Handlers
// =============================================================

function api_config(): void {
    $rows = Database::fetchAll('SELECT config_key, config_value, category, description FROM remote_config WHERE is_active = 1');
    $config = [];
    foreach ($rows as $r) {
        $config[$r['config_key']] = [
            'value' => json_decode($r['config_value'], true),
            'category' => $r['category'],
            'description' => $r['description'],
        ];
    }
    Response::success([
        'version' => APP_VERSION,
        'environment' => APP_ENV,
        'maintenance_mode' => FEATURE_MAINTENANCE_MODE,
        'shop_enabled' => FEATURE_SHOP_ENABLED,
        'liveops_enabled' => FEATURE_LIVEOPS_ENABLED,
        'config' => $config,
    ]);
}

function api_shop(): void {
    $platform = Security::input('platform', 'android', 'string');
    $platformField = $platform === 'ios' ? 'app_store_sku' : 'google_play_sku';

    $items = Database::fetchAll(
        "SELECT id, sku, {$platformField} AS platform_sku, name_key, description_key,
                category, price_usd, currency_amount, bonus_percent, cosmetic_id,
                inventory_json, is_featured, is_limited, max_purchases, sort_order, image_url
         FROM shop_items WHERE is_active = 1 ORDER BY sort_order ASC"
    );

    $formatted = array_map(function($i) {
        $inv = $i['inventory_json'] ? json_decode($i['inventory_json'], true) : null;
        return [
            'sku' => $i['sku'],
            'platform_sku' => $i['platform_sku'],
            'name_key' => $i['name_key'],
            'description_key' => $i['description_key'],
            'category' => $i['category'],
            'price_usd' => (float) $i['price_usd'],
            'currency_amount' => $i['currency_amount'] ? (int) $i['currency_amount'] : null,
            'bonus_percent' => (int) $i['bonus_percent'],
            'cosmetic_id' => $i['cosmetic_id'],
            'inventory' => $inv,
            'is_featured' => (bool) $i['is_featured'],
            'is_limited' => (bool) $i['is_limited'],
            'max_purchases' => $i['max_purchases'] ? (int) $i['max_purchases'] : null,
            'sort_order' => (int) $i['sort_order'],
            'image_url' => $i['image_url'],
        ];
    }, $items);

    Response::success(['items' => $formatted, 'count' => count($formatted)]);
}

function api_events(): void {
    $events = Database::fetchAll(
        'SELECT event_uid, title_key, description_key, event_type, scenario_id,
                start_at, end_at, is_featured, reward_currency, reward_xp,
                reward_cosmetic_id, config_json, banner_image
         FROM events
         WHERE is_active = 1 AND end_at >= NOW()
         ORDER BY is_featured DESC, start_at ASC'
    );

    $formatted = array_map(function($e) {
        $cfg = $e['config_json'] ? json_decode($e['config_json'], true) : null;
        return [
            'event_uid' => $e['event_uid'],
            'title_key' => $e['title_key'],
            'description_key' => $e['description_key'],
            'event_type' => $e['event_type'],
            'scenario_id' => $e['scenario_id'],
            'starts_at' => $e['start_at'],
            'ends_at' => $e['end_at'],
            'is_featured' => (bool) $e['is_featured'],
            'rewards' => [
                'currency' => (int) $e['reward_currency'],
                'xp' => (int) $e['reward_xp'],
                'cosmetic_id' => $e['reward_cosmetic_id'],
            ],
            'config' => $cfg,
            'banner_image' => $e['banner_image'],
            'seconds_remaining' => max(0, strtotime($e['end_at']) - time()),
        ];
    }, $events);

    Response::success(['events' => $formatted, 'count' => count($formatted)]);
}

function api_quests(): void {
    $now = date('Y-m-d H:i:s');
    $quests = Database::fetchAll(
        "SELECT quest_uid, title_key, description_key, quest_type, objective_type,
                objective_target, objective_metadata, scenario_id, timeline_filter,
                reward_currency, reward_xp, reward_cosmetic_id, is_repeatable,
                start_at, end_at, sort_order
         FROM quests
         WHERE is_active = 1
           AND (start_at IS NULL OR start_at <= ?)
           AND (end_at IS NULL OR end_at >= ?)
         ORDER BY quest_type, sort_order",
        [$now, $now]
    );

    $formatted = array_map(function($q) {
        $meta = $q['objective_metadata'] ? json_decode($q['objective_metadata'], true) : null;
        return [
            'quest_uid' => $q['quest_uid'],
            'title_key' => $q['title_key'],
            'description_key' => $q['description_key'],
            'quest_type' => $q['quest_type'],
            'objective' => [
                'type' => $q['objective_type'],
                'target' => (int) $q['objective_target'],
                'metadata' => $meta,
            ],
            'scenario_id' => $q['scenario_id'],
            'timeline_filter' => $q['timeline_filter'],
            'rewards' => [
                'currency' => (int) $q['reward_currency'],
                'xp' => (int) $q['reward_xp'],
                'cosmetic_id' => $q['reward_cosmetic_id'],
            ],
            'is_repeatable' => (bool) $q['is_repeatable'],
            'expires_at' => $q['end_at'],
        ];
    }, $quests);

    Response::success(['quests' => $formatted, 'count' => count($formatted)]);
}

function api_announcements(): void {
    $lang = Security::input('lang', '', 'string');
    $platform = Security::input('platform', '', 'string');

    $where = 'is_active = 1 AND (start_at IS NULL OR start_at <= NOW()) AND (end_at IS NULL OR end_at >= NOW())';
    $params = [];
    if ($lang) { $where .= ' AND (language = ? OR language = "both")'; $params[] = $lang; }
    if ($platform) { $where .= ' AND (target_platform IS NULL OR target_platform = ?)'; $params[] = $platform; }

    $rows = Database::fetchAll("SELECT title, body, language, type FROM announcements WHERE {$where} ORDER BY created_at DESC LIMIT 5", $params);
    Response::success(['announcements' => $rows]);
}

function api_scenarios_list(): void {
    $dir = __DIR__ . '/data/scenarios';
    $list = [];
    foreach (glob($dir . '/*.json') as $file) {
        $data = json_decode(file_get_contents($file), true);
        if (!$data) continue;
        $list[] = [
            'id' => basename($file, '.json'),
            'name_key' => $data['name_key'] ?? '',
            'description_key' => $data['description_key'] ?? '',
            'supported_timelines' => $data['supported_timelines'] ?? [],
            'duration_seconds' => $data['catastrophe']['duration_seconds'] ?? 600,
        ];
    }
    Response::success(['scenarios' => $list, 'count' => count($list)]);
}

function api_scenario(): void {
    $id = Security::input('id', '', 'string');
    if (!$id || !preg_match('/^[a-z0-9_]+$/', $id)) {
        Response::error('Invalid scenario id');
    }
    $file = __DIR__ . '/data/scenarios/' . $id . '.json';
    if (!file_exists($file)) {
        Response::error('Scenario not found', 404);
    }
    $data = json_decode(file_get_contents($file), true);
    Response::success(['scenario' => $data]);
}

function api_analytics(): void {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::error('POST required');
    }
    $body = Security::jsonInput();
    $event = $body['event'] ?? '';
    if (!$event) Response::error('Missing event');

    $playerUid = substr($body['player_uid'] ?? '', 0, 64);
    $sessionId = substr($body['session_id'] ?? '', 0, 64);
    $data = isset($body['data']) ? json_encode($body['data'], JSON_UNESCAPED_UNICODE) : null;

    Database::insert('analytics_events', [
        'player_uid' => $playerUid ?: null,
        'event_name' => substr($event, 0, 64),
        'event_data' => $data,
        'session_id' => $sessionId ?: null,
        'app_version' => substr($body['app_version'] ?? '', 0, 32) ?: null,
        'platform' => substr($body['platform'] ?? '', 0, 16) ?: null,
        'country_code' => substr($body['country'] ?? '', 0, 8) ?: null,
    ]);

    Response::success(['recorded' => true]);
}

function api_receipt(): void {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('POST required');

    $body = Security::jsonInput();
    $platform = $body['platform'] ?? 'google_play';
    $receiptData = $body['receipt'] ?? '';
    $transactionId = substr($body['transaction_id'] ?? '', 0, 128);
    $productId = substr($body['product_id'] ?? '', 0, 128);
    $playerUid = substr($body['player_uid'] ?? '', 0, 64);

    if (!$receiptData) Response::error('Missing receipt');

    // Basic dedup
    $existing = Database::fetch(
        'SELECT id, validation_result FROM receipt_verifications WHERE transaction_id = ? AND platform = ? LIMIT 1',
        [$transactionId, $platform]
    );
    if ($existing && $existing['validation_result'] === 'valid') {
        Response::success(['result' => 'duplicate', 'message' => 'Already processed']);
    }

    // Find product in shop
    $item = Database::fetch(
        'SELECT * FROM shop_items WHERE google_play_sku = ? OR app_store_sku = ? OR sku = ? LIMIT 1',
        [$productId, $productId, $productId]
    );

    $result = 'error';
    $message = 'Not implemented for this platform in sandbox mode';

    // For demo: trust the receipt if item found. In production, validate with vendor.
    if ($item && $transactionId) {
        try {
            Database::insert('sales_log', [
                'transaction_id' => $transactionId,
                'player_id' => $playerUid,
                'sku' => $item['sku'],
                'platform' => $platform === 'google_play' ? 'android' : 'ios',
                'amount_usd' => $item['price_usd'],
                'currency_code' => 'USD',
                'status' => 'verified',
                'verified_at' => date('Y-m-d H:i:s'),
            ]);
            $result = 'valid';
            $message = 'Receipt verified (sandbox)';
        } catch (Exception $e) {
            $result = 'duplicate';
            $message = 'Already processed';
        }
    }

    Database::insert('receipt_verifications', [
        'platform' => $platform,
        'receipt_data' => substr($receiptData, 0, 1000),
        'transaction_id' => $transactionId,
        'product_id' => $productId,
        'validation_result' => $result,
        'validation_message' => $message,
        'raw_response' => json_encode($body, JSON_UNESCAPED_UNICODE),
        'player_uid' => $playerUid,
        'ip_address' => Security::clientIp(),
    ]);

    Response::success([
        'result' => $result,
        'message' => $message,
        'reward' => $item ? [
            'sku' => $item['sku'],
            'currency_amount' => (int) ($item['currency_amount'] ?? 0),
            'bonus_percent' => (int) $item['bonus_percent'],
            'cosmetic_id' => $item['cosmetic_id'],
            'inventory' => $item['inventory_json'] ? json_decode($item['inventory_json'], true) : null,
        ] : null,
    ]);
}

function api_report(): void {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('POST required');

    $body = Security::jsonInput();
    $reporter = substr($body['reporter_uid'] ?? '', 0, 64);
    $target = substr($body['target_uid'] ?? '', 0, 64);
    $reason = $body['reason'] ?? 'other';
    $matchId = substr($body['match_id'] ?? '', 0, 64) ?: null;
    $desc = substr($body['description'] ?? '', 0, 1000);

    if (!$reporter || !$target) Response::error('Missing reporter or target');
    if (!in_array($reason, ['cheating','harassment','inappropriate_name','griefing','spam','other'], true)) {
        $reason = 'other';
    }

    Database::insert('reports', [
        'reporter_uid' => $reporter,
        'target_uid' => $target,
        'match_id' => $matchId,
        'reason' => $reason,
        'description' => $desc,
    ]);

    Response::success(['submitted' => true]);
}

function api_login(): void {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('POST required');

    $body = Security::jsonInput();
    $displayName = Security::sanitizeString(substr($body['display_name'] ?? 'Guest', 0, 32));
    $platform = $body['platform'] ?? 'android';
    $platformId = substr($body['platform_id'] ?? '', 0, 255) ?: null;
    $countryCode = substr($body['country'] ?? '', 0, 8) ?: null;
    $lang = substr($body['language'] ?? 'en', 0, 8);

    if (!in_array($platform, ['android', 'ios', 'web', 'steam'], true)) {
        $platform = 'android';
    }

    // Find or create player
    $player = null;
    if ($platformId) {
        $player = Database::fetch(
            'SELECT * FROM players WHERE platform_id = ? AND platform = ? LIMIT 1',
            [$platformId, $platform]
        );
    }

    if ($player) {
        Database::update('players', [
            'display_name' => $displayName,
            'last_login_at' => date('Y-m-d H:i:s'),
            'preferred_language' => $lang,
        ], 'player_uid = ?', [$player['player_uid']]);
    } else {
        $uid = 'p_' . bin2hex(random_bytes(8));
        try {
            Database::insert('players', [
                'player_uid' => $uid,
                'display_name' => $displayName,
                'platform' => $platform,
                'platform_id' => $platformId,
                'preferred_language' => $lang,
                'country_code' => $countryCode,
                'last_login_at' => date('Y-m-d H:i:s'),
            ]);
            $player = Database::fetch('SELECT * FROM players WHERE player_uid = ?', [$uid]);
        } catch (\Throwable $e) {
            Response::error('Failed to create player');
        }
    }

    Response::success([
        'player' => [
            'uid' => $player['player_uid'],
            'display_name' => $player['display_name'],
            'level' => (int) $player['level'],
            'xp' => (int) $player['xp'],
            'currency_premium' => (int) $player['currency_premium'],
            'currency_soft' => (int) $player['currency_soft'],
            'is_banned' => (bool) $player['is_banned'],
        ],
    ]);
}

function api_heartbeat(): void {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('POST required');
    $body = Security::jsonInput();
    $uid = substr($body['player_uid'] ?? '', 0, 64);
    if (!$uid) Response::error('Missing uid');
    Database::update('players', [
        'last_login_at' => date('Y-m-d H:i:s'),
    ], 'player_uid = ?', [$uid]);
    Response::success(['recorded' => true]);
}

function api_i18n(): void {
    $lang = Security::input('lang', 'en', 'string');
    if (!preg_match('/^[a-z-]+$/', $lang)) Response::error('Invalid lang');

    $dir = __DIR__ . '/data/i18n';
    $file = $dir . '/' . $lang . '.json';
    if (!file_exists($file)) {
        $file = $dir . '/en.json'; // fallback
    }
    if (!file_exists($file)) {
        Response::success(['catalog' => (object) []]);
    }
    $catalog = json_decode(file_get_contents($file), true) ?: [];
    Response::success(['catalog' => $catalog, 'locale' => $lang, 'count' => count($catalog)]);
}