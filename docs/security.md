# Security, Privacy & Player Safety — ECHO//LINE (أصداء)

## 1. Threat Model & Mitigations

| Threat | Impact | Server Mitigation |
| :--- | :--- | :--- |
| **Packet Flooding / Spam** | Server starvation | Token-bucket rate limiter per connection (30 max tokens, 10 refill/sec). |
| **State Mutation Spoofing** | Invalid world state | Clients transmit semantic intents; server validates preconditions authoritatively. |
| **BiDi / Unicode Attacks** | UI corruption / XSS | Strict string sanitization stripping ASCII/Unicode control characters. |
| **Griefing / Abuse** | Player harassment | Semantic-only quick messages avoid toxic typing; player mute/kick support. |

## 2. Privacy & Data Minimization
* No personal data, location, or contact permissions collected.
* Guest accounts supported with ephemeral session identifiers.
* Ephemeral in-memory room lifecycle; match logs discarded after recap generation.
