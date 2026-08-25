#!/usr/bin/env python3
"""
Pseudo-Localization Generator for ECHO//LINE (أصداء)
Generates:
  1. qps-expanded: ~40% text expansion with accented Latin glyphs to test UI clipping.
  2. qps-mirrored: Character-mirrored RTL testing locale with preserved placeholders.
"""

import json
import re
import os

ACCENT_MAP = {
    'a': 'á', 'b': 'ḅ', 'c': 'ç', 'd': 'ḍ', 'e': 'é', 'f': 'ḟ', 'g': 'ğ',
    'h': 'ḥ', 'i': 'í', 'j': 'ĵ', 'k': 'ḳ', 'l': 'ḷ', 'm': 'ṃ', 'n': 'ñ',
    'o': 'ó', 'p': 'ṗ', 'q': 'ʠ', 'r': 'ṛ', 's': 'š', 't': 'ṭ', 'u': 'ú',
    'v': 'ṿ', 'w': 'ŵ', 'x': 'ẋ', 'y': 'ý', 'z': 'ž',
    'A': 'Á', 'B': 'Ḅ', 'C': 'Ç', 'D': 'Ḍ', 'E': 'É', 'F': 'Ḟ', 'G': 'Ğ',
    'H': 'Ḥ', 'I': 'Í', 'J': 'Ĵ', 'K': 'Ḳ', 'L': 'Ḷ', 'M': 'Ṃ', 'N': 'Ñ',
    'O': 'Ó', 'P': 'Ṗ', 'Q': 'Ǫ', 'R': 'Ṛ', 'S': 'Š', 'T': 'Ṭ', 'U': 'Ú',
    'V': 'Ṿ', 'W': 'Ŵ', 'X': 'Ẋ', 'Y': 'Ý', 'Z': 'Ž'
}

MIRROR_MAP = {
    'a': 'ɐ', 'b': 'q', 'c': 'ɔ', 'd': 'p', 'e': 'ǝ', 'f': 'ɟ', 'g': 'ƃ',
    'h': 'ɥ', 'i': 'ᴉ', 'j': 'ɾ', 'k': 'ʞ', 'l': 'ʃ', 'm': 'ɯ', 'n': 'u',
    'o': 'o', 'p': 'd', 'q': 'b', 'r': 'ɹ', 's': 's', 't': 'ʇ', 'u': 'n',
    'v': 'ʌ', 'w': 'ʍ', 'x': 'x', 'y': 'ʎ', 'z': 'z',
    '(': ')', ')': '(', '[': ']', ']': '[', '<': '>', '>': '<', '{': '}', '}': '{'
}

PLACEHOLDER_REGEX = re.compile(r'(\{[a-zA-Z0-9_]+\})')

def transform_expanded(text: str) -> str:
    tokens = PLACEHOLDER_REGEX.split(text)
    transformed_tokens = []
    for token in tokens:
        if PLACEHOLDER_REGEX.match(token):
            transformed_tokens.append(token)
        else:
            acc_chars = [ACCENT_MAP.get(c, c) for c in token]
            acc_str = "".join(acc_chars)
            # Expand length by ~40% with pad characters
            if len(acc_str.strip()) > 3:
                expansion = " " + "~" * max(1, int(len(acc_str) * 0.35))
                acc_str = acc_str + expansion
            transformed_tokens.append(acc_str)
    return f"⟦{ ''.join(transformed_tokens) }⟧"

def transform_mirrored(text: str) -> str:
    tokens = PLACEHOLDER_REGEX.split(text)
    transformed_tokens = []
    for token in tokens:
        if PLACEHOLDER_REGEX.match(token):
            # BiDi isolate placeholders so they stay legible
            transformed_tokens.append(f"\u2068{token}\u2069")
        else:
            mirrored = "".join(MIRROR_MAP.get(c, c) for c in reversed(token))
            transformed_tokens.append(mirrored)
    # Wrap in RTL embedding
    return f"\u200f⁅{''.join(transformed_tokens)}⁆\u200f"

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    en_path = os.path.join(base_dir, "shared", "localization", "en.json")
    expanded_path = os.path.join(base_dir, "shared", "localization", "qps_expanded.json")
    mirrored_path = os.path.join(base_dir, "shared", "localization", "qps_mirrored.json")

    with open(en_path, "r", encoding="utf-8") as f:
        en_catalog = json.load(f)

    expanded_catalog = {k: transform_expanded(v) for k, v in en_catalog.items()}
    mirrored_catalog = {k: transform_mirrored(v) for k, v in en_catalog.items()}

    with open(expanded_path, "w", encoding="utf-8") as f:
        json.dump(expanded_catalog, f, ensure_ascii=False, indent=2)

    with open(mirrored_path, "w", encoding="utf-8") as f:
        json.dump(mirrored_catalog, f, ensure_ascii=False, indent=2)

    print(f"[OK] Generated {len(expanded_catalog)} pseudo-expanded keys -> {expanded_path}")
    print(f"[OK] Generated {len(mirrored_catalog)} pseudo-mirrored keys -> {mirrored_path}")

if __name__ == "__main__":
    main()
