@tool
class_name WorldMap
extends Resource

## Zentrale Registry aller Spielszenen (Dioramen) in Barnaby.

@export var start_scene_id: StringName = &""
@export var scenes: Array[WorldMapEntry] = []

func get_entry(p_scene_id: StringName) -> WorldMapEntry:
	for entry in scenes:
		if entry and entry.scene_id == p_scene_id:
			return entry
	return null

func get_scene_path(p_scene_id: StringName) -> String:
	var entry := get_entry(p_scene_id)
	return entry.scene_path if entry else ""

func get_display_name(p_scene_id: StringName) -> String:
	var entry := get_entry(p_scene_id)
	return entry.display_name if entry else str(p_scene_id)

func has_scene(p_scene_id: StringName) -> bool:
	return get_entry(p_scene_id) != null

func is_test_scene(p_scene_id: StringName) -> bool:
	var entry := get_entry(p_scene_id)
	return entry.is_test if entry else false

func get_game_entries() -> Array[WorldMapEntry]:
	var result: Array[WorldMapEntry] = []
	for entry in scenes:
		if entry and not entry.is_test:
			result.append(entry)
	return result

func find_scene_id_by_path(p_path: String) -> StringName:
	for entry in scenes:
		if entry and entry.scene_path == p_path:
			return entry.scene_id
	return &""

