# Build, Run & Release Guide — ECHO//LINE (أصداء)

## 1. Prerequisites
* **Node.js**: v18+ or v20+
* **Python**: 3.10+
* **Godot Engine**: 4.2+ or 4.3+ (Standard/Mobile)
* **Android SDK / NDK**: (For Android builds) OpenJDK 17, Android Build Tools 34.0.0
* **macOS & Xcode 15+**: (For iOS builds)

---

## 2. Quickstart Instructions

### Step 1: Install Server Dependencies & Run Automated Tests
```powershell
cd server
npm install
npm test
```
*Expected Output:*
`ℹ pass 11, fail 0 (duration_ms < 150ms)`

### Step 2: Validate Scenarios and Catalogs
```powershell
python tools/pseudo_loc_generator.py
python tools/localization_validator.py
python tools/scenario_validator.py
```
*Expected Output:*
`[PASS] All 4 localization catalogs verified`
`[PASS] 108 reachable states explored, multiple solution paths verified`

### Step 3: Start Authoritative Server
```powershell
cd server
npm start
# Server listens on ws://localhost:7777
```

### Step 4: Run the Client in Desktop Development Mode
Open Godot 4, import `client/project.godot`, and press **F5** to run the project.
Alternatively, launch headless or desktop build:
```powershell
godot --path ./client
```

---

## 3. Mobile Build Instructions

### Android Development Build (APK / AAB)
1. In Godot 4 Editor: Open `Project -> Install Android Build Template`.
2. Configure Editor Settings:
   * Set `Android SDK Path` to your SDK location (e.g. `C:/Users/<User>/AppData/Local/Android/Sdk`).
   * Set `Debug Keystore` path (generate via `keytool -genkey -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000`).
3. Export Configuration:
   * Open `Project -> Export...` and add an **Android** preset.
   * Architecture: Enable `arm64-v8a` (Primary) and `armeabi-v7a`.
   * Renderer: `Mobile` (Vulkan Mobile).
   * Permissions: Enable `Internet` (Network multiplayer). Keep all microphone/contacts/location disabled.
4. Build Command via CLI:
```powershell
godot --headless --path ./client --export-debug "Android" ./builds/android/echoline-debug.apk
```

### iOS Development Build (Xcode Project)
1. On macOS with Xcode 15+:
2. Open Godot 4, go to `Project -> Export...`, and add an **iOS** preset.
3. Set `App Store Team ID` and `Bundle Identifier` (e.g. `com.ecouni.echoline`).
4. Generate Xcode Project:
```bash
godot --headless --path ./client --export-debug "iOS" ./builds/ios/Echolline.xcodeproj
```
5. Open Xcode project, select your provisioning profile, and build to connected iOS device or simulator:
```bash
xcodebuild -project ./builds/ios/Echolline.xcodeproj -scheme "Echolline" -destination "generic/platform=iOS" build
```
