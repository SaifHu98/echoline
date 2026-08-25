<?php
require_once __DIR__ . '/config.php';
Auth::require();

$uid = Security::input('uid', '', 'string');
if (!$uid || !preg_match('/^[a-z0-9_]+$/i', $uid)) {
    Response::error('Invalid archive UID');
}

$archive = Database::fetch('SELECT * FROM sales_archive WHERE archive_uid = ?', [$uid]);
if (!$archive) {
    Response::error('Archive not found', 404);
}

// Log the download
Audit::log(Auth::id(), 'archive.download', 'sales_archive', $uid);

// Send as JSON download
$filename = 'echoline_sales_' . $uid . '.json';
header('Content-Type: application/json; charset=utf-8');
header('Content-Disposition: attachment; filename="' . $filename . '"');
header('Cache-Control: no-cache, must-revalidate');

// Include the full archive data
$archive['data'] = $archive['data_json'] ? json_decode($archive['data_json'], true) : null;
unset($archive['data_json']); // raw string not needed
$archive['downloaded_by'] = Auth::user()['username'] ?? 'unknown';
$archive['downloaded_at'] = date('Y-m-d H:i:s');

echo json_encode($archive, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
exit;