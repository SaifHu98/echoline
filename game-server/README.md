# ECHO//LINE — Game Server Deployment Guide (Render.com Free Tier)

## 🎯 Overview

The game server is a **Node.js + Socket.IO** application that:
- Hosts real-time multiplayer matches (3 timelines per match)
- Runs the authoritative **Echo Engine** (causal rule engine)
- Syncs state across all players in a room
- Pulls **live config / events / quests / shop** from your Hostinger admin panel

Deploys on **Render.com free tier** (no cost, no credit card required for the free plan).

---

## 📋 Prerequisites

- A GitHub account (free)
- A Render.com account (free — sign up at https://render.com)
- Your ECHO//LINE repository pushed to GitHub
- A running Hostinger admin panel (so the bridge can fetch live data)

---

## 🚀 Deployment Steps

### Option A: One-Click Blueprint (Recommended)

1. Push this repo to GitHub
2. Go to https://render.com → **New → Blueprint**
3. Connect your GitHub repo
4. Render auto-detects `render.yaml` and creates the service
5. Wait for build (~2 minutes)
6. You'll get a URL like `https://echoline-game-server.onrender.com`

### Option B: Manual Setup

1. Go to https://render.com → **New → Web Service**
2. Connect your GitHub repo
3. Configure:
   - **Name**: echoline-game-server
   - **Region**: Oregon (free tier region)
   - **Branch**: main
   - **Root Directory**: `game-server`
   - **Runtime**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Plan**: Free
4. Add environment variables (see below)
5. Click **Create Web Service**

---

## 🔧 Environment Variables

Set these in Render Dashboard → Service → Environment:

| Variable | Value | Required |
|----------|-------|----------|
| `NODE_ENV` | `production` | ✅ |
| `PORT` | `10000` (Render default) | ✅ |
| `ADMIN_API_URL` | `https://yourdomain.com/admin/api.php` | ⚠️ For live data |
| `ALLOWED_ORIGINS` | `*` or specific domains | ✅ |
| `MAX_ROOMS` | `100` | optional |
| `MAX_PLAYERS_PER_ROOM` | `4` | optional |
| `MATCH_DURATION_SECONDS` | `600` | optional |
| `DISCONNECT_GRACE_SECONDS` | `30` | optional |
| `LOG_LEVEL` | `info` | optional |

---

## 🔌 Connecting Hostinger Admin (Bridge)

The game server pulls live data from your Hostinger panel:

```
AdminBridge → Hostinger /admin/api.php?action=config
                    → ?action=events
                    → ?action=quests
                    → ?action=shop
```

This works **out of the box** as long as `ADMIN_API_URL` points to your live Hostinger domain. No API key required (it uses rate limiting).

**Verify it works**:
```bash
curl https://echoline-game-server.onrender.com/api/config
```

Should return config data (from Hostinger or fallback defaults).

---

## 🧪 Testing Locally First

```bash
cd game-server
npm install
cp .env.example .env
# Edit .env to set ADMIN_API_URL
npm run dev
```

Then open `http://localhost:3000` — should return server status JSON.

---

## 📊 Monitoring

Free tier on Render:
- **750 hours/month** of runtime (plenty for testing)
- Spins down after 15 min of inactivity (cold start ~30s on first request)
- 100 GB bandwidth/month

For production traffic, upgrade to Starter plan ($7/month for always-on).

---

## 🔄 Updating the Server

Push to your GitHub repo's `main` branch → Render auto-deploys.

Or in Render dashboard: **Manual Deploy → Deploy latest commit**.

---

## 🌐 Connecting Godot Client

In your Godot client, set the server URL:

```gdscript
# In project settings or autoload
const GAME_SERVER_URL = "https://echoline-game-server.onrender.com"
const ADMIN_API_URL = "https://yourdomain.com/admin/api.php"
```

Then use `WebSocketPeer` or `HTTPRequest` to connect.

---

## ⚠️ Free Tier Limitations

| Limitation | Impact | Mitigation |
|-----------|--------|------------|
| Spins down after 15 min idle | Cold start ~30s | Upgrade to Starter plan |
| 100 GB/month bandwidth | ~100K players/month | Monitor + upgrade as needed |
| Single instance | No redundancy | Add 2nd instance later |
| No persistent disk | Room state lost on restart | Acceptable for game state |

---

## 🔐 Security Notes

- Server validates every player action (no client trust)
- Rate-limited socket events per connection
- CORS configured via `ALLOWED_ORIGINS`
- Sanitization of all incoming payloads
- No PII stored on server (player identity via Hostinger)

---

## 📞 Troubleshooting

**Server won't start?**
- Check Render logs (Dashboard → Logs)
- Verify `package.json` is valid
- Verify Node version ≥ 18 in `engines`

**Bridge not fetching Hostinger data?**
- Check `ADMIN_API_URL` is set correctly
- Verify Hostinger admin is installed and accessible
- Test: `curl https://yourdomain.com/admin/api.php?action=config`

**Socket connections failing?**
- Check CORS settings (`ALLOWED_ORIGINS`)
- Verify Render service is awake (free tier spins down)
- Check that client uses `wss://` not `ws://` for HTTPS

**Players see stale data?**
- AdminBridge caches for 60s — this is intentional (rate limiting)
- Use `?action=*` endpoints directly if to client to bypass cache

---

## 📝 License

© 2026 ECHO//LINE — All rights reserved.