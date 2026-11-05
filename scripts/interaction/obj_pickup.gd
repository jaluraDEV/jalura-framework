@tool
class_name ObjPickup
extends InteractiveObject

## Vorlage für aufsammelbare Welt-Items (Pickups).
## Exponiert wichtige Einstellungen direkt auf dem Wurzel-Node im Inspector,
## sodass diese ohne "Editable Children" bearbeitet werden können.
## Leitet Item-Definition, Menge, Verschwinden und Prompts an das untergeordnete PickableBehavior weiter.
@export_group("Pickup Settings")
@export var item_data: ItemData:
	set(val):
		item_data = val
		_sync_pickable_properties()

@export var item_id: String = "":
	set(val):
		item_id = val
		_sync_pickable_properties()

@export var amount: int = 1:
	set(val):
		amount = maxi(1, val)
		_sync_pickable_properties()

@export_group("Behavior & Visuals")
@export var disappear_on_pickup: bool = true:
	set(val):
		disappear_on_pickup = val
		_sync_pickable_properties()

@export var auto_bob: bool = true:
	set(val):
		auto_bob = val
		_sync_pickable_properties()

@export_group("Prompts & Text")
@export var prompt_pickup: String = "":
	set(val):
		prompt_pickup = val
		_sync_pickable_properties()

var is_collected: bool:
	get:
		var pb := find_child("PickableBehavior", false, false) as PickableBehavior
		return pb.is_collected if pb else false

func _ready() -> void:
	super._ready()
	_sync_pickable_properties()
	_setup_visual_if_needed()

func _sync_pickable_properties() -> void:
	var pb := find_child("PickableBehavior", false, false) as PickableBehavior
	if pb:
		pb.item_data = item_data
		pb.item_id = item_id
		pb.amount = amount
		pb.disappear_on_pickup = disappear_on_pickup
		pb.auto_bob = auto_bob
		pb.custom_prompt = prompt_pickup
		refresh_prompt()

func _setup_visual_if_needed() -> void:
	var visual := find_child("Visual", false, false) as Node3D
	if visual and visual.get_child_count() == 0 and item_data and item_data.model_scene:
		var model_inst := item_data.model_scene.instantiate()
		visual.add_child(model_inst)
