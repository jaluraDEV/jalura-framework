@tool
class_name InteractiveObject
extends Node3D

## Hub für modulare Weltobjekte in Barnaby.
## Verwaltet Bausteine (ObjectBehavior), Interaktionen, Events,
## automatische Kollisionserzeugung und Savegame-Persistenz.

signal event(name: StringName, data: Dictionary)

enum CollisionMode {
	MANUAL = 0,       ## Bereits existierende CollisionShape3D nutzen
	BOX = 1,          ## Ausgerichtete Box um alle Meshes
	CONVEX = 2,       ## Konvexe Hülle (für dynamische oder einfache Formen)
	MULTI_CONVEX = 3, ## Mehrere konvexe Hüllen (für hohle Formen)
	TRIMESH = 4       ## Exakte Dreiecks-Kollision (NUR für statische Körper!)
}

@export_group("Identification")
@export var object_id: String = "" ## Stabile ID. Wenn leer, wird sie automatisch aus dem Pfad generiert.

@export_group("Triggers & Actions")
@export var triggers: Array[ObjectTrigger] = []

@export_group("Collision & Detection")
@export var collision_mode: CollisionMode = CollisionMode.MANUAL
@export_flags_3d_physics var collision_layer: int = 1
@export_flags_3d_physics var collision_mask: int = 1
@export var interaction_padding: Vector3 = Vector3(0.6, 0.4, 0.6)
@export_tool_button("Kollision erzeugen") var bake_collision_button = bake_collision_to_scene
@export var bake_collision_in_editor: bool = false: set = _set_bake_collision

var interactable: Interactable
var _executed_triggers: Dictionary = {} # trigger_key: String -> bool

# Cache für berechnete CollisionShapes pro Mesh-Ressource (vermeidet Mehrfachberechnung)
static var _shape_cache: Dictionary = {}

func _ready() -> void:
	_resolve_object_id()
	_setup_interactable()
	_setup_collision()
	_load_save_state()
	_register_defined_flags()
	call_deferred("_validate_object")
	refresh_prompt()


func _set_bake_collision(val: bool) -> void:
	if val and Engine.is_editor_hint():
		bake_collision_to_scene()
	bake_collision_in_editor = false

## Erzeugt eine stabile ID aus Szenen- und Node-Pfad, falls keine gesetzt ist
func _resolve_object_id() -> void:
	if object_id.is_empty():
		var scene_path := ""
		if owner and not owner.scene_file_path.is_empty():
			scene_path = owner.scene_file_path.get_file().get_basename()
		elif get_tree() and get_tree().current_scene and not get_tree().current_scene.scene_file_path.is_empty():
			scene_path = get_tree().current_scene.scene_file_path.get_file().get_basename()
		else:
			scene_path = "world"
		object_id = "%s_%s" % [scene_path, str(get_path()).replace("/root/", "").replace("/", "_")]

	# Prüfung auf doppelte IDs in der Szene
	if get_tree():
		var existing := get_tree().get_nodes_in_group("interactive_objects")
		for node in existing:
			if node != self and node is InteractiveObject and node.object_id == object_id:
				push_warning("InteractiveObject: Doppelte object_id '%s' bei '%s' und '%s'! Generiere eindeutigen Suffix." % [object_id, name, node.name])
				object_id = "%s_%s" % [object_id, str(get_instance_id())]
				break
	add_to_group("interactive_objects")

# ==========================================
# INTERACTABLE SETUP & PROMPTS
# ==========================================

func _setup_interactable() -> void:
	# 1. Bestehendes Interactable suchen (im Hub oder unter Kindern/Eltern)
	interactable = find_child("Interactable", true, false) as Interactable
	if not interactable and get_parent() is Node3D:
		interactable = get_parent().find_child("Interactable", false, false) as Interactable

	# 2. Wenn keines existiert: ECHTES Interactable (Layer 8, Mask 2, Gruppe "interactables") erzeugen
	if not interactable:
		interactable = Interactable.new()
		interactable.name = "Interactable"
		interactable.collision_layer = 8
		interactable.collision_mask = 2
		add_child(interactable)
		# WICHTIG (Regel b): Niemals interactable.owner setzen! Verhindert Serialisierung in die Level-Szene.

		# Kollisionsform für die Interaktions-Area erzeugen
		var aabb := _calculate_combined_aabb()
		var col_shape := CollisionShape3D.new()
		col_shape.name = "InteractionCollision"
		var box := BoxShape3D.new()
		box.size = aabb.size + (interaction_padding * 2.0)
		col_shape.shape = box
		col_shape.position = aabb.position + (aabb.size * 0.5)
		interactable.add_child(col_shape)
		# WICHTIG (Regel b): Niemals col_shape.owner setzen!

	# 3. Synchronisieren & Verbinden
	interactable.interactable_id = object_id
	if not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)

func _on_interacted(player: Node) -> void:
	interact(player)

## Öffentliche Schnittstelle für Interaktion (wie durch Interactable oder Tests ausgelöst)
func interact(player: Node) -> bool:
	var behavior := get_active_behavior(player)
	if behavior:
		var handled := behavior.interact(player)
		if handled:
			refresh_prompt(player)
		return handled
	return false

## Updates the prompt on the interactable upon state change
func refresh_prompt(player: Node = null) -> void:
	if not is_instance_valid(interactable):
		return
		
	if not player and get_tree():
		player = get_tree().root.find_child("Player", true, false)
		
	var behavior := get_active_behavior(player)
	if behavior:
		interactable.enabled = true
		interactable.prompt_text = behavior.get_prompt()
	else:
		interactable.enabled = false

## Gibt den aktuellen Interaktionsprompt des aktiven Bausteins zurück
func get_prompt(player: Node = null) -> String:
	var behavior := get_active_behavior(player)
	if behavior:
		return behavior.get_prompt()
	return interactable.prompt_text if is_instance_valid(interactable) else ""

# ==========================================
# BAUSTEINE (BEHAVIORS) & EVENTS
# ==========================================

func get_behaviors() -> Array[ObjectBehavior]:
	var list: Array[ObjectBehavior] = []
	for child in get_children():
		if child is ObjectBehavior:
			child.hub = self
			list.append(child)
	return list

func get_active_behavior(player: Node = null) -> ObjectBehavior:
	var behaviors := get_behaviors()
	var best: ObjectBehavior = null
	var highest_priority := -999999
	
	for b in behaviors:
		if b.can_interact(player):
			var p := b.get_priority()
			if p > highest_priority:
				highest_priority = p
				best = b
	return best

## Feuert ein Event am Hub aus und benachrichtigt verbundene Systeme
func emit_object_event(event_name: StringName, data: Dictionary = {}) -> void:
	_process_event_triggers(event_name, data)
	event.emit(event_name, data)
	if event_name != &"focused" and event_name != &"unfocused":
		refresh_prompt()
		_save_state_to_manager()

func on_interactable_focused(_player: Node = null) -> void:
	emit_object_event(&"focused")

func on_interactable_unfocused(_player: Node = null) -> void:
	emit_object_event(&"unfocused")

func _process_event_triggers(event_name: StringName, data: Dictionary) -> void:
	for i in range(triggers.size()):
		var trig := triggers[i]
		if not trig:
			continue
		if trig.get_effective_event_name() != event_name:
			continue
			
		var tr_key := trig.trigger_id if not trig.trigger_id.is_empty() else ("trigger_%d" % i)
		if trig.once and _executed_triggers.get(tr_key, false):
			continue

		# Bedingungen prüfen
		var conditions_met := true
		for cond in trig.conditions:
			if cond and not cond.is_met(self):
				conditions_met = false
				break
		if not conditions_met:
			continue

		# Aktionen ausführen
		var ctx := {
			"hub": self,
			"source": data.get("source", self),
			"player": data.get("player", null),
			"event_name": event_name,
			"data": data
		}
		for act in trig.actions:
			if act:
				act.execute(ctx)

		if trig.once:
			_executed_triggers[tr_key] = true

# ==========================================
# AUTOMATISCHE KOLLISION (ANPASSUNG 2 & REGELN a-c)
# ==========================================

## Prüft, ob am Objekt oder am Elternkörper bereits eine Kollision vorhanden ist (Regel a)
func has_collision() -> bool:
	# 1. Elternkörper prüfen (falls Hub Kind eines PhysicsBody3D ist)
	if get_parent() is PhysicsBody3D:
		for child in get_parent().get_children():
			if (child is CollisionShape3D or child is CollisionPolygon3D) and not (child.get_parent() is Area3D):
				return true
	# 3. Kind-PhysicsBody3D prüfen (z.B. AutoStaticBody oder eingebackener StaticBody3D)
	for body in find_children("*", "PhysicsBody3D", true, false):
		for col in body.find_children("*", "CollisionShape3D", true, false):
			return true
		for col in body.find_children("*", "CollisionPolygon3D", true, false):
			return true
	return false

func _setup_collision() -> void:
	if collision_mode == CollisionMode.MANUAL:
		return
	if has_collision():
		return
	# Regel (b): Zur Laufzeit / Editor-Preview erzeugte Nodes bekommen KEINEN owner
	_generate_collision(null)

func _cleanup_auto_collision() -> void:
	if get_parent() is PhysicsBody3D:
		for child in get_parent().get_children():
			if child is CollisionShape3D and child.name.begins_with("AutoCol_"):
				child.free()
	var old_sb := find_child("AutoStaticBody", false, false)
	if old_sb:
		old_sb.free()
	for child in get_children():
		if child is StaticBody3D and (child.name == "AutoStaticBody" or child.name.begins_with("@StaticBody3D@")):
			child.free()

func _generate_collision(target_owner: Node = null) -> void:
	# Zielkörper bestimmen: Wenn Elternknoten ein PhysicsBody3D ist, nutzen wir diesen.
	var target_body: CollisionObject3D = null
	if get_parent() is PhysicsBody3D:
		target_body = get_parent() as CollisionObject3D
	else:
		target_body = find_child("AutoStaticBody", false, false) as CollisionObject3D
		if not target_body:
			for child in get_children():
				if child is StaticBody3D:
					target_body = child
					break
		if not target_body:
			var sb := StaticBody3D.new()
			sb.name = "AutoStaticBody"
			sb.collision_layer = collision_layer
			sb.collision_mask = collision_mask
			add_child(sb)
			if target_owner:
				sb.owner = target_owner
			target_body = sb

	# Sicherheitsprüfung für dynamische RigidBody3Ds:
	var effective_mode := collision_mode
	if target_body is RigidBody3D and effective_mode == CollisionMode.TRIMESH:
		push_warning("InteractiveObject '%s': TRIMESH ist für RigidBody3D unzulässig! Automatischer Fallback auf CONVEX." % name)
		effective_mode = CollisionMode.CONVEX

	# Prüfen, ob der Zielkörper schon eine CollisionShape hat
	var existing_shape = target_body.find_child("*", true, false)
	if existing_shape is CollisionShape3D:
		return

	_generate_collision_shapes_for_body(target_body, effective_mode, target_owner)

func _generate_collision_shapes_for_body(target_body: CollisionObject3D, mode: CollisionMode, target_owner: Node = null) -> void:
	var meshes := _find_all_meshes(self)
	if meshes.is_empty() and get_parent() is Node3D:
		meshes = _find_all_meshes(get_parent())
		
	if meshes.is_empty():
		return

	if mode == CollisionMode.BOX:
		var aabb := _calculate_combined_aabb()
		var col := CollisionShape3D.new()
		col.name = "AutoCol_Box"
		var box := BoxShape3D.new()
		box.size = aabb.size
		col.shape = box
		col.position = aabb.position + (aabb.size * 0.5)
		_safe_add_collision_shape(target_body, col, target_owner)
		return

	for mi in meshes:
		if not mi.mesh:
			continue
			
		var shape: Shape3D = _get_or_create_cached_shape(mi.mesh, mode)
		if shape:
			var col := CollisionShape3D.new()
			col.name = "AutoCol_" + mi.name
			col.shape = shape
			if mi.get_parent() == target_body:
				col.transform = mi.transform
			elif mi != target_body:
				col.global_transform = mi.global_transform
			_safe_add_collision_shape(target_body, col, target_owner)

func _safe_add_collision_shape(target_body: CollisionObject3D, col: CollisionShape3D, target_owner: Node = null) -> void:
	if target_body == get_parent() and is_inside_tree():
		target_body.add_child.call_deferred(col)
	else:
		target_body.add_child(col)
	if target_owner:
		col.owner = target_owner

func _get_or_create_cached_shape(mesh: Mesh, mode: CollisionMode) -> Shape3D:
	var cache_key := "%d_%d" % [mesh.get_instance_id(), mode]
	if _shape_cache.has(cache_key):
		return _shape_cache[cache_key]

	var shape: Shape3D = null
	match mode:
		CollisionMode.CONVEX:
			shape = mesh.create_convex_shape(true, true)
		CollisionMode.MULTI_CONVEX:
			shape = mesh.create_convex_shape(true, false)
		CollisionMode.TRIMESH:
			shape = mesh.create_trimesh_shape()

	if shape:
		_shape_cache[cache_key] = shape
	return shape

## Backt die generierten Kollisionsformen als echte Editor-Nodes ein (Regel c)
## Ersetzt dabei vorhandene Auto-Kollisionen statt zu verdoppeln.
func bake_collision_to_scene() -> void:
	if collision_mode == CollisionMode.MANUAL:
		print("InteractiveObject [%s]: Kollisionsmodus ist MANUAL, kein Backen nötig." % name)
		return
	_cleanup_auto_collision()
	var scene_owner: Node = owner
	if not scene_owner and Engine.is_editor_hint() and get_tree():
		scene_owner = get_tree().edited_scene_root
	if not scene_owner:
		scene_owner = self
	_generate_collision(scene_owner)
	print("InteractiveObject [%s]: Kollision erfolgreich in Szene gebacken." % name)

func _calculate_combined_aabb() -> AABB:
	var meshes := _find_all_meshes(self)
	if meshes.is_empty() and get_parent() is Node3D:
		meshes = _find_all_meshes(get_parent())
	if meshes.is_empty():
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))

	var first: bool = true
	var combined: AABB
	for mi in meshes:
		if not mi.mesh:
			continue
		# Relativen Transform zum Hub berechnen
		var rel_xform := Transform3D.IDENTITY
		var curr: Node = mi
		while curr and curr != self and curr is Node3D:
			rel_xform = (curr as Node3D).transform * rel_xform
			curr = curr.get_parent()
		var mi_aabb := rel_xform * mi.get_aabb()
		if first:
			combined = mi_aabb
			first = false
		else:
			combined = combined.merge(mi_aabb)
	return combined if not first else AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))

func _find_all_meshes(root_node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and child.mesh and not (child.get_parent() is Interactable):
			result.append(child)
	return result

# ==========================================
# SAVE / LOAD ANBINDUNG
# ==========================================

func get_save_state() -> Dictionary:
	var state: Dictionary = {}
	for b in get_behaviors():
		var b_state := b.get_save_state()
		if not b_state.is_empty():
			state[b.name] = b_state
	if not _executed_triggers.is_empty():
		state["_executed_triggers"] = _executed_triggers.duplicate()
	return state

func load_save_state(state: Dictionary) -> void:
	_executed_triggers.clear()
	if state.has("_executed_triggers") and state["_executed_triggers"] is Dictionary:
		_executed_triggers = state["_executed_triggers"].duplicate()
	for b in get_behaviors():
		if state.has(b.name) and state[b.name] is Dictionary:
			b.load_save_state(state[b.name])
	refresh_prompt()

func _load_save_state() -> void:
	if not is_inside_tree():
		return
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("get_world_object_state"):
		var state: Dictionary = sm.call("get_world_object_state", object_id)
		if not state.is_empty():
			load_save_state(state)

func _save_state_to_manager() -> void:
	if not is_inside_tree():
		return
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("set_world_object_state"):
		sm.call("set_world_object_state", object_id, get_save_state())

# ==========================================
# START-VALIDIERUNG (ZUSATZ A: QUESTS & FLAGS)
# ==========================================

func _register_defined_flags() -> void:
	var gf = get_node_or_null("/root/GameFlags")
	if not gf or not gf.has_method("register_defined_flag"):
		return
	for trig in triggers:
		if not trig:
			continue
		for act in trig.actions:
			if act is SetFlagAction and not act.flag_id.is_empty():
				gf.register_defined_flag(act.flag_id)

func _validate_object() -> void:
	if not is_inside_tree():
		return
	var qm: Node = get_node_or_null("/root/QuestManager")
	var gf: Node = get_node_or_null("/root/GameFlags")

	for i in range(triggers.size()):
		var trig := triggers[i]
		if not trig:
			continue
		for cond in trig.conditions:
			if cond:
				_validate_condition(cond, qm, gf)
		for act in trig.actions:
			if act:
				_validate_action(act, qm, gf)

	for b in get_behaviors():
		if "lock_conditions" in b and b.lock_conditions is Array:
			for cond in b.lock_conditions:
				if cond:
					_validate_condition(cond, qm, gf)

func _validate_condition(cond: QuestCondition, qm: Node, gf: Node) -> void:
	if not cond:
		return
	if cond is QuestCompletedCondition:
		var q_id: String = cond.quest_id
		if not q_id.is_empty() and qm and qm.has_method("has_quest"):
			if not qm.has_quest(q_id):
				push_warning("InteractiveObject '%s' (ID '%s'): QuestCompletedCondition verwendet unbekannte Quest-ID '%s'!" % [name, object_id, q_id])
	elif cond is FlagCondition:
		var f_id: String = cond.flag_id
		if not f_id.is_empty() and gf and gf.has_method("is_flag_known"):
			if not gf.is_flag_known(f_id):
				push_warning("InteractiveObject '%s' (ID '%s'): FlagCondition fragt Flag '%s' ab, das nirgends im Spiel gesetzt oder registriert wird!" % [name, object_id, f_id])
	elif cond is CompositeCondition:
		for sub_cond in cond.conditions:
			if sub_cond:
				_validate_condition(sub_cond, qm, gf)

func _validate_action(act: ReactionAction, qm: Node, _gf: Node) -> void:
	if not act:
		return
	if act is StartQuestAction:
		var q_id: String = act.quest_id
		if not q_id.is_empty() and qm and qm.has_method("has_quest"):
			if not qm.has_quest(q_id):
				push_warning("InteractiveObject '%s' (ID '%s'): StartQuestAction verwendet unbekannte Quest-ID '%s'!" % [name, object_id, q_id])
	elif act is CompleteQuestAction:
		var q_id: String = act.quest_id
		if not q_id.is_empty() and qm and qm.has_method("has_quest"):
			if not qm.has_quest(q_id):
				push_warning("InteractiveObject '%s' (ID '%s'): CompleteQuestAction verwendet unbekannte Quest-ID '%s'!" % [name, object_id, q_id])

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_behaviors().is_empty():
		warnings.append("InteractiveObject hat keine ObjectBehavior-Bausteine als Kinder.")
	for trig in triggers:
		if trig and trig.actions.is_empty():
			warnings.append("Ein Trigger für Event '%s' hat keine Reaktionen (actions) definiert." % trig.event)
	return warnings
