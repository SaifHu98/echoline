# ECHO//LINE APK Build Script
# Builds Android APK (debug or release) using Godot 4.7.2 + Gradle.
# Usage: .\build_android.ps1 -Release
#        .\build_android.ps1 -Debug

param(
    [switch]$Release = $false,
    [switch]$AAB = $false,
    [string]$GodotPath = "",
    [string]$AndroidHome = "",
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

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCandidates = @(
        (Join-Path $env:USERPROFILE "Desktop\Godot_v4.7.2-stable_win64_console.exe"),
        "C:\Program Files\Godot\godot_4.7.2-stable_win64_console.exe",
        (Join-Path $env:USERPROFILE "Desktop\Godot_v4.7.2-stable_win64.exe"),
        "C:\Program Files\Godot\godot_4.7.2-stable_win64.exe"
    )
    $GodotPath = $godotCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if ([string]::IsNullOrWhiteSpace($AndroidHome)) {
    $AndroidHome = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    Write-Error "Godot executable not found at: $GodotPath"
    exit 1
}

if (-not (Test-Path -LiteralPath $AndroidHome)) {
    Write-Error "Android SDK not found at: $AndroidHome"
    exit 1
}

if (-not [System.IO.Path]::IsPathRooted($KeystorePath)) {
    $KeystorePath = Join-Path $scriptPath $KeystorePath
}

Write-Host "Resolved Godot:  $GodotPath"
Write-Host "Resolved SDK:    $AndroidHome"

if ($Release -and -not $AAB) {
    if (-not (Test-Path -LiteralPath $KeystorePath)) {
        Write-Error "Release keystore not found at $KeystorePath. Refusing to produce a falsely production-signed APK."
        exit 1
    }
    if ([string]::IsNullOrWhiteSpace($KeystorePassword) -or [string]::IsNullOrWhiteSpace($KeystoreUser)) {
        Write-Error "Release signing requires KeystorePassword and KeystoreUser."
        exit 1
    }
}

# Set environment
$env:ANDROID_HOME = $AndroidHome
$pathSeparator = [System.IO.Path]::PathSeparator
$platformTools = Join-Path $AndroidHome "platform-tools"
$buildToolsDir = Join-Path (Join-Path $AndroidHome "build-tools") "34.0.0"
$env:PATH = "$platformTools$pathSeparator$buildToolsDir$pathSeparator$env:PATH"
# Godot's Android exporter invokes Gradle internally. A stale daemon can keep
# the exporter alive after the APK is written, so use a single-use daemon for
# deterministic CI/local builds.
$env:GRADLE_OPTS = "$($env:GRADLE_OPTS) -Dorg.gradle.daemon=false"

# Create output directory
$outputDir = Join-Path $projectRoot "builds"
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
} else {
    $godotArgs = @(
        "--headless",
        "--path", $projectRoot,
        "--export-debug", $presetName, $outputFile
    )
}

$godotOutput = & $GodotPath @godotArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    $godotOutput | Select-Object -Last 25 | ForEach-Object { Write-Host $_ }
    Write-Error "Godot export failed with exit code $LASTEXITCODE"
    exit 1
}

if (-not (Test-Path -LiteralPath $outputFile)) {
    Write-Error "Build failed — output file not created: $outputFile"
    exit 1
}

$fileSize = (Get-Item -LiteralPath $outputFile).Length / 1MB
Write-Host "  ✓ Built $outputFile ($([Math]::Round($fileSize, 1)) MB)" -ForegroundColor Green

# Sign if release + APK (AAB is signed by Play)
if ($Release -and -not $AAB) {
    Write-Host "`n[2/3] Signing release APK..." -ForegroundColor Yellow
    $zipalign = Join-Path $buildToolsDir "zipalign.exe"
    $apksigner = Join-Path $buildToolsDir "apksigner.exe"
    $alignedFile = $outputFile -replace '\.apk$', '-aligned.apk'

    & $zipalign -v 4 $outputFile $alignedFile
    if ($LASTEXITCODE -ne 0) {
        Write-Error "zipalign failed with exit code $LASTEXITCODE"
        exit 1
    }
    & $apksigner sign --ks $KeystorePath --ks-pass "pass:$KeystorePassword" --ks-key-alias $KeystoreUser --key-pass "pass:$KeystorePassword" --out $outputFile $alignedFile
    if ($LASTEXITCODE -ne 0) {
        Write-Error "apksigner sign failed with exit code $LASTEXITCODE"
        exit 1
    }
    & $apksigner verify --print-certs $outputFile
    if ($LASTEXITCODE -ne 0) {
        Write-Error "apksigner verification failed with exit code $LASTEXITCODE"
        exit 1
    }
    Remove-Item -LiteralPath $alignedFile -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Signed APK" -ForegroundColor Green
} else {
    Write-Host "`n[2/3] Skipping signing (debug or AAB)" -ForegroundColor DarkGray
}

# Verify
Write-Host "`n[3/3] Verifying APK..." -ForegroundColor Yellow
if (-not $AAB) {
    $aapt = Join-Path $buildToolsDir "aapt2.exe"
    if (Test-Path -LiteralPath $aapt) {
        $aaptOutput = & $aapt dump badging $outputFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "aapt2 verification failed with exit code $LASTEXITCODE"
            exit 1
        }
        $aaptOutput | Select-String -Pattern "package:|application-label:|launchable-activity:|sdkVersion:|targetSdkVersion:|native-code:" | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkCyan }
    }
}

Write-Host "`n=== Build complete ===" -ForegroundColor Green
Write-Host "Output: $outputFile ($([Math]::Round($fileSize, 1)) MB)`n"
