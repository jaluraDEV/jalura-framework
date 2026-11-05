@tool
class_name CollisionInspectorPlugin
extends EditorInspectorPlugin

## Adds a quick 'Convert to Collision Scene' button when inspecting a MeshInstance3D in the editor.

signal mesh_action_requested(mesh_node: MeshInstance3D)

func _can_handle(object: Object) -> bool:
	return object is MeshInstance3D


func _parse_begin(object: Object) -> void:
	var mesh_node := object as MeshInstance3D
	if mesh_node == null:
		return

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var btn := Button.new()
	btn.text = "✨ Collision Maker: Save as Scene..."
	btn.tooltip_text = "Generates a physics-ready .tscn scene from this MeshInstance3D."
	btn.custom_minimum_size = Vector2(0, 32)
	
	btn.pressed.connect(func():
		mesh_action_requested.emit(mesh_node)
	)

	container.add_child(btn)
	add_custom_control(container)
