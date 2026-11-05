@tool
class_name PushableBehavior
extends ObjectBehavior

## Baustein: Schiebbares Objekt (ObjPushable / Block / Kiste).
## Ermöglicht das Schieben (und optional Ziehen) von Objekten in Raster-Schritten.
## Inklusive Hindernis- und Bodenprüfung, animiertem Gleiten (Tween),
## Event-Auslösung ('pushed', 'pulled') und Savegame-Persistenz der Position.

signal push_finished(from_pos: Vector3, to_pos: Vector3)

enum PushAxis {
	ALL = 0,    ## Schieben in alle 4 Himmelsrichtungen (+X, -X, +Z, -Z)
	X_ONLY = 1, ## Nur entlang der X-Achse
	Z_ONLY = 2  ## Nur entlang der Z-Achse
}

enum PushTrigger {
	INTERACT = 0, ## Standard: Taste [E] drücken = Block rutscht einen festen Schritt
	BUMP = 1,     ## Gegenlaufen: Spieler läuft kurz gegen den Block (~0.2s Haltezeit)
	BOTH = 2      ## Erlaubt sowohl Taste [E] als auch Gegenlaufen
}

@export_group("Push Properties")
@export var push_trigger: PushTrigger = PushTrigger.INTERACT ## Auslöser: INTERACT (Taste [E]), BUMP (Dagegenlaufen) oder BOTH
@export var bump_hold_time: float = 0.2 ## Haltezeit beim Dagegenlaufen in Sekunden, bevor der Schub auslöst
@export var step_distance: float = 1.5 ## Versatz pro Schiebevorgang in Metern
@export var push_duration: float = 0.38 ## Dauer der Gleit-Animation in Sekunden
@export var push_axis: PushAxis = PushAxis.ALL
@export var can_push: bool = true
@export var can_pull: bool = false ## Erlaubt Ziehen zum Spieler hin
@export var snap_to_grid: bool = true ## Richtet Koordinaten nach der Bewegung exakt aus
@export var check_collision: bool = true ## Prüft Hindernisse vor der Bewegung
@export var check_floor: bool = true ## Verhindert Schieben ins Leere (Bodenprüfung)
@export_flags_3d_physics var obstacle_collision_mask: int = 1

@export_group("Prompts & Text")
@export var push_prompt: String = "Schieben":
	set(val):
		push_prompt = val
		notify_state_changed()

@export var pull_prompt: String = "Ziehen":
	set(val):
		pull_prompt = val
		notify_state_changed()

@export var blocked_message: String = "Blockiert! Der Weg ist versperrt."
@export var priority: int = 15

@export_group("Audio & Feedback")
@export var push_toast_badge: String = "📦"
@export var push_toast_title: String = "BEWEGT"

@export_group("Persistence")
@export var save_position: bool = true ## Wenn false, setzt sich die Kiste beim Raum-Reload auf die Startposition zurück (Softlock-Schutz für Rätsel)

var is_moving: bool = false
var _initial_position: Vector3 = Vector3.ZERO
var _initialized_pos: bool = false
var _tween: Tween = null

func _ready() -> void:
	_resolve_hub()
	_cache_initial_position()

func _get_target_node() -> Node3D:
	_resolve_hub()
	if hub and hub is Node3D:
		return hub as Node3D
	if get_parent() is Node3D:
		return get_parent() as Node3D
	return null

func _cache_initial_position() -> void:
	if _initialized_pos:
		return
	var target := _get_target_node()
	if target and target.is_inside_tree():
		_initial_position = target.global_position
		_initialized_pos = true

func set_initial_position(pos: Vector3) -> void:
	_initial_position = pos
	_initialized_pos = true

func can_interact(_player: Node) -> bool:
	if is_moving:
		return false
	if push_trigger == PushTrigger.BUMP:
		return false
	return can_push or can_pull

func get_priority() -> int:
	return priority

func get_prompt() -> String:
	return push_prompt

func interact(player: Node) -> bool:
	if is_moving or not player:
		return false
	if push_trigger == PushTrigger.BUMP:
		return false
	var target := _get_target_node()
	if not target:
		return false

	_cache_initial_position()

	var block_pos: Vector3 = target.global_position
	var to_block: Vector3 = block_pos - (player as Node3D).global_position
	to_block.y = 0.0

	if to_block.length_squared() < 0.01:
		return false

	# Ermittle dominierende Himmelsrichtung
	var direction := Vector3.ZERO
	if abs(to_block.x) > abs(to_block.z):
		direction = Vector3(sign(to_block.x), 0.0, 0.0)
	else:
		direction = Vector3(0.0, 0.0, sign(to_block.z))

	# Achsen-Einschränkung prüfen
	if push_axis == PushAxis.X_ONLY and direction.x == 0.0:
		_show_blocked_feedback(direction, true, player)
		return false
	if push_axis == PushAxis.Z_ONLY and direction.z == 0.0:
		_show_blocked_feedback(direction, true, player)
		return false

	# Schieben ausführen
	return push(direction, player, true)

## Löst das Schieben durch physisches Dagegenlaufen (BUMP) aus
func bump(player: Node, push_direction: Vector3 = Vector3.ZERO) -> bool:
	if is_moving or not player:
		return false
	if not can_push:
		return false
	var target := _get_target_node()
	if not target:
		return false

	_cache_initial_position()

	var dir := push_direction
	dir.y = 0.0

	# Falls keine Richtung übergeben wurde: berechne aus Spieler -> Block
	if dir.length_squared() < 0.01 and player is Node3D:
		var to_block: Vector3 = target.global_position - (player as Node3D).global_position
		to_block.y = 0.0
		dir = to_block

	if dir.length_squared() < 0.01:
		return false

	# Ermittle dominierende Himmelsrichtung (4 Richtungen)
	var cardinal_dir := Vector3.ZERO
	if abs(dir.x) > abs(dir.z):
		cardinal_dir = Vector3(sign(dir.x), 0.0, 0.0)
	else:
		cardinal_dir = Vector3(0.0, 0.0, sign(dir.z))

	# Achsen-Einschränkung prüfen
	if push_axis == PushAxis.X_ONLY and cardinal_dir.x == 0.0:
		_show_blocked_feedback(cardinal_dir, true, player)
		return false
	if push_axis == PushAxis.Z_ONLY and cardinal_dir.z == 0.0:
		_show_blocked_feedback(cardinal_dir, true, player)
		return false

	return push(cardinal_dir, player, true)

func push(direction: Vector3, player: Node = null, animate: bool = true) -> bool:
	if is_moving:
		return false
	var target := _get_target_node()
	if not target:
		return false

	_cache_initial_position()

	var current_pos: Vector3 = target.global_position
	var target_pos: Vector3 = current_pos + (direction.normalized() * step_distance)

	# 1. Hindernis- und Bodenprüfung
	if check_collision and not _is_path_clear(current_pos, target_pos):
		_show_blocked_feedback(direction, animate, player)
		return false

	# 2. Bewegung ausführen
	if _tween and _tween.is_valid():
		_tween.kill()

	if animate and is_inside_tree() and push_duration > 0.0:
		is_moving = true
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(target, "global_position", target_pos, push_duration)
		_tween.finished.connect(func():
			_on_push_finished(current_pos, target_pos, direction, player)
		)
	else:
		target.global_position = target_pos
		_on_push_finished(current_pos, target_pos, direction, player)

	return true

func _on_push_finished(from_pos: Vector3, _to_pos: Vector3, direction: Vector3, player: Node) -> void:
	is_moving = false
	var target := _get_target_node()
	if not is_instance_valid(target):
		return

	if snap_to_grid and step_distance > 0.0:
		target.global_position.x = round(target.global_position.x / step_distance) * step_distance
		target.global_position.z = round(target.global_position.z / step_distance) * step_distance

	var final_pos: Vector3 = target.global_position

	if hub and is_instance_valid(hub) and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"pushed", {
			"player": player,
			"source": self,
			"from": from_pos,
			"to": final_pos,
			"direction": direction
		})

	notify_state_changed()
	if hub and is_instance_valid(hub) and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

	push_finished.emit(from_pos, final_pos)

func _is_path_clear(from_pos: Vector3, to_pos: Vector3) -> bool:
	var target := _get_target_node()
	if not target or not target.is_inside_tree():
		return true

	var world_3d := target.get_world_3d()
	if not world_3d:
		return true
	var space := world_3d.direct_space_state
	if not space:
		return true

	var exclude_rids: Array[RID] = []
	for child in target.find_children("*", "CollisionObject3D", true, false):
		if child is CollisionObject3D:
			exclude_rids.append(child.get_rid())

	# 1. Ermittle Dimensionen des Blocks (Breite, Tiefe, Höhe, Center-Offset)
	var col_shape_node := target.find_child("CollisionShape3D", true, false) as CollisionShape3D
	var box_size: Vector3 = Vector3(1.15, 1.15, 1.15)
	var center_offset: Vector3 = Vector3(0.0, 0.6, 0.0)
	if col_shape_node and col_shape_node.shape is BoxShape3D:
		var bs := col_shape_node.shape as BoxShape3D
		box_size = bs.size
		center_offset = col_shape_node.position

	# Leichter Inset (Margin), damit bündig anliegende Böden/Wände nicht fälschlich blockieren
	var test_shape := BoxShape3D.new()
	test_shape.size = Vector3(
		max(0.1, box_size.x - 0.08),
		max(0.1, box_size.y - 0.08),
		max(0.1, box_size.z - 0.08)
	)

	# 2. Zielort-Volumenprüfung (intersect_shape): Ist am Zielort bereits ein Objekt (Schild, NPC, Wand, Kiste)?
	var dest_query := PhysicsShapeQueryParameters3D.new()
	dest_query.shape = test_shape
	dest_query.transform = Transform3D(Basis(), to_pos + center_offset)
	dest_query.collision_mask = obstacle_collision_mask
	dest_query.exclude = exclude_rids
	dest_query.collide_with_areas = false
	dest_query.collide_with_bodies = true

	var dest_hits := space.intersect_shape(dest_query, 8)
	if not dest_hits.is_empty():
		return false

	# 3. Pfad-Bewegungsprüfung (cast_motion): Steht etwas im Weg zwischen Start und Ziel?
	var sweep_query := PhysicsShapeQueryParameters3D.new()
	sweep_query.shape = test_shape
	sweep_query.transform = Transform3D(Basis(), from_pos + center_offset)
	sweep_query.motion = to_pos - from_pos
	sweep_query.collision_mask = obstacle_collision_mask
	sweep_query.exclude = exclude_rids
	sweep_query.collide_with_areas = false
	sweep_query.collide_with_bodies = true

	var motion_res := space.cast_motion(sweep_query)
	if motion_res.size() >= 2 and float(motion_res[0]) < 0.99:
		return false

	# 4. Multi-Ray Sweep zur Absicherung gegen dünne Kanten/Objekte
	var delta_pos: Vector3 = to_pos - from_pos
	var move_dir: Vector3 = delta_pos.normalized()
	var perp_dir: Vector3 = Vector3(-move_dir.z, 0.0, move_dir.x)
	var half_w: float = (box_size.x if abs(move_dir.z) > 0.5 else box_size.z) * 0.45
	var y_mid: float = center_offset.y
	var y_low: float = max(0.15, center_offset.y - (box_size.y * 0.35))
	var y_high: float = center_offset.y + (box_size.y * 0.35)

	var ray_offsets: Array[Vector3] = [
		Vector3(0.0, y_mid, 0.0),
		(perp_dir * half_w) + Vector3(0.0, y_mid, 0.0),
		(-perp_dir * half_w) + Vector3(0.0, y_mid, 0.0),
		Vector3(0.0, y_low, 0.0),
		Vector3(0.0, y_high, 0.0)
	]

	for offset in ray_offsets:
		var ray_query := PhysicsRayQueryParameters3D.create(from_pos + offset, to_pos + offset, obstacle_collision_mask)
		ray_query.exclude = exclude_rids
		ray_query.collide_with_areas = false
		ray_query.collide_with_bodies = true
		var hit: Dictionary = space.intersect_ray(ray_query)
		if not hit.is_empty():
			return false

	# 5. Bodenprüfung am Zielort
	if check_floor:
		var floor_start := to_pos + Vector3(0.0, 0.4, 0.0)
		var floor_end := to_pos + Vector3(0.0, -1.5, 0.0)
		var floor_query := PhysicsRayQueryParameters3D.create(floor_start, floor_end, obstacle_collision_mask)
		floor_query.exclude = exclude_rids
		var floor_hit: Dictionary = space.intersect_ray(floor_query)
		if floor_hit.is_empty():
			return false # Loch / Abgrund am Zielort

	return true

func _show_blocked_feedback(direction: Vector3, animate: bool = true, player: Node = null) -> void:
	var target := _get_target_node()
	if animate and is_inside_tree() and target:
		var orig_pos := target.global_position
		var nudge_pos := orig_pos + (direction.normalized() * 0.08)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "global_position", nudge_pos, 0.08)
		tween.tween_property(target, "global_position", orig_pos, 0.08)

	_show_toast("🛑", "BLOCKIERT", blocked_message)

	if hub and is_instance_valid(hub) and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"blocked", {
			"player": player,
			"source": self,
			"direction": direction
		})

func reset_to_initial_position() -> void:
	if _initialized_pos:
		var target := _get_target_node()
		if target:
			target.global_position = _initial_position
			notify_state_changed()

## Alias für Fernsteuerungen (z. B. Reset-Hebel via target_method = "reset_position")
func reset_position() -> void:
	reset_to_initial_position()

func _show_toast(badge: String, title: String, text: String) -> void:
	var hud := get_tree().root.find_child("HUD", true, false) if get_tree() else null
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", badge, title, text)
	else:
		print("[%s] %s: %s" % [badge, title, text])

# ==========================================
# SAVE / LOAD
# ==========================================

func get_save_state() -> Dictionary:
	if not save_position:
		return {}
	var target := _get_target_node()
	if not target:
		return {}
	return {
		"pos_x": target.global_position.x,
		"pos_y": target.global_position.y,
		"pos_z": target.global_position.z
	}

func load_save_state(state: Dictionary) -> void:
	if state.has("pos_x") and state.has("pos_y") and state.has("pos_z"):
		var target := _get_target_node()
		if target:
			target.global_position = Vector3(
				float(state["pos_x"]),
				float(state["pos_y"]),
				float(state["pos_z"])
			)
	_cache_initial_position()
	notify_state_changed()
