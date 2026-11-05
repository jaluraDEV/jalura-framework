@tool
class_name SceneEventsBehavior
extends ObjectBehavior

## Baustein: Meldet Szenen-Ereignisse (scene_entered, scene_first_entered) an den InteractiveObject-Hub,
## damit universelle ObjectTrigger darauf reagieren können (Dialoge, Toasts, Flags, Quests etc.).

signal scene_entered(scene_id: StringName, is_first: bool)
signal scene_first_entered(scene_id: StringName)

@export var auto_trigger: bool = true
@export var delay_seconds: float = 0.05 ## Kurze Verzögerung, damit HUD und Kamera vollständig bereit sind

var _has_triggered_this_load: bool = false
var _first_entry_fired: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_resolve_hub()
	if auto_trigger:
		call_deferred("_schedule_trigger")

func _schedule_trigger() -> void:
	if delay_seconds > 0.0:
		var timer := get_tree().create_timer(delay_seconds)
		timer.timeout.connect(_on_trigger_timer, CONNECT_ONE_SHOT)
	else:
		_trigger_events()

func _on_trigger_timer() -> void:
	_trigger_events()

func _trigger_events() -> void:
	if _has_triggered_this_load:
		return
	_has_triggered_this_load = true

	var st = get_node_or_null("/root/SceneTransition")
	var gf = get_node_or_null("/root/GameFlags")
	var current_scene := get_tree().current_scene if get_tree() else null

	var cur_scene_id: StringName = st.current_scene_id if st else &""
	if cur_scene_id.is_empty() and current_scene:
		var wm: WorldMap = load("res://resources/world/world_map.tres")
		if wm:
			cur_scene_id = wm.find_scene_id_by_path(current_scene.scene_file_path)
		if cur_scene_id.is_empty():
			cur_scene_id = StringName(current_scene.name.to_snake_case())

	var first_flag := "scene_first_entered_" + str(cur_scene_id)
	var is_first: bool = true
	if gf and gf.has_method("has_flag"):
		if gf.call("has_flag", first_flag):
			is_first = false
		else:
			gf.call("set_flag", first_flag, true)
	elif _first_entry_fired:
		is_first = false

	var event_data := {
		"scene_id": cur_scene_id,
		"is_first": is_first
	}

	if is_first:
		_first_entry_fired = true
		scene_first_entered.emit(cur_scene_id)
		if hub and is_instance_valid(hub) and hub.has_method("emit_object_event"):
			hub.call("emit_object_event", &"scene_first_entered", event_data)

	scene_entered.emit(cur_scene_id, is_first)
	if hub and is_instance_valid(hub) and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"scene_entered", event_data)

# ==========================================
# SAVE / LOAD PERSISTENZ
# ==========================================

func get_save_state() -> Dictionary:
	return {
		"first_entry_fired": _first_entry_fired
	}

func load_save_state(state: Dictionary) -> void:
	if state.has("first_entry_fired"):
		_first_entry_fired = bool(state["first_entry_fired"])
