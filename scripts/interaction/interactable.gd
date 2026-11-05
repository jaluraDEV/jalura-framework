class_name Interactable
extends Area3D

signal interacted(player: Node)
signal focus_entered
signal focus_exited

@export var interactable_id: String = "" ## Optionale ID für Quest-Ziele (z. B. "apple_tree", "ship_helm", "lighthouse_switch")
@export var prompt_text: String = "Interact"
@export var action_key: String = "E"
@export var enabled: bool = true
@export var interaction_priority: int = 0

func _init() -> void:
	collision_layer = 8
	collision_mask = 2

func _ready() -> void:
	add_to_group("interactables")

func can_interact(_player: Node) -> bool:
	return enabled and is_visible_in_tree()

func interact(player: Node) -> void:
	if can_interact(player):
		interacted.emit(player)
		if not interactable_id.is_empty():
			var qm = get_node_or_null("/root/QuestManager")
			if qm and qm.has_method("notify_interaction"):
				qm.notify_interaction(interactable_id)

func on_focus_gained() -> void:
	focus_entered.emit()
	var hub = get_parent()
	if hub and hub.has_method("on_interactable_focused"):
		hub.on_interactable_focused()

func on_focus_lost() -> void:
	focus_exited.emit()
	var hub = get_parent()
	if hub and hub.has_method("on_interactable_unfocused"):
		hub.on_interactable_unfocused()
