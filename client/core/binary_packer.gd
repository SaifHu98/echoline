class_name BinaryPacker
extends RefCounted

# Client-Side Binary Message Packer and Unpacker for Mobile Network Optimization

enum Opcode {
	CONNECT = 0x01,
	JOIN_ROOM = 0x02,
	READY_TOGGLE = 0x03,
	SEND_PING = 0x04,
	SEND_MESSAGE = 0x05,
	TRIGGER_INTENT = 0x06,
	STATE_SYNC = 0x07,
	HEARTBEAT = 0x08
}

static func pack_intent(timeline: String, entity_id: String, action: String) -> PackedByteArray:
	var packet = PackedByteArray()
	packet.append(Opcode.TRIGGER_INTENT)

	var timeline_code = 1
	if timeline == "present": timeline_code = 2
	elif timeline == "future": timeline_code = 3
	packet.append(timeline_code)

	var entity_bytes = entity_id.to_utf8_buffer()
	packet.append(entity_bytes.size())
	packet.append_array(entity_bytes)

	var action_bytes = action.to_utf8_buffer()
	packet.append(action_bytes.size())
	packet.append_array(action_bytes)

	return packet

static func unpack(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty():
		return {}

	var opcode = packet[0]
	if opcode == Opcode.TRIGGER_INTENT:
		var timeline_code = packet[1]
		var timeline = "past"
		if timeline_code == 2: timeline = "present"
		elif timeline_code == 3: timeline = "future"

		var entity_len = packet[2]
		var entity_bytes = packet.slice(3, 3 + entity_len)
		var entity_id = entity_bytes.get_string_from_utf8()

		var action_offset = 3 + entity_len
		var action_len = packet[action_offset]
		var action_bytes = packet.slice(action_offset + 1, action_offset + 1 + action_len)
		var action = action_bytes.get_string_from_utf8()

		return {
			"type": "TRIGGER_INTENT",
			"payload": {
				"timeline": timeline,
				"entityId": entity_id,
				"action": action
			}
		}

	return {}
