@tool
class_name CollisionContextMenuPlugin
extends EditorContextMenuPlugin

## Adds quick collision creation options to FileSystem dock context menus for 3D model files.

signal action_requested(paths: PackedStringArray, mode: String)

var _cached_paths: PackedStringArray = []

func _popup_menu(paths: PackedStringArray) -> void:
	_cached_paths = paths
	
	# Only show if at least one selected file is a 3D model
	var has_3d_file := false
	for path in paths:
		var ext := path.get_extension().to_lower()
		if ext in ["glb", "gltf", "obj"]:
			has_3d_file = true
			break

	if not has_3d_file:
		return

	# Add direct actions to the context menu
	add_context_menu_item("✨ Create Static Scene (Convex Shape)", _on_convex_selected)
	add_context_menu_item("✨ Create Static Scene (Trimesh / Concave)", _on_trimesh_selected)
	add_context_menu_item("✨ Create Static Scene (Bounding Box)", _on_box_selected)
	add_context_menu_item("⚙️ Create Collision Scene (Custom Options...)", _on_custom_selected)


func _on_convex_selected(arg1 = null, arg2 = null) -> void:
	_emit_action("convex", arg1, arg2)


func _on_trimesh_selected(arg1 = null, arg2 = null) -> void:
	_emit_action("trimesh", arg1, arg2)


func _on_box_selected(arg1 = null, arg2 = null) -> void:
	_emit_action("box", arg1, arg2)


func _on_custom_selected(arg1 = null, arg2 = null) -> void:
	_emit_action("custom", arg1, arg2)


func _emit_action(mode: String, arg1 = null, arg2 = null) -> void:
	var paths := _cached_paths
	if arg1 is PackedStringArray and not arg1.is_empty():
		paths = arg1
	elif arg2 is PackedStringArray and not arg2.is_empty():
		paths = arg2
	action_requested.emit(paths, mode)
