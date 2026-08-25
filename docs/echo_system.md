# The Temporal Echo System — ECHO//LINE (أصداء)

## 1. Overview
The **Temporal Echo System** is a data-driven causal graph simulation engine. Every meaningful action taken in one timeline produces validated, deterministic consequences across other timelines.

## 2. Echo Rule Structure
Each echo is defined using a declarative schema:
```json
{
  "id": "echo_divert_canal_water",
  "source_timeline": "past",
  "source_entity": "canal_sluice_gate",
  "trigger_action": "open_sluice_gate",
  "preconditions": [
    { "timeline": "past", "entity": "canal_debris", "property": "state", "operator": "==", "value": "cleared" }
  ],
  "effects": [
    { "target_timeline": "past", "entity": "canal_sluice_gate", "action": "set_property", "property": "state", "value": "open" },
    { "target_timeline": "present", "entity": "canal_basin", "action": "set_property", "property": "water_level", "value": "flowing", "propagation_delay_ms": 600 },
    { "target_timeline": "future", "entity": "hydro_turbine", "action": "set_property", "property": "status", "value": "water_powered", "propagation_delay_ms": 1200 }
  ],
  "reversible": false,
  "conflict_priority": 80,
  "localization_key": "echo.divert_canal_water",
  "audio_cue": "sfx_water_flow_surge",
  "visual_ripple": "temporal_wave_cyan"
}
```

## 3. Causal Propagation & Cycle Prevention
1. **Precondition Checks**: Evaluated atomically on the server.
2. **Conflict Priority**: When simultaneous opposing actions occur, the echo with the highest `conflict_priority` takes precedence.
3. **Propagation Delays**: Simulated timeline ripple travel times (`propagation_delay_ms`) provide dramatic player feedback while maintaining strict causality order.
4. **Cycle Prevention**: Offline validator (`tools/scenario_validator.py`) statically guarantees that no circular infinite cascades exist.
