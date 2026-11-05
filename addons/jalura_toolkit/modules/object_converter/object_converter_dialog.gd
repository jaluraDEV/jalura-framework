@tool
class_name JaluraConverterDialog
extends ConfirmationDialog

## Custom settings dialog for fine-tuning Jalura Object conversion.

const Generator = preload("res://addons/jalura_toolkit/modules/object_converter/object_converter_generator.gd")

var line_source: LineEdit
var line_output: LineEdit
var opt_type: OptionButton
var opt_col: OptionButton
var chk_open: CheckBox

var _file_dlg_src: EditorFileDialog
var _file_dlg_out: EditorFileDialog

var _type_keys: Array[String] = [
	"chest",
	"door",
	"switch",
	"sign",
	"pickup",
	"pushable",
	"wobble",
	"bounce_pad",
	"generic"
]

func _init() -> void:
	title = "Jalura Object Converter"
	min_size = Vector2i(540, 360)
	ok_button_text = "Generate Object"

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# 1. Source Model
	var grp_src := VBoxContainer.new()
	var lbl_src := Label.new()
	lbl_src.text = "Source Model (GLB / GLTF):"
	grp_src.add_child(lbl_src)

	var hbox_src := HBoxContainer.new()
	line_source = LineEdit.new()
	line_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_source.text_changed.connect(_on_source_changed)
	hbox_src.add_child(line_source)

	var btn_browse_src := Button.new()
	btn_browse_src.text = "Browse..."
	btn_browse_src.pressed.connect(func(): _file_dlg_src.popup_file_dialog())
	hbox_src.add_child(btn_browse_src)
	grp_src.add_child(hbox_src)
	vbox.add_child(grp_src)

	# 2. Object Type & Collision
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)

	var lbl_type := Label.new()
	lbl_type.text = "Jalura Object Type:"
	grid.add_child(lbl_type)

	opt_type = OptionButton.new()
	for i in range(_type_keys.size()):
		var k: String = _type_keys[i]
		var def: Dictionary = Generator.PREFAB_DEFS[k]
		opt_type.add_item("%s (%s)" % [def["label"], k], i)
	opt_type.item_selected.connect(_on_type_selected)
	grid.add_child(opt_type)

	var lbl_col := Label.new()
	lbl_col.text = "Collision Shape:"
	grid.add_child(lbl_col)

	opt_col = OptionButton.new()
	opt_col.add_item("Box (Fast Box)", 0)
	opt_col.add_item("Convex Hull", 1)
	opt_col.add_item("Trimesh (Exact 1:1 Mesh)", 2)
	opt_col.add_item("No Collision (e.g. Pickup)", 3)
	grid.add_child(opt_col)
	vbox.add_child(grid)

	# 3. Output Path
	var grp_out := VBoxContainer.new()
	var lbl_out := Label.new()
	lbl_out.text = "Target Scene (.tscn):"
	grp_out.add_child(lbl_out)

	var hbox_out := HBoxContainer.new()
	line_output = LineEdit.new()
	line_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_out.add_child(line_output)

	var btn_browse_out := Button.new()
	btn_browse_out.text = "Save as..."
	btn_browse_out.pressed.connect(func(): _file_dlg_out.popup_file_dialog())
	hbox_out.add_child(btn_browse_out)
	grp_out.add_child(hbox_out)
	vbox.add_child(grp_out)

	# 4. Options
	chk_open = CheckBox.new()
	chk_open.text = "Open scene in 3D editor after generation"
	chk_open.button_pressed = true
	vbox.add_child(chk_open)

	# File dialogs
	_file_dlg_src = EditorFileDialog.new()
	_file_dlg_src.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dlg_src.add_filter("*.glb, *.gltf, *.obj", "3D Models")
	_file_dlg_src.file_selected.connect(func(p: String):
		line_source.text = p
		_on_source_changed(p)
	)
	add_child(_file_dlg_src)

	_file_dlg_out = EditorFileDialog.new()
	_file_dlg_out.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_file_dlg_out.add_filter("*.tscn", "Godot Scene (*.tscn)")
	_file_dlg_out.file_selected.connect(func(p: String):
		line_output.text = p
	)
	add_child(_file_dlg_out)

	confirmed.connect(_on_confirmed)


func open_for_model(glb_path: String, default_type: String = "chest") -> void:
	line_source.text = glb_path
	var idx := _type_keys.find(default_type)
	if idx >= 0:
		opt_type.select(idx)
	_update_defaults()
	popup_centered()


func _on_source_changed(_new_text: String) -> void:
	_update_defaults()


func _on_type_selected(idx: int) -> void:
	var k: String = _type_keys[idx]
	var def: Dictionary = Generator.PREFAB_DEFS[k]
	match def["collision_type"]:
		"box": opt_col.select(0)
		"convex": opt_col.select(1)
		"trimesh": opt_col.select(2)
		"none": opt_col.select(3)
	_update_defaults()


func _update_defaults() -> void:
	var src := line_source.text.strip_edges()
	if src.is_empty():
		return
	var type_key: String = _type_keys[opt_type.selected]
	var pdef: Dictionary = Generator.PREFAB_DEFS[type_key]
	var raw := src.get_file().get_basename().trim_prefix("obj_").trim_prefix("prop_").trim_prefix("item_")
	var target_name := "obj_%s%s.tscn" % [pdef["prefix"], raw]
	line_output.text = src.get_base_dir().path_join(target_name)


func _on_confirmed() -> void:
	var src := line_source.text.strip_edges()
	if src.is_empty():
		return

	var type_key: String = _type_keys[opt_type.selected]
	var col_type := "box"
	match opt_col.selected:
		0: col_type = "box"
		1: col_type = "convex"
		2: col_type = "trimesh"
		3: col_type = "none"

	var config := {
		"output_path": line_output.text.strip_edges(),
		"collision_type": col_type,
		"open_scene": chk_open.button_pressed
	}

	Generator.convert_model(src, type_key, config)
