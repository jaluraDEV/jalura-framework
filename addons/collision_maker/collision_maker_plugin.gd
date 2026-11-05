@tool
extends EditorPlugin

## Main entry point for the Collision Maker plugin.

const CollisionContextMenuPlugin = preload("res://addons/collision_maker/collision_context_menu.gd")
const CollisionInspectorPlugin = preload("res://addons/collision_maker/collision_inspector_plugin.gd")
const CollisionDialog = preload("res://addons/collision_maker/collision_dialog.gd")
const CollisionGenerator = preload("res://addons/collision_maker/collision_generator.gd")

var context_menu_plugin
var inspector_plugin
var dialog

func _enter_tree() -> void:
	# 1. Create and attach configuration dialog
	dialog = CollisionDialog.new()
	EditorInterface.get_base_control().add_child(dialog)

	# 2. Register FileSystem Context Menu (Right Click on GLB/GLTF/OBJ)
	if ClassDB.class_exists("EditorContextMenuPlugin"):
		context_menu_plugin = CollisionContextMenuPlugin.new()
		context_menu_plugin.action_requested.connect(_on_context_action_requested)
		add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, context_menu_plugin)

	# 3. Register Inspector Plugin (For MeshInstance3D nodes)
	inspector_plugin = CollisionInspectorPlugin.new()
	inspector_plugin.mesh_action_requested.connect(_on_inspector_mesh_action)
	add_inspector_plugin(inspector_plugin)

	# 4. Register Project/Tools menu item
	add_tool_menu_item("Collision Maker...", _open_tool_menu_dialog)


func _exit_tree() -> void:
	# Unregister FileSystem context menu
	if context_menu_plugin:
		remove_context_menu_plugin(context_menu_plugin)
		context_menu_plugin = null

	# Unregister Inspector plugin
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null

	# Remove menu item
	remove_tool_menu_item("Collision Maker...")

	# Clean up dialog
	if dialog:
		dialog.queue_free()
		dialog = null


func _on_context_action_requested(paths: PackedStringArray, mode: String) -> void:
	if paths.is_empty():
		return

	if mode == "custom":
		# Open configuration dialog for the first selected item
		for p in paths:
			var ext := p.get_extension().to_lower()
			if ext in ["glb", "gltf", "obj"]:
				dialog.open_for_glb(p)
				return
		return

	# Direct 1-Click generation (supports batch selection)
	var processed := 0
	var total_models := 0
	var single_target := (paths.size() == 1)

	for p in paths:
		var ext := p.get_extension().to_lower()
		if ext not in ["glb", "gltf", "obj"]:
			continue
		
		total_models += 1
		var result := CollisionGenerator.generate_from_glb(p, {
			"collision_type": mode,
			"body_type": "StaticBody3D",
			"open_scene": single_target,
			"clean_convex": true,
			"simplify_convex": false,
		})
		if result.get("success", false):
			processed += 1

	if total_models > 1:
		print_rich("[color=green][b]✔ [Collision Maker][/b][/color] Batch completed: Generated %d / %d scenes." % [processed, total_models])


func _on_inspector_mesh_action(mesh_node: MeshInstance3D) -> void:
	if dialog and mesh_node:
		dialog.open_for_mesh_instance(mesh_node)


func _open_tool_menu_dialog() -> void:
	if dialog:
		dialog.open_for_glb("")
