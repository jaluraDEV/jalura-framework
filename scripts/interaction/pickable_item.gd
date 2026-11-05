extends Node3D
class_name PickableItem

## Universelles, datengetriebenes Welt-Item.
## Kann als Szene in jedem Level platziert werden:
## Einfach ein ItemData (.tres) zuweisen (oder item_id eingeben).

@export_group("Item Definition")
@export var item_data: ItemData             ## Primäre Ressource. Wenn gesetzt, bestimmt sie alles automatisch!
@export var item_id: String = ""       ## Fallback/ID-Referenz
@export var item_count: int = 1             ## Anzahl, die ins Inventar wandert
@export var unique_id: String = ""          ## Eindeutige ID für Speichern/Laden (wird nie wieder gespawnt)

@export_group("Behavior & Visuals")
@export var prompt_text: String = ""        ## Leer = dynamisch "%s aufheben"
@export var auto_bob: bool = true           ## Sanftes Schweben und Rotieren

@onready var visual: Node3D = $Visual
@onready var interactable: Interactable = $Interactable

var _base_y: float = 0.0
var _time: float = 0.0
var _is_picked: bool = false

func _ready() -> void:
	_base_y = position.y
	_resolve_item_definition()
	add_to_group("pickable_items")
	
	# Modular unique ID determination
	if unique_id.is_empty():
		unique_id = "item_" + str(get_path()).replace("/root/", "").replace("/", "_")
	
	# SaveManager Prüfung: Bereits in diesem Savefile aufgesammelt?
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.is_world_item_collected(unique_id):
		queue_free()
		return
			
	_setup_visuals()
	
	if interactable:
		var display_name := item_data.name if item_data else item_id
		if prompt_text.is_empty():
			interactable.prompt_text = "%s aufheben" % display_name
		else:
			interactable.prompt_text = prompt_text
		interactable.action_key = "E"
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

func _resolve_item_definition() -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if item_data:
		item_id = item_data.id
		if inv and inv.has_method("register_item"):
			inv.register_item(item_data)
	elif inv and not item_id.is_empty():
		item_data = inv.get_item_data(item_id)

func _setup_visuals() -> void:
	# Falls kein Mesh vorhanden ist, aber das Item ein Model hat, automatisch instanziieren
	if visual and visual.get_child_count() == 0 and item_data and item_data.model_scene:
		var inst := item_data.model_scene.instantiate()
		visual.add_child(inst)

	# Modell-Größe und Boden-Abstand automatisch normalisieren (verhindert Clipping z.B. bei rail_shoe.glb)
	if visual:
		for child in visual.get_children():
			if child is Node3D and not (child is Light3D):
				_normalize_visual_model(child as Node3D)

	# Clutter-Gruppe für Entfernungs-Culling hinzufügen
	for geom in find_children("*", "GeometryInstance3D", true, false):
		geom.add_to_group("clutter")

func _normalize_visual_model(inst: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst and mesh_inst.mesh and mesh_inst.visible:
			var xf := Transform3D.IDENTITY
			var curr: Node = mesh_inst
			while curr and curr != inst:
				if curr is Node3D:
					xf = (curr as Node3D).transform * xf
				curr = curr.get_parent()
			var sub_aabb := xf * mesh_inst.mesh.get_aabb()
			if first:
				aabb = sub_aabb
				first = false
			else:
				aabb = aabb.merge(sub_aabb)

	if first or aabb.size.length_squared() < 0.00001:
		return

	var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var target_max := 0.72 if (item_data and item_data.category == ItemData.Category.TOOL) else 0.52
	var s := 1.0
	if max_dim > target_max or max_dim < 0.15:
		s = target_max / maxf(max_dim, 0.001)
		inst.scale = Vector3.ONE * s
	else:
		s = inst.scale.x

	var center := aabb.get_center()
	var min_y := aabb.position.y
	# Zentriere X/Z und hebe die Unterkante sauber leicht über den Ursprung an
	inst.position = Vector3(-center.x * s, -min_y * s + 0.12, -center.z * s)
		

func _process(delta: float) -> void:
	if _is_picked:
		return
	_time += delta
	if auto_bob and visual:
		visual.rotation.y += delta * 1.5
		visual.position.y = sin(_time * 3.0) * 0.08

func drop_from(start_pos: Vector3, target_ground_pos: Vector3) -> void:
	global_position = start_pos
	_base_y = target_ground_pos.y + 0.45
	auto_bob = false
	if visual:
		visual.scale = Vector3.ZERO
		
	var tween := create_tween()
	# Pop in scale
	tween.tween_property(visual, "scale", Vector3.ONE, 0.2)
	# Fall down with arc/bounce
	var fall_tween := create_tween()
	fall_tween.tween_property(self, "global_position:x", target_ground_pos.x, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall_tween.parallel().tween_property(self, "global_position:z", target_ground_pos.z, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall_tween.parallel().tween_property(self, "global_position:y", target_ground_pos.y + 0.45, 0.65).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	await fall_tween.finished
	_base_y = position.y
	auto_bob = true

func _on_interacted(_player: Node) -> void:
	if _is_picked:
		return

	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		if not inv.can_add_item(item_id, item_count):
			var hud: Node = null
			if is_inside_tree():
				hud = get_tree().root.find_child("HUD", true, false)
			if not hud:
				hud = get_node_or_null("/root/HUD")
			var display_name := item_data.name if item_data else item_id
			if hud and hud.has_method("show_toast"):
				hud.call("show_toast", "🎒", "INVENTORY FULL", "No room in backpack for %s!" % display_name)
			return

	_is_picked = true
	if interactable:
		interactable.enabled = false
		
	if not unique_id.is_empty():
		var sm = get_node_or_null("/root/SaveManager")
		if sm:
			sm.mark_world_item_collected(unique_id)
		
	if inv:
		inv.add_item(item_id, item_count)

	_show_pickup_toast()

	# Pickup pop animation
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector3.ONE * 1.4, 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", position.y + 0.5, 0.2)
	await tween.finished
	
	var fade_tween := create_tween()
	fade_tween.tween_property(visual, "scale", Vector3.ZERO, 0.15)
	await fade_tween.finished
	queue_free()

func _show_pickup_toast() -> void:
	var hud: Node = null
	if is_inside_tree():
		hud = get_tree().root.find_child("HUD", true, false)
	if not hud:
		hud = get_node_or_null("/root/HUD")
	if not hud or not hud.has_method("show_toast"):
		return

	var display_name := item_data.name if item_data else item_id.capitalize()
	var is_tool := (item_data != null and item_data.category == ItemData.Category.TOOL) or (item_id in ["glider", "rail_shoe", "flashlight", "lamp"])
	if is_tool:
		var msg := "%s equipped! ([U] Equipment)" % display_name
		match item_id:
			"glider":
				msg = "Glider equipped! Hold [Space] in mid-air to glide."
			"rail_shoe":
				msg = "Rail Shoes equipped! Jump onto rails to grind."
			"flashlight", "lamp":
				msg = "Flashlight equipped! Press [F] for light."
		hud.call("show_toast", "⚙️", "EQUIPMENT OBTAINED", msg)
	else:
		hud.call("show_toast", "🎁", "ERHALTEN", "%dx %s erhalten!" % [item_count, display_name])
