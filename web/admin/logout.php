<?php
require_once __DIR__ . '/config.php';
Auth::require();
Auth::logout();
Response::redirect('login.php');