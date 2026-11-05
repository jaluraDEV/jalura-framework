@tool
class_name WorldMapEntry
extends Resource

## Repräsentiert einen Eintrag in der zentralen Weltkarten-Registry.

@export var scene_id: StringName = &""
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
@export var is_test: bool = false

func _init(p_scene_id: StringName = &"", p_display_name: String = "", p_scene_path: String = "", p_is_test: bool = false) -> void:
	scene_id = p_scene_id
	display_name = p_display_name
	scene_path = p_scene_path
	is_test = p_is_test
