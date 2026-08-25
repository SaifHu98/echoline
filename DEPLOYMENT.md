# � ECHO//LINE — Deployment Guide

This guide covers:
- ✅ Uploading code to GitHub
- ✅ Deploying Game Server to Render
- ✅ Deploying Admin Panel to Hostinger
- ✅ Building Android APK

---

## 📋 Step 1: Push to GitHub (One-time setup)

You already have the repo: https://github.com/SaifHu98/echoline

### Open PowerShell on Windows:
```powershell
cd D:\EcoUni\Echos
git init
git config user.name "Your Name"
git config user.email "your-github@email.com"
git add .
git commit -m "ECHO//LINE v1.0.0 - initial release"
git branch -M main
git remote add origin https://github.com/SaifHu98/echoline.git
git push -u origin main --force
```

If asked for credentials:
- Username: `SaifHu98`
- Password: use **Personal Access Token** (NOT your GitHub password)
  - Get it: https://github.com/settings/tokens
  - Click "Generate new token (classic)"
  - Scopes: `repo`, `workflow`
  - Copy the token → paste as password

---

## 🎮 Step 2: Deploy Game Server to Render

### Option A: Manual Setup in Dashboard

1. Open https://dashboard.render.com
2. Click **"New +"** → **"Web Service"** (not Static Site!)
3. Click **"Connect GitHub"** → Authorize Render
4. Select repository: **`echoline`**
5. Configure:

| Field | Value |
|-------|-------|
| Name | `echoline-game-server` |
| Region | `Oregon (US West)` |
| Branch | `main` |
| **Root Directory** | **`game-server`** ⭐ critical |
| Runtime | `Node` |
| Build Command | `npm install` |
| Start Command | `npm start` |
| Plan | `Free` |

6. Click **"Advanced"** → add Environment Variables:

| Key | Value |
|-----|-------|
| `NODE_ENV` | `production` |
| `ADMIN_API_URL` | `https://echoline.eduiraq.net/admin/api.php` |
| `ALLOWED_ORIGINS` | `*` |
| `MAX_ROOMS` | `100` |
| `MAX_PLAYERS_PER_ROOM` | `4` |
| `MATCH_DURATION_SECONDS` | `600` |
| `DISCONNECT_GRACE_SECONDS` | `30` |
| `LOG_LEVEL` | `info` |
| `USE_REDIS` | `false` |

7. Click **"Create Web Service"**
8. Wait 2-3 minutes for first build
9. Your URL will be: **`https://echoline-game-server.onrender.com`**

### Option B: Blueprint (One-Click from render.yaml)

1. Render dashboard → **"New +"** → **"Blueprint"**
2. Connect `echoline` repo
3. Render reads `render.yaml` and creates the service automatically
4. Click **Apply**

---

## ✅ Step 3: Verify Game Server is Live

Open these URLs in your browser:

### Root (should return JSON):
```
https://echoline-game-server.onrender.com/
```

Expected response:
```json
{
  "name": "ECHO//LINE Game Server",
  "version": "1.0.0",
  "status": "ok",
  "rooms": 0,
  "players": 0,
  "admin_bridge": "https://echoline.eduiraq.net/admin/api.php",
  ...
}
```

### Scenarios:
```
https://echoline-game-server.onrender.com/api/scenarios
```

### Config (should pull from Hostinger):
```
https://echoline-game-server.onrender.com/api/config
```

If `api/config` returns the fallback (not your Hostinger data):
- Check `ADMIN_API_URL` is correct in Render env vars
- Check `https://echoline.eduiraq.net/admin/api.php?action=config` works
- Wait 60s for cache refresh

---

## 🌐 Step 4: Update Admin Panel on Hostinger

### A. Fix the Auth.php error first

The error `Class "Auth" not found` means some files used wrong path. **Upload the corrected files**:

1. Go to Hostinger File Manager → `public_html/echoline/`
2. **Replace** these files:
   - `dashboard.php`
   - `analytics.php`
   - `archive.php`
   - `archive_download.php`
   - `tools.php`

3. Verify all `require_once` use the correct path:
```php
require_once __DIR__ . '/config.php';  // ✅ correct
// NOT
require_once __DIR__ . '/../config.php';  // ❌ wrong (only header.php uses this)
```

### B. Verify admin panel works
1. Visit: `https://echoline.eduiraq.net/`
2. Should redirect to `login.php`
3. Login with your admin credentials
4. Dashboard should load

---

## 📱 Step 5: Update Godot Client with Render URL

Edit `client/autoload/network_client.gd`:
```gdscript
const DEFAULT_SERVER_URL := "wss://echoline-game-server.onrender.com/socket.io/?EIO=4&transport=websocket"
const DEFAULT_ADMIN_URL := "https://echoline.eduiraq.net/admin/api.php"
```

Replace `echoline-game-server.onrender.com` with **your actual Render URL** if different.

---

## � Step 6: Build Android APK

### Prerequisites:
1. Install **Godot 4.3+** from https://godotengine.org/download
2. Android SDK installed (Godot will guide you)

### Build:
1. Open Godot → **Import** → select `D:\EcoUni\Echos\client\project.godot`
2. Editor → **Manage Export Templates** → Download and Install
3. **Project → Export → Add → Android**
4. Fill:
   - Package Unique Name: `com.ecouni.echoline`
   - Name: `ECHO//LINE`
   - Version Code: `1`
   - Version Name: `1.0.0`
   - Screen Orientation: `sensor_landscape`
   - Architectures: `arm64-v8a` only
5. **Export Project** → save as `echoline.apk`

### Install on phone:
```powershell
adb install echoline.apk
```

Or transfer APK file to phone and install manually.

---

## � Troubleshooting

### "Class Auth not found"
**Cause**: Wrong path in `require_once`.
**Fix**: Make sure `dashboard.php` etc. use `/config.php`, not `/../config.php`.

### "Cannot connect to server" in game
**Cause**: Wrong Render URL or game server still deploying.
**Fix**: Wait 5 minutes after deploy, check Render logs.

### "Admin bridge returns fallback"
**Cause**: `ADMIN_API_URL` env var is wrong or Hostinger is down.
**Fix**: Verify env var in Render dashboard. Test `https://echoline.eduiraq.net/admin/api.php?action=config` in browser.

### Render free tier sleeps after 15min idle
**Cause**: Free tier sleeps inactive services.
**Fix**: First request after sleep takes 30-60 seconds. Or upgrade to paid plan.

---

## 📊 Deployment Status Checklist

- [ ] Code pushed to GitHub
- [ ] Render Web Service created (green checkmark)
- [ ] Render URL responds with JSON
- [ ] `/api/config` returns Hostinger data (not fallback)
- [ ] Admin panel loads without errors
- [ ] Admin login works
- [ ] Godot project opens in editor
- [ ] APK exports successfully
- [ ] APK installs on Android phone

---

## 🆘 Need Help?

1. Check Render logs: dashboard.render.com → your service → Logs
2. Check Hostinger logs: File Manager → `logs/error.log`
3. Test API endpoints manually with browser
4. Open browser DevTools (F12) → Console + Network tabs

---

**🎉 Once all checkboxes are green, your game is live on Android!**