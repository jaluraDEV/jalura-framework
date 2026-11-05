@tool
class_name WorldMapScanner
extends RefCounted

## Scanner für Jalura-Szenen (.tscn):
## Liest Szenendateien schnell als Text, um alle SpawnPoints (Eingänge)
## und TransitionBehaviors / obj_exit (Ausgänge) ohne Instanziierung zu ermitteln.

static func scan_scene_file(file_path: String, world_map: WorldMap = null) -> Dictionary:
	var result := {
		"spawns": [] as Array[Dictionary],
		"exits": [] as Array[Dictionary]
	}

	if not FileAccess.file_exists(file_path):
		return result

	var content := FileAccess.get_file_as_string(file_path)
	if content.is_empty():
		return result

	var lines := content.split("\n")
	var current_node_name := ""
	var current_node_type := ""
	var current_props := {}

	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed.begins_with("[node "):
			# Vorherigen Knoten auswerten
			_evaluate_node(current_node_name, current_node_type, current_props, result, world_map)
			current_props.clear()

			# Neuen Knoten parsen: [node name="Spawn_Default" type="Marker3D" ...
			current_node_name = _extract_attribute(trimmed, "name")
			current_node_type = _extract_attribute(trimmed, "type")
		elif trimmed.begins_with("["):
			# Anderer Block ([ext_resource, [sub_resource etc.)
			_evaluate_node(current_node_name, current_node_type, current_props, result, world_map)
			current_node_name = ""
			current_node_type = ""
			current_props.clear()
		elif "=" in trimmed:
			var parts := trimmed.split("=", false, 1)
			if parts.size() == 2:
				var key := parts[0].strip_edges()
				var val := parts[1].strip_edges()
				current_props[key] = val

	# Letzten Knoten auswerten
	_evaluate_node(current_node_name, current_node_type, current_props, result, world_map)

	return result


static func _evaluate_node(node_name: String, node_type: String, props: Dictionary, out_result: Dictionary, world_map: WorldMap) -> void:
	if node_name.is_empty():
		return

	# 1. SpawnPoint prüfen
	if props.has("spawn_id") or node_name.to_lower().begins_with("spawn"):
		var raw_spawn_id: String = props.get("spawn_id", "")
		var clean_spawn_id := _clean_string(raw_spawn_id)
		if clean_spawn_id.is_empty() and node_name.to_lower().begins_with("spawn"):
			clean_spawn_id = node_name.trim_prefix("Spawn_").trim_prefix("spawn_").to_lower()

		var is_default: bool = (props.get("is_default", "false").to_lower() == "true")

		if not clean_spawn_id.is_empty() or is_default:
			out_result["spawns"].append({
				"node_name": node_name,
				"spawn_id": clean_spawn_id if not clean_spawn_id.is_empty() else "standard",
				"is_default": is_default
			})
			return

	# 2. Exit / TransitionBehavior prüfen
	var has_target_scene: bool = props.has("target_scene_id") or props.has("target_scene_path")
	var is_exit_node: bool = node_name.to_lower().contains("exit") or props.get("is_exit_door", "false") == "true"

	if has_target_scene or is_exit_node:
		var target_scene_id := _clean_string(props.get("target_scene_id", ""))
		var target_scene_path := _clean_string(props.get("target_scene_path", ""))
		var target_spawn_id := _clean_string(props.get("target_spawn_id", ""))
		if target_spawn_id.is_empty():
			target_spawn_id = _clean_string(props.get("spawn_point_id", ""))

		# Falls nur target_scene_path angegeben ist, über world_map zur ID auflösen
		if target_scene_id.is_empty() and not target_scene_path.is_empty() and world_map:
			target_scene_id = str(world_map.find_scene_id_by_path(target_scene_path))
		if target_scene_id.is_empty() and not target_scene_path.is_empty():
			target_scene_id = target_scene_path.get_file().get_basename()

		var is_locked: bool = (props.get("is_locked", "false").to_lower() == "true")
		if props.has("lock_conditions"):
			is_locked = true
		var locked_msg := _clean_string(props.get("locked_message", ""))

		if not target_scene_id.is_empty() or not target_scene_path.is_empty():
			out_result["exits"].append({
				"node_name": node_name,
				"target_scene_id": target_scene_id,
				"target_spawn_id": target_spawn_id,
				"target_scene_path": target_scene_path,
				"is_locked": is_locked,
				"locked_message": locked_msg
			})


static func _extract_attribute(header_line: String, attr_name: String) -> String:
	var prefix := attr_name + '="'
	var idx := header_line.find(prefix)
	if idx == -1:
		return ""
	var start := idx + prefix.length()
	var end := header_line.find('"', start)
	if end == -1:
		return ""
	return header_line.substr(start, end - start)


static func _clean_string(val: String) -> String:
	var s := val.strip_edges()
	if s.begins_with('&"'):
		s = s.substr(2)
		if s.ends_with('"'):
			s = s.substr(0, s.length() - 1)
	elif s.begins_with('"'):
		s = s.substr(1)
		if s.ends_with('"'):
			s = s.substr(0, s.length() - 1)
	return s.strip_edges()
