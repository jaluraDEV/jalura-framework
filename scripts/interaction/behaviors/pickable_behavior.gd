@tool
class_name PickableBehavior
extends ObjectBehavior

## Baustein: Aufsammelbares Welt-Item (Pickable).
## Unterstützt beliebige Items via ItemData oder ID, Mengen, Verschwinden ja/nein,
## Schwebel-Animation (Bobbing), Inventar-Voll-Prüfung, Events und Persistenz.

@export_group("Item Definition")
@export var item_data: ItemData:
	set(val):
		item_data = val
		_resolve_item_info()
		notify_state_changed()

@export var item_id: String = "":
	set(val):
		item_id = val
		_resolve_item_info()
		notify_state_changed()

@export var amount: int = 1:
	set(val):
		amount = maxi(1, val)
		notify_state_changed()

@export_group("Behavior & Visuals")
## Ob das Objekt nach dem Aufsammeln verschwindet (Standard: true)
@export var disappear_on_pickup: bool = true:
	set(val):
		disappear_on_pickup = val
		notify_state_changed()

## Automatisches sanftes Schweben und Rotieren
@export var auto_bob: bool = true

## Optionale Pfadangabe zum visuellen Mesh/Node (Standard: sucht nach "Visual" oder nutzt Hub)
@export var visual_node_path: NodePath

@export_group("Prompts & Text")
## Eigener Interaktions-Prompt (leer = dynamisch "%s aufheben")
@export var custom_prompt: String = "":
	set(val):
		custom_prompt = val
		notify_state_changed()

@export var priority: int = 10

var is_collected: bool = false
var _base_y: float = 0.0
var _time: float = 0.0
var _visual: Node3D = null

func _ready() -> void:
	_resolve_item_info()
	_resolve_visual()
	if _visual:
		_base_y = _visual.position.y
	_apply_collected_state()

func _resolve_item_info() -> void:
	var inv = _get_inventory()
	if item_data:
		if item_id.is_empty() or item_id != item_data.id:
			item_id = item_data.id
		if inv and inv.has_method("register_item"):
			inv.register_item(item_data)
	elif not item_data and inv and not item_id.is_empty():
		item_data = inv.get_item_data(item_id)

func _resolve_visual() -> void:
	if not visual_node_path.is_empty():
		_visual = get_node_or_null(visual_node_path) as Node3D
	if not _visual:
		_visual = find_child("Visual", true, false) as Node3D
	if not _visual and hub:
		_visual = hub.find_child("Visual", true, false) as Node3D
	if not _visual and hub is Node3D:
		_visual = hub as Node3D

func can_interact(_player: Node) -> bool:
	return not is_collected

func get_priority() -> int:
	return priority

func get_prompt() -> String:
	if is_collected:
		return ""
	if not custom_prompt.is_empty():
		return custom_prompt
	var display_name := item_data.name if item_data else item_id
	return "%s aufheben" % display_name

func interact(player: Node) -> bool:
	_resolve_hub()
	if is_collected:
		return false

	var inv = _get_inventory()
	_resolve_item_info()

	var effective_id := item_id
	if item_data:
		effective_id = item_data.id

	var display_name := item_data.name if item_data else effective_id

	if inv:
		if not inv.can_add_item(effective_id, amount):
			# Rucksack ist VOLL: Item verbleibt sicher in der Welt!
			_show_toast("🎒", "INVENTORY FULL", "No room in backpack for %s!" % display_name)
			if hub and hub.has_method("emit_object_event"):
				hub.call("emit_object_event", &"inventory_full", {
					"player": player,
					"source": self,
					"item_id": effective_id,
					"amount": amount
				})
			return true

		# Item erfolgreich zum Inventar hinzufügen
		inv.add_item(effective_id, amount)

	is_collected = true
	var is_tool := (item_data != null and item_data.category == ItemData.Category.TOOL) or (effective_id in ["glider", "rail_shoe", "flashlight", "lamp"])
	if is_tool:
		_show_toast("⚙️", "EQUIPMENT OBTAINED", "%s equipped! ([U] Equipment)" % display_name)
	else:
		_show_toast("🎁", "ERHALTEN", "%dx %s erhalten!" % [amount, display_name])

	# Event feuern
	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"picked_up", {
			"player": player,
			"source": self,
			"item_id": effective_id,
			"amount": amount
		})

	# Visuelle Einsammel-Animation (Saftiges Pop & Shrink)
	_play_pickup_animation()

	# Zustand im SaveManager persistieren
	if hub and hub.has_method("_save_state_to_manager"):
		hub.call("_save_state_to_manager")

	notify_state_changed()
	return true

func _play_pickup_animation() -> void:
	if not _visual or not is_inside_tree():
		_apply_collected_state()
		return

	var orig_scale := _visual.scale
	var orig_pos_y := _visual.position.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "scale", orig_scale * 1.35, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "position:y", orig_pos_y + 0.45, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	var shrink := create_tween()
	shrink.tween_property(_visual, "scale", Vector3.ZERO, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await shrink.finished

	_apply_collected_state()

func _apply_collected_state() -> void:
	if not _visual:
		_resolve_visual()

	if is_collected and disappear_on_pickup:
		if _visual:
			_visual.visible = false
		if hub and hub is InteractiveObject:
			var inter: Interactable = hub.interactable
			if inter:
				inter.enabled = false
	else:
		if _visual:
			_visual.visible = true
			_visual.scale = Vector3.ONE
		if hub and hub is InteractiveObject:
			var inter: Interactable = hub.interactable
			if inter:
				inter.enabled = true

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_collected:
		return
	if auto_bob and _visual and _visual.visible:
		_time += delta
		_visual.rotation.y += delta * 1.6
		_visual.position.y = _base_y + sin(_time * 2.8) * 0.08

func _show_toast(badge: String, title: String, text: String) -> void:
	var hud: Node = null
	if is_inside_tree():
		hud = get_tree().root.find_child("HUD", true, false)
	if not hud:
		hud = get_node_or_null("/root/HUD")
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", badge, title, text)

func _get_inventory() -> Node:
	if is_inside_tree():
		var inv = get_node_or_null("/root/InventoryManager")
		if inv:
			return inv
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	return null

# ==========================================
# SAVE / LOAD
# ==========================================

func get_save_state() -> Dictionary:
	return {
		"is_collected": is_collected
	}

func load_save_state(state: Dictionary) -> void:
	if state.has("is_collected"):
		is_collected = bool(state["is_collected"])
	_apply_collected_state()
	notify_state_changed()
