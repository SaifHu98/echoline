# ECHO//LINE APK Build Script
# Builds Android APK (debug or release) using Godot 4.7.2 + Gradle.
# Usage: .\build_android.ps1 -Release
#        .\build_android.ps1 -Debug

param(
    [switch]$Release = $false,
    [switch]$AAB = $false,
    [string]$GodotPath = "C:\Program Files\Godot\godot_4.7.2-stable_win64.exe",
    [string]$AndroidHome = $env:ANDROID_HOME,
    [string]$KeystorePath = "keystore\echoline.keystore",
    [string]$KeystorePassword = $env:ECHOLINE_KEYSTORE_PASSWORD,
    [string]$KeystoreUser = $env:ECHOLINE_KEYSTORE_USER,
    [int]$VersionCode = 1,
    [string]$VersionName = "1.0.0"
)

$ErrorActionPreference = "Stop"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Split-Path -Parent $scriptPath

Write-Host "`n=== ECHO//LINE APK Build ===" -ForegroundColor Cyan
Write-Host "Build type:    $(if ($Release) { 'Release' } else { 'Debug' })"
Write-Host "Output:        $(if ($AAB) { 'AAB (Play Store)' } else { 'APK' })"
Write-Host "Godot path:    $GodotPath"
Write-Host "Android SDK:   $AndroidHome"
Write-Host "Project root:  $projectRoot`n"

if (-not (Test-Path -LiteralPath $GodotPath)) {
    Write-Error "Godot executable not found at: $GodotPath"
    exit 1
}

if (-not (Test-Path -LiteralPath $AndroidHome)) {
    Write-Error "Android SDK not found at: $AndroidHome"
    exit 1
}

# Set environment
$env:ANDROID_HOME = $AndroidHome
$env:PATH = "$AndroidHome\platform-tools;$AndroidHome\build-tools\34.0.0;$env:PATH"

# Create output directory
$outputDir = Join-Path $projectRoot "client\builds"
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$outputExt = if ($AAB) { "aab" } else { "apk" }
$buildType = if ($Release) { "release" } else { "debug" }
$presetName = "Android"
$outputFile = Join-Path $outputDir "echoline-$buildType.$outputExt"

# Build using Godot
Write-Host "[1/3] Exporting $buildType $outputExt from Godot..." -ForegroundColor Yellow
$godotArgs = @(
    "--headless",
    "--path", $projectRoot,
    "--export", $presetName, $outputFile
)
if ($Release) {
    $godotArgs = @(
        "--headless",
        "--path", $projectRoot,
        "--export-release", $presetName, $outputFile
    )
}

& $GodotPath @godotArgs 2>&1 | Out-Null

if (-not (Test-Path -LiteralPath $outputFile)) {
    Write-Error "Build failed — output file not created: $outputFile"
    exit 1
}

$fileSize = (Get-Item -LiteralPath $outputFile).Length / 1MB
Write-Host "  ✓ Built $outputFile ($([Math]::Round($fileSize, 1)) MB)" -ForegroundColor Green

# Sign if release + APK (AAB is signed by Play)
if ($Release -and -not $AAB) {
    Write-Host "`n[2/3] Signing release APK..." -ForegroundColor Yellow
    if (-not (Test-Path -LiteralPath $KeystorePath)) {
        Write-Warning "Keystore not found at $KeystorePath — using debug keystore (NOT for production!)"
        $KeystorePath = "$env:USERPROFILE\.android\debug.keystore"
        $KeystorePassword = "android"
        $KeystoreUser = "androiddebugkey"
        if (-not (Test-Path -LiteralPath $KeystorePath)) {
            Write-Error "Debug keystore missing. Generate one with: keytool -genkey -keystore ~/.android/debug.keystore"
            exit 1
        }
    }
    $apksigner = Join-Path $AndroidHome "build-tools\34.0.0\apksigner.exe"
    $alignedFile = $outputFile -replace '\.apk$', '-aligned.apk'

    & "$AndroidHome\build-tools\34.0.0\zipalign.exe" -v 4 $outputFile $alignedFile
    & $apksigner sign --ks $KeystorePath --ks-pass "pass:$KeystorePassword" --ks-key-alias $KeystoreUser --key-pass "pass:$KeystorePassword" --out $outputFile $alignedFile
    & $apksigner verify --print-certs $outputFile
    Remove-Item -LiteralPath $alignedFile -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Signed APK" -ForegroundColor Green
} else {
    Write-Host "`n[2/3] Skipping signing (debug or AAB)" -ForegroundColor DarkGray
}

# Verify
Write-Host "`n[3/3] Verifying APK..." -ForegroundColor Yellow
if (-not $AAB) {
    $aapt = Join-Path $AndroidHome "build-tools\34.0.0\aapt2.exe"
    if (Test-Path -LiteralPath $aapt) {
        & $aapt dump badging $outputFile 2>&1 | Select-String -Pattern "package:|application-label:|launchable-activity:|sdkVersion:|targetSdkVersion:|native-code:" | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkCyan }
    }
}

Write-Host "`n=== Build complete ===" -ForegroundColor Green
Write-Host "Output: $outputFile ($([Math]::Round($fileSize, 1)) MB)`n"