extends Node

## RoomManager
## Manages building entrances, interior transitions, and player return positions.

signal transition_started(target_scene: String)
signal transition_completed(current_scene: String)

var current_interior_scene: String = ""
var overworld_scene_path: String = ""
var overworld_return_position: Vector3 = Vector3.ZERO
var overworld_return_yaw: float = 0.0
var target_spawn_id: String = ""

var is_transitioning: bool = false
var _overlay: CanvasLayer
var _fade_rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_fade_overlay()

func _create_fade_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 120 # Above HUD and filters
	_overlay.name = "RoomFadeOverlay"
	
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	_overlay.add_child(_fade_rect)
	add_child(_overlay)

func is_in_interior() -> bool:
	return not current_interior_scene.is_empty()

func enter_room(target_scene_path: String, spawn_id: String = "default", return_pos: Vector3 = Vector3.ZERO, return_yaw: float = 0.0) -> void:
	if is_transitioning:
		return
	var st = get_node_or_null("/root/SceneTransition")
	if st and st.get("is_transitioning") == true:
		return
	is_transitioning = true
	
	var current := get_tree().current_scene
	if current and not current.scene_file_path.is_empty() and not is_in_interior():
		overworld_scene_path = current.scene_file_path
		
	overworld_return_position = return_pos
	overworld_return_yaw = return_yaw
	target_spawn_id = spawn_id
	current_interior_scene = target_scene_path
	
	transition_started.emit(target_scene_path)
	
	# Fade out
	await _fade(0.0, 1.0, 0.28)
	
	# Change scene
	var err := get_tree().change_scene_to_file(target_scene_path)
	if err != OK:
		push_error("RoomManager: Konnte Raum-Szene nicht laden: " + target_scene_path)
		await _fade(1.0, 0.0, 0.2)
		is_transitioning = false
		return
		
	# Wait for scene to mount and position player
	await get_tree().process_frame
	await get_tree().process_frame
	
	var interior_root := get_tree().current_scene
	if interior_root:
		_setup_interior_player(interior_root)
		
	# Apply graphics settings
	if SettingsManager:
		SettingsManager.apply_graphics_settings()
		
	# Fade in
	await _fade(1.0, 0.0, 0.28)
	is_transitioning = false
	transition_completed.emit(target_scene_path)

func exit_room() -> void:
	if is_transitioning:
		return
	var st = get_node_or_null("/root/SceneTransition")
	if st and st.get("is_transitioning") == true:
		return
	is_transitioning = true
	
	if overworld_scene_path.is_empty():
		push_error("RoomManager: exit_room() ohne overworld_scene_path aufgerufen.")
		is_transitioning = false
		return
		
	if overworld_return_position == Vector3.ZERO:
		overworld_return_position = Vector3.ZERO
		overworld_return_yaw = 0.0
	
	transition_started.emit(overworld_scene_path)
	
	# Fade out
	await _fade(0.0, 1.0, 0.28)
	
	var err := get_tree().change_scene_to_file(overworld_scene_path)
	if err != OK:
		push_error("RoomManager: Konnte Overworld-Szene nicht laden: " + overworld_scene_path)
		await _fade(1.0, 0.0, 0.2)
		is_transitioning = false
		return
		
	current_interior_scene = ""
	
	# Wait for scene to mount
	await get_tree().process_frame
	await get_tree().process_frame
	
	var overworld_root := get_tree().current_scene
	if overworld_root:
		apply_player_return(overworld_root)
		
	if SettingsManager:
		SettingsManager.apply_graphics_settings()
		
	# Fade in
	await _fade(1.0, 0.0, 0.28)
	is_transitioning = false
	transition_completed.emit(overworld_scene_path)

func has_pending_return() -> bool:
	return overworld_return_position != Vector3.ZERO

func apply_player_return(world_root: Node) -> void:
	if not world_root or overworld_return_position == Vector3.ZERO:
		return
		
	var player := world_root.find_child("Player", true, false) as CharacterBody3D
	if player:
		if player.has_method("set_camera_fade_enabled"):
			player.set_camera_fade_enabled(true)
		elif "camera_fade_enabled" in player:
			player.camera_fade_enabled = true
		player.global_position = overworld_return_position
		player.global_rotation.y = 0.0
		var pivot := player.find_child("CameraPivot", true, false) as Node3D
		if pivot:
			pivot.rotation.y = overworld_return_yaw
		var vis := player.find_child("Visual", true, false) as Node3D
		if vis:
			vis.global_rotation.y = overworld_return_yaw
		player.velocity = Vector3.ZERO
		
	overworld_return_position = Vector3.ZERO

func _setup_interior_player(interior_root: Node) -> void:
	var spawn_marker: Node3D = null
	
	if not target_spawn_id.is_empty():
		spawn_marker = interior_root.find_child(target_spawn_id, true, false) as Node3D
		
	if not spawn_marker:
		spawn_marker = interior_root.find_child("SpawnPoint", true, false) as Node3D
		
	var player := interior_root.find_child("Player", true, false) as CharacterBody3D
	if player:
		if player.has_method("set_camera_fade_enabled"):
			player.set_camera_fade_enabled(false)
		elif "camera_fade_enabled" in player:
			player.camera_fade_enabled = false
		if spawn_marker:
			player.global_position = spawn_marker.global_position
			player.global_rotation.y = 0.0
			var pivot := player.find_child("CameraPivot", true, false) as Node3D
			if pivot:
				pivot.rotation.y = spawn_marker.global_rotation.y
			var vis := player.find_child("Visual", true, false) as Node3D
			if vis:
				vis.global_rotation.y = spawn_marker.global_rotation.y
			player.velocity = Vector3.ZERO

func _fade(from_alpha: float, to_alpha: float, duration: float) -> void:
	if not _fade_rect:
		return
	var tween := create_tween()
	_fade_rect.color.a = from_alpha
	tween.tween_property(_fade_rect, "color:a", to_alpha, duration)
	await tween.finished
