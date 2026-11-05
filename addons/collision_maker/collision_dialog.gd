@tool
class_name CollisionDialog
extends ConfirmationDialog

const CollisionGenerator = preload("res://addons/collision_maker/collision_generator.gd")

## Configuration modal dialog for fine-tuning Collision Maker export settings.

signal confirmed_generation(source_path: String, config: Dictionary)

var line_source: LineEdit
var line_output: LineEdit
var opt_body: OptionButton
var opt_shape: OptionButton
var chk_simplify: CheckBox
var chk_open_scene: CheckBox

var _file_dialog_source: EditorFileDialog
var _file_dialog_output: EditorFileDialog

var _current_mesh_instance: MeshInstance3D = null

func _init() -> void:
	title = "Collision Maker - Settings"
	min_size = Vector2i(540, 360)
	ok_button_text = "Generate Scene"
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# --- 1. Source Path ---
	var grp_source := VBoxContainer.new()
	var lbl_source := Label.new()
	lbl_source.text = "Source 3D Model (GLB / GLTF):"
	grp_source.add_child(lbl_source)

	var hbox_source := HBoxContainer.new()
	line_source = LineEdit.new()
	line_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_source.placeholder_text = "res://path/to/model.glb"
	line_source.text_changed.connect(_on_source_path_changed)
	hbox_source.add_child(line_source)

	var btn_browse_source := Button.new()
	btn_browse_source.text = "Browse..."
	btn_browse_source.pressed.connect(_browse_source)
	hbox_source.add_child(btn_browse_source)
	grp_source.add_child(hbox_source)
	vbox.add_child(grp_source)

	# --- 2. Output Path ---
	var grp_output := VBoxContainer.new()
	var lbl_output := Label.new()
	lbl_output.text = "Target Scene (.tscn):"
	grp_output.add_child(lbl_output)

	var hbox_output := HBoxContainer.new()
	line_output = LineEdit.new()
	line_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_output.placeholder_text = "res://path/to/model.tscn"
	hbox_output.add_child(line_output)

	var btn_browse_output := Button.new()
	btn_browse_output.text = "Browse..."
	btn_browse_output.pressed.connect(_browse_output)
	hbox_output.add_child(btn_browse_output)
	grp_output.add_child(hbox_output)
	vbox.add_child(grp_output)

	# --- 3. Body Type & Shape Type ---
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)

	var lbl_body := Label.new()
	lbl_body.text = "Physics Body Type:"
	grid.add_child(lbl_body)

	opt_body = OptionButton.new()
	opt_body.add_item("StaticBody3D (Static Props, Environment)", 0)
	opt_body.add_item("RigidBody3D (Dynamic Physics)", 1)
	opt_body.add_item("CharacterBody3D (Kinematic / Character)", 2)
	opt_body.add_item("Area3D (Trigger / Detector)", 3)
	opt_body.item_selected.connect(_on_body_type_changed)
	grid.add_child(opt_body)

	var lbl_shape := Label.new()
	lbl_shape.text = "Collision Shape Type:"
	grid.add_child(lbl_shape)

	opt_shape = OptionButton.new()
	opt_shape.add_item("Convex Polygon (Balanced & Fast)", 0)
	opt_shape.add_item("Trimesh / Concave (100% Exact Mesh)", 1)
	opt_shape.add_item("Bounding Box (Fastest Approximate)", 2)
	grid.add_child(opt_shape)

	vbox.add_child(grid)

	# --- 4. Additional Options ---
	chk_simplify = CheckBox.new()
	chk_simplify.text = "Simplify Convex Shape (Fewer collision vertices)"
	chk_simplify.button_pressed = false
	vbox.add_child(chk_simplify)

	chk_open_scene = CheckBox.new()
	chk_open_scene.text = "Open created scene in 3D Editor immediately"
	chk_open_scene.button_pressed = true
	vbox.add_child(chk_open_scene)

	# Dialogs for browsing
	_file_dialog_source = EditorFileDialog.new()
	_file_dialog_source.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog_source.add_filter("*.glb, *.gltf, *.obj", "3D Models")
	_file_dialog_source.file_selected.connect(func(p: String):
		line_source.text = p
		_on_source_path_changed(p)
	)
	add_child(_file_dialog_source)

	_file_dialog_output = EditorFileDialog.new()
	_file_dialog_output.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_file_dialog_output.add_filter("*.tscn", "Godot Scene (*.tscn)")
	_file_dialog_output.file_selected.connect(func(p: String):
		line_output.text = p
	)
	add_child(_file_dialog_output)

	confirmed.connect(_on_confirmed)


func open_for_glb(glb_path: String) -> void:
	_current_mesh_instance = null
	line_source.text = glb_path
	line_source.editable = true
	_update_default_output(glb_path)
	popup_centered()


func open_for_mesh_instance(mesh_node: MeshInstance3D) -> void:
	_current_mesh_instance = mesh_node
	line_source.text = "[MeshInstance3D] " + mesh_node.name
	line_source.editable = false
	line_output.text = "res://" + mesh_node.name + ".tscn"
	popup_centered()


func _on_source_path_changed(new_path: String) -> void:
	_update_default_output(new_path)


func _update_default_output(source_path: String) -> void:
	if source_path.is_empty():
		return
	var ext := source_path.get_extension()
	if not ext.is_empty():
		line_output.text = source_path.get_basename() + ".tscn"


func _on_body_type_changed(idx: int) -> void:
	# RigidBody3D does not support Trimesh
	if idx == 1 and opt_shape.selected == 1:
		opt_shape.select(0)


func _browse_source() -> void:
	_file_dialog_source.popup_file_dialog()


func _browse_output() -> void:
	_file_dialog_output.popup_file_dialog()


func _on_confirmed() -> void:
	var body_type := "StaticBody3D"
	match opt_body.selected:
		1: body_type = "RigidBody3D"
		2: body_type = "CharacterBody3D"
		3: body_type = "Area3D"
		_: body_type = "StaticBody3D"

	var shape_type := "convex"
	match opt_shape.selected:
		1: shape_type = "trimesh"
		2: shape_type = "box"
		_: shape_type = "convex"

	var config := {
		"output_path": line_output.text.strip_edges(),
		"body_type": body_type,
		"collision_type": shape_type,
		"simplify_convex": chk_simplify.button_pressed,
		"clean_convex": true,
		"open_scene": chk_open_scene.button_pressed,
	}

	if _current_mesh_instance != null:
		CollisionGenerator.generate_from_mesh_instance(_current_mesh_instance, config)
	else:
		var src := line_source.text.strip_edges()
		if not src.is_empty():
			CollisionGenerator.generate_from_glb(src, config)
