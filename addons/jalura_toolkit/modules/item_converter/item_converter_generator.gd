@tool
class_name JaluraItemConverterGenerator
extends RefCounted

## Generator für das modulare Item-System in Jalura.
## Erzeugt aus einem 3D-Modell (.glb/.gltf/.obj):
## 1. Eine ItemData-Ressource (.tres) in res://resources/items/
## 2. Eine fertige PickableItem-Szene (.tscn) in res://scenes/items/
## 3. Registriert das Item für Inventar, Savegames und die Leveldesign-Palette.

const ItemDataScript = preload("res://scripts/data/item_data.gd")
const PickableItemScript = preload("res://scripts/interaction/pickable_item.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")

## Erstellt ItemData (.tres) und optional PickableItem (.tscn) aus einem 3D-Modell
static func create_item_from_model(glb_path: String, config: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(glb_path):
		var err := "Datei nicht gefunden: %s" % glb_path
		push_error("[Jalura Item Converter] " + err)
		return {"success": false, "error": err}

	var base_name: String = glb_path.get_file().get_basename()
	var raw_id: String = base_name.trim_prefix("item_").trim_prefix("prop_").trim_prefix("obj_").to_snake_case()

	# Konfiguration auslesen mit schlauen Defaults
	var item_id: String = config.get("id", raw_id).strip_edges().to_snake_case()
	if item_id.is_empty():
		item_id = raw_id

	var item_name: String = config.get("name", "")
	if item_name.is_empty():
		item_name = raw_id.replace("_", " ").capitalize()

	var default_cat := 0
	if "key" in item_id or "schluessel" in item_id or "karte" in item_id:
		default_cat = 2
	elif "batterie" in item_id or "battery" in item_id or "coin" in item_id or "muenze" in item_id:
		default_cat = 3
	elif "apple" in item_id or "apfel" in item_id or "fish" in item_id or "fisch" in item_id:
		default_cat = 1
	elif "lampe" in item_id or "light" in item_id or "torch" in item_id or "angel" in item_id or "tool" in item_id or "glider" in item_id or "shoe" in item_id or "schuh" in item_id or "rail" in item_id:
		default_cat = 4

	var category_idx: int = config.get("category", default_cat) # 0 = GENERAL, 4 = TOOL
	var max_stack: int = config.get("max_stack", 1 if (category_idx in [2, 4]) else (999 if category_idx == 3 else 99))
	var is_currency: bool = config.get("is_currency", category_idx == 3)
	var currency_attr: String = config.get("currency_attribute", "energy" if is_currency else "")
	var value: int = config.get("value", 1)
	var can_drop: bool = config.get("can_drop", not is_currency and category_idx not in [2, 4])
	var description: String = config.get("description", "")
	if description.is_empty():
		description = "Ein nützlicher Gegenstand: %s." % item_name

	var item_res_dir: String = config.get("item_res_dir", "res://resources/items")
	var pickup_scene_dir: String = config.get("pickup_scene_dir", "res://scenes/items")
	var create_pickup_scene: bool = config.get("create_pickup_scene", true)

	# 1. 3D-Modell Scene laden
	var model_scene := load(glb_path) as PackedScene
	if not model_scene:
		var err := "3D-Modell konnte nicht als PackedScene geladen werden: %s" % glb_path
		push_error("[Jalura Item Converter] " + err)
		return {"success": false, "error": err}

	# 2. Icon suchen (z. B. in res://assets/ui/icons/<id>.png)
	var icon_tex: Texture2D = null
	var possible_icon_paths = [
		config.get("icon_path", ""),
		"res://assets/ui/icons/%s.png" % item_id,
		"res://assets/ui/icons/icon_%s.png" % item_id,
		glb_path.get_base_dir().path_join(item_id + ".png"),
		glb_path.get_base_dir().path_join(base_name + ".png")
	]
	for icon_p in possible_icon_paths:
		if not icon_p.is_empty() and ResourceLoader.exists(icon_p):
			icon_tex = load(icon_p) as Texture2D
			if icon_tex:
				break

	# 3. ItemData Ressource erstellen und speichern
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(item_res_dir))
	var item_res_path: String = item_res_dir.path_join("%s.tres" % item_id)

	var item_data = ItemDataScript.new()
	item_data.id = item_id
	item_data.name = item_name
	item_data.description = description
	item_data.category = category_idx
	item_data.max_stack = max_stack
	item_data.is_currency = is_currency
	item_data.currency_attribute = currency_attr
	item_data.value = value
	item_data.can_drop = can_drop
	item_data.model_scene = model_scene
	if icon_tex:
		item_data.icon = icon_tex

	var save_err := ResourceSaver.save(item_data, item_res_path)
	if save_err != OK:
		var err := "Fehler beim Speichern von ItemData unter %s (Code: %d)" % [item_res_path, save_err]
		push_error("[Jalura Item Converter] " + err)
		return {"success": false, "error": err}

	print_rich("[color=green][b]✔ [Jalura Item Converter][/b][/color] ItemData erstellt: [b]%s[/b] -> [u]%s[/u]" % [item_name, item_res_path])

	# 4. Optional: PickableItem Welt-Szene erstellen (.tscn)
	var pickup_scene_path := ""
	if create_pickup_scene:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pickup_scene_dir))
		pickup_scene_path = pickup_scene_dir.path_join("pickable_%s.tscn" % item_id)

		var pickup_root := Node3D.new()
		pickup_root.name = "Pickable" + item_name.capitalize().replace(" ", "")
		pickup_root.set_script(PickableItemScript)
		pickup_root.set("item_data", item_data)
		pickup_root.set("item_id", item_id)
		pickup_root.set("item_count", 1)
		pickup_root.set("auto_bob", true)

		# Visual Container
		var visual := Node3D.new()
		visual.name = "Visual"
		pickup_root.add_child(visual)
		visual.owner = pickup_root

		# 3D-Modell Instanz unter Visual
		var model_inst := model_scene.instantiate()
		model_inst.name = base_name
		visual.add_child(model_inst)
		model_inst.owner = pickup_root

		# GlowLight für Saft & Kraft beim Aufsammeln
		var glow := OmniLight3D.new()
		glow.name = "GlowLight"
		glow.position = Vector3(0, 0.2, 0)
		glow.light_energy = 1.3
		glow.omni_range = 2.5
		glow.omni_attenuation = 1.1

		# Farbe passend zur Kategorie wählen
		match category_idx:
			1: # Consumable
				glow.light_color = Color(1.0, 0.75, 0.35)
			2: # Key Item
				glow.light_color = Color(1.0, 0.85, 0.2)
			3: # Currency
				glow.light_color = Color(0.4, 0.9, 1.0)
			4: # Tool
				glow.light_color = Color(0.9, 0.95, 1.0)
			_: # General / Collectible
				glow.light_color = Color(1.0, 0.9, 0.6)

		visual.add_child(glow)
		glow.owner = pickup_root

		# Interactable (Area3D auf Layer 8 für Jaluras Interaktions-System)
		var interactable := Area3D.new()
		interactable.name = "Interactable"
		interactable.collision_layer = 8
		interactable.collision_mask = 2
		interactable.set_script(InteractableScript)
		interactable.set("prompt_text", "%s aufheben" % item_name)
		interactable.set("action_key", "E")

		pickup_root.add_child(interactable)
		interactable.owner = pickup_root

		var col_shape := CollisionShape3D.new()
		col_shape.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = 1.25
		col_shape.shape = sphere

		interactable.add_child(col_shape)
		col_shape.owner = pickup_root

		# Szene packen und speichern
		var packed_scene := PackedScene.new()
		var pack_res := packed_scene.pack(pickup_root)
		if pack_res == OK:
			var scene_err := ResourceSaver.save(packed_scene, pickup_scene_path)
			if scene_err == OK:
				print_rich("[color=green][b]✔ [Jalura Item Converter][/b][/color] Pickable Szene erstellt: [b]%s[/b] -> [u]%s[/u]" % [pickup_root.name, pickup_scene_path])
			else:
				push_error("[Jalura Item Converter] Fehler beim Speichern der Szene: %d" % scene_err)
		else:
			push_error("[Jalura Item Converter] Fehler beim Packen der Szene: %d" % pack_res)

		pickup_root.free()

	# Filesystem Scan anstoßen
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		var efs := EditorInterface.get_resource_filesystem()
		if efs:
			efs.scan()

	return {
		"success": true,
		"item_id": item_id,
		"item_name": item_name,
		"item_res_path": item_res_path,
		"pickup_scene_path": pickup_scene_path
	}
