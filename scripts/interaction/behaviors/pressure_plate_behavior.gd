@tool
class_name PressurePlateBehavior
extends ObjectBehavior

## Baustein: Druckplatte (ObjPressurePlate).
## Erkennt Spieler und/oder schiebbare Blöcke über eine Area3D.
## Unterstützt HOLD- (Gedrückt solange belegt), ONCE- und TIMED-Modus,
## animiertes Absinken der Platte, Ansteuerung von Zielobjekten (Türen, Tore)
## und Savegame-Persistenz.

enum PlateMode {
	HOLD = 0,  ## Aktiv solange ein Körper auf der Platte steht; hebt sich danach wieder
	ONCE = 1,  ## Rastet bei erstmaligem Betreten dauerhaft ein
	TIMED = 2  ## Bleibt für 'timed_duration' Sekunden gedrückt und springt dann zurück
}

@export_group("Plate Mode")
@export var plate_mode: PlateMode = PlateMode.HOLD:
	set(val):
		plate_mode = val
		notify_state_changed()

@export var is_pressed: bool = false:
	set(val):
		is_pressed = val
		_update_visual(false)
		if hub and "_is_pressed" in hub:
			hub.set("_is_pressed", val)
		notify_state_changed()

@export var timed_duration: float = 4.0 ## Dauer für TIMED-Modus in Sekunden

@export_group("Filter & Detection")
@export var trigger_by_player: bool = true ## Reagiert auf den Spieler (Barnaby)
@export var trigger_by_blocks: bool = true ## Reagiert auf schiebbare Blöcke / Kisten
@export var detection_area_path: NodePath = NodePath("TriggerArea")

@export_group("Targets & Remote Control")
## Direkte Zielknoten (z. B. Türen, Tore, Mechanismen), die gesteuert werden sollen
@export var target_objects: Array[NodePath] = []:
	set(val):
		target_objects = val.duplicate()

@export var target_method: String = "activate" ## Methode am Ziel: 'activate', 'open', 'toggle' etc.
@export var call_deactivate_on_release: bool = true ## Ruft 'deactivate' oder 'close' am Ziel auf, wenn entlastet

@export_group("Visual Feedback")
@export var plate_mesh_path: NodePath = NodePath("PlateMesh")
@export var pressed_depth: float = 0.05 ## Wie tief die Platte nach unten einsinkt
@export var animation_duration: float = 0.16

@export_group("Toast Feedback")
@export var activate_toast_badge: String = "🔘"
@export var activate_toast_title: String = "DRUCKPLATTE"
@export var activate_toast_message: String = ""
@export var deactivate_toast_message: String = ""
@export var priority: int = 10

var _overlapping_bodies: Array[Node] = []
var _initial_plate_y: float = 0.05
var _initialized_plate: bool = false
var _tween: Tween = null
var _timed_timer: SceneTreeTimer = null

func _ready() -> void:
	target_objects = target_objects.duplicate()
	_resolve_hub()
	_cache_initial_plate()
	_setup_detection_area()
	_update_visual(false)

func _cache_initial_plate() -> void:
	if _initialized_plate:
		return
	var mesh := _get_plate_mesh()
	if mesh:
		_initial_plate_y = mesh.position.y
		_initialized_plate = true

func _setup_detection_area() -> void:
	var area := _get_detection_area()
	if not area:
		return
	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if not area.body_exited.is_connected(_on_body_exited):
		area.body_exited.connect(_on_body_exited)

func _get_detection_area() -> Area3D:
	_resolve_hub()
	var area: Area3D = null
	if hub and not detection_area_path.is_empty():
		area = hub.get_node_or_null(detection_area_path) as Area3D
	if not area and not detection_area_path.is_empty():
		area = get_node_or_null(detection_area_path) as Area3D
	if not area and hub:
		area = hub.find_child("TriggerArea", true, false) as Area3D
	if not area and hub:
		area = hub.find_child("DetectionArea", true, false) as Area3D
	return area

func _get_plate_mesh() -> Node3D:
	_resolve_hub()
	var mesh: Node3D = null
	if hub and not plate_mesh_path.is_empty():
		mesh = hub.get_node_or_null(plate_mesh_path) as Node3D
	if not mesh and not plate_mesh_path.is_empty():
		mesh = get_node_or_null(plate_mesh_path) as Node3D
	if not mesh and hub:
		mesh = hub.find_child("PlateMesh", true, false) as Node3D
	return mesh

func can_interact(_player: Node) -> bool:
	# Druckplatten werden physisch betreten, nicht mit 'E' gelesen/benutzt
	return false

func get_priority() -> int:
	return priority

func get_prompt() -> String:
	return ""

func _is_valid_body(body: Node) -> bool:
	if not body:
		return false
	# 1. Spieler prüfen
	if trigger_by_player:
		if body is CharacterBody3D or body.is_in_group("player") or body.name == "Player":
			return true
	# 2. Schiebbare Blöcke prüfen
	if trigger_by_blocks:
		if body.is_in_group("pushables"):
			return true
		if body.get_parent() and body.get_parent().is_in_group("pushables"):
			return true
		if body.owner and body.owner.is_in_group("pushables"):
			return true
	return false

func _on_body_entered(body: Node) -> void:
	if not _is_valid_body(body):
		return
	if not _overlapping_bodies.has(body):
		_overlapping_bodies.append(body)
	if not is_pressed:
		press(true, body)

func _exit_tree() -> void:
	var area := _get_detection_area()
	if area:
		if area.body_entered.is_connected(_on_body_entered):
			area.body_entered.disconnect(_on_body_entered)
		if area.body_exited.is_connected(_on_body_exited):
			area.body_exited.disconnect(_on_body_exited)

func _on_body_exited(body: Node) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if body and (not body.is_inside_tree() or body.is_queued_for_deletion()):
		return
	var st = get_node_or_null("/root/SceneTransition")
	if st and st.get("is_transitioning"):
		return
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.get("is_transitioning"):
		return
	_overlapping_bodies.erase(body)
	if plate_mode == PlateMode.HOLD and _overlapping_bodies.is_empty() and is_pressed:
		release(true, body)

func press(animate: bool = true, trigger_node: Node = null) -> void:
	if is_pressed and plate_mode != PlateMode.TIMED:
		return

	is_pressed = true
	if hub and "_is_pressed" in hub:
		hub.set("_is_pressed", true)

	_update_visual(animate)
	_trigger_targets_on()

	if not activate_toast_message.is_empty():
		_show_toast(activate_toast_badge, activate_toast_title, activate_toast_message)

	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"activated", {"trigger_node": trigger_node, "source": self, "is_pressed": true})
		hub.call("emit_object_event", &"toggled", {"trigger_node": trigger_node, "source": self, "is_pressed": true})

	if plate_mode == PlateMode.TIMED and is_inside_tree():
		_timed_timer = get_tree().create_timer(timed_duration)
		_timed_timer.timeout.connect(func():
			if is_pressed and _overlapping_bodies.is_empty():
				release(true)
		)

	notify_state_changed()
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

func release(animate: bool = true, trigger_node: Node = null) -> void:
	if not is_pressed or plate_mode == PlateMode.ONCE:
		return

	is_pressed = false
	if hub and "_is_pressed" in hub:
		hub.set("_is_pressed", false)

	_update_visual(animate)
	_trigger_targets_off()

	if not deactivate_toast_message.is_empty():
		_show_toast(activate_toast_badge, activate_toast_title, deactivate_toast_message)

	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"deactivated", {"trigger_node": trigger_node, "source": self, "is_pressed": false})
		hub.call("emit_object_event", &"toggled", {"trigger_node": trigger_node, "source": self, "is_pressed": false})

	notify_state_changed()
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

func _trigger_targets_on() -> void:
	_resolve_hub()
	for target_path in target_objects:
		var target := _resolve_target_node(target_path)
		if not target:
			continue
		if not target_method.is_empty() and target.has_method(target_method):
			target.call(target_method)
		elif target.has_method("activate"):
			target.call("activate")
		elif target.has_method("open"):
			target.call("open")
		elif target.has_method("toggle"):
			target.call("toggle")

func _trigger_targets_off() -> void:
	_resolve_hub()
	for target_path in target_objects:
		var target := _resolve_target_node(target_path)
		if not target:
			continue
		if call_deactivate_on_release:
			if target.has_method("deactivate"):
				target.call("deactivate")
			elif target.has_method("close"):
				target.call("close")
			elif target_method == "toggle" and target.has_method("toggle"):
				target.call("toggle")

func _resolve_target_node(path: NodePath) -> Node:
	if path.is_empty():
		return null
	var target: Node = null
	if hub:
		target = hub.get_node_or_null(path)
	if not target:
		target = get_node_or_null(path)
	if not target and is_inside_tree() and get_tree().current_scene:
		target = get_tree().current_scene.get_node_or_null(path)
	if not target and is_inside_tree():
		target = get_tree().root.get_node_or_null(path)
	return target

func _update_visual(animate: bool) -> void:
	var mesh := _get_plate_mesh()
	if not mesh:
		return
	_cache_initial_plate()

	if _tween and _tween.is_valid():
		_tween.kill()

	var target_y := _initial_plate_y - (pressed_depth if is_pressed else 0.0)
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(mesh, "position:y", target_y, animation_duration)
	else:
		mesh.position.y = target_y

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
	return {
		"is_pressed": is_pressed
	}

func load_save_state(state: Dictionary) -> void:
	if state.has("is_pressed"):
		is_pressed = bool(state["is_pressed"])
		if hub and "_is_pressed" in hub:
			hub.set("_is_pressed", is_pressed)
	_update_visual(false)
	notify_state_changed()
