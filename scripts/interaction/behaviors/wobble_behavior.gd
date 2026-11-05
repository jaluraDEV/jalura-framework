@tool
class_name WobbleBehavior
extends ObjectBehavior

## Baustein: Wackel-/Deko-Objekte (WobbleBehavior).
## Reine Optik für lebendige Welten (Büsche, Fässer, Schilder, Straßenlaternen).
## Reagiert elastisch, wenn der Spieler dagegenläuft oder die Interaktions-Taste drückt.

signal wobbled(player: Node)

@export_group("Wobble Properties")
@export var wobble_angle: float = 14.0 ## Maximaler Neigungswinkel in Grad
@export var wobble_duration: float = 0.45 ## Dauer der elastischen Abklingphase
@export var wobble_on_contact: bool = true ## Reagiert auf physischen Kontakt / Dagegenlaufen
@export var contact_radius: float = 1.05 ## Erkennungsradius für Berührung

@export_group("Interaction")
@export var can_interact_with_key: bool = true ## Erlaubt Taste [E] zum manuellen Anstupsen
@export var prompt_text: String = "Anstupsen":
	set(val):
		prompt_text = val
		notify_state_changed()
@export var priority: int = 5

var _base_rotation: Vector3 = Vector3.ZERO
var _cached_rotation: bool = false
var _contact_area: Area3D = null
var _current_tween: Tween = null
var _last_wobble_time: float = 0.0

func _ready() -> void:
	_resolve_hub()
	_cache_base_rotation()
	if wobble_on_contact and not Engine.is_editor_hint():
		call_deferred("_setup_contact_area")

func _exit_tree() -> void:
	if _contact_area and is_instance_valid(_contact_area):
		_contact_area.queue_free()
		_contact_area = null

func _get_target_node() -> Node3D:
	_resolve_hub()
	if hub and is_instance_valid(hub):
		var vis := hub.find_child("Visual", false, false) as Node3D
		if vis:
			return vis
		return hub as Node3D
	if get_parent() is Node3D:
		return get_parent() as Node3D
	return null

func _cache_base_rotation() -> void:
	if _cached_rotation:
		return
	var target := _get_target_node()
	if target:
		_base_rotation = target.rotation
		_cached_rotation = true

func _setup_contact_area() -> void:
	if _contact_area or not is_inside_tree():
		return
	_resolve_hub()
	var parent_3d: Node3D = null
	if hub and hub is Node3D:
		parent_3d = hub as Node3D
	elif get_parent() is Node3D:
		parent_3d = get_parent() as Node3D
	if not parent_3d:
		return

	_contact_area = Area3D.new()
	_contact_area.name = "WobbleContactDetector"
	_contact_area.collision_layer = 0
	_contact_area.collision_mask = 2 # Spieler Layer

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = contact_radius
	shape.shape = sphere
	shape.position = Vector3(0.0, 0.5, 0.0)

	_contact_area.add_child(shape)
	parent_3d.add_child(_contact_area)
	_contact_area.body_entered.connect(_on_contact_body_entered)

func _on_contact_body_entered(body: Node) -> void:
	if not wobble_on_contact:
		return
	var current_time := float(Time.get_ticks_msec()) / 1000.0
	if current_time - _last_wobble_time < 0.3:
		return
	_last_wobble_time = current_time
	wobble(wobble_angle * 0.85, body)

func can_interact(_player: Node) -> bool:
	return can_interact_with_key

func get_priority() -> int:
	return priority

func get_prompt() -> String:
	return prompt_text

func interact(player: Node) -> bool:
	if not can_interact_with_key:
		return false
	wobble(wobble_angle, player)
	return true

## Löst das elastische Wackeln aus
func wobble(angle_deg: float = 0.0, from_source: Node = null) -> void:
	var target := _get_target_node()
	if not target or not is_inside_tree():
		return

	_cache_base_rotation()
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	var angle := angle_deg if angle_deg != 0.0 else wobble_angle
	var rad := deg_to_rad(angle)

	# Richtung berechnen (weg von Quelle, z. B. Spieler)
	var tilt_axis := Vector3(-1.0, 0.0, 0.0)
	if from_source and from_source is Node3D:
		var diff: Vector3 = target.global_position - (from_source as Node3D).global_position
		diff.y = 0.0
		if diff.length_squared() > 0.001:
			var push_dir := diff.normalized()
			# Kippt das Objekt exakt in Schubrichtung 'push_dir' weg
			tilt_axis = Vector3(push_dir.z, 0.0, -push_dir.x)

	wobbled.emit(from_source)
	if hub and is_instance_valid(hub) and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"wobbled", {
			"player": from_source,
			"source": self,
			"angle": angle
		})

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var tilt_rot := _base_rotation + (tilt_axis * rad)
	_current_tween.tween_property(target, "rotation", tilt_rot, wobble_duration * 0.2)
	_current_tween.tween_property(target, "rotation", _base_rotation, wobble_duration * 0.8)
