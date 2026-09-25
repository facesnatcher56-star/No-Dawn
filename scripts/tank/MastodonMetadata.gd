extends RefCounted
class_name MastodonMetadata
## Manages technical metadata, armor thickness, component HP, and crew roles for A-47 Mastodon.

var metadata: Dictionary = {}
var armor_map: Dictionary = {}
var component_map: Dictionary = {}
var crew_map: Dictionary = {}
var ammo_map: Dictionary = {}

func _init(json_path: String = "res://assets/models/tank/mastodon_metadata.json") -> void:
	load_metadata(json_path)

func load_metadata(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("MastodonMetadata: Metadata file not found at " + path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(text) == OK:
		metadata = json.data
		_index_metadata()
	else:
		push_error("MastodonMetadata: Failed to parse JSON from " + path)

func _index_metadata() -> void:
	armor_map.clear()
	component_map.clear()
	crew_map.clear()
	ammo_map.clear()
	
	for entry in metadata.get("armor_sections", []):
		armor_map[entry.get("name", "")] = entry
		
	for entry in metadata.get("components", []):
		component_map[entry.get("name", "")] = entry
		
	for entry in metadata.get("crew", []):
		crew_map[entry.get("name", "")] = entry
		
	for entry in metadata.get("ammunition_racks", []):
		ammo_map[entry.get("name", "")] = entry

func get_vehicle_info() -> Dictionary:
	return metadata.get("vehicle", {})

func get_armor(plate_name: String) -> Dictionary:
	return armor_map.get(plate_name, {})

func get_armor_plate(plate_name: String) -> Dictionary:
	return get_armor(plate_name)

func get_component(comp_name: String) -> Dictionary:
	return component_map.get(comp_name, {})

func get_crew(crew_name: String) -> Dictionary:
	return crew_map.get(crew_name, {})

func get_crew_member(crew_name: String) -> Dictionary:
	return get_crew(crew_name)

func get_ammo_rack(rack_name: String) -> Dictionary:
	return ammo_map.get(rack_name, {})

func get_all_armor_names() -> Array:
	return armor_map.keys()

func get_all_component_names() -> Array:
	return component_map.keys()

func get_all_crew_names() -> Array:
	return crew_map.keys()

func get_all_ammo_names() -> Array:
	return ammo_map.keys()
