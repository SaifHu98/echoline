"""
ECHO//LINE — Gray Screen After Intro Fix Tests
==============================================

Tests verify that the scene transition logic is correct and won't
cause a stuck gray screen after the intro cinematic.

Run with: python -m pytest tests/godot/test_intro_fix.py -v
Or:       python tests/godot/test_intro_fix.py
"""

import re
import sys
from pathlib import Path

# -*- coding: utf-8 -*-
import sys
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
INTRO_GD = REPO_ROOT / "client" / "scenes" / "intro.gd"
MAIN_MENU_GD = REPO_ROOT / "client" / "scenes" / "main_menu.gd"
INTRO_TSCN = REPO_ROOT / "client" / "scenes" / "intro.tscn"
MAIN_MENU_TSCN = REPO_ROOT / "client" / "scenes" / "main_menu.tscn"

# ANSI colors (no colors if redirected)
def _supports_color():
    return sys.stdout.isatty()

class TestResult:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.failures = []

    def check(self, name, condition, detail=""):
        if condition:
            self.passed += 1
            print(f"  \033[32m✔\033[0m {name}" if _supports_color() else f"  ✔ {name}")
        else:
            self.failed += 1
            self.failures.append((name, detail))
            print(f"  \033[31m✗\033[0m {name}" if _supports_color() else f"  ✗ {name}")
            if detail:
                print(f"    \033[33m{detail}\033[0m" if _supports_color() else f"    {detail}")

def run_tests():
    results = TestResult()

    print("\n=== ECHO//LINE Gray Screen Fix Tests ===\n")

    # Group 1: Intro scene
    print("[1] Intro Scene (intro.gd)")
    if not INTRO_GD.exists():
        results.check("intro.gd exists", False, f"not found at {INTRO_GD}")
        return results
    intro_content = INTRO_GD.read_text(encoding="utf-8")

    results.check(
        "intro.gd starts modulate.a = 1.0 (NOT 0.0)",
        "modulate.a = 1.0" in intro_content,
        "If modulate.a starts at 0, the entire scene is invisible from frame 1."
    )

    results.check(
        "intro.gd has background reference",
        "@onready var background: ColorRect = $Background" in intro_content,
        "Need explicit background reference to ensure it stays visible."
    )

    results.check(
        "intro.gd explicitly sets background visible",
        "background.visible = true" in intro_content,
        "Without this, the background could be hidden if parent is invisible."
    )

    results.check(
        "intro.gd has is_transitioning guard",
        "is_transitioning" in intro_content and "if is_transitioning:" in intro_content,
        "Prevents double transition causing stuck scene."
    )

    results.check(
        "intro.gd has _transition_lock",
        "_transition_lock" in intro_content,
        "Prevents re-entry during fade-out."
    )

    results.check(
        "intro.gd uses ResourceLoader.exists check",
        "ResourceLoader.exists" in intro_content,
        "Verifies target scene exists before attempting transition."
    )

    results.check(
        "intro.gd uses change_scene_to_file (NOT packed scene load)",
        "change_scene_to_file" in intro_content,
        "Proper scene change API."
    )

    results.check(
        "intro.gd checks change_scene_to_file return code",
        "change_scene_to_file(NEXT_SCENE_PATH)" in intro_content and "err != OK" in intro_content,
        "Detects failed scene changes."
    )

    results.check(
        "intro.gd has call_deferred fallback",
        "call_deferred" in intro_content,
        "Recovery mechanism if scene change fails."
    )

    results.check(
        "intro.gd fade tween uses callback (not direct scene change)",
        re.search(r"tween_callback\(_do_scene_change\)", intro_content) is not None,
        "Ensures fade completes BEFORE scene changes (prevents gray flash)."
    )

    results.check(
        "intro.gd _process exits early when transitioning",
        re.search(r"func _process.*?if is_transitioning:.*?return", intro_content, re.DOTALL) is not None,
        "Stops time accumulation during transition."
    )

    # Group 2: Main Menu scene
    print("\n[2] Main Menu Scene (main_menu.gd)")
    if not MAIN_MENU_GD.exists():
        results.check("main_menu.gd exists", False, f"not found at {MAIN_MENU_GD}")
        return results
    menu_content = MAIN_MENU_GD.read_text(encoding="utf-8")

    results.check(
        "main_menu.gd starts modulate.a = 1.0 (NOT 0.0)",
        re.search(r"^func _ready.*?modulate\.a = 1\.0", menu_content, re.DOTALL | re.MULTILINE) is not None,
        "Prevents invisible main menu."
    )

    results.check(
        "main_menu.gd explicitly sets Background visible",
        'bg.visible = true' in menu_content,
        "Background visible regardless of parent state."
    )

    results.check(
        "main_menu.gd explicitly sets BgGradient visible",
        'bg_gradient.visible = true' in menu_content,
        "Second background layer visible."
    )

    results.check(
        "main_menu.gd has _connect_event_bus_safely",
        "_connect_event_bus_safely" in menu_content,
        "Defensive EventBus connection (won't crash if missing)."
    )

    results.check(
        "main_menu.gd uses get_node_or_null for EventBus",
        'get_node_or_null("/root/EventBus")' in menu_content,
        "Defensive singleton access."
    )

    results.check(
        "main_menu.gd uses has_method before NetworkClient call",
        'has_method("is_socket_connected")' in menu_content,
        "Defensive method check."
    )

    results.check(
        "main_menu.gd falls back to offline mode",
        "Offline mode" in menu_content or "Offline" in menu_content,
        "Graceful degradation."
    )

    results.check(
        "main_menu.gd has _animate_entrance function (exactly once)",
        menu_content.count("func _animate_entrance") == 1,
        f"Found {menu_content.count('func _animate_entrance')} occurrences (should be 1)."
    )

    results.check(
        "main_menu.gd does NOT use button.position.y += 30 (causes layout shift)",
        "btn.position.y += 30" not in menu_content,
        "Avoids button layout shift on first frame."
    )

    results.check(
        "main_menu.gd has ResourceLoader.exists for Play scene",
        'ResourceLoader.exists(PLAY_SCENE)' in menu_content,
        "Verifies Play scene exists before transition."
    )

    results.check(
        "main_menu.gd _on_play uses fade tween (not instant)",
        re.search(r"_on_play.*?tween_callback.*?change_scene_to_file", menu_content, re.DOTALL) is not None,
        "Smooth transition prevents gray flash on Play."
    )

    # Group 3: Project config
    print("\n[3] Project Configuration")
    project_godot = REPO_ROOT / "client" / "project.godot"
    if project_godot.exists():
        project_content = project_godot.read_text(encoding="utf-8")
        results.check(
            "main_scene = intro.tscn",
            'run/main_scene="res://scenes/intro.tscn"' in project_content,
            "Game launches to intro."
        )

        results.check(
            "EventBus autoload registered",
            'EventBus="*res://autoload/event_bus.gd"' in project_content,
            "EventBus singleton available."
        )

        results.check(
            "NetworkClient autoload registered",
            'NetworkClient="*res://autoload/network_client.gd"' in project_content,
            "NetworkClient singleton available."
        )

        results.check(
            "Localization autoload registered",
            'Localization="*res://autoload/localization.gd"' in project_content,
            "Localization singleton available."
        )

    # Group 4: Scene file sanity
    print("\n[4] Scene File Structure")
    if INTRO_TSCN.exists():
        intro_tscn = INTRO_TSCN.read_text(encoding="utf-8")
        results.check(
            "intro.tscn has Background node",
            '[node name="Background" type="ColorRect"' in intro_tscn,
            "Background must be present in scene tree."
        )

        results.check(
            "intro.tscn Background has dark color (not gray default)",
            'color = Color(0.02, 0.03, 0.06, 1)' in intro_tscn,
            "Custom dark blue background (not Godot's default gray)."
        )

    if MAIN_MENU_TSCN.exists():
        menu_tscn = MAIN_MENU_TSCN.read_text(encoding="utf-8")
        results.check(
            "main_menu.tscn has Background node",
            '[node name="Background" type="ColorRect"' in menu_tscn,
            "Background must be present."
        )

        results.check(
            "main_menu.tscn has all 5 main buttons",
            all(btn in menu_tscn for btn in ["PlayButton", "TutorialButton", "SettingsButton", "LanguageButton", "CreditsButton"]),
            "All buttons exist in scene tree."
        )

        results.check(
            "main_menu.tscn connects button signals",
            'pressed" from="SplitContainer/LeftPanel/LeftScroll/LeftVBox/PlayButton"' in menu_tscn,
            "Signal connections wired in scene."
        )

    print(f"\n=== Results ===")
    print(f"  Passed: \033[32m{results.passed}\033[0m" if _supports_color() else f"  Passed: {results.passed}")
    print(f"  Failed: \033[31m{results.failed}\033[0m" if _supports_color() else f"  Failed: {results.failed}")
    if results.failures:
        print(f"\n  \033[31mFailures:\033[0m" if _supports_color() else "\n  Failures:")
        for name, detail in results.failures:
            print(f"    - {name}: {detail}")

    return results


if __name__ == "__main__":
    r = run_tests()
    sys.exit(0 if r.failed == 0 else 1)
