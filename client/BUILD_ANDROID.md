# ECHO//LINE — Android APK Build Guide

## Build Time
This is the first official Android build for ECHO//LINE. To build the APK:

### Requirements
1. **Godot Engine 4.3+** installed
2. **Android SDK** installed (Godot will install via Export wizard)
3. **OpenJDK 17+** for build tools
4. **Export Templates** for Godot Android

---

## Build Steps (Windows)

### Step 1: Open project in Godot
```
Godot.exe --path D:\EcoUni\Echos\client
```

### Step 2: Install Android Export Template
In Godot editor:
```
Editor → Manage Export Templates → Download and Install
```
Choose version matching your Godot engine (4.3.x).

### Step 3: Configure Android Export
In Godot editor:
```
Project → Export → Add → Android
```

Fill in:
- **Package → Unique Name**: `com.ecouni.echoline`
- **Package → Name**: `ECHO//LINE`
- **Version → Code**: `1`
- **Version → Name**: `1.0.0`
- **Screen → Orientation**: `sensor_landscape`
- **Architectures**: `arm64-v8a` only (smaller APK, covers 99% devices)

### Step 4: Export APK
Click **Save** and choose filename `echoline.apk`. Godot will:
1. Generate Android project
2. Build debug APK
3. Save to your chosen location

### Step 5: Test on phone
```
adb install echoline.apk
```

Or transfer `echoline.apk` to phone and install (enable "Unknown Sources" first).

---

## Server Configuration (edit before building!)

Edit `client/autoload/network_client.gd` lines 8-9:

```gdscript
const DEFAULT_SERVER_URL := "wss://YOUR-SERVER.onrender.com/socket.io/?EIO=4&transport=websocket"
const DEFAULT_ADMIN_URL := "https://YOUR-DOMAIN.com/admin/api.php"
```

For the first test build, use **sandbox servers** (free, no setup):
- Game Server: `wss://echoline-game-server.onrender.com/socket.io/?EIO=4&transport=websocket`
- Admin API: `https://echoline.eduiraq.net/admin/api.php`

---

## What's in v1.0.0 (First Build)

✓ Main menu with online status indicator
✓ Lobby creation / joining via room code
✓ Real-time 2-4 player match
✓ Timeline selection (Past/Present/Future)
✓ Quick chat (auto-translates)
✓ Match end + outcome screen
✓ Save progress to server
✓ Settings (language, audio, graphics)
✓ RTL Arabic interface
✓ Guest login (no account required)

---

## Known Limitations (v1.0)
- No account system (only guest UID)
- Only 2 scenarios (Clocktower, Observatory)
- Match length: 5 minutes
- Single Android architecture (arm64-v8a)

---

## File Sizes (approximate)
- APK: ~30-45 MB
- Download size: ~25 MB (after Play Store compression)
