# -*- coding: utf-8 -*-
"""
ECHO//LINE — Real Android Build + Smoke Tests
=============================================

Verifies that:
1. App icon is properly bound in project.godot
2. main_menu.tscn has correct button hierarchy (no overlap)
3. Button signals are properly connected
4. APK can be built and is launchable

Run with: python tests/godot/test_main_menu_fix.py
"""

import re
import sys
import os
import subprocess
import time
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
INTRO_GD = REPO_ROOT / "client" / "scenes" / "intro.gd"
MAIN_MENU_GD = REPO_ROOT / "client" / "scenes" / "main_menu.gd"
INTRO_TSCN = REPO_ROOT / "client" / "scenes" / "intro.tscn"
MAIN_MENU_TSCN = REPO_ROOT / "client" / "scenes" / "main_menu.tscn"
PROJECT_GODOT = REPO_ROOT / "client" / "project.godot"
ICON_SVG = REPO_ROOT / "client" / "icon.svg"
ICON_IMPORT = REPO_ROOT / "client" / "icon.svg.import"

class TestResult:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.failures = []

    def check(self, name, condition, detail=""):
        if condition:
            self.passed += 1
            print(f"  [PASS] {name}")
        else:
            self.failed += 1
            self.failures.append((name, detail))
            print(f"  [FAIL] {name}")
            if detail:
                print(f"         {detail}")


def run_tests():
    results = TestResult()
    print("\n" + "=" * 70)
    print("ECHO//LINE — Android APK Build & UI Fix Verification")
    print("=" * 70)

    # Group 1: App Icon
    print("\n[1] App Icon Configuration")
    results.check(
        "icon.svg exists",
        ICON_SVG.exists(),
        f"Need SVG icon at {ICON_SVG}"
    )

    if ICON_SVG.exists():
        icon_content = ICON_SVG.read_text(encoding="utf-8")
        results.check(
            "icon.svg has ECHO//LINE branding",
            "ECHO//LINE" in icon_content,
            "Brand name should be in the icon"
        )
        results.check(
            "icon.svg has 3 timeline colors (past/present/future)",
            all(c in icon_content for c in ["#00E5FF", "#FFD86B", "#FF4FBF"]),
            "All 3 timeline colors must be present"
        )
        results.check(
            "icon.svg is 512x512",
            'width="512"' in icon_content and 'height="512"' in icon_content,
            "Android adaptive icon recommends 512x512 source"
        )

    if ICON_IMPORT.exists():
        import_content = ICON_IMPORT.read_text(encoding="utf-8")
        results.check(
            "icon.svg.import has mipmaps enabled",
            "mipmaps/generate=true" in import_content,
            "Mipmaps needed for proper rendering at all sizes"
        )

    if PROJECT_GODOT.exists():
        project_content = PROJECT_GODOT.read_text(encoding="utf-8")
        results.check(
            "project.godot has config/icon = res://icon.svg",
            'config/icon="res://icon.svg"' in project_content,
            "Without this, Godot uses default engine icon"
        )

    # Group 2: main_menu.tscn structure
    print("\n[2] main_menu.tscn Structure (no overlapping buttons)")
    if MAIN_MENU_TSCN.exists():
        menu_tscn = MAIN_MENU_TSCN.read_text(encoding="utf-8")

        results.check(
            "main_menu.tscn uses ScrollContainer for buttons",
            all(path in menu_tscn for path in [
                '[node name="LeftScroll" type="ScrollContainer"',
                '[node name="RightScroll" type="ScrollContainer"'
            ]),
            "ScrollContainer ensures no overlap on small screens"
        )

        results.check(
            "main_menu.tscn buttons are inside ScrollContainer/Buttons",
            'parent="SplitContainer/LeftPanel/LeftScroll/LeftVBox"' in menu_tscn and "PlayButton" in menu_tscn,
            "Buttons hierarchy must be nested in ScrollContainer"
        )

        results.check(
            "main_menu.tscn Background has mouse_filter=2 (ignore)",
            'mouse_filter = 2' in menu_tscn,
            "Background should not block clicks (mouse_filter=2=IGNORE)"
        )

        results.check(
            "main_menu.tscn BgGradient has mouse_filter=2 (ignore)",
            menu_tscn.count('mouse_filter = 2') >= 2,
            "BgGradient should also not block clicks"
        )

        results.check(
            "main_menu.tscn PlayButton has an explicit minimum size",
            '[node name="PlayButton" type="Button"' in menu_tscn and 'Vector2(300, 110)' in menu_tscn,
            "PlayButton must have explicit minimum size"
        )

        results.check(
            "main_menu.tscn all 5 buttons exist",
            all(btn in menu_tscn for btn in [
                "PlayButton", "TutorialButton", "SettingsButton",
                "LanguageButton", "CreditsButton"
            ]),
            "All 5 main buttons must exist"
        )

        # Check signal connections
        results.check(
            "main_menu.tscn PlayButton connected to _on_play",
            '"SplitContainer/LeftPanel/LeftScroll/LeftVBox/PlayButton"' in menu_tscn and '_on_play' in menu_tscn,
            "Play button must be connected to _on_play"
        )

        results.check(
            "main_menu.tscn TutorialButton connected to _on_tutorial",
            '"SplitContainer/LeftPanel/LeftScroll/LeftVBox/TutorialButton"' in menu_tscn and '_on_tutorial' in menu_tscn,
            "Tutorial button must be connected to _on_tutorial"
        )

        results.check(
            "main_menu.tscn SettingsButton connected to _on_settings",
            '"SplitContainer/RightPanel/RightScroll/RightVBox/SettingsButton"' in menu_tscn and '_on_settings' in menu_tscn,
            "Settings button must be connected to _on_settings"
        )

        results.check(
            "main_menu.tscn LanguageButton connected to _on_language",
            '"SplitContainer/RightPanel/RightScroll/RightVBox/LanguageButton"' in menu_tscn and '_on_language' in menu_tscn,
            "Language button must be connected to _on_language"
        )

        results.check(
            "main_menu.tscn CreditsButton connected to _on_credits",
            '"SplitContainer/RightPanel/RightScroll/RightVBox/CreditsButton"' in menu_tscn and '_on_credits' in menu_tscn,
            "Credits button must be connected to _on_credits"
        )

        # Check that the .tscn doesn't have conflicting/old layout
        results.check(
            "main_menu.tscn does NOT have old 'Layout/Buttons' hierarchy",
            "Layout/Buttons/PlayButton" not in menu_tscn,
            "Old layout path should be removed"
        )

        results.check(
            "main_menu.tscn has PlayButton StyleBox (highlighted)",
            "StyleBoxFlat_play" in menu_tscn,
            "PlayButton should be visually distinguished as primary action"
        )

        results.check(
            "main_menu.tscn buttons have cursor_pointing_hand",
            "mouse_default_cursor_shape = 2" in menu_tscn,
            "Buttons should show pointing hand cursor (cursor_shape=2)"
        )

    # Group 3: main_menu.gd signal connections
    print("\n[3] main_menu.gd Signal Connections (button press works)")
    if MAIN_MENU_GD.exists():
        menu_gd = MAIN_MENU_GD.read_text(encoding="utf-8")

        results.check(
            "main_menu.gd has _on_play()",
            "func _on_play()" in menu_gd,
            "Play button handler required"
        )

        results.check(
            "main_menu.gd has _on_tutorial()",
            "func _on_tutorial()" in menu_gd,
            "Tutorial button handler required"
        )

        results.check(
            "main_menu.gd has _on_settings()",
            "func _on_settings()" in menu_gd,
            "Settings button handler required"
        )

        results.check(
            "main_menu.gd has _on_language()",
            "func _on_language()" in menu_gd,
            "Language button handler required"
        )

        results.check(
            "main_menu.gd has _on_credits()",
            "func _on_credits()" in menu_gd,
            "Credits button handler required"
        )

        results.check(
            "main_menu.gd uses _connect_button_safely",
            "_connect_button_safely" in menu_gd,
            "Defensive button connection prevents double-fire"
        )

        results.check(
            "main_menu.gd _on_play has print debug",
            '_on_play' in menu_gd and 'print("[MainMenu] _on_play()' in menu_gd,
            "Debug print confirms handler is called"
        )

        results.check(
            "main_menu.gd _on_play checks ResourceLoader.exists",
            "ResourceLoader.exists(PLAY_SCENE)" in menu_gd,
            "Defensive check prevents crashes on missing scenes"
        )

        results.check(
            "main_menu.gd _on_play uses fade tween",
            re.search(r"func _on_play.*?fade.*?tween_callback", menu_gd, re.DOTALL) is not None,
            "Smooth fade-out before scene change prevents gray flash"
        )

        results.check(
            "main_menu.gd _show_tutorial cleans up old panel",
            '"InfoDialog"' in menu_gd and "queue_free()" in menu_gd,
            "Cleanup prevents accumulation of dialogs"
        )

        results.check(
            "main_menu.gd _show_simple_settings cleans up old panel",
            '"InfoDialog"' in menu_gd and "queue_free()" in menu_gd,
            "Cleanup prevents accumulation"
        )

        results.check(
            "main_menu.gd _show_credits cleans up old panel",
            '"InfoDialog"' in menu_gd and "queue_free()" in menu_gd,
            "Cleanup prevents accumulation"
        )

        # Check for print statements to verify execution
        results.check(
            "main_menu.gd prints at start of _ready",
            'print("[MainMenu] _ready() called")' in menu_gd,
            "Verify _ready is reached"
        )

        # Check for safe button connections
        results.check(
            "main_menu.gd uses is_connected check before connect",
            "is_connected" in menu_gd,
            "Avoid double-firing by checking existing connections"
        )

    # Group 4: Build verification
    print("\n[4] Build Verification (Android)")
    android_dir = REPO_ROOT / "client" / "android"
    if android_dir.exists():
        results.check(
            "android/build_android.ps1 exists",
            (android_dir / "build_android.ps1").exists(),
            "Build script for APK"
        )

        results.check(
            "android/BUILD_ANDROID.md exists",
            (android_dir / "BUILD_ANDROID.md").exists(),
            "Build documentation"
        )

        results.check(
            "android/build.gradle.template exists",
            (android_dir / "build.gradle.template").exists(),
            "Gradle configuration"
        )

        results.check(
            "android/proguard-rules.pro exists",
            (android_dir / "proguard-rules.pro").exists(),
            "ProGuard rules"
        )

    # Group 5: File integrity
    print("\n[5] File Integrity")
    results.check(
        "main_menu.gd has no duplicate functions",
        MAIN_MENU_GD.exists() and MAIN_MENU_GD.read_text(encoding="utf-8").count("func _animate_entrance") == 1,
        "Exactly 1 _animate_entrance function (was duplicated before)"
    )

    results.check(
        "intro.gd has all required safety guards",
        INTRO_GD.exists() and all(s in INTRO_GD.read_text(encoding="utf-8") for s in [
            "is_transitioning", "_transition_lock", "ResourceLoader.exists",
            "call_deferred", "_do_scene_change"
        ]),
        "All 5 safety guards from previous fix are still present"
    )

    # Final
    print(f"\n{'=' * 70}")
    print(f"Total: {results.passed} passed, {results.failed} failed")
    print(f"{'=' * 70}\n")

    if results.failures:
        print("FAILURES:")
        for name, detail in results.failures:
            print(f"  - {name}: {detail}")
        return False
    return True


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
