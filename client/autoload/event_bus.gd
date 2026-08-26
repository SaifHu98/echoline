extends Node

# Decoupled Central Event Router for ECHO//LINE (أصداء)

# Network & Room Lifecycle
signal network_connected()
signal network_disconnected()
signal network_status_changed(state: String, detail: String)
signal room_joined(room_code: String, assigned_timeline: String, is_reconnect: bool)
signal lobby_updated(roster: Variant)
signal match_started(match_id: String, initial_state: Dictionary)
signal match_state_updated(state: Dictionary)
signal match_concluded(recap: Dictionary)
signal network_error(reason: String)
signal player_disconnected_notice(player_id: String, timeline: String, seconds_left: int)

# State & Causal Echoes
signal echo_propagated(echo_id: String, loc_key: String, audio_cue: String, visual_ripple: String, deltas: Array)
signal state_delta_received(delta: Dictionary)
signal catastrophe_updated(remaining_ms: int, stability_pct: float, stage_name: String)

# Local Gameplay & Interaction
signal interact_requested(entity_id: String, action_id: String)
signal item_selected(item_id: String)
signal smart_ping_triggered(ping_id: String, world_pos: Vector3)
signal quick_message_sent(intent_id: String, args: Dictionary)
signal quick_message_received(sender_timeline: String, intent_id: String, args: Dictionary)
signal ping_received(sender_timeline: String, ping_id: String, world_pos: Vector2)

# UI & Accessibility
signal locale_changed(new_locale: String, is_rtl: bool)
signal contrast_mode_changed(high_contrast: bool)
signal motion_mode_changed(reduced_motion: bool)
signal text_scale_changed(scale_factor: float)
signal subtitle_requested(text: String, duration_sec: float)

