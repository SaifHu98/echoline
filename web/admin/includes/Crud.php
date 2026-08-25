<?php
/**
 * CRUD helper — used by all entity pages (events, quests, shop, etc.)
 */
class Crud
{
    public static function handle(string $table, array $fields, string $redirect, ?callable $beforeSave = null): void
    {
        if (!Security::verifyCsrf(Security::input(CSRF_TOKEN_NAME))) {
            Response::error(I18n::t('error.csrf'), 403);
        }

        $action = Security::input('action');
        $id = Security::input('id', null, 'int');

        if ($action === 'delete' && $id) {
            $before = Database::fetch("SELECT * FROM {$table} WHERE id = ?", [$id]);
            Database::delete($table, 'id = ?', [$id]);
            if ($before && Auth::check()) {
                Audit::log(Auth::id(), "{$table}.delete", $table, (string) $id, $before);
            }
            Response::json(['success' => true, 'message' => I18n::t('success.deleted')]);
        }

        if ($action === 'toggle' && $id) {
            $field = Security::input('field');
            if (!in_array($field, ['is_active', 'is_featured'], true)) {
                Response::error('Invalid field');
            }
            $current = Database::fetch("SELECT {$field} FROM {$table} WHERE id = ?", [$id]);
            $newVal = $current[$field] ? 0 : 1;
            Database::update($table, [$field => $newVal], 'id = ?', [$id]);
            if (Auth::check()) {
                Audit::log(Auth::id(), "{$table}.toggle", $table, (string) $id, [$field => $newVal]);
            }
            Response::json(['success' => true, 'value' => $newVal]);
        }

        if ($action === 'save') {
            $data = [];
            foreach ($fields as $f) {
                $fieldName = $f['name'];
                $value = Security::input($fieldName);
                if ($value === null && !empty($f['required'])) {
                    Response::error("Missing field: {$fieldName}");
                }
                if (!empty($f['json']) && is_string($value)) {
                    $decoded = json_decode($value, true);
                    if ($decoded === null && $value !== 'null') {
                        Response::error("Invalid JSON for field: {$f['name']}");
                    }
                    $value = json_encode($decoded, JSON_UNESCAPED_UNICODE);
                }
                if (!empty($f['sanitize'])) {
                    $value = Security::sanitizeString((string) $value);
                }
                $data[$f['name']] = $value;
            }

            if ($beforeSave) $data = $beforeSave($data);

            if ($id) {
                Database::update($table, $data, 'id = ?', [$id]);
                if (Auth::check()) {
                    Audit::log(Auth::id(), "{$table}.update", $table, (string) $id, $data);
                }
            } else {
                $id = Database::insert($table, $data);
                if (Auth::check()) {
                    Audit::log(Auth::id(), "{$table}.create", $table, (string) $id, $data);
                }
            }
            Response::json(['success' => true, 'id' => $id, 'message' => I18n::t('success.saved')]);
        }
    }
}