@tool
class_name TransitionBehavior
extends ObjectBehavior

## Baustein für Szenenübergänge (Türen, Tore, Laufzonen, Wege).
## Unterstützt Modus INTERACT (Taste [E]) und ENTER_AREA (Laufzone beim Hineintreten).
## Beinhaltet Schloss-, Schlüssel- und Bedingungslogik (QuestCondition),
## Einweg-/Laufzonen-Entschärfung gegen Pendeln, Hindernis-Warteschlange (Dialog/Transition),
## Spam-Schutz bei gesperrten Zonen und Savegame-Persistenz.

enum TransitionMode {
	INTERACT = 0,   ## Spieler drückt [E] zum Betreten / Aufschließen
	ENTER_AREA = 1  ## Automatischer Übergang beim Hineintreten in die Zone
}

signal transition_used(target_scene_id: StringName, target_spawn_id: StringName)
signal transition_blocked(target_scene_id: StringName, reason: String)
signal unlocked(player: Node)

@export_group("Target Settings")
@export var transition_mode: TransitionMode = TransitionMode.INTERACT:
	set(val):
		transition_mode = val
		_setup_area_detection()
		notify_state_changed()

@export var target_scene_id: StringName = &"":
	set(val):
		target_scene_id = val
		notify_state_changed()

@export var target_spawn_id: StringName = &"":
	set(val):
		target_spawn_id = val
		notify_state_changed()

@export_group("Lock & Conditions")
@export var is_locked: bool = false:
	set(val):
		is_locked = val
		notify_state_changed()

@export var key_item: ItemData = null:
	set(val):
		key_item = val
		if key_item and key_item_id.is_empty():
			key_item_id = key_item.id
		notify_state_changed()

@export var key_item_id: String = "":
	set(val):
		key_item_id = val
		notify_state_changed()

@export var consume_key: bool = false
@export var lock_conditions: Array[QuestCondition] = []:
	set(val):
		lock_conditions = val.duplicate(true)
		notify_state_changed()

@export var locked_message: String = "Hier geht es gerade nicht weiter.":
	set(val):
		locked_message = val

@export var unlock_prompt: String = "Unlock":
	set(val):
		unlock_prompt = val
		notify_state_changed()

@export_group("Prompts & Text")
@export var prompt_text: String = "Betreten":
	set(val):
		prompt_text = val
		notify_state_changed()

@export var priority: int = 12

var _area_detector: Area3D = null
var _disarmed: bool = false
var _player_inside: bool = false
var _has_shown_locked_message_this_stay: bool = false
var _waiting_for_clearance: bool = false
var _cached_player: Node = null

func _ready() -> void:
	lock_conditions = lock_conditions.duplicate(true)
	_resolve_hub()
	_setup_area_detection()
	add_to_group("transition_behaviors")
	set_process(false)
	_check_initial_overlap.call_deferred()

func _check_initial_overlap() -> void:
	if Engine.is_editor_hint():
		return
	if transition_mode != TransitionMode.ENTER_AREA or not _area_detector:
		return
	if is_inside_tree():
		await get_tree().physics_frame
	if not is_inside_tree() or not _area_detector:
		return
	for body in _area_detector.get_overlapping_bodies():
		if _is_player(body):
			_player_inside = true
			_cached_player = body
			_disarmed = true
			break

func _setup_area_detection() -> void:
	if Engine.is_editor_hint():
		return
	if transition_mode != TransitionMode.ENTER_AREA:
		return

	var target := _get_target_node()
	if not target:
		return

	var area := target.find_child("TriggerArea", true, false) as Area3D
	if not area:
		area = target.find_child("ZoneArea", true, false) as Area3D
	if not area:
		for child in target.get_children():
			if child is Area3D and not (child is Interactable):
				area = child
				break

	if area and area != _area_detector:
		if _area_detector:
			if _area_detector.body_entered.is_connected(_on_body_entered):
				_area_detector.body_entered.disconnect(_on_body_entered)
			if _area_detector.body_exited.is_connected(_on_body_exited):
				_area_detector.body_exited.disconnect(_on_body_exited)
		_area_detector = area
		if not _area_detector.body_entered.is_connected(_on_body_entered):
			_area_detector.body_entered.connect(_on_body_entered)
		if not _area_detector.body_exited.is_connected(_on_body_exited):
			_area_detector.body_exited.connect(_on_body_exited)

func disarm_if_overlapping(player_node: Node) -> void:
	if transition_mode != TransitionMode.ENTER_AREA or not _area_detector:
		return
	if not is_instance_valid(player_node) or not (player_node is Node3D):
		return
	if _area_detector.overlaps_body(player_node as Node3D):
		_player_inside = true
		_cached_player = player_node
		_disarmed = true

func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	_cached_player = body

	var st = get_node_or_null("/root/SceneTransition")
	if st and st.get("is_transitioning") == true:
		_disarmed = true
		return

	if _disarmed:
		return

	_try_enter_area_transition(body)

func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = false
	_disarmed = false
	_has_shown_locked_message_this_stay = false
	_waiting_for_clearance = false
	set_process(false)

func _try_enter_area_transition(player: Node) -> void:
	if _disarmed:
		return

	# Schloss & Bedingungen prüfen
	if is_exit_locked():
		if _can_player_unlock():
			_consume_key_if_needed()
			is_locked = false
			if hub and "is_locked" in hub:
				hub.set("is_locked", false)
			if hub and hub.has_method("_save_state_to_manager"):
				hub.call("_save_state_to_manager")
			_show_toast("🗝️", "AUFGESCHLOSSEN", "Ausgang aufgeschlossen!")
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"unlocked", {"player": player, "source": self})
			unlocked.emit(player)
			notify_state_changed()
			_execute_transition(player)
		else:
			# Gesperrt: locked_message nur 1x pro Betreten zeigen (kein Spam pro Frame!)
			if not _has_shown_locked_message_this_stay:
				_show_toast("🔒", "LOCKED", locked_message)
				_has_shown_locked_message_this_stay = true
				if hub and hub.has_method("emit_object_event"):
					hub.call("emit_object_event", &"transition_blocked", {"player": player, "source": self, "reason": "locked"})
				transition_blocked.emit(target_scene_id, "locked")
		return

	# Nicht gesperrt: Temporäre Hindernisse prüfen (Dialog oder Überblendung)
	var hud: Node = _get_active_hud()
	var diag_active: bool = hud != null and hud.is_dialogue_active
	var st = get_node_or_null("/root/SceneTransition")
	var rm = get_node_or_null("/root/RoomManager")
	var trans_active: bool = (st != null and st.get("is_transitioning") == true) or (rm != null and rm.get("is_transitioning") == true)

	if diag_active or trans_active:
		# Temporäres Hindernis! Warten, bis es frei wird
		_waiting_for_clearance = true
		set_process(true)
		return

	# Kein temporäres Hindernis: Freigabe beenden und Übergang starten
	_waiting_for_clearance = false
	set_process(false)
	_execute_transition(player)

func _process(_delta: float) -> void:
	if not _waiting_for_clearance:
		set_process(false)
		return
	if not _player_inside or _disarmed:
		_waiting_for_clearance = false
		set_process(false)
		return

	var st = get_node_or_null("/root/SceneTransition")
	var rm = get_node_or_null("/root/RoomManager")
	var hud: Node = _get_active_hud()

	var is_trans: bool = (st != null and st.get("is_transitioning") == true) or (rm != null and rm.get("is_transitioning") == true)
	var is_diag: bool = hud != null and hud.is_dialogue_active

	if not is_trans and not is_diag:
		_waiting_for_clearance = false
		set_process(false)
		if _player_inside and not _disarmed:
			_try_enter_area_transition(_cached_player)

func _is_player(node: Node) -> bool:
	if not node:
		return false
	return node.is_in_group("player") or node.name == "Player"

func _get_effective_key_id() -> String:
	if not key_item_id.is_empty():
		return key_item_id
	if key_item and not key_item.id.is_empty():
		return key_item.id
	for cond in lock_conditions:
		if cond is ItemCondition and not cond.item_id.is_empty():
			return cond.item_id
	return ""

func _are_lock_conditions_met() -> bool:
	if lock_conditions.is_empty():
		return true
	for cond in lock_conditions:
		if cond and not cond.is_met(hub if hub else self):
			return false
	return true

func is_exit_locked() -> bool:
	if is_locked:
		return true
	if not _are_lock_conditions_met():
		return true
	return false

func _can_player_unlock() -> bool:
	if not _are_lock_conditions_met():
		return false
	if is_locked:
		var inv := _get_inventory()
		var key_id := _get_effective_key_id()
		if not key_id.is_empty() and inv:
			return inv.has_item(key_id, 1)
		return false
	return true

func _consume_key_if_needed() -> void:
	if not consume_key:
		return
	var inv := _get_inventory()
	if not inv:
		return
	var key_id := _get_effective_key_id()
	if not key_id.is_empty() and inv.has_item(key_id, 1):
		inv.remove_item(key_id, 1)

func can_interact(_player: Node) -> bool:
	if transition_mode == TransitionMode.ENTER_AREA:
		return false
	return not target_scene_id.is_empty()

func get_priority() -> int:
	return priority

func get_prompt() -> String:
	if is_exit_locked():
		if _can_player_unlock():
			return unlock_prompt
		return prompt_text
	return prompt_text

func interact(player: Node) -> bool:
	if transition_mode == TransitionMode.ENTER_AREA:
		return false

	if is_exit_locked():
		if _can_player_unlock():
			_consume_key_if_needed()
			is_locked = false
			if hub and "is_locked" in hub:
				hub.set("is_locked", false)
			if hub and hub.has_method("_save_state_to_manager"):
				hub.call("_save_state_to_manager")
			_show_toast("🗝️", "AUFGESCHLOSSEN", "Ausgang aufgeschlossen!")
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"unlocked", {"player": player, "source": self})
			unlocked.emit(player)
			notify_state_changed()
			return _execute_transition(player)
		else:
			_show_toast("🔒", "LOCKED", locked_message)
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"transition_blocked", {"player": player, "source": self, "reason": "locked"})
			transition_blocked.emit(target_scene_id, "locked")
			return true

	return _execute_transition(player)

func _execute_transition(player: Node = null) -> bool:
	if target_scene_id.is_empty():
		return false

	var st = get_node_or_null("/root/SceneTransition")
	if not st:
		push_warning("TransitionBehavior: Autoload 'SceneTransition' nicht gefunden!")
		return false

	if st.get("is_transitioning") == true:
		return false

	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.get("is_transitioning") == true:
		return false

	var hud: Node = _get_active_hud()
	if hud and hud.is_dialogue_active:
		return false

	if hub and is_instance_valid(hub) and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"transition_used", {
			"player": player,
			"source": self,
			"target_scene_id": target_scene_id,
			"target_spawn_id": target_spawn_id
		})

	transition_used.emit(target_scene_id, target_spawn_id)
	return st.go_to(target_scene_id, target_spawn_id)

func _get_target_node() -> Node3D:
	_resolve_hub()
	if hub and hub is Node3D:
		return hub as Node3D
	if get_parent() is Node3D:
		return get_parent() as Node3D
	return null

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

func _show_toast(badge: String, title: String, text: String) -> void:
	var hud: Node = _get_active_hud()
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", badge, title, text)
	else:
		print("[%s] %s: %s" % [badge, title, text])

func _get_inventory() -> Node:
	if hub and hub.get_node_or_null("/root/InventoryManager"):
		return hub.get_node_or_null("/root/InventoryManager")
	if get_tree() and get_tree().root.get_node_or_null("InventoryManager"):
		return get_tree().root.get_node_or_null("InventoryManager")
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	return null

# ==========================================
# SAVE / LOAD
# ==========================================

func get_save_state() -> Dictionary:
	return {
		"is_locked": is_locked
	}

func load_save_state(state: Dictionary) -> void:
	if state.has("is_locked"):
		is_locked = bool(state["is_locked"])
		if hub and "is_locked" in hub:
			hub.set("is_locked", is_locked)
	notify_state_changed()
