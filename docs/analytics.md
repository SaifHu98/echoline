# Analytics & Telemetry Specification — ECHO//LINE (أصداء)

In accordance with Section 21 of `promat.md`, this document defines the opt-in, privacy-preserving gameplay telemetry system used solely for scenario balance and design validation.

---

## 1. Privacy & Legal Guardrails
* **Opt-In Only**: Analytics are disabled by default and require explicit player consent on initial setup.
* **Zero PII**: No device identifiers, IP addresses, names, or chat/voice contents are ever recorded.
* **Gameplay Fully Functional Offline**: The game functions 100% identically when analytics are disabled.

---

## 2. Telemetry Event Schema

| Event Name | Trigger Condition | Payload Properties |
| :--- | :--- | :--- |
| `match_started` | All 3 players ready up | `match_id`, `scenario_id`, `seed`, `locale_combination` |
| `match_completed` | Victory or Defeat reached | `match_id`, `outcome_id`, `outcome_grade`, `duration_sec`, `echo_count` |
| `timeline_assigned` | Role confirmed in lobby | `match_id`, `timeline` (`past` / `present` / `future`) |
| `echo_triggered` | Preconditions verified & delta applied | `echo_id`, `source_timeline`, `elapsed_sec` |
| `player_disconnected` | Client socket closes | `match_id`, `timeline`, `match_stage` |
| `reconnection_succeeded` | Client rejoins within 60s | `match_id`, `timeline`, `recovery_duration_sec` |
| `quick_message_used` | Semantic message sent | `intent_id`, `sender_timeline` |
| `smart_ping_used` | Radial ping dispatched | `ping_id`, `sender_timeline` |

---

## 3. Design Validation Metrics
These event streams allow designers to evaluate:
1. **Role Engagement**: Are all three timelines actively interacting or is one role passive?
2. **Ping Adoption**: How effectively do players communicate across different languages using semantic pings?
3. **Branch Diversity**: Is `perfect_restoration` or `city_saved_with_sacrifices` chosen with balanced frequency?
4. **RTL UX Friction**: Are Arabic RTL users experiencing higher drop-off at any specific interaction points?
