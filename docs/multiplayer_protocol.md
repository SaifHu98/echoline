# Multiplayer Protocol — ECHO//LINE (أصداء)

## 1. Network Topology
* **Transport**: Dedicated WebSocket connection (`ws://<host>:<port>`).
* **Format**: Structured JSON packets adhering to `shared/schemas/protocol.schema.json`.
* **State Sync**: Delta updates with monotonic `seq` identifiers.

## 2. Core Protocol Opcodes

| Opcode | Sender | Description |
| :--- | :--- | :--- |
| `JOIN_ROOM_REQUEST` | Client | Requests room join by 4-char code or room creation |
| `JOIN_ROOM_SUCCESS` | Server | Confirms room code, assigned timeline role, and roster |
| `PLAYER_READY` | Client | Toggles ready state and timeline role preference |
| `MATCH_START` | Server | Initiates the match and broadcasts initial world state |
| `PLAYER_INTENT` | Client | Submits semantic player action intent (`echo_id`) |
| `ECHO_PROPAGATED` | Server | Broadcasts validated echo effects, audio cue, and deltas |
| `CATASTROPHE_UPDATE` | Server | Periodic timer tick (remaining ms, stability %, stage) |
| `SEMANTIC_PING` | Client/Server | Broadcasts smart pings (zero text on wire) |
| `SEMANTIC_QUICK_MSG` | Client/Server | Broadcasts quick message intent ID |
| `MATCH_CONCLUDED` | Server | Broadcasts final outcome and full causal tree recap |
| `PLAYER_DISCONNECTED` | Server | Notifies remaining players of grace window |

## 3. Disconnection Recovery Flow
1. Client drops connection.
2. Server marks player slot as `disconnected` and starts 60-second recovery timer.
3. Client reconnects with same `player_id` and sends `JOIN_ROOM_REQUEST`.
4. Server recognizes returning player, restores timeline role, and transmits full `STATE_SNAPSHOT` and causal history delta.
