ECHO//LINE Android Build Guide
==============================

This guide covers building ECHO//LINE Android APK using Godot 4.7.2 + Gradle 8.11.1.

## Prerequisites

1. **Godot 4.7.2-stable** — Download from https://godotengine.org/download (Windows / Linux / macOS)
2. **Android SDK 34+** — Install via Android Studio or `cmdline-tools`
3. **Java JDK 17+** — OpenJDK recommended
4. **Gradle 8.11.1** — Used by Godot's Android export template
5. **Android NDK 25.2.9519653** — Required for native code

## Environment Setup

### Windows (PowerShell)

```powershell
# Set ANDROID_HOME
[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "User")
[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Java\jdk-17", "User")

# Verify Java
java -version

# Verify Android SDK
& "$env:ANDROID_HOME\platform-tools\adb.exe" version
```

### Linux/macOS

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

## Step 1: Install Android Export Template (one-time)

1. Open Godot 4.7.2
2. **Editor → Manage Export Templates**
3. Click **Download and Install** for Android
4. Wait for ~500 MB download

## Step 2: Configure export_presets.cfg

Already configured in `client/export_presets.cfg`. Key settings:

```ini
[preset.0]
name="Android"
platform="Android"
runnable=true
custom_features="android,etc2"
export_filter="all_resources"
include_filter=""
exclude_filter="addons/**,demo/**,editor_only/**,road_demos/**"
export_path="./echoline.apk"
pck_only=false
encryption_key=""
apk_expansion=false
apk_expansion_pck=""
apk_expansion_sections=""
use_custom_build=yes
android_target_sdk_version="34"
android_min_sdk_version="24"
screen_orientation="landscape"
```

## Step 3: Build the APK

### Debug build (unsigned)

```powershell
cd client
& .\android\build_android.ps1 -Debug
```

The APK is generated at `client/builds/echoline-debug.apk`; the current full
asset set is approximately 363 MB and is verified with `aapt2`.

### Release build (signed)

#### Option A: Use Android signing (recommended)

1. Generate keystore (one-time):
```powershell
keytool -genkey -v -keystore client/android/keystore/echoline.keystore -alias echoline -keyalg RSA -keysize 2048 -validity 10950
```

2. Build and sign with the protected values (the script refuses a missing
   keystore and never falls back to the debug key):
```powershell
& .\android\build_android.ps1 -Release `
  -KeystorePath "android\keystore\echoline.keystore" `
  -KeystorePassword $env:ECHOLINE_KEYSTORE_PASSWORD `
  -KeystoreUser $env:ECHOLINE_KEYSTORE_USER
```

#### Option B: Manual signing (post-build)

```powershell
# Generate keystore once
keytool -genkey -v -keystore echoline.keystore -alias echoline -keyalg RSA -keysize 2048 -validity 10950

# Zipalign + sign
& "$env:ANDROID_HOME\build-tools\34.0.0\zipalign.exe" -v 4 echoline-release-unsigned.apk echoline-release-aligned.apk
& "$env:ANDROID_HOME\build-tools\34.0.0\apksigner.exe" sign --ks echoline.keystore --out echoline-release.apk echoline-release-aligned.apk

# Verify signature
& "$env:ANDROID_HOME\build-tools\34.0.0\apksigner.exe" verify --print-certs echoline-release.apk
```

## Step 4: Install on Device

```powershell
# Enable USB debugging on Android device
# Connect via USB

# List devices
& "$env:ANDROID_HOME\platform-tools\adb.exe" devices

# Install
& "$env:ANDROID_HOME\platform-tools\adb.exe" install -r client/builds/echoline-release.apk

# Launch
& "$env:ANDROID_HOME\platform-tools\adb.exe" shell am start -n com.ecouni.echoline/.MainActivity

# View logs (Godot prints to logcat under "godot")
& "$env:ANDROID_HOME\platform-tools\adb.exe" logcat -s godot -v threadtime
```

## Step 5: Submit to Google Play

### Pre-submission checklist

- [ ] Release APK signed with **release keystore** (NOT debug keystore)
- [ ] `versionCode` incremented
- [ ] `versionName` updated (e.g., "1.0.0")
- [ ] Privacy policy URL hosted
- [ ] Data safety form filled
- [ ] Target API level 34+
- [ ] 64-bit support (arm64-v8a + x86_64)
- [ ] ProGuard mapping uploaded for crash reports
- [ ] Asset bundles split (use `splits` in gradle)
- [ ] App icon 432x432, 192x192, 144x144, 96x96, 48x48
- [ ] Feature graphic 1024x500
- [ ] Screenshots (phone + tablet, 8" minimum 4)
- [ ] Short description (<= 80 chars)
- [ ] Full description
- [ ] Content rating: IARC completed
- [ ] Privacy policy on official website

### Build the Android App Bundle (AAB)

```powershell
# Build AAB instead of APK (Play Store requires AAB)
& "C:\Program Files\Godot\godot_4.7.2-stable_win64.exe" --headless --export-release "Android" builds/echoline.aab
```

The AAB is uploaded to Play Console, Google Play signs it.

## Step 6: In-App Purchase Setup

ECHO//LINE uses Google Play Billing Library v6+ for IAP:

1. **Create products in Play Console**:
   - `echoline.shards.pack.100` — 100 shards pack (consumable)
   - `echoline.shards.pack.500` — 500 shards pack (consumable)
   - `echoline.premium.pass` — Monthly pass (subscription)

2. **Verify receipts server-side**: `web/admin/api/receipt_verifier.php`

3. **IAP manager**: `client/autoload/iap_manager.gd` handles flow on client

## Step 7: Crash Reporting

Crash reports are sent to Render via `/api/v1/telemetry/crash`. Backend aggregates and exposes:
- `crash_rate_last_24h` — must be < 0.5%
- `crash_rate_last_1h` — must be < 2%
- Top 10 crashes by stack trace

## CI/CD Integration

`.github/workflows/ci.yml` automatically:
- Builds Android debug APK on every PR
- Builds Android release APK on every main commit (signed with CI keystore)
- Uploads as workflow artifact
- Triggered by `paths: ['client/**']`

## Troubleshooting

### "Android SDK not found"
- Set `ANDROID_HOME` environment variable
- Verify with `echo $ANDROID_HOME` (or `[Environment]::GetEnvironmentVariable("ANDROID_HOME")`)

### "Keystore was tampered with, or password was incorrect"
- Verify `ECHOLINE_KEYSTORE_PASSWORD` in gradle.properties
- Check keystore file integrity: `keytool -list -keystore echoline.keystore`

### "INSTALL_FAILED_UPDATE_INCOMPATIBLE"
- Uninstall first: `adb uninstall com.ecouni.echoline`
- Then install new APK

### "INSTALL_FAILED_NO_MATCHING_ABIS"
- Build with `arm64-v8a` AND `x86_64` (default in Godot export preset)
- Verify with `aapt dump badging echoline.apk | grep -i native-code`

### App crashes on launch
- Check `adb logcat -s godot` for stack trace
- Verify all autoloads registered in `project.godot`
- Check `client/android/.build_version` exists

## Build Times (reference)

- Debug APK: ~90s (incremental: ~30s)
- Release APK (with splits): ~120s
- Android Asset Bundle: ~180s

## File Sizes (reference)

- Debug APK: approximately 363 MB with the current full asset set
- Release APK: depends on signing and resource optimization
- AAB (Play Asset Delivery): ~45 MB main + 30 MB asset packs

## Security

- **Keystore**: NEVER commit keystore file. `.gitignore` excludes `*.keystore` and `*.jks`.
- **API Keys**: Use Gradle properties, not hardcoded values.
- **ProGuard**: Keep Godot signals + reflection-friendly code. Strip unused symbols.
- **Root detection**: Enable in `client/autoload/network_client.gd` for sensitive flows.
- **SSL pinning**: Configure for production API URLs in release builds.
