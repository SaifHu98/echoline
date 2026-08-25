# دليل النشر على Hostinger — لوحة إدارة ECHO//LINE
# Hostinger Deployment Guide — ECHO//LINE Admin Panel

## 🎮 نظرة عامة (Overview)

لوحة إدارة احترافية لـ **ECHO//LINE** تعمل على **استضافة Hostinger المشتركة** (PHP + MySQL).
تدير: المبيعات، الفعاليات، المهمات، اللاعبين، الإعدادات عن بُعد، الترجمة، والخرائط.

The admin panel for **ECHO//LINE** that runs on **Hostinger shared hosting** (PHP + MySQL).
Manages: sales, events, quests, players, remote config, localization, and scenarios.

---

## 📋 المتطلبات (Requirements)

- حساب Hostinger مع باقة تدعم PHP 7.4+ و MySQL
- Hostinger account with PHP 7.4+ and MySQL support
- 50 MB مساحة على الأقل
- ~50 MB disk space

---

## 🚀 خطوات النشر (Deployment Steps)

### 1. رفع الملفات (Upload Files)

ارفع كل محتويات مجلد `web/admin/` إلى المجلد الرئيسي في Hostinger (عادة `public_html/`).
تأكد أن الملفات تحتفظ ببنيتها:

```
public_html/
├── .htaccess
├── config.php
├── install.php
├── login.php
├── dashboard.php
├── events.php
├── quests.php
├── shop.php
├── scenarios.php
├── echo_system.php
├── players.php
├── reports.php
├── receipts.php
├── config.php          (Remote Config)
├── announcements.php
├── localization.php
├── analytics.php
├── audit.php
├── admins.php
├── api.php
├── includes/
├── assets/
├── api/
└── database/
    └── schema.sql
```

Upload the entire `web/admin/` folder contents to Hostinger's root (typically `public_html/`).
Keep the directory structure intact.

### 2. إنشاء قاعدة البيانات (Create Database)

في لوحة Hostinger:
1. اذهب إلى **Databases → MySQL Databases**
2. أنشئ قاعدة بيانات جديدة، مثال: `u123456789_echoline`
3. أنشئ مستخدمًا بكلمة مرور قوية
4. اربط المستخدم بالقاعدة

In Hostinger panel:
1. Go to **Databases → MySQL Databases**
2. Create new database, e.g., `u123456789_echoline`
3. Create a user with a strong password
4. Assign the user to the database

### 3. تعديل إعدادات الاتصال (Configure Connection)

افتح ملف `config.php` وعدّل:

```php
define('DB_HOST', 'localhost');           // عادة localhost
define('DB_NAME', 'u123456789_echoline');  // اسم القاعدة الكامل
define('DB_USER', 'u123456789_admin');     // اسم المستخدم الكامل
define('DB_PASS', 'كلمة_المرور_القوية');
define('APP_ENV', 'production');
```

### 4. تشغيل المثبت (Run Installer)

افتح في المتصفح:
```
https://yourdomain.com/install.php
```

واتبع الخطوات:
1. ✓ تحقق من الاتصال بقاعدة البيانات
2. إنشاء الجداول
3. إنشاء حساب المدير الأول
4. إدخال بيانات تجريبية (اختياري)

⚠️ **مهم جداً**: بعد الانتهاء، **احذف ملف `install.php`** فوراً للأمان!

Open in browser and follow the steps:
1. ✓ Verify DB connection
2. Create tables
3. Create first admin account
4. Insert demo data (optional)

⚠️ **Critical**: After completion, **DELETE `install.php`** immediately for security!

### 5. الدخول إلى لوحة الإدارة (Login)

```
https://yourdomain.com/login.php
```

أو ببساطة:
```
https://yourdomain.com/
```

(الملف الافتراضي يُحوّل تلقائياً)

---

## 🔌 واجهة API للعبة (Game API)

اللعبة على الهاتف تتصل بـ `api.php` للحصول على البيانات:

```
GET  /api.php?action=config         → الإعدادات عن بُعد
GET  /api.php?action=shop           → كتالوج المتجر
GET  /api.php?action=events         → الفعاليات النشطة
GET  /api.php?action=quests         → المهمات
GET  /api.php?action=announcements  → الإعلانات
GET  /api.php?action=scenarios      → قائمة السيناريوهات
GET  /api.php?action=scenario&id=xxx → ملف سيناريو محدد
POST /api.php?action=analytics      → إرسال أحداث تحليلات
POST /api.php?action=receipt        → التحقق من إيصالات الشراء
POST /api.php?action=report         → بلاغ من لاعب
POST /api.php?action=login          → تسجيل دخول اللاعب (ضيف)
POST /api.php?action=heartbeat      → نبضة اتصال
GET  /api.php?action=i18n&lang=ar   → ملف الترجمة
```

### مثال من Godot (GDScript):

```gdscript
# Fetch remote config on app start
var http = HTTPRequest.new()
add_child(http)
http.request_completed.connect(func(result, code, headers, body):
    if code == 200:
        var json = JSON.parse_string(body.get_string_from_utf8())
        if json.success:
            var config = json.data.config
            var match_duration = config.match.duration_seconds.value
            var starting_stability = config.catastrophe.starting_stability.value
            # apply...
)
http.request("https://yourdomain.com/api.php?action=config")

# Verify a Google Play purchase
var payload = {
    "platform": "google_play",
    "receipt": receipt_data,
    "transaction_id": txn_id,
    "product_id": product_id,
    "player_uid": player_uid
}
http.request(
    "https://yourdomain.com/api.php?action=receipt",
    ["Content-Type: application/json"],
    HTTPClient.METHOD_POST,
    JSON.stringify(payload)
)
```

---

## 🛡️ الأمان (Security)

- ✅ كل كلمات المرور مشفرة بـ bcrypt
- ✅ حماية CSRF على جميع النماذج
- ✅ Rate limiting على API (120 طلب/دقيقة لكل IP)
- ✅ Headers أمنية (X-Frame-Options, CSP, etc.)
- ✅ Audit log كامل لكل إجراء إداري
- ✅ تشفير الجلسات و Cookies HttpOnly
- ✅ منع تصفح المجلدات (Options -Indexes)

تذكّر:
- غيّر كلمة مرور المدير الافتراضي فوراً
- استخدم HTTPS فقط (مفعّل تلقائياً في .htaccess)
- احذف install.php بعد التثبيت
- لا تشارك بيانات DB في أي مكان عام

---

## 📊 قاعدة البيانات (Database Schema)

13 جدول رئيسي:

| الجدول | الغرض |
|--------|-------|
| `admins` | المديرون وسجلات الدخول |
| `events` | الفعاليات والبطولات |
| `quests` | المهمات والتحديات |
| `shop_items` | كتالوج المتجر |
| `sales_log` | سجل المبيعات |
| `players` | اللاعبين وملفاتهم |
| `reports` | بلاغات اللاعبين |
| `remote_config` | إعدادات اللعبة عن بُعد |
| `audit_log` | سجل نشاط المديرين |
| `admin_sessions` | جلسات المديرين |
| `receipt_verifications` | سجل التحقق من الإيصالات |
| `announcements` | إعلانات اللعبة |
| `analytics_events` | أحداث تحليلات اللعبة |

---

## 🎯 المهام الرئيسية (Admin Workflow)

### إضافة فعالية جديدة (Create Event)
1. **الفعاليات** → **+ إنشاء فعالية**
2. املأ المعرّف، النوع، السيناريو، التواريخ
3. حدد "مميزة" لتظهر في الواجهة الرئيسية
4. حدد المكافآت (عملات، XP، تجميلي)

### إضافة منتج للمتجر (Add Shop Item)
1. **المتجر** → **+ إضافة منتج**
2. SKU فريد
3. سعر USD
4. ربط بـ Google Play SKU و App Store SKU
5. فعّل/عطّل، خصم، محدود الوقت

### إدارة اللاعبين (Player Management)
- ابحث بالاسم أو المعرّف
- حظر/رفع حظر مع السبب والمدة
- منح مكافآت يدوياً (عملات/XP)

### تعديل سيناريو (Edit Scenario)
1. **إدارة الخرائط** → اختر سيناريو
2. محرر JSON مباشر مع تحقق من الصحة
3. تنسيق وتحقق قبل الحفظ

### تعديل الترجمة (Localization)
1. **إدارة الترجمة** → اختر اللغة
2. عدّل القيم مباشرة
3. أضف مفاتيح جديدة بـ EN + AR معاً

---

## 🔧 استكشاف الأخطاء (Troubleshooting)

### "Database connection failed"
- تحقق من بيانات `config.php` (DB_HOST, DB_NAME, DB_USER, DB_PASS)
- تأكد أن المستخدم مرتبط بالقاعدة في Hostinger

### "403 Forbidden / 500 Internal Server Error"
- تحقق من صلاحيات الملفات (يجب 644 للملفات، 755 للمجلدات)
- تحقق من وجود ملف `.htaccess`

### "الصور/الخطوط لا تظهر"
- تأكد أن المجلدات تم رفعها بشكل كامل
- تأكد من صلاحيات القراءة

### "API لا يستجيب من تطبيق الجوال"
- تحقق من CORS: مفعّل افتراضياً `Access-Control-Allow-Origin: *`
- تأكد أن عنوان URL صحيح (https://)

---

## 📞 الدعم (Support)

- 📖 التوثيق الفني الكامل في `/docs/` و `promat.md`
- 🐛 الأخطاء: افتح issue على GitHub
- 💬 الدعم المباشر: support@ecouni.com

---

## 📝 الترخيص (License)

© 2026 ECHO//LINE — جميع الحقوق محفوظة.
© 2026 ECHO//LINE — All rights reserved.

Proprietary software. Unauthorized redistribution prohibited.