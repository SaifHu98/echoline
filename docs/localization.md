# Localization & BiDi Architecture — ECHO//LINE (أصداء)

## 1. Principles
* **Semantic Keys**: Key names are stable semantic tokens (e.g. `menu.play`, `echo.divert_canal_water`).
* **Zero Hardcoded Text**: No hardcoded visible strings in scripts, shaders, or scene files.
* **BiDi & RTL Engine**: Native Right-To-Left layout switching in Godot 4.

## 2. Arabic & RTL Implementation Details
* **Text Direction**: Setting Arabic automatically updates `get_tree().root.layout_direction = Control.LAYOUT_DIRECTION_RTL`.
* **Logical Flow**: Buttons align text to right in Arabic, left in English.
* **Placeholder Protection**: Dynamic variables (e.g. `{code}`, `{seconds}`) are wrapped with Unicode BiDi isolation characters (`\u2068` and `\u2069`) to prevent Latin or numeric tokens from disrupting Arabic sentence flow.

## 3. Pseudo-Localization
* `qps_expanded`: Expands Latin text by ~40% with accented characters to detect UI clipping.
* `qps_mirrored`: Reverses and mirrors Latin glyphs to stress-test RTL directionality and layout symmetry.

## 4. Validation
Run `python tools/localization_validator.py` before every build to guarantee 100% key parity and placeholder integrity.
