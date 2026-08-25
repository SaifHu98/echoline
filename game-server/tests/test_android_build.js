const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const ANDROID_DIR = path.join(ROOT, 'client', 'android');
const DOC = path.join(ANDROID_DIR, 'BUILD_ANDROID.md');
const GRADLE = path.join(ANDROID_DIR, 'build.gradle.template');
const PROGUARD = path.join(ANDROID_DIR, 'proguard-rules.pro');
const SCRIPT = path.join(ANDROID_DIR, 'build_android.ps1');

test('Android docs: BUILD_ANDROID.md exists and is comprehensive', () => {
  assert.ok(fs.existsSync(DOC), 'BUILD_ANDROID.md missing');
  const content = fs.readFileSync(DOC, 'utf8');
  assert.match(content, /Prerequisites/);
  assert.match(content, /Environment Setup/);
  assert.match(content, /Install Android Export Template/);
  assert.match(content, /Step 1/);
  assert.match(content, /Step 2/);
  assert.match(content, /Step 3/);
  assert.match(content, /Step 4/);
  assert.match(content, /Step 5/);
  assert.match(content, /Step 6/);
  assert.match(content, /Step 7/);
  assert.match(content, /Troubleshooting/);
  assert.match(content, /Build Times/);
  assert.match(content, /File Sizes/);
  assert.match(content, /Security/);
});

test('Android build: gradle template has correct SDK targets', () => {
  const content = fs.readFileSync(GRADLE, 'utf8');
  assert.match(content, /compileSdkVersion 34/);
  assert.match(content, /targetSdkVersion 34/);
  assert.match(content, /minSdkVersion 24/);
  assert.match(content, /abiFilters 'arm64-v8a', 'x86_64'/);
});

test('Android build: gradle has signing config gated on keystore property', () => {
  const content = fs.readFileSync(GRADLE, 'utf8');
  assert.match(content, /ECHOLINE_KEYSTORE_PATH/);
  assert.match(content, /ECHOLINE_KEYSTORE_PASSWORD/);
  assert.match(content, /ECHOLINE_KEYSTORE_USER/);
  assert.match(content, /if \(project\.hasProperty/);
});

test('Android build: gradle has Play bundle splits enabled', () => {
  const content = fs.readFileSync(GRADLE, 'utf8');
  assert.match(content, /enableSplit true/);
  assert.match(content, /language/);
  assert.match(content, /density/);
  assert.match(content, /abi/);
});

test('Android build: gradle has multidex enabled', () => {
  const content = fs.readFileSync(GRADLE, 'utf8');
  assert.match(content, /multiDexEnabled true/);
});

test('Android build: gradle ProGuard config has shrink + minify for release', () => {
  const content = fs.readFileSync(GRADLE, 'utf8');
  assert.match(content, /minifyEnabled true/);
  assert.match(content, /shrinkResources true/);
  assert.match(content, /proguardFiles/);
});

test('Android build: proguard-rules.pro keeps Godot classes', () => {
  const content = fs.readFileSync(PROGUARD, 'utf8');
  assert.match(content, /com\.godot\.game/);
  assert.match(content, /com\.godot\.game\.GodotApp/);
});

test('Android build: proguard keeps autoload scripts', () => {
  const content = fs.readFileSync(PROGUARD, 'utf8');
  assert.match(content, /accessibility_service/);
  assert.match(content, /network_client/);
  assert.match(content, /iap_manager/);
  assert.match(content, /audio_mixer_service/);
  assert.match(content, /dark_patterns_guard/);
  assert.match(content, /ux_telemetry/);
});

test('Android build: proguard keeps building system classes', () => {
  const content = fs.readFileSync(PROGUARD, 'utf8');
  assert.match(content, /shard_inventory/);
  assert.match(content, /anchor_placement_controller/);
  assert.match(content, /anchor_network_sync/);
});

test('Android build: proguard keeps Godot signal annotations', () => {
  const content = fs.readFileSync(PROGUARD, 'utf8');
  assert.match(content, /@com\.godot\.game\.Signal/);
});

test('Android build: build script accepts Release and Debug params', () => {
  const content = fs.readFileSync(SCRIPT, 'utf8');
  assert.match(content, /\[switch\]\$Release/);
  assert.match(content, /\[switch\]\$AAB/);
});

test('Android build: build script signs APK in release mode', () => {
  const content = fs.readFileSync(SCRIPT, 'utf8');
  assert.match(content, /apksigner/);
  assert.match(content, /zipalign/);
  assert.match(content, /sign --ks/);
});

test('Android build: build script warns when keystore missing in release', () => {
  const content = fs.readFileSync(SCRIPT, 'utf8');
  assert.match(content, /Keystore not found/);
  assert.match(content, /debug keystore/);
});

test('Android build: build script verifies output APK with aapt2', () => {
  const content = fs.readFileSync(SCRIPT, 'utf8');
  assert.match(content, /aapt2/);
  assert.match(content, /dump badging/);
});

test('Android build: build script supports custom version code + name', () => {
  const content = fs.readFileSync(SCRIPT, 'utf8');
  assert.match(content, /\[int\]\$VersionCode/);
  assert.match(content, /\[string\]\$VersionName/);
});