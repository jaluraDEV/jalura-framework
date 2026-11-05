@tool
class_name SwitchBehavior
extends ObjectBehavior

## Baustein: Schalter & Hebel (ObjSwitch / ObjLever).
## Unterstützt TOGGLE-, ONCE- und TIMED-Modus,
## Animation des Hebelarms / Knopfs, Ansteuerung von Zielobjekten (target_objects),
## Event-Auslösung und Savegame-Persistenz.

enum SwitchMode {
	TOGGLE = 0, ## Wechselt bei jeder Betätigung zwischen Aktiv und Inaktiv
	ONCE = 1,   ## Einmalige Betätigung pro Spielstand; bleibt danach aktiv
	TIMED = 2   ## Aktiviert sich für 'timed_duration' Sekunden und schaltet sich dann automatisch zurück
}

@export_group("Switch Mode")
@export var switch_mode: SwitchMode = SwitchMode.TOGGLE:
	set(val):
		switch_mode = val
		notify_state_changed()

@export var is_active: bool = false:
	set(val):
		is_active = val
		_update_visual(false)
		if hub and "_is_active" in hub:
			hub.set("_is_active", val)
		notify_state_changed()

@export var timed_duration: float = 5.0 ## Dauer in Sekunden für TIMED-Modus
@export var can_player_interact: bool = true

@export_group("Targets & Remote Control")
## Direkte Zielknoten (z. B. Türen, Tore, Lichter), die gesteuert werden sollen
@export var target_objects: Array[NodePath] = []:
	set(val):
		target_objects = val.duplicate()

@export var target_method: String = "toggle" ## Methode am Ziel: 'toggle', 'activate', 'open' etc.
@export var call_deactivate_on_off: bool = true ## Beim Ausschalten: 'deactivate' oder 'close' am Ziel aufrufen

@export_group("Visual Feedback")
@export var handle_node_path: NodePath = NodePath("LeverHandle") ## Beweglicher Hebelarm oder Knopf
@export var active_rotation: Vector3 = Vector3(35.0, 0.0, 0.0) ## Drehung in Grad wenn aktiv
@export var inactive_rotation: Vector3 = Vector3(-35.0, 0.0, 0.0) ## Drehung in Grad wenn inaktiv
@export var is_button: bool = false ## True = Positionsversatz (Knopf), False = Rotation (Hebel)
@export var active_offset: Vector3 = Vector3(0.0, 0.0, -0.05)
@export var inactive_offset: Vector3 = Vector3.ZERO
@export var animation_duration: float = 0.25

@export_group("Prompts & Text")
@export var activate_prompt: String = "Activate":
	set(val):
		activate_prompt = val
		notify_state_changed()

@export var deactivate_prompt: String = "Reset":
	set(val):
		deactivate_prompt = val
		notify_state_changed()

@export var already_active_prompt: String = "":
	set(val):
		already_active_prompt = val
		notify_state_changed()

@export var priority: int = 15

@export_group("Toast Feedback")
@export var activate_toast_badge: String = "⚙️"
@export var activate_toast_title: String = "HEBEL"
@export var activate_toast_message: String = ""

var _tween: Tween = null
var _timed_timer: SceneTreeTimer = null

func _ready() -> void:
	target_objects = target_objects.duplicate()
	_update_visual(false)

func can_interact(_player: Node) -> bool:
	if not can_player_interact:
		return false
	if switch_mode == SwitchMode.ONCE and is_active:
		return not already_active_prompt.is_empty()
	return true

func get_priority() -> int:
	return priority

func get_prompt() -> String:
	if switch_mode == SwitchMode.ONCE and is_active:
		return already_active_prompt
	if is_active:
		return deactivate_prompt
	return activate_prompt

func interact(player: Node) -> bool:
	_resolve_hub()

	if switch_mode == SwitchMode.ONCE:
		if is_active:
			if not already_active_prompt.is_empty():
				_show_toast(activate_toast_badge, activate_toast_title, already_active_prompt)
			return true
		activate(true, player)
		return true

	if switch_mode == SwitchMode.TIMED:
		activate(true, player)
		return true

	if switch_mode == SwitchMode.TOGGLE:
		toggle(true, player)
		return true

	return true

func activate(animate: bool = true, player: Node = null) -> void:
	if is_active and switch_mode != SwitchMode.TIMED:
		return

	is_active = true
	if hub and "_is_active" in hub:
		hub.set("_is_active", true)
	_update_visual(animate)
	_trigger_targets_on()

	if not activate_toast_message.is_empty():
		_show_toast(activate_toast_badge, activate_toast_title, activate_toast_message)

	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"activated", {"player": player, "source": self, "is_active": true})
		hub.call("emit_object_event", &"toggled", {"player": player, "source": self, "is_active": true})

	if switch_mode == SwitchMode.TIMED and is_inside_tree():
		_timed_timer = get_tree().create_timer(timed_duration)
		_timed_timer.timeout.connect(func():
			if is_active:
				deactivate(true)
		)

	notify_state_changed()
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

func deactivate(animate: bool = true, player: Node = null) -> void:
	if not is_active:
		return

	is_active = false
	if hub and "_is_active" in hub:
		hub.set("_is_active", false)
	_update_visual(animate)
	_trigger_targets_off()

	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"deactivated", {"player": player, "source": self, "is_active": false})
		hub.call("emit_object_event", &"toggled", {"player": player, "source": self, "is_active": false})

	notify_state_changed()
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

func toggle(animate: bool = true, player: Node = null) -> void:
	if is_active:
		deactivate(animate, player)
	else:
		activate(animate, player)

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
		if call_deactivate_on_off:
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

func _get_handle_node() -> Node3D:
	_resolve_hub()
	var handle: Node3D = null
	if hub and not handle_node_path.is_empty():
		handle = hub.get_node_or_null(handle_node_path) as Node3D
	if not handle and not handle_node_path.is_empty():
		handle = get_node_or_null(handle_node_path) as Node3D
	if not handle and hub:
		handle = hub.find_child("LeverHandle", true, false) as Node3D
	if not handle and hub:
		handle = hub.find_child("Handle", true, false) as Node3D
	if not handle and hub:
		handle = hub.find_child("Button", true, false) as Node3D
	return handle

func _update_visual(animate: bool) -> void:
	var handle := _get_handle_node()
	if not handle:
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	if is_button:
		var target_pos := active_offset if is_active else inactive_offset
		if animate and is_inside_tree():
			_tween = create_tween()
			_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(handle, "position", target_pos, animation_duration)
		else:
			handle.position = target_pos
	else:
		var target_rot := active_rotation if is_active else inactive_rotation
		if animate and is_inside_tree():
			_tween = create_tween()
			_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(handle, "rotation_degrees", target_rot, animation_duration)
		else:
			handle.rotation_degrees = target_rot

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
		"is_active": is_active
	}

func load_save_state(state: Dictionary) -> void:
	if state.has("is_active"):
		is_active = bool(state["is_active"])
		if hub and "_is_active" in hub:
			hub.set("_is_active", is_active)
	_update_visual(false)
	notify_state_changed()
