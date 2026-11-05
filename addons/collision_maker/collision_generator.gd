@tool
class_name CollisionGenerator
extends RefCounted

## Generator logic for converting 3D models (GLB/GLTF/OBJ) into Collision Scenes (.tscn)

static func generate_from_glb(glb_path: String, config: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(glb_path):
		var err_msg := "File does not exist: %s" % glb_path
		push_error("[Collision Maker] " + err_msg)
		return {"success": false, "error": err_msg}

	var packed_glb := load(glb_path) as PackedScene
	if packed_glb == null:
		var err_msg := "Failed to load 3D scene from: %s" % glb_path
		push_error("[Collision Maker] " + err_msg)
		return {"success": false, "error": err_msg}

	var model_instance: Node = packed_glb.instantiate()
	if model_instance == null:
		var err_msg := "Failed to instantiate model from: %s" % glb_path
		push_error("[Collision Maker] " + err_msg)
		return {"success": false, "error": err_msg}

	var model_name: String = glb_path.get_file().get_basename()
	var output_path: String = config.get("output_path", "")
	if output_path.is_empty():
		output_path = glb_path.get_base_dir().path_join(model_name + ".tscn")

	# Find all MeshInstance3D nodes in the hierarchy
	var mesh_instances: Array[MeshInstance3D] = []
	find_mesh_instances(model_instance, mesh_instances)

	if mesh_instances.is_empty():
		model_instance.free()
		var err_msg := "No MeshInstance3D found in %s" % glb_path
		push_warning("[Collision Maker] " + err_msg)
		return {"success": false, "error": err_msg}

	# Create root body based on chosen type
	var body_type: String = config.get("body_type", "StaticBody3D")
	var root: Node3D = null
	match body_type:
		"RigidBody3D":
			root = RigidBody3D.new()
		"CharacterBody3D":
			root = CharacterBody3D.new()
		"Area3D":
			root = Area3D.new()
		_:
			root = StaticBody3D.new()

	root.name = model_name

	# Optional collision layer / mask settings
	if root is CollisionObject3D:
		var col_obj := root as CollisionObject3D
		if config.has("collision_layer"):
			col_obj.collision_layer = int(config.get("collision_layer"))
		if config.has("collision_mask"):
			col_obj.collision_mask = int(config.get("collision_mask"))

	# Attach model under root body
	model_instance.name = model_name + "_Model"
	root.add_child(model_instance)
	model_instance.owner = root

	var collision_type: String = config.get("collision_type", "convex").to_lower()
	var clean_convex: bool = config.get("clean_convex", true)
	var simplify_convex: bool = config.get("simplify_convex", false)

	# RigidBody3D in Godot cannot use concave/trimesh shapes for dynamic simulation
	if root is RigidBody3D and collision_type == "trimesh":
		push_warning("[Collision Maker] RigidBody3D does not support Trimesh (Concave) shapes. Falling back to Convex.")
		collision_type = "convex"

	# Generate CollisionShape3D for each mesh
	var shape_count := 0
	for mesh_node in mesh_instances:
		var mesh: Mesh = mesh_node.mesh
		if mesh == null:
			continue

		var shape: Shape3D = null
		var shape_offset := Vector3.ZERO

		match collision_type:
			"trimesh":
				shape = mesh.create_trimesh_shape()
			"box":
				var aabb := mesh.get_aabb()
				var box_shape := BoxShape3D.new()
				box_shape.size = aabb.size
				shape = box_shape
				shape_offset = aabb.get_center()
			_: # "convex" is default
				shape = mesh.create_convex_shape(clean_convex, simplify_convex)

		if shape == null:
			continue

		var col_node := CollisionShape3D.new()
		var col_name := "Collision_" + mesh_node.name
		if root.has_node(col_name):
			col_name = "Collision_%d_%s" % [shape_count + 1, mesh_node.name]
		col_node.name = col_name
		col_node.shape = shape

		var rel_xform := get_relative_transform(mesh_node, model_instance)
		if shape_offset != Vector3.ZERO:
			col_node.transform = rel_xform * Transform3D(Basis.IDENTITY, shape_offset)
		else:
			col_node.transform = rel_xform

		root.add_child(col_node)
		col_node.owner = root
		shape_count += 1

	if shape_count == 0:
		root.free()
		var err_msg := "Could not generate any collision shapes for %s" % glb_path
		push_error("[Collision Maker] " + err_msg)
		return {"success": false, "error": err_msg}

	# Pack into scene
	var packed_scene := PackedScene.new()
	var pack_err := packed_scene.pack(root)
	if pack_err != OK:
		root.free()
		var err_msg := "Failed to pack scene: Error code %d" % pack_err
		push_error("[Collision Maker] " + err_msg)
		return {"success": false, "error": err_msg}

	var save_err := ResourceSaver.save(packed_scene, output_path)
	root.free()

	if save_err != OK:
		var err_msg := "Failed to save scene to %s (Error code: %d)" % [output_path, save_err]
		push_error("[Collision Maker] " + err_msg)
		return {"success": false, "error": err_msg}

	# Notify Editor FileSystem
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.scan()

		if config.get("open_scene", false):
			EditorInterface.open_scene_from_path(output_path)

	print_rich("[color=green][b]✔ [Collision Maker][/b][/color] Created scene: [color=cyan]%s[/color] (%d collision shapes)" % [output_path, shape_count])
	return {"success": true, "scene_path": output_path, "shape_count": shape_count}


static func generate_from_mesh_instance(mesh_node: MeshInstance3D, config: Dictionary = {}) -> Dictionary:
	if mesh_node == null or mesh_node.mesh == null:
		var err_msg := "MeshInstance3D does not have a valid Mesh resource."
		push_error("[Collision Maker] " + err_msg)
		return {"success": false, "error": err_msg}

	var mesh: Mesh = mesh_node.mesh
	var default_name: String = mesh_node.name
	var output_path: String = config.get("output_path", "")
	if output_path.is_empty():
		output_path = "res://%s.tscn" % default_name

	var body_type: String = config.get("body_type", "StaticBody3D")
	var root: Node3D = null
	match body_type:
		"RigidBody3D":
			root = RigidBody3D.new()
		"CharacterBody3D":
			root = CharacterBody3D.new()
		"Area3D":
			root = Area3D.new()
		_:
			root = StaticBody3D.new()

	root.name = default_name

	# Copy visual mesh
	var visual_copy: MeshInstance3D = mesh_node.duplicate() as MeshInstance3D
	visual_copy.transform = Transform3D.IDENTITY
	root.add_child(visual_copy)
	visual_copy.owner = root

	var collision_type: String = config.get("collision_type", "convex").to_lower()
	var clean_convex: bool = config.get("clean_convex", true)
	var simplify_convex: bool = config.get("simplify_convex", false)

	if root is RigidBody3D and collision_type == "trimesh":
		collision_type = "convex"

	var shape: Shape3D = null
	var shape_offset := Vector3.ZERO
	match collision_type:
		"trimesh":
			shape = mesh.create_trimesh_shape()
		"box":
			var aabb := mesh.get_aabb()
			var box_shape := BoxShape3D.new()
			box_shape.size = aabb.size
			shape = box_shape
			shape_offset = aabb.get_center()
		_:
			shape = mesh.create_convex_shape(clean_convex, simplify_convex)

	if shape != null:
		var col_node := CollisionShape3D.new()
		col_node.name = "CollisionShape3D"
		col_node.shape = shape
		if shape_offset != Vector3.ZERO:
			col_node.transform = Transform3D(Basis.IDENTITY, shape_offset)
		root.add_child(col_node)
		col_node.owner = root

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		root.free()
		return {"success": false, "error": "Failed to pack scene: %d" % pack_err}

	var save_err := ResourceSaver.save(packed, output_path)
	root.free()

	if save_err != OK:
		return {"success": false, "error": "Failed to save: %d" % save_err}

	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.scan()
		if config.get("open_scene", false):
			EditorInterface.open_scene_from_path(output_path)

	print_rich("[color=green][b]✔ [Collision Maker][/b][/color] Created scene from Mesh: [color=cyan]%s[/color]" % output_path)
	return {"success": true, "scene_path": output_path, "shape_count": 1}


static func find_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		find_mesh_instances(child, result)


static func get_relative_transform(target: Node3D, root_ancestor: Node3D) -> Transform3D:
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
