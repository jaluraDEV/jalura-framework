@tool
class_name JaluraObjectConverterGenerator
extends RefCounted

## Generator logic that converts raw 3D models (GLB/GLTF/OBJ) into full Jalura InteractiveObjects.

const InteractiveObject = preload("res://scripts/interaction/interactive_object.gd")

const PREFAB_DEFS := {
	"chest": {
		"label": "Truhe / Behälter",
		"root_script": "res://scripts/interaction/obj_chest.gd",
		"behavior_script": "res://scripts/interaction/behaviors/container_behavior.gd",
		"behavior_name": "ContainerBehavior",
		"collision_type": "box",
		"prefix": "chest_"
	},
	"door": {
		"label": "Tür / Tor",
		"root_script": "res://scripts/interaction/obj_door.gd",
		"behavior_script": "res://scripts/interaction/behaviors/door_behavior.gd",
		"behavior_name": "DoorBehavior",
		"collision_type": "trimesh",
		"prefix": "door_"
	},
	"switch": {
		"label": "Hebel / Schalter",
		"root_script": "res://scripts/interaction/obj_switch.gd",
		"behavior_script": "res://scripts/interaction/behaviors/switch_behavior.gd",
		"behavior_name": "SwitchBehavior",
		"collision_type": "box",
		"prefix": "switch_"
	},
	"sign": {
		"label": "Hinweisschild",
		"root_script": "res://scripts/interaction/obj_sign.gd",
		"behavior_script": "res://scripts/interaction/behaviors/readable_behavior.gd",
		"behavior_name": "ReadableBehavior",
		"collision_type": "box",
		"prefix": "sign_"
	},
	"pickup": {
		"label": "Aufhebbares Item",
		"root_script": "res://scripts/interaction/obj_pickup.gd",
		"behavior_script": "res://scripts/interaction/behaviors/pickable_behavior.gd",
		"behavior_name": "PickableBehavior",
		"collision_type": "none", # Pickups use Area3D for detection
		"prefix": "pickup_"
	},
	"pushable": {
		"label": "Schiebe-Block",
		"root_script": "res://scripts/interaction/obj_pushable.gd",
		"behavior_script": "res://scripts/interaction/behaviors/pushable_behavior.gd",
		"behavior_name": "PushableBehavior",
		"collision_type": "box",
		"prefix": "pushable_"
	},
	"wobble": {
		"label": "Wackel-Deko",
		"root_script": "res://scripts/interaction/obj_wobble.gd",
		"behavior_script": "res://scripts/interaction/behaviors/wobble_behavior.gd",
		"behavior_name": "WobbleBehavior",
		"collision_type": "convex",
		"prefix": "wobble_"
	},
	"bounce_pad": {
		"label": "Sprung-Plattform / Trampolin",
		"root_script": "res://scripts/interaction/obj_bounce_pad.gd",
		"behavior_script": "res://scripts/interaction/behaviors/bounce_pad_behavior.gd",
		"behavior_name": "BouncePadBehavior",
		"collision_type": "convex",
		"prefix": "bounce_pad_"
	},
	"generic": {
		"label": "Allgemeines Weltobjekt",
		"root_script": "res://scripts/interaction/interactive_object.gd",
		"behavior_script": "",
		"behavior_name": "",
		"collision_type": "convex",
		"prefix": "obj_"
	}
}

static func convert_model(glb_path: String, type_key: String, config: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(glb_path):
		var err := "Model file does not exist: %s" % glb_path
		push_error("[Jalura Object Converter] " + err)
		return {"success": false, "error": err}

	if not PREFAB_DEFS.has(type_key):
		type_key = "generic"

	var pdef: Dictionary = PREFAB_DEFS[type_key]
	var model_name: String = glb_path.get_file().get_basename()
	var raw_name: String = model_name.trim_prefix("obj_").trim_prefix("prop_").trim_prefix("item_")

	# Target .tscn path
	var output_path: String = config.get("output_path", "")
	if output_path.is_empty():
		var target_file_name := "obj_%s%s.tscn" % [pdef["prefix"], raw_name]
		output_path = glb_path.get_base_dir().path_join(target_file_name)

	# 1. Load model scene
	var model_packed := load(glb_path) as PackedScene
	if model_packed == null:
		var err := "Could not load PackedScene from %s" % glb_path
		push_error("[Jalura Object Converter] " + err)
		return {"success": false, "error": err}

	var model_instance: Node = model_packed.instantiate()
	if model_instance == null:
		var err := "Failed to instantiate model %s" % glb_path
		push_error("[Jalura Object Converter] " + err)
		return {"success": false, "error": err}

	# 2. Instantiate root object
	var root_script: GDScript = load(pdef["root_script"])
	if root_script == null:
		model_instance.free()
		var err := "Failed to load script: %s" % pdef["root_script"]
		push_error("[Jalura Object Converter] " + err)
		return {"success": false, "error": err}

	var root: Node3D = root_script.new() as Node3D
	var pascal_name := raw_name.capitalize().replace(" ", "")
	root.name = "Obj" + pdef["prefix"].trim_suffix("_").capitalize() + pascal_name
	root.set("object_id", (pdef["prefix"] + raw_name).to_snake_case())

	# 3. Add to groups
	root.add_to_group("interactive_objects", true)
	if type_key == "pushable":
		root.add_to_group("pushables", true)
	if type_key == "bounce_pad":
		root.add_to_group("bounce_pads", true)

	# 4. Handle Visual Node and Hierarchy
	var visual_container := Node3D.new()
	visual_container.name = "Visual"

	var parent_for_visual: Node = root
	var parent_for_collision: Node = root

	if type_key == "pushable":
		# Pushables place visuals and collision inside BlockBody (AnimatableBody3D)
		var block_body := AnimatableBody3D.new()
		block_body.name = "BlockBody"
		block_body.add_to_group("pushables")
		block_body.collision_layer = 1
		block_body.collision_mask = 1
		block_body.sync_to_physics = false
		root.add_child(block_body)
		block_body.owner = root

		parent_for_visual = block_body
		parent_for_collision = block_body

	parent_for_visual.add_child(visual_container)
	visual_container.owner = root

	model_instance.name = pascal_name + "_Mesh"
	visual_container.add_child(model_instance)
	model_instance.owner = root

	# 5. Collision generation
	var col_type: String = config.get("collision_type", pdef["collision_type"]).to_lower()
	var bake_collision: bool = config.get("bake_collision", true)

	if col_type != "none":
		var meshes: Array[MeshInstance3D] = []
		_find_meshes(model_instance, meshes)

		if not meshes.is_empty():
			var target_body: CollisionObject3D = null
			if parent_for_collision is CollisionObject3D:
				target_body = parent_for_collision as CollisionObject3D
			else:
				var sb := StaticBody3D.new()
				sb.name = "AutoStaticBody"
				sb.collision_layer = 1
				sb.collision_mask = 1
				root.add_child(sb)
				sb.owner = root
				target_body = sb

			_create_collision_shapes(meshes, target_body, col_type, root, visual_container)
			root.set("collision_mode", InteractiveObject.CollisionMode.MANUAL)
		else:
			root.set("collision_mode", InteractiveObject.CollisionMode.BOX)
	else:
		root.set("collision_mode", InteractiveObject.CollisionMode.MANUAL)

	# 5b. Spezielle TriggerArea für Sprung-Plattformen / Trampoline
	if type_key == "bounce_pad":
		var meshes: Array[MeshInstance3D] = []
		_find_meshes(model_instance, meshes)
		var aabb := _calculate_combined_aabb(meshes, visual_container) if not meshes.is_empty() else AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, 0.5, 1.6))

		var trigger_area := Area3D.new()
		trigger_area.name = "TriggerArea"
		trigger_area.collision_layer = 0
		trigger_area.collision_mask = 3 # Layer 1 (Blöcke) & Layer 2 (Spieler)
		trigger_area.monitoring = true
		trigger_area.monitorable = true
		root.add_child(trigger_area)
		trigger_area.owner = root

		var col_shape := CollisionShape3D.new()
		col_shape.name = "TriggerShape"
		var box := BoxShape3D.new()
		var sx := maxf(aabb.size.x * 0.92, 0.6)
		var sz := maxf(aabb.size.z * 0.92, 0.6)
		var sy := 0.4
		box.size = Vector3(sx, sy, sz)
		col_shape.shape = box

		var top_y := aabb.position.y + aabb.size.y
		col_shape.position = Vector3(
			aabb.position.x + aabb.size.x * 0.5,
			top_y + (sy * 0.5) - 0.05,
			aabb.position.z + aabb.size.z * 0.5
		)
		trigger_area.add_child(col_shape)
		col_shape.owner = root

	# 6. Add ObjectBehavior if specified
	if not str(pdef["behavior_script"]).is_empty():
		var b_script: GDScript = load(pdef["behavior_script"])
		if b_script:
			var behavior: Node = b_script.new()
			behavior.name = pdef["behavior_name"]
			root.add_child(behavior)
			behavior.owner = root

	# 7. Add ObjectFeedback for game feel (Squash & Stretch, Audio, Wobble)
	var feedback_script_path := "res://scripts/interaction/behaviors/object_feedback.gd"
	if FileAccess.file_exists(feedback_script_path):
		var fb_script: GDScript = load(feedback_script_path)
		if fb_script:
			var feedback: Node = fb_script.new()
			feedback.name = "ObjectFeedback"
			var visual_path := root.get_path_to(visual_container)
			feedback.set("visual_node_path", visual_path)
			if type_key == "bounce_pad":
				feedback.set("enable_focus_highlight", false)
				feedback.set("enable_squash", false)
			root.add_child(feedback)
			feedback.owner = root

	# 8. Pack and save scene
	var packed_scene := PackedScene.new()
	var pack_res := packed_scene.pack(root)
	if pack_res != OK:
		root.free()
		var err := "PackedScene.pack failed with code %d" % pack_res
		push_error("[Jalura Object Converter] " + err)
		return {"success": false, "error": err}

	var save_res := ResourceSaver.save(packed_scene, output_path)
	root.free()

	if save_res != OK:
		var err := "ResourceSaver.save to %s failed with code %d" % [output_path, save_res]
		push_error("[Jalura Object Converter] " + err)
		return {"success": false, "error": err}

	# 9. Notify Godot FileSystem
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.scan()
		if config.get("open_scene", false):
			EditorInterface.open_scene_from_path(output_path)

	print_rich("[color=green][b]✔ [Jalura Toolkit][/b][/color] Converted [color=yellow]%s[/color] to [color=cyan]%s[/color] (%s)" % [glb_path.get_file(), output_path.get_file(), pdef["label"]])
	return {
		"success": true,
		"scene_path": output_path,
		"type": type_key,
		"label": pdef["label"]
	}


static func _create_collision_shapes(meshes: Array[MeshInstance3D], target_body: CollisionObject3D, mode: String, scene_owner: Node, reference_root: Node3D) -> void:
	if mode == "box":
		var aabb := _calculate_combined_aabb(meshes, reference_root)
		var col := CollisionShape3D.new()
		col.name = "AutoCol_Box"
		var box := BoxShape3D.new()
		box.size = aabb.size
		col.shape = box
		col.position = aabb.position + (aabb.size * 0.5)
		target_body.add_child(col)
		col.owner = scene_owner
		return

	var idx := 1
	for mi in meshes:
		if not mi.mesh:
			continue
		var shape: Shape3D = null
		if mode == "trimesh":
			shape = mi.mesh.create_trimesh_shape()
		else: # convex
			shape = mi.mesh.create_convex_shape(true, false)

		if shape:
			var col := CollisionShape3D.new()
			col.name = "AutoCol_%s" % mi.name
			if target_body.has_node(NodePath(col.name)):
				col.name = "AutoCol_%d_%s" % [idx, mi.name]
			col.shape = shape
			col.transform = _get_relative_transform(mi, reference_root)
			target_body.add_child(col)
			col.owner = scene_owner
			idx += 1


static func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, result)


static func _get_relative_transform(target: Node3D, root_ancestor: Node3D) -> Transform3D:
	var accumulated := Transform3D.IDENTITY
	var curr: Node = target
	var stack: Array[Transform3D] = []
	while curr != null and curr != root_ancestor:
		if curr is Node3D:
			stack.push_front((curr as Node3D).transform)
		curr = curr.get_parent()
	for t in stack:
		accumulated = accumulated * t
	return accumulated


static func _calculate_combined_aabb(meshes: Array[MeshInstance3D], reference_root: Node3D) -> AABB:
	if meshes.is_empty():
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	var combined: AABB
	var first := true
	for mi in meshes:
		if not mi.mesh:
			continue
		var rel_xform := _get_relative_transform(mi, reference_root)
		var mi_aabb := rel_xform * mi.get_aabb()
		if first:
			combined = mi_aabb
			first = false
		else:
			combined = combined.merge(mi_aabb)
	return combined if not first else AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
