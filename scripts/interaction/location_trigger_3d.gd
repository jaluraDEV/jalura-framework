class_name LocationTrigger3D
extends Area3D

@export var location_id: String = ""
@export var trigger_once_only: bool = true

var _triggered: bool = false

func _ready() -> void:
	collision_layer = 0 # Triggers don't need a layer
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _triggered and trigger_once_only:
		return
		
	if body.name == "Player" or body.is_in_group("player"):
		_triggered = true
		var qm = get_node_or_null("/root/QuestManager")
		if qm and qm.has_method("notify_location_reached"):
			qm.notify_location_reached(location_id)
