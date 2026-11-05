extends Node

signal game_saved(slot_id: int)
signal game_loaded(slot_id: int)
signal save_deleted(slot_id: int)

const SAVE_DIR: String = "user://saves"
const MAX_SLOTS: int = 3

var current_slot: int = 1
var _pending_world_data: Dictionary = {}
var _collected_world_items: Dictionary = {} # unique_id -> bool
var _world_objects: Dictionary = {}         # object_id -> Dictionary
var _scene_custom_data: Dictionary = {}      # scene_id -> Dictionary
var _scene_ground_pickups: Dictionary = {}   # scene_id -> Array[Dictionary]

## Szene, mit der dynamische Boden-Drops wiederhergestellt werden (vom Weltskript setzen)
var ground_pickup_scene: PackedScene = null

func get_world_data() -> Dictionary:
	return _pending_world_data.duplicate()

func is_world_item_collected(unique_id: String) -> bool:
	if unique_id.is_empty():
		return false
	return _collected_world_items.get(unique_id, false)

func mark_world_item_collected(unique_id: String) -> void:
	if not unique_id.is_empty():
		_collected_world_items[unique_id] = true

func get_world_object_state(object_id: String) -> Dictionary:
	if object_id.is_empty():
		return {}
	return _world_objects.get(object_id, {}).duplicate()

func set_world_object_state(object_id: String, state: Dictionary) -> void:
	if not object_id.is_empty():
		_world_objects[object_id] = state.duplicate()

func set_scene_custom_data(scene_id: StringName, key: String, value: Variant) -> void:
	if scene_id.is_empty():
		return
	if not _scene_custom_data.has(scene_id):
		_scene_custom_data[scene_id] = {}
	_scene_custom_data[scene_id][key] = value

func get_scene_custom_data(scene_id: StringName, key: String, default_val: Variant = null) -> Variant:
	if scene_id.is_empty() or not _scene_custom_data.has(scene_id):
		return default_val
	return _scene_custom_data[scene_id].get(key, default_val)

func has_scene_custom_data(scene_id: StringName, key: String) -> bool:
	if scene_id.is_empty() or not _scene_custom_data.has(scene_id):
		return false
	return _scene_custom_data[scene_id].has(key)

## Sichert alle Weltobjekt-Zustände und unaufgesammelte Boden-Drops der aktuellen Szene
func flush_scene_state(scene_root: Node, scene_id: StringName = &"") -> bool:
	if not scene_root:
		return false
		
	# 1. Alle InteractiveObjects sichern
	for obj in scene_root.find_children("*", "InteractiveObject", true, false):
		if obj.has_method("_save_state_to_manager"):
			obj.call("_save_state_to_manager")
		elif obj.has_method("get_save_state") and "object_id" in obj and not obj.object_id.is_empty():
			var obj_state: Dictionary = obj.get_save_state()
			if not obj_state.is_empty():
				_world_objects[obj.object_id] = obj_state

	# 3. Dynamische Boden-Pickups sichern
	if not scene_id.is_empty() and scene_root.is_inside_tree():
		var ground_items: Array[Dictionary] = []
		for child in scene_root.get_tree().get_nodes_in_group("dynamic_ground_pickups"):
			if is_instance_valid(child) and scene_root.is_ancestor_of(child) and child is Node3D:
				var is_picked: bool = bool(child.get("_is_picked")) if "_is_picked" in child else false
				if not is_picked:
					ground_items.append({
						"item_id": child.get("item_id") if "item_id" in child else "item",
						"item_count": child.get("item_count") if "item_count" in child else 1,
						"pos": [child.global_position.x, child.global_position.y, child.global_position.z]
					})
		_scene_ground_pickups[scene_id] = ground_items

	return true

## Stellt Weltobjekt-Zustände, Sonderobjekte und Boden-Drops für eine Szene wieder her
func restore_scene_state(scene_root: Node, scene_id: StringName = &"") -> void:
	if not scene_root:
		return

	# 1. InteractiveObjects wiederherstellen
	for obj in scene_root.find_children("*", "InteractiveObject", true, false):
		if "object_id" in obj and _world_objects.has(obj.object_id):
			if obj.has_method("load_save_state"):
				obj.load_save_state(_world_objects[obj.object_id])

	# 3. Dynamische Boden-Pickups wiederherstellen
	if not scene_id.is_empty() and _scene_ground_pickups.has(scene_id) and scene_root.is_inside_tree():
		for child in scene_root.get_tree().get_nodes_in_group("dynamic_ground_pickups"):
			if is_instance_valid(child) and scene_root.is_ancestor_of(child):
				child.queue_free()

		if ground_pickup_scene == null:
			push_warning("SaveManager: ground_pickup_scene nicht gesetzt, Boden-Drops bleiben weg.")
			return
		var drop_scene: PackedScene = ground_pickup_scene
		var items_arr: Array = _scene_ground_pickups[scene_id]
		for item_dict in items_arr:
			if item_dict is Dictionary:
				var inst: Node3D = drop_scene.instantiate() as Node3D
				inst.add_to_group("dynamic_ground_pickups")
				if "item_id" in inst:
					inst.item_id = str(item_dict.get("item_id", "item"))
				if "item_count" in inst:
					inst.item_count = int(item_dict.get("item_count", 1))
				var pos_arr: Array = item_dict.get("pos", [0, 0, 0])
				if pos_arr.size() >= 3:
					inst.position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
				scene_root.add_child(inst)

func _ready() -> void:
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _get_save_path(slot_id: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot_id]

func has_save(slot_id: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot_id))

func get_slot_info(slot_id: int) -> Dictionary:
	var path := _get_save_path(slot_id)
	if not FileAccess.file_exists(path):
		return {
			"exists": false,
			"slot_id": slot_id,
			"title": "Save Slot %d" % slot_id,
			"description": "Leerer Speicherplatz"
		}
		
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return { "exists": false, "slot_id": slot_id, "title": "Fehler beim Lesen", "description": "" }
		
	var json_str := file.get_as_text()
	var json := JSON.new()
	var parse_err := json.parse(json_str)
	if parse_err != OK or not json.data is Dictionary:
		return { "exists": false, "slot_id": slot_id, "title": "Corrupted Save Slot", "description": "" }
		
	var data: Dictionary = json.data
	var energy: int = int(data.get("inventory", {}).get("energy", 0))
	var date_str: String = str(data.get("date_string", "Unbekannt"))
	
	# Count completed quests
	var q_dict: Dictionary = data.get("quests", {})
	var completed_quests := 0
	for q_val in q_dict.values():
		if (q_val is int or q_val is float) and int(q_val) == 2: # QuestData.QuestState.COMPLETED
			completed_quests += 1
			
	var desc := "%d Energie  |  %d Quests  |  %s" % [energy, completed_quests, date_str]
	
	return {
		"exists": true,
		"slot_id": slot_id,
		"title": "Save Slot %d" % slot_id,
		"energy": energy,
		"completed_quests": completed_quests,
		"date_string": date_str,
		"description": desc,
		"data": data
	}

func save_game(slot_id: int = -1) -> bool:
	_ensure_save_dir()
	if slot_id <= 0:
		slot_id = current_slot
	current_slot = slot_id
	
	var save_dict: Dictionary = {}
	save_dict["version"] = 2
	save_dict["slot_id"] = slot_id
	save_dict["timestamp"] = int(Time.get_unix_time_from_system())
	
	# Current formatted date and time
	var dt := Time.get_datetime_dict_from_system()
	save_dict["date_string"] = "%02d.%02d.%d  %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]
	
	# 1. Inventory & Energy
	if InventoryManager:
		save_dict["inventory"] = InventoryManager.get_save_data()
	else:
		save_dict["inventory"] = {}
		
	# 2. Quests
	if QuestManager:
		save_dict["quests"] = QuestManager.get_save_data()
	else:
		save_dict["quests"] = {}
		
	# 3. World state (Player, Scene, Tree, Weather)
	var world_data: Dictionary = {}
	var tree_root := get_tree().root if get_tree() else null
	var current_scene := get_tree().current_scene if get_tree() else null
	var st = get_node_or_null("/root/SceneTransition")
	
	var cur_scene_id: StringName = st.current_scene_id if st else &""
	if cur_scene_id.is_empty() and current_scene:
		var wm: WorldMap = load("res://resources/world/world_map.tres")
		if wm:
			cur_scene_id = wm.find_scene_id_by_path(current_scene.scene_file_path)
				
	world_data["scene_id"] = str(cur_scene_id)
	world_data["scene_path"] = current_scene.scene_file_path if current_scene else ""
	world_data["last_spawn_id"] = str(st.current_spawn_id) if st else ""

	if tree_root:
		var player := tree_root.find_child("Player", true, false) as Node3D
		if player:
			world_data["player_pos"] = [player.global_position.x, player.global_position.y, player.global_position.z]
			world_data["player_yaw"] = player.global_rotation.y
			
	# Flush scene vor dem Schreiben
	if current_scene:
		flush_scene_state(current_scene, cur_scene_id)

	save_dict["world"] = world_data
	save_dict["collected_world_items"] = _collected_world_items.keys()
	save_dict["world_objects"] = _world_objects.duplicate()
	save_dict["scene_custom_data"] = _scene_custom_data.duplicate(true)
	save_dict["scene_ground_pickups"] = _scene_ground_pickups.duplicate(true)

	# RoomManager Zustand sichern
	var rm = get_node_or_null("/root/RoomManager")
	if rm:
		save_dict["room_manager"] = {
			"current_interior_scene": rm.current_interior_scene,
			"overworld_return_position": [rm.overworld_return_position.x, rm.overworld_return_position.y, rm.overworld_return_position.z],
			"overworld_return_yaw": rm.overworld_return_yaw,
			"overworld_scene_path": rm.overworld_scene_path
		}
	
	# Story- / Game-Flags
	var gf = get_node_or_null("/root/GameFlags")
	if gf and gf.has_method("get_all_flags"):
		save_dict["flags"] = gf.call("get_all_flags")
	
	var json_str := JSON.stringify(save_dict, "\t")
	var file := FileAccess.open(_get_save_path(slot_id), FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Konnte Spielstand nicht schreiben: " + _get_save_path(slot_id))
		return false
		
	file.store_string(json_str)
	file.close()
	
	game_saved.emit(slot_id)
	return true

func load_game(slot_id: int) -> bool:
	# Übergangs-Sperre: Laden abweisen, wenn gerade ein Szenenwechsel läuft
	var st = get_node_or_null("/root/SceneTransition")
	if st and st.get("is_transitioning") == true:
		return false
	var rm_guard = get_node_or_null("/root/RoomManager")
	if rm_guard and rm_guard.get("is_transitioning") == true:
		return false

	var path := _get_save_path(slot_id)
	if not FileAccess.file_exists(path):
		return false
		
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
		
	var json_str := file.get_as_text()
	var json := JSON.new()
	if json.parse(json_str) != OK or not json.data is Dictionary:
		return false
		
	var data: Dictionary = json.data
	current_slot = slot_id
	
	# Restore Inventory
	if InventoryManager and data.has("inventory"):
		InventoryManager.load_save_data(data["inventory"])
		
	# Restore Quests
	if QuestManager and data.has("quests"):
		QuestManager.load_save_data(data["quests"])
		
	# Restore Collected World Items
	_collected_world_items.clear()
	if data.has("collected_world_items") and data["collected_world_items"] is Array:
		for item_id in data["collected_world_items"]:
			_collected_world_items[str(item_id)] = true
			
	# Restore World Objects
	_world_objects.clear()
	if data.has("world_objects") and data["world_objects"] is Dictionary:
		_world_objects = data["world_objects"].duplicate()

	# Restore Scene Custom Data & Ground Pickups
	_scene_custom_data.clear()
	if data.has("scene_custom_data") and data["scene_custom_data"] is Dictionary:
		_scene_custom_data = data["scene_custom_data"].duplicate(true)

	_scene_ground_pickups.clear()
	if data.has("scene_ground_pickups") and data["scene_ground_pickups"] is Dictionary:
		_scene_ground_pickups = data["scene_ground_pickups"].duplicate(true)

	# Restore RoomManager
	var rm = get_node_or_null("/root/RoomManager")
	if rm and data.has("room_manager") and data["room_manager"] is Dictionary:
		var rm_data: Dictionary = data["room_manager"]
		rm.current_interior_scene = str(rm_data.get("current_interior_scene", ""))
		rm.overworld_scene_path = str(rm_data.get("overworld_scene_path", ""))
		var ret_pos: Array = rm_data.get("overworld_return_position", [0, 0, 0])
		if ret_pos.size() >= 3:
			rm.overworld_return_position = Vector3(ret_pos[0], ret_pos[1], ret_pos[2])
		rm.overworld_return_yaw = float(rm_data.get("overworld_return_yaw", 0.0))

	# Restore Game Flags
	var gf = get_node_or_null("/root/GameFlags")
	if gf:
		if data.has("flags") and data["flags"] is Dictionary:
			gf.call("load_save_data", data["flags"])
		else:
			gf.call("reset")
		
	# Store pending world data
	_pending_world_data = data.get("world", {}).duplicate()

	# Zielszene ermitteln
	var target_scene_id: StringName = StringName(str(_pending_world_data.get("scene_id", "")))
	var target_scene_path: String = str(_pending_world_data.get("scene_path", ""))

	# Fallback für Altspeicherstände (vor Phase 1, ohne scene_id)
	if target_scene_id.is_empty() and target_scene_path.is_empty():
		target_scene_path = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	elif target_scene_path.is_empty() and not target_scene_id.is_empty():
		var wm: WorldMap = load("res://resources/world/world_map.tres")
		if wm:
			target_scene_path = wm.get_scene_path(target_scene_id)

	_pending_world_data["scene_id"] = str(target_scene_id)
	_pending_world_data["scene_path"] = target_scene_path

	# Szene laden / anwenden
	var cur := get_tree().current_scene if get_tree() else null
	if cur and cur.scene_file_path == target_scene_path:
		apply_pending_world_data(cur)
	elif st and not target_scene_path.is_empty():
		st.load_saved_scene(target_scene_path, target_scene_id, _pending_world_data)
	elif not target_scene_path.is_empty() and get_tree():
		get_tree().change_scene_to_file(target_scene_path)
		
	game_loaded.emit(slot_id)
	return true

func start_new_game(slot_id: int) -> void:
	current_slot = slot_id
	_collected_world_items.clear()
	_world_objects.clear()
	_scene_custom_data.clear()
	_scene_ground_pickups.clear()
	if InventoryManager:
		InventoryManager.reset()
	if QuestManager:
		QuestManager.reset()
	var gf = get_node_or_null("/root/GameFlags")
	if gf:
		gf.call("reset")
	_pending_world_data.clear()
	
	var st = get_node_or_null("/root/SceneTransition")
	var wm: WorldMap = load("res://resources/world/world_map.tres") if ResourceLoader.exists("res://resources/world/world_map.tres") else null
	var start_scene: String = "res://scenes/demo/demo_level.tscn"
	var start_id: StringName = &"demo_level"
	if wm and not wm.start_scene_id.is_empty():
		start_id = wm.start_scene_id
		start_scene = wm.get_scene_path(wm.start_scene_id)

	if st:
		st.go_to(start_id)
	elif get_tree() and not start_scene.is_empty():
		get_tree().change_scene_to_file(start_scene)

func delete_save(slot_id: int) -> bool:
	var path := _get_save_path(slot_id)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err == OK:
			save_deleted.emit(slot_id)
			return true
	return false

func has_pending_world_data() -> bool:
	return not _pending_world_data.is_empty()

func apply_pending_world_data(world_root: Node) -> void:
	if _pending_world_data.is_empty() or not world_root:
		return
		
	# Restore player position & rotation
	if _pending_world_data.has("player_pos"):
		var p_arr: Array = _pending_world_data["player_pos"]
		var player := world_root.find_child("Player", true, false) as Node3D
		if player and p_arr.size() >= 3:
			player.global_position = Vector3(p_arr[0], p_arr[1], p_arr[2])
			if _pending_world_data.has("player_yaw"):
				player.global_rotation.y = float(_pending_world_data["player_yaw"])
				
	# Restore Scene State (InteractiveObjects, Custom Data, Ground Pickups)
	var scene_id: StringName = StringName(str(_pending_world_data.get("scene_id", "")))
	restore_scene_state(world_root, scene_id)
	
	if world_root.has_method("snap_camera"):
		world_root.snap_camera()

	_pending_world_data.clear()
