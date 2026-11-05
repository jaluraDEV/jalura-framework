@tool
class_name DoorBehavior
extends ObjectBehavior

## Baustein: Tür / Tor (ObjDoor).
## Unterstützt Dreh- (Pivot/Hinge) und Schiebe-Türen (Slide),
## Schloss & Schlüssel-Logik, automatische Schließung,
## Steuerung aus der Ferne (ActivateTargetAction / Hebel) und Savegame-Persistenz.

enum OpenMode {
	ROTATE = 0, ## Drehung um Hinge / Pivot (Euler Y)
	SLIDE = 1   ## Verschiebung um Offset-Vektor (z.B. Fallgatter, Schiebetor)
}

@export_group("Door Mechanics")
@export var open_mode: OpenMode = OpenMode.ROTATE
@export var open_angle: float = 90.0 ## Drehwinkel in Grad für ROTATE-Modus (z.B. 90.0 oder -90.0)
@export var slide_offset: Vector3 = Vector3(0.0, 2.5, 0.0) ## Versatzvektor für SLIDE-Modus
@export var animation_duration: float = 0.55
@export var can_player_interact: bool = true ## Wenn false, kann die Tür nur ferngesteuert geöffnet werden
@export var can_close: bool = true ## Kann der Spieler eine offene Tür wieder schließen?
@export var auto_close: bool = false ## Schließt sich die Tür nach einer Weile automatisch?
@export var auto_close_delay: float = 3.0 ## Zeit in Sekunden bis zum automatischen Schließen
@export var disable_collision_when_open: bool = true ## Schaltet den Türblatt-Collider bei geöffneter Tür ab
@export var leaf_node_path: NodePath = NodePath("DoorLeaf") ## Pfad zum beweglichen Türblatt
@export var collider_node_path: NodePath = NodePath("DoorCollider") ## Pfad zum Türblatt-Collider

@export_group("Lock & Key")
@export var is_locked: bool = false:
	set(val):
		is_locked = val
		notify_state_changed()

@export var key_item_id: String = "" ## Benötigtes Item im Rucksack (z.B. 'key_rusty')
@export var consume_key: bool = false ## Wird der Schlüssel beim Aufschließen verbraucht?
@export var lock_conditions: Array[QuestCondition] = []:
	set(val):
		lock_conditions = val.duplicate(true)

@export var locked_message: String = "Locked. You need a matching key!":
	set(val):
		locked_message = val

@export_group("Automatic Conditions")
## Bedingungen, denen die Tür automatisch folgt (z.B. Zaun öffnet sich bei Flag-Änderung).
## Standard leer = Tür verhält sich unverändert. Auswertung läuft bei Szenen-Start und Signalen (nicht pro Frame).
@export var auto_open_conditions: Array[QuestCondition] = []:
	set(val):
		auto_open_conditions = val.duplicate(true)

@export_group("Prompts & Text")
@export var open_prompt: String = "Öffnen":
	set(val):
		open_prompt = val
		notify_state_changed()

@export var close_prompt: String = "Schließen":
	set(val):
		close_prompt = val
		notify_state_changed()

@export var unlock_prompt: String = "Aufschließen":
	set(val):
		unlock_prompt = val
		notify_state_changed()

@export var priority: int = 15

var is_open: bool = false
var _closed_position: Vector3 = Vector3.ZERO
var _closed_rotation: Vector3 = Vector3.ZERO
var _initialized_transforms: bool = false
var _tween: Tween = null
var _auto_close_timer: SceneTreeTimer = null

func _ready() -> void:
	lock_conditions = lock_conditions.duplicate(true)
	auto_open_conditions = auto_open_conditions.duplicate(true)
	_cache_initial_transform()
	_update_visual_and_collision(false)
	_connect_condition_signals()
	_evaluate_auto_open_conditions(false)

func _cache_initial_transform() -> void:
	if _initialized_transforms:
		return
	var leaf := _get_leaf_node()
	if leaf:
		_closed_position = leaf.position
		_closed_rotation = leaf.rotation_degrees
		_initialized_transforms = true

func _get_leaf_node() -> Node3D:
	_resolve_hub()
	var leaf: Node3D = null
	if hub and not leaf_node_path.is_empty():
		leaf = hub.get_node_or_null(leaf_node_path) as Node3D
	if not leaf and not leaf_node_path.is_empty():
		leaf = get_node_or_null(leaf_node_path) as Node3D
	if not leaf and hub:
		leaf = hub.find_child("DoorLeaf", true, false) as Node3D
	if not leaf and hub:
		leaf = hub.find_child("Door", true, false) as Node3D
	if not leaf and hub:
		leaf = hub.find_child("Gate", true, false) as Node3D
	return leaf

func _get_collider_node() -> Node:
	_resolve_hub()
	var col: Node = null
	if hub and not collider_node_path.is_empty():
		col = hub.get_node_or_null(collider_node_path)
	if not col and not collider_node_path.is_empty():
		col = get_node_or_null(collider_node_path)
	if not col and hub:
		col = hub.find_child("DoorCollider", true, false)
	if not col and hub:
		col = hub.find_child("DoorLeafCollider", true, false)
	return col

func can_interact(_player: Node) -> bool:
	if not can_player_interact:
		return false
	if is_open and not can_close:
		return false
	return true

func get_priority() -> int:
	return priority

func get_prompt() -> String:
	if is_locked:
		if _can_player_unlock():
			return unlock_prompt
		return open_prompt
	if not is_open:
		return open_prompt
	return close_prompt

func _can_player_unlock() -> bool:
	var inv := _get_inventory()
	# 1. Direkte Schlüssel-Prüfung
	if not key_item_id.is_empty() and inv:
		if inv.has_item(key_item_id, 1):
			return true
	# 2. Schloss-Bedingungen (ItemCondition, FlagCondition etc.)
	if not lock_conditions.is_empty():
		for cond in lock_conditions:
			if cond and not cond.is_met(hub if hub else self):
				return false
		return true
	return false

func interact(player: Node) -> bool:
	_resolve_hub()
	_cache_initial_transform()

	# 1. Schloss-Logik
	if is_locked:
		if _can_player_unlock():
			is_locked = false
			if hub and "is_locked" in hub:
				hub.set("is_locked", false)
			_consume_key_if_needed()
			_show_toast("🗝️", "UNLOCKED", "Door unlocked!")
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"unlocked", {"player": player, "source": self})
			# Direkt aufschließen und öffnen
			open(true, player)
			return true
		else:
			_show_toast("🔒", "VERSCHLOSSEN", locked_message)
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"unlock_failed", {"player": player, "source": self})
			return true

	# 2. Öffnen / Schließen
	if is_open:
		if can_close:
			close(true, player)
	else:
		open(true, player)
	return true

func open(animate: bool = true, player: Node = null) -> void:
	if is_open:
		return
	_cache_initial_transform()
	is_open = true
	_update_visual_and_collision(animate)
	
	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"opened", {"player": player, "source": self})

	if auto_close and is_inside_tree():
		_auto_close_timer = get_tree().create_timer(auto_close_delay)
		_auto_close_timer.timeout.connect(func():
			if is_open:
				close(true)
		)

	notify_state_changed()
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

func close(animate: bool = true, player: Node = null) -> void:
	if not is_open:
		return
	_cache_initial_transform()
	is_open = false
	_update_visual_and_collision(animate)

	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"closed", {"player": player, "source": self})

	notify_state_changed()
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

func toggle(animate: bool = true, player: Node = null) -> void:
	if is_open:
		close(animate, player)
	else:
		open(animate, player)

## Remote-Schnittstellen für Trigger / Hebel / Schalter
func activate() -> void:
	open(true)

func deactivate() -> void:
	close(true)

func unlock(player: Node = null) -> void:
	if not is_locked:
		return
	is_locked = false
	if hub and "is_locked" in hub:
		hub.set("is_locked", false)
	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"unlocked", {"player": player, "source": self})
	notify_state_changed()
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

func lock() -> void:
	is_locked = true
	if hub and "is_locked" in hub:
		hub.set("is_locked", true)
	notify_state_changed()
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

func _consume_key_if_needed() -> void:
	if not consume_key:
		return
	var inv := _get_inventory()
	if not inv:
		return
	if not key_item_id.is_empty() and inv.has_item(key_item_id, 1):
		inv.remove_item(key_item_id, 1)
		return
	for cond in lock_conditions:
		if cond is ItemCondition:
			inv.remove_item(cond.item_id, maxi(cond.required_count, 1))

func _update_visual_and_collision(animate: bool) -> void:
	var leaf := _get_leaf_node()
	var col := _get_collider_node()

	# Kollision anpassen
	if col:
		var should_disable := is_open and disable_collision_when_open
		if col is CollisionShape3D or col is CollisionPolygon3D:
			col.set_deferred("disabled", should_disable)
		elif col is CollisionObject3D:
			for child in col.find_children("*", "CollisionShape3D", true, false):
				(child as CollisionShape3D).set_deferred("disabled", should_disable)

	if not leaf:
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	if open_mode == OpenMode.ROTATE:
		var target_rot := _closed_rotation + Vector3(0.0, open_angle if is_open else 0.0, 0.0)
		if animate and is_inside_tree():
			_tween = create_tween()
			_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(leaf, "rotation_degrees", target_rot, animation_duration)
		else:
			leaf.rotation_degrees = target_rot
	elif open_mode == OpenMode.SLIDE:
		var target_pos := _closed_position + (slide_offset if is_open else Vector3.ZERO)
		if animate and is_inside_tree():
			_tween = create_tween()
			_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(leaf, "position", target_pos, animation_duration)
		else:
			leaf.position = target_pos

func _show_toast(badge: String, title: String, text: String) -> void:
	var hud := get_tree().root.find_child("HUD", true, false) if get_tree() else null
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

func _connect_condition_signals() -> void:
	if Engine.is_editor_hint():
		return
	if auto_open_conditions.is_empty():
		return
	var gf = get_node_or_null("/root/GameFlags")
	if gf and gf.has_signal("flag_changed"):
		if not gf.flag_changed.is_connected(_on_condition_signal_triggered):
			gf.flag_changed.connect(_on_condition_signal_triggered)
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		if qm.has_signal("quest_started") and not qm.quest_started.is_connected(_on_quest_signal_triggered):
			qm.quest_started.connect(_on_quest_signal_triggered)
		if qm.has_signal("quest_completed") and not qm.quest_completed.is_connected(_on_quest_signal_triggered):
			qm.quest_completed.connect(_on_quest_signal_triggered)
		if qm.has_signal("quest_objective_updated") and not qm.quest_objective_updated.is_connected(_on_quest_signal_triggered):
			qm.quest_objective_updated.connect(_on_quest_signal_triggered)
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_updated"):
		if not inv.inventory_updated.is_connected(_on_inventory_signal_triggered):
			inv.inventory_updated.connect(_on_inventory_signal_triggered)

func _disconnect_condition_signals() -> void:
	var gf = get_node_or_null("/root/GameFlags")
	if gf and gf.has_signal("flag_changed"):
		if gf.flag_changed.is_connected(_on_condition_signal_triggered):
			gf.flag_changed.disconnect(_on_condition_signal_triggered)
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		if qm.has_signal("quest_started") and qm.quest_started.is_connected(_on_quest_signal_triggered):
			qm.quest_started.disconnect(_on_quest_signal_triggered)
		if qm.has_signal("quest_completed") and qm.quest_completed.is_connected(_on_quest_signal_triggered):
			qm.quest_completed.disconnect(_on_quest_signal_triggered)
		if qm.has_signal("quest_objective_updated") and qm.quest_objective_updated.is_connected(_on_quest_signal_triggered):
			qm.quest_objective_updated.disconnect(_on_quest_signal_triggered)
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_updated"):
		if inv.inventory_updated.is_connected(_on_inventory_signal_triggered):
			inv.inventory_updated.disconnect(_on_inventory_signal_triggered)

func _exit_tree() -> void:
	_disconnect_condition_signals()

func _on_condition_signal_triggered(_flag_id: String, _val: bool) -> void:
	if not is_inside_tree():
		return
	_evaluate_auto_open_conditions(true)

func _on_quest_signal_triggered(_arg1: Variant = null, _arg2: Variant = null) -> void:
	if not is_inside_tree():
		return
	_evaluate_auto_open_conditions(true)

func _on_inventory_signal_triggered() -> void:
	if not is_inside_tree():
		return
	_evaluate_auto_open_conditions(true)

func _evaluate_auto_open_conditions(animate: bool) -> void:
	if Engine.is_editor_hint():
		return
	if not is_inside_tree() or auto_open_conditions.is_empty():
		return
	_resolve_hub()
	var all_met := true
	for cond in auto_open_conditions:
		if cond and not cond.is_met(hub if hub else self):
			all_met = false
			break
	if all_met:
		if is_locked:
			is_locked = false
			if hub and "is_locked" in hub:
				hub.set("is_locked", false)
		if not is_open:
			open(animate)
	else:
		if is_open and can_close:
			close(animate)

# ==========================================
# SAVE / LOAD
# ==========================================

func get_save_state() -> Dictionary:
	return {
		"is_open": is_open,
		"is_locked": is_locked
	}

func load_save_state(state: Dictionary) -> void:
	if state.has("is_open"):
		is_open = bool(state["is_open"])
	if state.has("is_locked"):
		is_locked = bool(state["is_locked"])
	_cache_initial_transform()
	_update_visual_and_collision(false)
	_evaluate_auto_open_conditions(false)
	notify_state_changed()
