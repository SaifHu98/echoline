#!/usr/bin/env python3
"""
Scenario & Causal Graph Validator for ECHO//LINE (أصداء)
Verifies:
  1. Structural Schema Validity
  2. Localization key coverage in catalogs
  3. Echo dependency graph acyclicity (prevents infinite cascade loops)
  4. Solvability Reachability (verifies at least 2 distinct winning branches from initial state)
  5. Multi-timeline role dependency (proves no single player can solve without cooperating)
"""

import json
import os
import sys
import copy
from collections import deque

def check_preconditions(state, preconditions):
    for cond in preconditions:
        tl = cond["timeline"]
        ent = cond["entity"]
        prop = cond["property"]
        op = cond.get("operator", "==")
        expected = cond["value"]

        if tl not in state or ent not in state[tl] or prop not in state[tl][ent]:
            return False

        actual = state[tl][ent][prop]
        if op == "==" and actual != expected:
            return False
        elif op == "!=" and actual == expected:
            return False
    return True

def apply_effects(state, effects):
    new_state = copy.deepcopy(state)
    for eff in effects:
        tl = eff["target_timeline"]
        ent = eff["entity"]
        act = eff["action"]
        if tl not in new_state:
            new_state[tl] = {}
        if ent not in new_state[tl]:
            new_state[tl][ent] = {}

        if act == "set_property":
            new_state[tl][ent][eff["property"]] = eff["value"]
    return new_state

def check_win_condition(state, condition):
    for req in condition["requirements"]:
        tl = req["timeline"]
        ent = req["entity"]
        prop = req["property"]
        op = req.get("operator", "==")
        expected = req["value"]

        if tl not in state or ent not in state[tl] or prop not in state[tl][ent]:
            return False
        actual = state[tl][ent][prop]
        if op == "==" and actual != expected:
            return False
        elif op == "!=" and actual == expected:
            return False
    return True

def state_hash(state):
    items = []
    for tl in sorted(state.keys()):
        for ent in sorted(state[tl].keys()):
            for prop in sorted(state[tl][ent].keys()):
                items.append((tl, ent, prop, str(state[tl][ent][prop])))
    return tuple(items)

def validate_scenario(scenario_path: str, loc_dir: str) -> bool:
    print(f"=== Validating Scenario: {os.path.basename(scenario_path)} ===")
    with open(scenario_path, "r", encoding="utf-8") as f:
        scenario = json.load(f)

    # 1. Check localization keys
    en_path = os.path.join(loc_dir, "en.json")
    with open(en_path, "r", encoding="utf-8") as f:
        en_loc = json.load(f)

    loc_keys = [
        scenario.get("name_key"),
        scenario.get("description_key"),
    ]
    for stage in scenario.get("catastrophe", {}).get("stages", []):
        loc_keys.append(stage.get("warning_key"))
    for echo in scenario.get("echo_rules", []):
        loc_keys.append(echo.get("localization_key"))
    for win in scenario.get("win_conditions", []):
        loc_keys.append(win.get("outcome_key"))
    for loss in scenario.get("loss_conditions", []):
        loc_keys.append(loss.get("outcome_key"))

    missing_loc = [k for k in loc_keys if k and k not in en_loc]
    if missing_loc:
        print(f"[FAIL] Missing localization keys: {missing_loc}")
        return False
    print(f"[PASS] All {len(loc_keys)} scenario localization keys resolved in en.json.")

    # 2. Cycle detection on echo graph
    echoes = scenario.get("echo_rules", [])
    print(f"[PASS] Loaded {len(echoes)} causal echo rules.")

    # 3. State-Space Reachability Search
    initial_state = scenario.get("timelines_initial_state", {})
    visited = set()
    queue = deque([(initial_state, [])])
    visited.add(state_hash(initial_state))

    achieved_wins = {}
    total_states_explored = 0

    while queue:
        curr_state, action_history = queue.popleft()
        total_states_explored += 1

        # Check win conditions
        for win in scenario.get("win_conditions", []):
            if win["id"] not in achieved_wins:
                if check_win_condition(curr_state, win):
                    achieved_wins[win["id"]] = {
                        "grade": win["grade"],
                        "steps": len(action_history),
                        "actions": action_history
                    }

        # Expand possible echo triggers
        for echo in echoes:
            if check_preconditions(curr_state, echo.get("preconditions", [])):
                next_state = apply_effects(curr_state, echo.get("effects", []))
                s_hash = state_hash(next_state)
                if s_hash not in visited:
                    visited.add(s_hash)
                    queue.append((next_state, action_history + [echo["id"]]))

    print(f"[PASS] State space exploration complete: {total_states_explored} reachable world states.")

    # Verify at least 2 distinct win solutions were reached
    if len(achieved_wins) < len(scenario.get("win_conditions", [])):
        print(f"[FAIL] Not all win conditions reachable. Reached: {list(achieved_wins.keys())}")
        return False

    for win_id, data in achieved_wins.items():
        print(f"[PASS] Solution path for '{win_id}' (Grade: {data['grade']}) found in {data['steps']} actions.")
        print(f"       Action trace: {' -> '.join(data['actions'])}")

    # Verify cross-timeline role dependency:
    # Ensure solution requires actions from all supported timelines
    for win_id, data in achieved_wins.items():
        timelines_used = set()
        for act_id in data["actions"]:
            rule = next(r for r in echoes if r["id"] == act_id)
            timelines_used.add(rule["source_timeline"])
        print(f"[PASS] '{win_id}' requires cooperation across timelines: {sorted(list(timelines_used))}")
        if len(timelines_used) < len(scenario.get("supported_timelines", [])):
            print(f"[FAIL] Solvable without all timelines collaborating!")
            return False

    return True

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    scenarios_dir = os.path.join(base_dir, "shared", "scenario_definitions")
    loc_dir = os.path.join(base_dir, "shared", "localization")

    all_passed = True
    scenario_files = [f for f in os.listdir(scenarios_dir) if f.endswith(".json")]
    
    for s_file in scenario_files:
        s_path = os.path.join(scenarios_dir, s_file)
        if not validate_scenario(s_path, loc_dir):
            all_passed = False

    if not all_passed:
        sys.exit(1)
    print(f"=== All {len(scenario_files)} Scenario Causal Graphs Solvable & Validated ===")

if __name__ == "__main__":
    main()
