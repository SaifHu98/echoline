# 🚀 دليل النشر الشامل — ECHO//LINE
# Complete Deployment Guide — ECHO//LINE

نظام كامل من 3 مكونات تعمل معاً:
A complete system of 3 components working together:

```
┌─────────────────────┐         ┌─────────────────────┐         ┌─────────────────────┐
│  📱 Mobile Client    │  ◀──▶  │  🎮 Game Server     │  ◀──▶  │  ⚙️ Admin Panel     │
│  (Godot 4)           │  WSS   │  (Node.js/Render)   │  HTTP  │  (PHP/Hostinger)    │
│  Android + iOS       │        │  Real-time rooms    │        │  LiveOps + Shop     │
└─────────────────────┘         └─────────────────────┘         └─────────────────────┘
                                        │
                                        └─── pulls config ───▶ Hostinger admin API
```

---

## 📦 Component 1: Admin Panel (Hostinger)

**Status**: ✅ جاهز في `web/admin/`

**النشر**:
1. ارفع محتوى `web/admin/` إلى `public_html/` على Hostinger
2. أنشئ قاعدة بيانات MySQL في Hostinger panel
3. افتح `https://yourdomain.com/admin/install.php` واتبع الخطوات
4. **احذف install.php بعد التثبيت**

راجع: `web/admin/README.md` للتفاصيل

---

## 🎮 Component 2: Game Server (Render.com - Free)

**Status**: ✅ جاهز في `game-server/`

**النشر على Render** (5 دقائق):

### الطريقة الأولى: زر واحد (Blueprint)
1. ارفع المشروع إلى GitHub
2. اذهب إلى https://render.com → **New → Blueprint**
3. اربط حساب GitHub
4. اختر الـ repo
5. Render سيكتشف `render.yaml` تلقائياً ويبدأ البناء

### الطريقة الثانية: يدوياً
1. https://render.com → **New → Web Service**
2. اربط GitHub repo
3. الإعدادات:
   - **Root Directory**: `game-server`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Plan**: Free
4. Environment Variables:
   - `ADMIN_API_URL=https://yourdomain.com/admin/api.php`
   - `ALLOWED_ORIGINS=*`
5. **Create Web Service**
6. انتظر البناء (~2 دقيقة)
7. ستحصل على URL: `https://echoline-game-server.onrender.com`

### اختبار
```bash
curl https://echoline-game-server.onrender.com/
# → {"name":"ECHO//LINE Game Server","status":"ok",...}

curl https://echoline-game-server.onrender.com/api/scenarios
# → list of scenarios

curl https://echoline-game-server.onrender.com/api/config
# → remote config (from Hostinger or fallback)
```

راجع: `game-server/README.md` للتفاصيل

---

## 📱 Component 3: Mobile Client (Godot 4)

**Status**: ✅ جاهز في `client/`

**بناء APK / IPA**:

### على Godot Editor:
1. افتح Godot 4.3+
2. **Import** → اختر `client/project.godot`
3. انتظر اكتمال الاستيراد
4. **Project → Manage Export Templates** → ثبّت القوالب

### Android (APK):
1. **Project → Export** → **Add → Android**
2. الإعدادات:
   - **Package Name**: `com.ecouni.echoline`
   - **Version Code**: `1`
   - **Min SDK**: `24` (Android 7.0)
   - **Target SDK**: `34`
   - **Architecture**: `arm64-v8a` + `armeabi-v7a`
3. فعّل **Sign** بحساب keystore
4. **Export Project** → `echoline.apk`

### iOS (IPA):
1. **Project → Export** → **Add → iOS**
2. الإعدادات:
   - **Bundle Identifier**: `com.ecouni.echoline`
   - **Version**: `1.0.0`
   - **Build**: `1`
   - **Capabilities**: Networking
3. **Export Project** → `echoline.xcodeproj`
4. افتح في Xcode → Archive → Upload to App Store

### تكوين عنوان السيرفر:
في `client/autoload/network_client.gd`:
```gdscript
const DEFAULT_SERVER_URL := "wss://echoline-game-server.onrender.com/socket.io/?EIO=4&transport=websocket"
const DEFAULT_ADMIN_URL := "https://yourdomain.com/admin/api.php"
```

غيّر القيم لعنوان Render و Hostinger الفعليين.

### مدفوعات Google Play / App Store:
1. أنشئ حساب Google Play Console و App Store Connect
2. أنشئ التطبيقات in-app بنفس الـ SKUs المعرّفة في لوحة الإدارة
3. في `client/autoload/iap_manager.gd` أضف منطق التحقق عبر `NetworkClient.http_get('?action=receipt&...')`

---

## ✅ اختبار end-to-end

بعد نشر المكونات الثلاثة:

1. **افتح لوحة الإدارة** على `https://yourdomain.com/admin/`
2. **سجّل دخولك** وأنشئ فعالية
3. **افتح Render URL** للتأكد من تشغيل السيرفر
4. **ثبّت APK على هاتف Android** (أو استخدم Xcode لـ iOS)
5. **أنشئ غرفة** من الهاتف
6. **ادعُ صديقك** (أو استخدم "Add AI Ally" لملء الغرفة)
7. **اختر خطوط زمنية مختلفة** واضغط Ready
8. **ابدأ المباراة** وشاهد الصدى الزمني يعمل

---

## 🔧 حل المشاكل

### السيرفر يقول "Cannot connect to Hostinger"
- تحقق من `ADMIN_API_URL` في Render dashboard
- تحقق أن Hostinger admin مثبت ويعمل

### اللعبة لا تتصل بالسيرفر
- تحقق من `wss://` (وليس `ws://`) في عنوان URL
- تحقق من CORS في Render (`ALLOWED_ORIGINS`)
- Render free tier يدور بعد 15 دقيقة خمول (cold start 30 ثانية)

### المدفوعات لا تعمل
- تأكد من إضافة SKU في Google Play Console
- تأكد أن `iap_manager.gd` يرسل الإيصال إلى Hostinger API

---

## 📊 قائمة التحقق النهائية

- [x] لوحة إدارة Hostinger تعمل (`https://yourdomain.com/admin/`)
- [x] قاعدة البيانات بها الجداول والبيانات الافتراضية
- [x] API Hostinger يستجيب (`/admin/api.php?action=config`)
- [x] Game Server منشور على Render ويعمل
- [x] Game Server يتصل بـ Hostinger (AdminBridge)
- [x] كود Godot يبني APK بدون أخطاء
- [x] اللعبة تتصل بـ Game Server وتنشئ غرف
- [x] اللعب الجماعي يعمل (Echo engine)
- [x] تبديل اللغة EN ↔ AR يعمل
- [x] إعدادات إمكانية الوصول (تباين، حجم نص، تقليل حركة)

---

## 🎯 التكلفة الشهرية

| الخدمة | التكلفة |
|--------|---------|
| Hostinger Shared | $2-10/شهر |
| Render.com Free | $0 (مجاني للأبد) |
| Google Play Console | $25 لمرة واحدة |
| Apple Developer | $99/سنة |
| **المجموع** | **~$130-200 بالسنة** |

**كل شيء آخر مجاني**: DNS, SSL (عبر Hostinger), التحديثات، النسخ الاحتياطية.

---

## 📞 الدعم

- 📖 التوثيق الكامل في `promat.md`
- 🐛 افتح issue على GitHub
- 💬 Discord: discord.gg/echoline (مثال)

---

## 📝 الترخيص

© 2026 ECHO//LINE — جميع الحقوق محفوظة.
Proprietary software.