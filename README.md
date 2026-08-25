# ECHO//LINE — Cooperative Cross-Timeline Multiplayer

> Echoes Across Time. Cooperate across timelines. Prevent catastrophe.

ECHO//LINE is a cooperative social puzzle game where 2-4 players occupy different timelines (Past / Present / Future), interact with unique objects, and trigger "echoes" that affect other players' timelines.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Mobile Client (Godot 4.3+)                              │
│  - Android APK (arm64-v8a)                              │
│  - WebSocket client (Socket.IO)                         │
└──────────────────┬──────────────────────────────────────┘
                   │ wss://
                   ▼
┌─────────────────────────────────────────────────────────┐
│  Game Server (Node.js + Socket.IO)                      │
│  - Authoritative match state                            │
│  - EchoEngine causal simulation                         │
│  - Matchmaking + Rooms                                  │
│  Hosted on: Render (free tier)                          │
└──────────────────┬──────────────────────────────────────┘
                   │ https://
                   ▼
┌─────────────────────────────────────────────────────────┐
│  Admin Panel (PHP 8 + MySQL)                            │
│  - Live ops control (events, quests, shop, scenarios)   │
│  - Player management + analytics                        │
│  - Sales archive + receipt validation                   │
│  Hosted on: Hostinger (shared hosting)                  │
└─────────────────────────────────────────────────────────┘
```

## Repository Structure

```
echoline/
├── client/                 Godot 4.3+ mobile game client
│   ├── autoload/           Autoloaded singletons (Network, Audio, etc.)
│   ├── scenes/             Main scenes (main_menu, main)
│   ├── ui/                 UI components (hud, lobby, etc.)
│   ├── gameplay/           Game logic (timelines, echo, interaction)
│   ├── core/               Utilities (state, types, pools)
│   ├── icon.svg            App icon
│   └── project.godot       Godot project config
│
├── game-server/            Node.js authoritative game server
│   ├── src/
│   │   ├── server.js       Main entry (HTTP + Socket.IO)
│   │   ├── rooms/          Room logic (Room, RoomManager, MatchMaker)
│   │   ├── simulation/     EchoEngine causal rule engine
│   │   └── admin-bridge/   Polls Hostinger admin API
│   ├── tests/              Test files
│   ├── package.json        Node deps
│   └── .env.example        Config template
│
├── web/admin/              PHP admin panel
│   ├── config.php          DB config + autoloader
│   ├── dashboard.php       Main dashboard
│   ├── api.php             Public API for game server
│   ├── includes/           PHP classes (Auth, Database, etc.)
│   ├── database/           SQL schema
│   ├── data/               Translations + scenarios
│   └── assets/             CSS + JS
│
├── render.yaml             Render deployment blueprint
└── README.md               This file
```

## Quick Deploy

### 1. Deploy Game Server to Render

1. Push this repo to GitHub (public recommended)
2. Go to https://dashboard.render.com → New + → Web Service
3. Connect the GitHub repo `echoline`
4. Set:
   - Root Directory: `game-server`
   - Build Command: `npm install`
   - Start Command: `npm start`
5. Add env vars (see `.env.example`)
6. Create Web Service → URL like `https://echoline-game-server.onrender.com`

### 2. Deploy Admin Panel to Hostinger

1. Upload `web/admin/*` to `public_html/echoline/` via File Manager
2. Edit `web/admin/config.php` with your MySQL credentials
3. Visit `https://yourdomain.com/echoline/install.php` to create tables
4. Login at `https://yourdomain.com/echoline/login.php`

### 3. Build Android APK

1. Open `client/project.godot` in Godot 4.3+
2. Project → Export → Add → Android
3. Fill in package details
4. Export APK to phone

## Environment Variables (Game Server)

| Var | Default | Description |
|-----|---------|-------------|
| `PORT` | `3000` | HTTP port |
| `NODE_ENV` | `production` | Runtime mode |
| `ALLOWED_ORIGINS` | `*` | CORS allowed origins |
| `ADMIN_API_URL` | — | Hostinger admin API URL |
| `ADMIN_API_KEY` | (empty) | API key for admin endpoints |
| `MAX_ROOMS` | `100` | Max concurrent rooms |
| `MAX_PLAYERS_PER_ROOM` | `4` | Players per match |
| `MATCH_DURATION_SECONDS` | `600` | 10 minutes |
| `LOG_LEVEL` | `info` | pino log level |

## API Endpoints (Game Server)

- `GET /` — server info
- `GET /healthz` — health check
- `GET /api/config` — remote config (cached 60s, from Hostinger)
- `GET /api/events` — active events
- `GET /api/quests` — active quests
- `GET /api/shop` — shop catalog
- `GET /api/scenarios` — available scenarios
- `GET /api/scenario?id=xxx` — specific scenario JSON
- `GET /api/announcements` — current announcements
- `GET /api/i18n?lang=ar` — translations

Socket.IO events: `lobby:create`, `lobby:join`, `lobby:select_timeline`, `lobby:set_ready`, `lobby:start`, `match:interact`, `match:quick_message`, `match:ping`, `match:state_request`.

## License

ISC License — see LICENSE file.

## Contributing

Issues and PRs welcome on GitHub.

---

**Status**: v1.0.0 (production-ready)
**Last updated**: 2026