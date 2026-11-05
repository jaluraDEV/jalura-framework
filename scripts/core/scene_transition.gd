extends Node

## SceneTransition
## Zentraler Manager für weiche Szenenübergänge (Dioramen) und Weltkarten-Navigation.
## Verwaltet Black-Fades, Eingabesperren, Spieler-Spawns, Kamera-Snaps und Zustandssicherung.

signal transition_started(from_scene_id: StringName, to_scene_id: StringName)
signal scene_entered(scene_id: StringName, spawn_id: StringName)

const WORLD_MAP_PATH: String = "res://resources/world/world_map.tres"

var current_scene_id: StringName = &""
var current_spawn_id: StringName = &""
var previous_scene_id: StringName = &""
var last_exterior_scene_id: StringName = &""
var last_exterior_scene_path: String = ""
## Szenen, die als Außenwelt gelten (vom Projekt zu füllen), z. B. [&"overworld"]
var exterior_scene_ids: Array[StringName] = []
var is_transitioning: bool = false

var world_map: WorldMap = null
var fade_duration: float = 0.28
var fade_color: Color = Color(0, 0, 0, 1)

var _overlay: CanvasLayer
var _fade_rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_world_map()
	_create_fade_overlay()
	_detect_initial_scene()

func _load_world_map() -> void:
	if ResourceLoader.exists(WORLD_MAP_PATH):
		world_map = load(WORLD_MAP_PATH) as WorldMap
	if not world_map:
		world_map = WorldMap.new()

func _create_fade_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 125 # Über HUD (Layer 100) und RoomManager (Layer 120)
	_overlay.name = "SceneTransitionOverlay"
	
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	_overlay.add_child(_fade_rect)
	add_child(_overlay)

func _detect_initial_scene() -> void:
	if not get_tree() or not get_tree().current_scene:
		return
	var curr := get_tree().current_scene
	if world_map and not curr.scene_file_path.is_empty():
		for entry in world_map.scenes:
			if entry and entry.scene_path == curr.scene_file_path:
				current_scene_id = entry.scene_id
				return
	if current_scene_id.is_empty() and world_map:
		current_scene_id = world_map.start_scene_id

## Wechselt zu einer Szene aus der WorldMap und platziert Barnaby am gewünschten SpawnPoint
func go_to(target_scene_id: StringName, target_spawn_id: StringName = &"") -> bool:
	if is_transitioning:
		return false
		
	# Abstimmung mit RoomManager (vermeidet gleichzeitiges Überblenden)
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.get("is_transitioning") == true:
		return false

	# Dialog-Prüfung: Wechsel verweigern, solange ein Gespräch aktiv ist
	var hud := _get_active_hud()
	if hud and hud.is_dialogue_active:
		return false

	# Zielszene in der Registry suchen
	if not world_map:
		_load_world_map()
	var entry := world_map.get_entry(target_scene_id) if world_map else null
	if not entry or entry.scene_path.is_empty():
		push_warning("SceneTransition: Unbekannte oder ungültige scene_id '%s'!" % str(target_scene_id))
		return false

	# Zustands-Flush vor dem Entladen der alten Szene
	var flush_ok := _flush_current_scene_state()
	if not flush_ok:
		push_error("SceneTransition: Zustands-Flush fehlgeschlagen! Szenenwechsel abgebrochen.")
		return false

	is_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Spieler-Bewegung beim Übergangsstart sofort stoppen
	var cur_sc := get_tree().current_scene if get_tree() else null
	if cur_sc:
		var p := cur_sc.find_child("Player", true, false) as CharacterBody3D
		if p:
			p.velocity = Vector3.ZERO
	
	var old_scene_id := current_scene_id
	transition_started.emit(old_scene_id, target_scene_id)
	_run_transition_flow(entry.scene_path, target_scene_id, target_spawn_id)
	return true

func _run_transition_flow(scene_path: String, target_scene_id: StringName, target_spawn_id: StringName) -> void:
	# 1. Weich ausblenden
	await _fade(0.0, 1.0, fade_duration)

	# 2. Szene wechseln
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneTransition: Konnte Szene nicht laden: %s (Fehler %d)" % [scene_path, err])
		await _fade(1.0, 0.0, 0.15)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		is_transitioning = false
		return

	# 3. Frames abwarten, bis die neue Szene vollständig gemountet ist
	await get_tree().process_frame
	await get_tree().process_frame

	var new_scene := get_tree().current_scene
	if new_scene:
		_setup_spawn(new_scene, target_spawn_id)
		var cm = get_node_or_null("/root/CameraManager")
		if cm and cm.has_method("snap_active_camera"):
			cm.snap_active_camera()
		elif new_scene.has_method("snap_camera"):
			new_scene.snap_camera()

	# 1 Physik-Frame warten, damit Überlappungen von Spawns und Zonen sicher erkannt werden
	await get_tree().physics_frame
	if new_scene:
		_disarm_spawn_zones(new_scene)

	# Grafikeinstellungen synchronisieren
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("apply_graphics_settings"):
		sm.call("apply_graphics_settings")

	# Automatische Flags: scene_visited_<scene_id> setzen (Phase 2)
	var gf = get_node_or_null("/root/GameFlags")
	if gf:
		var visited_flag := "scene_visited_" + str(target_scene_id)
		gf.call("set_flag", visited_flag, true)

	previous_scene_id = current_scene_id
	if current_scene_id in exterior_scene_ids:
		last_exterior_scene_id = current_scene_id
		var old_entry := world_map.get_entry(current_scene_id) if world_map else null
		if old_entry:
			last_exterior_scene_path = old_entry.scene_path

	current_scene_id = target_scene_id
	current_spawn_id = target_spawn_id

	# In-Memory-Zustände der neuen Szene wiederherstellen (Phase 2)
	var save_m = get_node_or_null("/root/SaveManager")
	if save_m and new_scene and save_m.has_method("restore_scene_state"):
		save_m.restore_scene_state(new_scene, target_scene_id)

	# 4. Weich einblenden
	await _fade(1.0, 0.0, fade_duration)
	
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	scene_entered.emit(target_scene_id, target_spawn_id)

## Lädt eine gespeicherte Szene mit weichem Aus-/Einblenden und stellt den Zustand her
func load_saved_scene(scene_path: String, target_scene_id: StringName, world_data: Dictionary) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var old_scene_id := current_scene_id
	transition_started.emit(old_scene_id, target_scene_id)
	
	# 1. Weich ausblenden
	await _fade(0.0, 1.0, fade_duration)
	
	# 2. Szene wechseln
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneTransition: Konnte gespeicherte Szene nicht laden: %s" % scene_path)
		await _fade(1.0, 0.0, 0.15)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		is_transitioning = false
		return
		
	# 3. Frames warten bis gemountet
	await get_tree().process_frame
	await get_tree().process_frame
	
	var new_scene := get_tree().current_scene
	var save_m = get_node_or_null("/root/SaveManager")
	if new_scene and save_m:
		save_m.apply_pending_world_data(new_scene)
		
	if new_scene and new_scene.has_method("snap_camera"):
		new_scene.call("snap_camera")
		
	# 1 Physik-Frame warten, damit Überlappungen von Spawns und Zonen sicher erkannt werden
	await get_tree().physics_frame
	if new_scene:
		_disarm_spawn_zones(new_scene)
		
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("apply_graphics_settings"):
		sm.call("apply_graphics_settings")
		
	var gf = get_node_or_null("/root/GameFlags")
	if gf:
		var visited_flag := "scene_visited_" + str(target_scene_id)
		gf.call("set_flag", visited_flag, true)
		
	current_scene_id = target_scene_id
	current_spawn_id = StringName(str(world_data.get("last_spawn_id", "")))
	
	# 4. Weich einblenden
	await _fade(1.0, 0.0, fade_duration)
	
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	scene_entered.emit(target_scene_id, current_spawn_id)

func _disarm_spawn_zones(scene_root: Node) -> void:
	if not scene_root:
		return
	var player := scene_root.find_child("Player", true, false)
	if not player:
		return
	for b in scene_root.find_children("*", "TransitionBehavior", true, false):
		if b.has_method("disarm_if_overlapping"):
			b.call("disarm_if_overlapping", player)
	for dt in scene_root.find_children("*", "DoorTrigger3D", true, false):
		if dt.has_method("disarm_if_overlapping"):
			dt.call("disarm_if_overlapping", player)

func _setup_spawn(scene_root: Node, spawn_id: StringName) -> void:
	var spawn_node: Node3D = null
	
	# 1. Gezielt nach SpawnPoint mit passender spawn_id suchen
	if not spawn_id.is_empty():
		for sp in scene_root.get_tree().get_nodes_in_group("spawn_points"):
			if sp is SpawnPoint and sp.spawn_id == spawn_id and scene_root.is_ancestor_of(sp):
				spawn_node = sp
				break
		if not spawn_node:
			spawn_node = scene_root.find_child(str(spawn_id), true, false) as Node3D

	# 2. Fallback auf Default-SpawnPoint
	if not spawn_node:
		for sp in scene_root.get_tree().get_nodes_in_group("spawn_points"):
			if sp is SpawnPoint and sp.is_default and scene_root.is_ancestor_of(sp):
				spawn_node = sp
				break

	# 3. Fallback auf irgendeinen SpawnPoint oder Marker3D
	if not spawn_node:
		var any_sp = scene_root.find_child("SpawnPoint*", true, false) as Node3D
		if any_sp:
			spawn_node = any_sp
		else:
			spawn_node = scene_root.find_child("*Spawn*", true, false) as Node3D

	# Spieler platzieren & mit Raycast präzise an Boden heften
	var player := scene_root.find_child("Player", true, false) as CharacterBody3D
	if player:
		if spawn_node:
			var target_pos := spawn_node.global_position
			# Raycast nach unten zur perfekten Boden-Höhe (verhindert Schweben oder Fallen)
			var space := player.get_world_3d().direct_space_state if player.is_inside_tree() else null
			if space:
				var ray_from := target_pos + Vector3(0.0, 0.6, 0.0)
				var ray_to := target_pos + Vector3(0.0, -3.5, 0.0)
				var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
				var hit := space.intersect_ray(query)
				if hit and hit.has("position"):
					target_pos.y = hit["position"].y + 0.02
			
			player.global_position = target_pos
			player.global_rotation.y = spawn_node.global_rotation.y
			var pivot := player.find_child("CameraPivot", true, false) as Node3D
			if pivot:
				pivot.rotation.y = spawn_node.global_rotation.y
			var vis := player.find_child("Visual", true, false) as Node3D
			if vis:
				vis.global_rotation.y = spawn_node.global_rotation.y
		player.velocity = Vector3.ZERO
		player.apply_floor_snap()

		# WaterHazard über sicheren Spawn-Punkt informieren
		var wh = player.find_child("WaterHazard", true, false)
		if wh:
			wh.set("last_safe_position", player.global_position)
			wh.set("last_safe_yaw", spawn_node.global_rotation.y if spawn_node else 0.0)
			wh.set("has_safe_position", true)
			wh.set("is_recovering", false)

	# Konflikt mit RoomManager vermeiden
	var rm = get_node_or_null("/root/RoomManager")
	if rm:
		rm.overworld_return_position = Vector3.ZERO

	# Kamera-Snap: Kamera sofort ohne Gleiten auf Zielposition setzen
	if scene_root.has_method("snap_camera"):
		scene_root.call("snap_camera")
	elif scene_root.find_child("DioramaCamera", true, false):
		var dcam := scene_root.find_child("DioramaCamera", true, false) as Camera3D
		if dcam:
			dcam.current = true

func _flush_current_scene_state() -> bool:
	var sm = get_node_or_null("/root/SaveManager")
	var cur_scene := get_tree().current_scene if get_tree() else null
	if sm and cur_scene and sm.has_method("flush_scene_state"):
		return sm.flush_scene_state(cur_scene, current_scene_id)
	return true

## Sucht das HUD in der aktuellen Szene. Duck-Typing, damit das Framework ohne UI-Modul laedt.
func _get_active_hud() -> Node:
	if not get_tree():
		return null
	if get_tree().current_scene:
		var h := get_tree().current_scene.find_child("HUD", true, false)
		if h:
			return h
	if get_tree().root:
		return get_tree().root.find_child("HUD", true, false)
	return null

func _fade(from_alpha: float, to_alpha: float, duration: float) -> void:
	if not _fade_rect:
		return
	var tween := create_tween()
	_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, from_alpha)
	tween.tween_property(_fade_rect, "color:a", to_alpha, duration)
	await tween.finished
