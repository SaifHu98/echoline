# Testing Suite & QA Guidelines — ECHO//LINE (أصداء)

## 1. Automated Test Suites

### 1. Server & Multiplayer Tests (Node.js)
```bash
cd server
npm test
```
Tests:
* `echo_engine.test.js`: Precondition evaluation, state mutation, timeline mismatch rejection.
* `multiplayer_flow.test.js`: 3-player private room lifecycle, role assignment, ready initiation, cross-timeline echo synchronization, victory recap.
* `disconnect_recovery.test.js`: 60-second recovery window and seamless state snapshot restoration.

### 2. Localization & BiDi Validator (Python)
```bash
python tools/localization_validator.py
```
Tests:
* 100% key parity across `en.json`, `ar.json`, `qps_expanded.json`, `qps_mirrored.json`.
* Placeholder token preservation (`{code}`, `{seconds}`, `{count}`, `{percent}`).

### 3. Scenario Reachability & Causal Cycle Solver (Python)
```bash
python tools/scenario_validator.py
```
Tests:
* Graph acyclicity.
* Solvability reachability from initial state to multiple victory grades (`perfect_restoration` & `city_saved_with_sacrifices`).
* Proves multi-timeline cooperation requirement.
