@tool
class_name JaluraItemConverterDialog
extends ConfirmationDialog

## Einstellungs-Dialog zur Erstellung eines modularen Jalura-Items (ItemData + PickableItem)
## aus einer beliebigen 3D-Modelldatei (.glb / .gltf / .obj).

const Generator = preload("res://addons/jalura_toolkit/modules/item_converter/item_converter_generator.gd")

var line_source: LineEdit
var line_id: LineEdit
var line_name: LineEdit
var opt_category: OptionButton
var text_description: TextEdit
var spin_stack: SpinBox
var spin_value: SpinBox
var chk_currency: CheckBox
var chk_can_drop: CheckBox
var chk_create_pickup: CheckBox
var chk_open_scene: CheckBox

var _current_model_path: String = ""


func _init() -> void:
	title = "🎒 Jalura: Create New Inventory Item"
	min_size = Vector2i(540, 520)
	ok_button_text = "Generate Item & Pickup"

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# 1. Quell-Modell Info
	var grp_src := VBoxContainer.new()
	var lbl_src := Label.new()
	lbl_src.text = "3D Model (GLB / GLTF):"
	lbl_src.modulate = Color(0.5, 0.8, 1.0)
	grp_src.add_child(lbl_src)

	line_source = LineEdit.new()
	line_source.editable = false
	grp_src.add_child(line_source)
	vbox.add_child(grp_src)

	vbox.add_child(HSeparator.new())

	# 2. Formular-Felder
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)

	# Item ID
	var lbl_id := Label.new()
	lbl_id.text = "Item ID (Code/Savegame):"
	grid.add_child(lbl_id)

	line_id = LineEdit.new()
	line_id.placeholder_text = "e.g. old_lamp"
	line_id.text_changed.connect(_on_id_changed)
	grid.add_child(line_id)

	# Anzeigename
	var lbl_name := Label.new()
	lbl_name.text = "Display Name (HUD/Inventory):"
	grid.add_child(lbl_name)

	line_name = LineEdit.new()
	line_name.placeholder_text = "e.g. Old Mining Lamp"
	grid.add_child(line_name)

	# Kategorie
	var lbl_cat := Label.new()
	lbl_cat.text = "Category:"
	grid.add_child(lbl_cat)

	opt_category = OptionButton.new()
	opt_category.add_item("📦 General Item", 0)
	opt_category.add_item("🍎 Consumable (Food / Drink)", 1)
	opt_category.add_item("🔑 Key Item / Key", 2)
	opt_category.add_item("⚡ Currency (Energy / Coins)", 3)
	opt_category.add_item("🔦 Tool & Equipment", 4)
	opt_category.add_item("✨ Collectible & Treasure", 5)
	opt_category.item_selected.connect(_on_category_selected)
	grid.add_child(opt_category)

	# Stapelgröße
	var lbl_stack := Label.new()
	lbl_stack.text = "Max Stack Size:"
	grid.add_child(lbl_stack)

	spin_stack = SpinBox.new()
	spin_stack.min_value = 1
	spin_stack.max_value = 999
	spin_stack.value = 99
	grid.add_child(spin_stack)

	# Tauschwert
	var lbl_val := Label.new()
	lbl_val.text = "Value / Coins:"
	grid.add_child(lbl_val)

	spin_value = SpinBox.new()
	spin_value.min_value = 0
	spin_value.max_value = 9999
	spin_value.value = 1
	grid.add_child(spin_value)

	vbox.add_child(grid)

	# Beschreibung
	var lbl_desc := Label.new()
	lbl_desc.text = "Description (Inventory Details):"
	vbox.add_child(lbl_desc)

	text_description = TextEdit.new()
	text_description.custom_minimum_size = Vector2(0, 60)
	text_description.placeholder_text = "Short description of the item..."
	vbox.add_child(text_description)

	# Optionen (Checkboxes)
	var grp_chk := VBoxContainer.new()
	grp_chk.add_theme_constant_override("separation", 4)

	chk_currency = CheckBox.new()
	chk_currency.text = "Counts as Currency (Syncs with HUD)"
	grp_chk.add_child(chk_currency)

	chk_can_drop = CheckBox.new()
	chk_can_drop.text = "Can be dropped from inventory"
	chk_can_drop.button_pressed = true
	grp_chk.add_child(chk_can_drop)

	chk_create_pickup = CheckBox.new()
	chk_create_pickup.text = "Create 3D world pickup (res://scenes/items/pickable_<id>.tscn)"
	chk_create_pickup.button_pressed = true
	grp_chk.add_child(chk_create_pickup)

	chk_open_scene = CheckBox.new()
	chk_open_scene.text = "Open generated scene in 3D editor immediately"
	chk_open_scene.button_pressed = false
	grp_chk.add_child(chk_open_scene)

	vbox.add_child(grp_chk)

	confirmed.connect(_on_confirmed)


## Öffnet den Dialog für ein konkretes 3D-Modell
func open_for_model(glb_path: String) -> void:
	_current_model_path = glb_path
	line_source.text = glb_path

	var base_name: String = glb_path.get_file().get_basename()
	var raw_id: String = base_name.trim_prefix("item_").trim_prefix("prop_").trim_prefix("obj_").to_snake_case()

	line_id.text = raw_id
	line_name.text = raw_id.replace("_", " ").capitalize()
	text_description.text = "A useful item: %s." % line_name.text

	# Schlaue Kategorie-Vorauswahl nach Name
	if "key" in raw_id or "schluessel" in raw_id or "karte" in raw_id:
		opt_category.select(2) # Key Item
	elif "batterie" in raw_id or "battery" in raw_id or "coin" in raw_id or "muenze" in raw_id:
		opt_category.select(3) # Currency
	elif "apple" in raw_id or "apfel" in raw_id or "fish" in raw_id or "fisch" in raw_id:
		opt_category.select(1) # Consumable
	elif "lampe" in raw_id or "light" in raw_id or "torch" in raw_id or "angel" in raw_id or "tool" in raw_id or "glider" in raw_id or "shoe" in raw_id or "schuh" in raw_id or "rail" in raw_id:
		opt_category.select(4) # Tool / Equipment
	else:
		opt_category.select(0) # General

	_on_category_selected(opt_category.selected)
	popup_centered()


func _on_id_changed(new_id: String) -> void:
	var clean_id := new_id.strip_edges().to_snake_case()
	if line_name.text.is_empty() or line_name.text == line_id.text.replace("_", " ").capitalize():
		line_name.text = clean_id.replace("_", " ").capitalize()


func _on_category_selected(index: int) -> void:
	match index:
		2: # Key Item
			spin_stack.value = 1
			chk_can_drop.button_pressed = false
			chk_currency.button_pressed = false
		3: # Currency
			spin_stack.value = 999
			chk_currency.button_pressed = true
			chk_can_drop.button_pressed = false
		4: # Tool / Equipment
			spin_stack.value = 1
			chk_can_drop.button_pressed = false
			chk_currency.button_pressed = false
		_:
			spin_stack.value = 99
			chk_currency.button_pressed = false
			chk_can_drop.button_pressed = true


func _on_confirmed() -> void:
	if _current_model_path.is_empty():
		return

	var config := {
		"id": line_id.text.strip_edges().to_snake_case(),
		"name": line_name.text.strip_edges(),
		"category": opt_category.selected,
		"max_stack": int(spin_stack.value),
		"value": int(spin_value.value),
		"is_currency": chk_currency.button_pressed,
		"currency_attribute": "energy" if chk_currency.button_pressed else "",
		"can_drop": chk_can_drop.button_pressed,
		"description": text_description.text.strip_edges(),
		"create_pickup_scene": chk_create_pickup.button_pressed
	}

	var res := Generator.create_item_from_model(_current_model_path, config)
	if res.get("success", false):
		var p_path: String = res.get("pickup_scene_path", "")
		if chk_open_scene.button_pressed and not p_path.is_empty() and Engine.is_editor_hint():
			EditorInterface.open_scene_from_path(p_path)
