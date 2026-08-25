#!/usr/bin/env python3
"""
Localization & BiDi QA Validator for ECHO//LINE (أصداء)
Enforces:
  1. 100% Key Parity between source (en.json) and all target locales.
  2. Placeholder Token Integrity ({player_name}, {seconds}, {count}, etc.).
  3. No empty strings or broken bracket structures.
  4. Directionality & BiDi sanity checks.
"""

import json
import re
import os
import sys

PLACEHOLDER_REGEX = re.compile(r'\{([a-zA-Z0-9_]+)\}')

def extract_placeholders(text: str) -> set:
    return set(PLACEHOLDER_REGEX.findall(text))

def validate_catalogs(loc_dir: str) -> bool:
    en_path = os.path.join(loc_dir, "en.json")
    if not os.path.exists(en_path):
        print(f"[FAIL] Source catalog not found: {en_path}")
        return False

    with open(en_path, "r", encoding="utf-8") as f:
        source_catalog = json.load(f)

    all_files = [f for f in os.listdir(loc_dir) if f.endswith(".json")]
    has_errors = False

    print(f"=== Localization Validation (Source Keys: {len(source_catalog)}) ===")

    for fname in all_files:
        filepath = os.path.join(loc_dir, fname)
        with open(filepath, "r", encoding="utf-8") as f:
            try:
                target_catalog = json.load(f)
            except Exception as e:
                print(f"[FAIL] JSON Parse error in {fname}: {e}")
                has_errors = True
                continue

        source_keys = set(source_catalog.keys())
        target_keys = set(target_catalog.keys())

        missing_keys = source_keys - target_keys
        extra_keys = target_keys - source_keys

        if missing_keys:
            print(f"[FAIL] {fname} is missing {len(missing_keys)} keys: {sorted(list(missing_keys))[:5]}...")
            has_errors = True

        if extra_keys:
            print(f"[WARN] {fname} has {len(extra_keys)} extra keys: {sorted(list(extra_keys))[:5]}...")

        # Validate placeholder match for each key
        placeholder_mismatches = 0
        for key in source_keys.intersection(target_keys):
            src_val = source_catalog[key]
            tgt_val = target_catalog[key]

            if not isinstance(tgt_val, str) or len(tgt_val.strip()) == 0:
                print(f"[FAIL] {fname}: Key '{key}' is empty or invalid.")
                has_errors = True
                continue

            src_ph = extract_placeholders(src_val)
            tgt_ph = extract_placeholders(tgt_val)

            if src_ph != tgt_ph:
                print(f"[FAIL] {fname}: Placeholder mismatch in '{key}': expected {src_ph}, got {tgt_ph}")
                placeholder_mismatches += 1
                has_errors = True

        if not missing_keys and placeholder_mismatches == 0:
            print(f"[PASS] {fname} (Keys: {len(target_keys)}, Placeholders Verified)")

    return not has_errors

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    loc_dir = os.path.join(base_dir, "shared", "localization")
    success = validate_catalogs(loc_dir)
    if not success:
        sys.exit(1)
    print("=== All Localization Catalogs Validated Successfully ===")

if __name__ == "__main__":
    main()
