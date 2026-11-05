@tool
class_name ContainerBehavior
extends ObjectBehavior

## Baustein: Behälter (z. B. Truhen, Schränke, Kisten, Beete).
## Verwaltet Inhalte, Öffnungs-Animationen, Schlösser/Schlüssel,
## Inventar-Voll-Prüfung und Speichern des Zustands.

enum ContainerMode {
	CHEST = 0,        ## Schatztruhe mit aufklappbarem Deckel
	CUPBOARD = 1,     ## Schrank mit Schwenktür
	HARVEST_PATCH = 2 ## Beet / Erntebereich
}

@export_group("Contents")
## Liste der enthaltenen Items als Dictionaries, z. B. [{"item_id": "apple", "amount": 2}]
@export var contents: Array = []:
	set(val):
		var typed: Array[Dictionary] = []
		for item in val:
			if item is Dictionary:
				typed.append((item as Dictionary).duplicate(true))
		contents = typed
		_check_empty_state()
		notify_state_changed()



@export_group("Lock & Key")
@export var is_locked: bool = false:
	set(val):
		is_locked = val
		notify_state_changed()

@export var lock_conditions: Array[QuestCondition] = []:
	set(val):
		lock_conditions = val.duplicate(true)

@export var key_item_id: String = "" ## Optionales Schlüssel-Item (z. B. 'key_rusty')
@export var consume_key: bool = false ## Soll der Schlüssel beim Aufschließen verbraucht werden?
@export var locked_message: String = "Locked. You need a key!":
	set(val):
		locked_message = val

@export_group("Prompts & Text")
@export var open_prompt: String = "Öffnen":
	set(val):
		open_prompt = val
		notify_state_changed()

@export var unlock_prompt: String = "Aufschließen":
	set(val):
		unlock_prompt = val
		notify_state_changed()

@export var empty_prompt: String = "Hineinschauen":
	set(val):
		empty_prompt = val
		notify_state_changed()

@export var loot_prompt: String = "Plündern":
	set(val):
		loot_prompt = val
		notify_state_changed()

@export var container_mode: ContainerMode = ContainerMode.CHEST
@export var priority: int = 15

var is_open: bool = false
var is_empty: bool = false

func _ready() -> void:
	contents = contents.duplicate(true)
	lock_conditions = lock_conditions.duplicate(true)
	_check_empty_state()
	_update_visual_state(false)

func _check_empty_state() -> void:
	is_empty = contents.is_empty()

func can_interact(_player: Node) -> bool:
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
	if is_empty:
		return empty_prompt
	return loot_prompt

func _can_player_unlock() -> bool:
	var inv = _get_inventory()
	# Direkter Schlüssel
	if not key_item_id.is_empty() and inv:
		if inv.has_item(key_item_id, 1):
			return true
	# Schloss-Bedingungen (ItemCondition, FlagCondition etc.)
	if not lock_conditions.is_empty():
		for cond in lock_conditions:
			if cond and not cond.is_met(hub if hub else self):
				return false
		return true
	return false

func interact(player: Node) -> bool:
	_resolve_hub()
	
	# 1. Schloss-Logik
	if is_locked:
		if _can_player_unlock():
			# Aufschließen erfolgreich
			is_locked = false
			if hub and "is_locked" in hub:
				hub.set("is_locked", false)
			_consume_key_if_needed()
			_show_toast("🗝️", "UNLOCKED", "Lock opened successfully!")
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"unlocked", {"player": player, "source": self})
		else:
			# Schloss bleibt verschlossen
			_show_toast("🔒", "VERSCHLOSSEN", locked_message)
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"unlock_failed", {"player": player, "source": self})
			return true



	# 2. Öffnen (falls noch geschlossen)
	if not is_open:
		is_open = true
		_update_visual_state(true)
		if hub and hub.has_method("emit_object_event"):
			hub.call("emit_object_event", &"opened", {"player": player, "source": self, "contents": contents.duplicate(true)})

	# 3. Plündern / Inventar-Transfer
	var inv = _get_inventory()
	if is_empty:
		_show_toast("📦", "LEER", "Diese Truhe ist bereits leer.")
		notify_state_changed()
		if hub and hub.has_method("emit_object_event"):
			hub.call("emit_object_event", &"wobbled", {"player": player, "source": self})
		return true

	if not inv:
		return true

	var remaining_contents: Array[Dictionary] = []
	var looted_any := false
	var inventory_full_reported := false

	for entry in contents:
		var item_id: String = str(entry.get("item_id", entry.get("id", entry.get("item", ""))))
		var amount: int = int(entry.get("amount", entry.get("count", 1)))
		if item_id.is_empty() or amount <= 0:
			continue

		if inv.can_add_item(item_id, amount):
			inv.add_item(item_id, amount)
			looted_any = true
			var item_data = inv.get_item_data(item_id)
			var item_name: String = item_data.name if item_data else item_id
			_show_toast("🎁", "ERHALTEN", "%dx %s erhalten!" % [amount, item_name])
		else:
			# Inventar VOLL: Item verbleibt sicher in der Truhe!
			remaining_contents.append(entry.duplicate())
			if not inventory_full_reported:
				var item_data = inv.get_item_data(item_id)
				var item_name: String = item_data.name if item_data else item_id
				_show_toast("🎒", "INVENTORY FULL", "No room in backpack for %s!" % item_name)
				inventory_full_reported = true
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"inventory_full", {"player": player, "source": self, "item_id": item_id, "amount": amount})

	if looted_any and hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"looted", {"player": player, "source": self})

	contents = remaining_contents
	if hub and "contents" in hub:
		hub.contents = remaining_contents.duplicate(true)
	_check_empty_state()

	if is_empty and looted_any:
		if hub and hub.has_method("emit_object_event"):
			hub.call("emit_object_event", &"emptied", {"player": player, "source": self})

	notify_state_changed()
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

	return true

func _consume_key_if_needed() -> void:
	if not consume_key:
		return
	var inv = _get_inventory()
	if not inv:
		return
	if not key_item_id.is_empty() and inv.has_item(key_item_id, 1):
		inv.remove_item(key_item_id, 1)
		return
	for cond in lock_conditions:
		if cond is ItemCondition:
			inv.remove_item(cond.item_id, maxi(cond.required_count, 1))

func _update_visual_state(animate: bool) -> void:
	var lid: Node3D = null
	if hub:
		lid = hub.find_child("Lid", true, false) as Node3D
		if not lid:
			lid = hub.find_child("ChestLid", true, false) as Node3D
		if not lid:
			lid = hub.find_child("Door", true, false) as Node3D
	if not lid:
		lid = find_child("Lid", true, false) as Node3D

	if not lid:
		return

	var target_rotation := -75.0 if is_open else 0.0
	if animate and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(lid, "rotation_degrees:x", target_rotation, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lid.rotation_degrees.x = target_rotation

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

# ==========================================
# SAVE / LOAD
# ==========================================

func get_save_state() -> Dictionary:
	return {
		"is_open": is_open,
		"is_locked": is_locked,
		"is_empty": is_empty,
		"contents": contents.duplicate(true)
	}

func load_save_state(state: Dictionary) -> void:
	if state.has("is_open"):
		is_open = bool(state["is_open"])
	if state.has("is_locked"):
		is_locked = bool(state["is_locked"])
	if state.has("is_empty"):
		is_empty = bool(state["is_empty"])
	if state.has("contents") and state["contents"] is Array:
		var typed: Array[Dictionary] = []
		for item in state["contents"]:
			if item is Dictionary:
				typed.append((item as Dictionary).duplicate(true))
		contents = typed
	_check_empty_state()

	_update_visual_state(false)
	notify_state_changed()
