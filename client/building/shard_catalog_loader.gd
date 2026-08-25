class_name ShardCatalogLoader
extends RefCounted

const CATALOG_PATH := "res://shared/shards/catalog.json"

static func load_catalog() -> Dictionary:
	var path: String = ProjectSettings.globalize_path(CATALOG_PATH)
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("ShardCatalogLoader: catalog not found at %s" % path)
		return {}
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("ShardCatalogLoader: failed to open catalog")
		return {}
	var content: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	var err := parser.parse(content)
	if err != OK:
		push_error("ShardCatalogLoader: JSON parse error at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return {}
	var data = parser.data
	if typeof(data) != TYPE_DICTIONARY or not data.has("shards"):
		push_error("ShardCatalogLoader: invalid catalog structure")
		return {}
	return data

static func shard_def(catalog: Dictionary, shard_id: String) -> Dictionary:
	if not catalog.has("shards"):
		return {}
	var shards: Dictionary = catalog.shards
	return shards.get(shard_id, {})

static func shards_for_timeline(catalog: Dictionary, timeline: String) -> Array:
	var result: Array = []
	if not catalog.has("shards"):
		return result
	for shard_id in catalog.shards:
		var def: Dictionary = catalog.shards[shard_id]
		if def.get("timeline") == timeline:
			result.append(def)
	return result

static func display_name(catalog: Dictionary, shard_id: String, locale: String = "en") -> String:
	var def := shard_def(catalog, shard_id)
	if def.is_empty():
		return shard_id
	var names: Dictionary = def.get("display_name", {"en": shard_id})
	return names.get(locale, names.get("en", shard_id))