@tool
class_name ShakeableBehavior
extends ObjectBehavior

## Baustein: Schüttelbares Welt-Objekt (z. B. Apfelbäume, Sträucher, Kisten, Automaten).
## Verwaltet Schüttel-Wobble-Animationen, konfigurierbare Drops, Cooldowns,
## Maximum pro Spielstand, Events ('shaken', 'depleted') und Persistenz.

@export_group("Drop Settings")
@export var drop_item_data: ItemData:
	set(val):
		drop_item_data = val
		if val and (drop_item_id.is_empty() or drop_item_id != val.id):
			drop_item_id = val.id
		notify_state_changed()

@export var drop_item_id: String = "":
	set(val):
		drop_item_id = val
		notify_state_changed()

@export var drop_amount: int = 1:
	set(val):
		drop_amount = maxi(1, val)
		notify_state_changed()

## Maximale Anzahl Drops pro Spielstand (-1 oder 0 für unendlich)
@export var max_drops: int = 1:
	set(val):
		max_drops = val
		_check_depleted_state()
		notify_state_changed()

## Szene des fallenden Drops (Standard: pickable_item.tscn)
@export var drop_scene: PackedScene = preload("res://scenes/objects/pickable_item.tscn")

@export_group("Shake & Cooldown")
@export var shake_cooldown: float = 0.8

@export_group("Prompts & Text")
@export var prompt_shake: String = "Shake":
	set(val):
		prompt_shake = val
		notify_state_changed()

@export var prompt_depleted: String = "Empty":
	set(val):
		prompt_depleted = val
		notify_state_changed()

@export var depleted_toast_text: String = "Nothing left here.":
	set(val):
		depleted_toast_text = val

@export_group("Node References")
## Node3D, das beim Schütteln wackelt (z. B. Krone/Visual)
@export var visual_node_path: NodePath

## Optionaler Node3D Startpunkt für fallende Früchte
@export var drop_spawn_point_path: NodePath

## Optionale sichtbare Früchte im Baum, die ausgeblendet werden, sobald der Baum leer ist
@export var hanging_mesh_path: NodePath

@export var priority: int = 10

var shakes_count: int = 0
var drops_spawned: int = 0
var is_depleted: bool = false
var _is_shaking: bool = false
var _last_shake_time: float = -100.0

func _ready() -> void:
	_check_depleted_state()
	_update_hanging_visual(not is_depleted)

func _check_depleted_state() -> void:
	if max_drops > 0 and drops_spawned >= max_drops:
		is_depleted = true
	else:
		is_depleted = false

func can_interact(_player: Node) -> bool:
	return true

func get_priority() -> int:
	return priority

func get_prompt() -> String:
	if is_depleted:
		return prompt_depleted
	return prompt_shake

func _get_hub_3d() -> Node3D:
	_resolve_hub()
	if hub is Node3D:
		return hub as Node3D
	if get_parent() is Node3D:
		return get_parent() as Node3D
	return null

func interact(player: Node) -> bool:
	_resolve_hub()
	if _is_shaking:
		return true

	if is_depleted:
		_show_toast("🍃", "LEER", depleted_toast_text)
		return true

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_shake_time < shake_cooldown:
		return true
	_last_shake_time = now

	_is_shaking = true
	shakes_count += 1

	# 1. Schüttel-Wobble Animation auf dem Ziel-Visual abspielen
	_play_shake_animation()

	# 2. Prüfen, ob noch Drops verfügbar sind
	var spawned_this_time := false
	if max_drops <= 0 or drops_spawned < max_drops:
		drops_spawned += 1
		spawned_this_time = true
		_spawn_falling_drop(player)

		if max_drops > 0 and drops_spawned >= max_drops:
			is_depleted = true
			_update_hanging_visual(false)
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"depleted", {
					"player": player,
					"source": self
				})

	# 3. 'shaken' Event feuern
	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"shaken", {
			"player": player,
			"source": self,
			"shakes_count": shakes_count,
			"drops_spawned": drops_spawned,
			"is_depleted": is_depleted,
			"dropped": spawned_this_time
		})

	# 4. Zustand persistieren
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

	notify_state_changed()
	return true

func _play_shake_animation() -> void:
	var visual: Node3D = null
	if not visual_node_path.is_empty():
		visual = get_node_or_null(visual_node_path) as Node3D
	if not visual and hub is Node3D:
		visual = hub as Node3D

	if not visual or not is_inside_tree():
		_is_shaking = false
		return

	var orig_rot := visual.rotation
	var tween := create_tween()
	tween.tween_property(visual, "rotation:z", orig_rot.z + deg_to_rad(3.5), 0.08)
	tween.tween_property(visual, "rotation:z", orig_rot.z - deg_to_rad(3.5), 0.08)
	tween.tween_property(visual, "rotation:x", orig_rot.x + deg_to_rad(2.5), 0.08)
	tween.tween_property(visual, "rotation:x", orig_rot.x - deg_to_rad(2.5), 0.08)
	tween.tween_property(visual, "rotation", orig_rot, 0.1)
	tween.tween_callback(func():
		_is_shaking = false
		notify_state_changed()
	)

func _spawn_falling_drop(player: Node = null) -> void:
	if not drop_scene:
		return

	var drop_inst: Node3D = drop_scene.instantiate() as Node3D
	if not drop_inst:
		return

	# Item-Definitionen übertragen
	if "item_data" in drop_inst and drop_item_data:
		drop_inst.item_data = drop_item_data
	if "item_id" in drop_inst:
		drop_inst.item_id = drop_item_id
	if "item_count" in drop_inst:
		drop_inst.item_count = drop_amount
	elif "amount" in drop_inst:
		drop_inst.amount = drop_amount

	drop_inst.add_to_group("dynamic_ground_pickups")

	# In Eltern-Szene oder Szenenwurzel einhängen
	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if not parent_node:
		parent_node = get_tree().root
	parent_node.add_child(drop_inst)

	var hub_3d := _get_hub_3d()
	var hub_pos: Vector3 = hub_3d.global_position if hub_3d else Vector3.ZERO

	# Startposition bestimmen
	var drop_start := hub_pos + Vector3(0, 3.4, 0)
	if not drop_spawn_point_path.is_empty():
		var sp := get_node_or_null(drop_spawn_point_path) as Node3D
		if sp:
			drop_start = sp.global_position

	# Zielposition Richtung Spieler berechnen
	var drop_dir := Vector3(0.5, 0.0, 0.8).normalized()
	var offset_dist := 1.8
	if player is Node3D:
		var diff: Vector3 = (player as Node3D).global_position - hub_pos
		diff.y = 0.0
		var dist := diff.length()
		if dist > 0.01:
			drop_dir = diff / dist
			if dist > 1.4:
				offset_dist = clampf(dist * 0.65, 1.2, 2.5)
			else:
				offset_dist = 1.6

	var jitter := Vector3(randf_range(-0.15, 0.15), 0.0, randf_range(-0.15, 0.15))
	var drop_target := hub_pos + (drop_dir * offset_dist) + jitter

	# Raycast nach unten zur Terrain-Bodenhöhe
	var ground_y := hub_pos.y
	if hub_3d and hub_3d.is_inside_tree():
		var space_state := hub_3d.get_world_3d().direct_space_state
		var ray_query := PhysicsRayQueryParameters3D.create(
			Vector3(drop_target.x, hub_pos.y + 4.0, drop_target.z),
			Vector3(drop_target.x, hub_pos.y - 8.0, drop_target.z)
		)
		ray_query.collision_mask = 1
		var result := space_state.intersect_ray(ray_query)
		if result:
			ground_y = result.position.y
	drop_target.y = ground_y

	# Fall-Animation über drop_from ausführen
	if drop_inst.has_method("drop_from"):
		drop_inst.call("drop_from", drop_start, drop_target)
	else:
		drop_inst.global_position = drop_target

func _update_hanging_visual(visible_state: bool = true) -> void:
	if hanging_mesh_path.is_empty():
		return
	var hm := get_node_or_null(hanging_mesh_path) as Node3D
	if not hm:
		return

	if is_depleted or (max_drops > 0 and drops_spawned >= max_drops):
		hm.visible = false
		return

	hm.visible = visible_state

	var children := hm.get_children()
	if children.size() > 1 and max_drops > 0:
		var remaining := maxi(0, max_drops - drops_spawned)
		for i in range(children.size()):
			if children[i] is Node3D:
				(children[i] as Node3D).visible = (i < remaining)

func _show_toast(badge: String, title: String, text: String) -> void:
	var hud: Node = null
	if is_inside_tree():
		hud = get_tree().root.find_child("HUD", true, false)
	if not hud:
		hud = get_node_or_null("/root/HUD")
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", badge, title, text)

# ==========================================
# SAVE / LOAD
# ==========================================

func get_save_state() -> Dictionary:
	return {
		"shakes_count": shakes_count,
		"drops_spawned": drops_spawned,
		"is_depleted": is_depleted
	}

func load_save_state(state: Dictionary) -> void:
	if state.has("shakes_count"):
		shakes_count = int(state["shakes_count"])
	if state.has("drops_spawned"):
		drops_spawned = int(state["drops_spawned"])
	if state.has("is_depleted"):
		is_depleted = bool(state["is_depleted"])

	_check_depleted_state()
	_update_hanging_visual(not is_depleted)
	notify_state_changed()
