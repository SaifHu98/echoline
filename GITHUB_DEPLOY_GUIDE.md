# ECHO//LINE — Deployment Strategy: GitHub Public vs Private

## Quick Answer

| Strategy | Pros | Cons |
|----------|------|------|
| **Public Repo** | Free, simple, builds automatically, easy to collaborate | Anyone sees source code |
| **Private Repo + Render** | Source code hidden | $7/month per user on GitHub |

---

## Option 1: Public Repo (RECOMMENDED for you)

**Yes, it will be open source**, but this is fine for indie projects:
- ✅ Free forever
- ✅ Render auto-builds when you push
- ✅ Easy to share with collaborators
- ✅ Backup of your work
- ✅ Shows your work to potential players/clients
- ⚠️ People see server endpoints, but they still can't cheat (server is authoritative)

### How to set up Public:
```
1. github.com → New Repository
2. Name: echoline
3. Visibility: PUBLIC ← important
4. Don't initialize with README (you have files already)
5. Create repository
```

Then on Windows PowerShell:
```
cd D:\EcoUni\Echos
git init
git add .
git commit -m "ECHO//LINE initial release"
git remote add origin https://github.com/YOUR-USERNAME/echoline.git
git branch -M main
git push -u origin main
```

---

## Option 2: Private Repo

If you want code private:
- GitHub free tier: **Unlimited private repos** but Render needs read access
- Render supports private repos — connect via OAuth
- Source code stays hidden from public
- Render still has read access

### How to set up Private:
```
1. github.com → New Repository
2. Name: echoline
3. Visibility: PRIVATE ← important
4. Create repository
5. Push as above
6. In Render: when connecting GitHub, install the GitHub App on YOUR account only
```

Render can access private repos you own. Other users can't see them.

---

## Recommendation for ECHO//LINE

**Use PUBLIC** because:
1. ✅ It's free (no cost)
2. ✅ You can showcase the project
3. ✅ Game logic is on the SERVER (not in Godot client)
4. ✅ Anyone can see the code, but they still need:
   - Your Hostinger admin API URL
   - Your Render server URL
   - Database credentials
5. ✅ Easy to set up Render auto-deploys
6. ✅ Backup in cloud

**Use PRIVATE** if:
1. You have paid content you don't want to share
2. Your game is about to launch and you want secrecy
3. You need to hide admin credentials/secrets

---

## ⚠️ Security Note

Whatever you choose, **NEVER commit these to any repo**:

```
# ❌ NEVER commit
.env
.env.local
config.local.php
admin/credentials.php
admin/data/sensitive/

# ✅ Safe to commit
game-server/src/*.js (no secrets in code)
client/*.gd (no API keys)
web/admin/*.php (uses config.php which has credentials)
```

Move sensitive values to:
- **Render**: Environment Variables in dashboard
- **Hostinger**: Use `config.php` outside `public_html` or with `.htaccess` deny
- **GitHub**: Use `.gitignore` to exclude

### Add this `.gitignore` to your project root:

```gitignore
# Secrets
.env
.env.local
admin/includes/credentials.local.php
admin/config.local.php
admin/data/sessions/
admin/data/backups/

# Database
*.sql.bak
*.db
*.sqlite

# Build artifacts
client/builds/
game-server/node_modules/
game-server/dist/

# IDE
.vscode/
.idea/
*.swp

# OS
Thumbs.db
.DS_Store
```

---

## Step-by-Step for You

### 1. Initialize Git
```powershell
cd D:\EcoUni\Echos
git init
git add .
git commit -m "ECHO//LINE v1.0.0 - initial"
```

### 2. Create GitHub Repo
- Go to https://github.com/new
- Name: `echoline`
- **Choose PUBLIC** (recommended)
- Skip README/license/gitignore (you have them)
- Click **Create repository**

### 3. Push
```powershell
git remote add origin https://github.com/YOUR-USERNAME/echoline.git
git branch -M main
git push -u origin main
```

You'll need a Personal Access Token if 2FA is enabled:
- github.com → Settings → Developer settings → Personal access tokens → Generate new token
- Scope: `repo`, `workflow`
- Copy token
- Use as password when prompted

### 4. Connect to Render
- dashboard.render.com → New + → Web Service
- Connect GitHub → Authorize Render
- Select `echoline` repo
- Configure:
  - Root Directory: `game-server`
  - Build Command: `npm install`
  - Start Command: `npm start`
- Add environment variables from your `.env`
- Create Web Service

---

## After Deploy

Render URL will be like:
```
https://echoline-game-server.onrender.com
```

Update `client/autoload/network_client.gd`:
```gdscript
const DEFAULT_SERVER_URL := "wss://echoline-game-server.onrender.com/socket.io/?EIO=4&transport=websocket"
const DEFAULT_ADMIN_URL := "https://echoline.eduiraq.net/admin/api.php"
```

Rebuild APK in Godot → new APK uses your Render server.

---

## Summary

**Use PUBLIC repo for fastest setup. Source code being public is not a problem for ECHO//LINE because:**
1. Game server logic is server-side authoritative
2. Players can't cheat just by seeing source
3. Your admin API requires authentication
4. Database stays on Hostinger (not in repo)

Go with PUBLIC and start shipping. 🚀