<?php
/**
 * Audit logging
 */
class Audit
{
    public static function log(int $adminId, string $action, ?string $entityType = null, ?string $entityId = null, ?array $details = null): void
    {
        try {
            Database::insert('audit_log', [
                'admin_id' => $adminId,
                'action' => $action,
                'entity_type' => $entityType,
                'entity_id' => $entityId,
                'details' => $details ? json_encode($details, JSON_UNESCAPED_UNICODE) : null,
                'ip_address' => Security::clientIp(),
                'user_agent' => isset($_SERVER['HTTP_USER_AGENT']) ? Security::truncateForLog($_SERVER['HTTP_USER_AGENT'], 250) : null,
            ]);
        } catch (\Throwable $e) {
            error_log('[Audit] Failed: ' . $e->getMessage());
        }
    }

    public static function getRecent(int $limit = 50): array
    {
        return Database::fetchAll(
            'SELECT a.*, ad.username FROM audit_log a
             LEFT JOIN admins ad ON ad.id = a.admin_id
             ORDER BY a.created_at DESC LIMIT ?',
            [$limit]
        );
    }

    public static function getByAdmin(int $adminId, int $limit = 100): array
    {
        return Database::fetchAll(
            'SELECT * FROM audit_log WHERE admin_id = ? ORDER BY created_at DESC LIMIT ?',
            [$adminId, $limit]
        );
    }
}