extends SceneTree

## Baut Materialien, Demo-Items, Quest, WorldMap, Meshes und das erweiterte Demo-Level.
## Aufruf: godot --headless --path . -s res://tools/build_demo.gd

const TILE: float = 2.0
const MAT_DIR := "res://resources/materials"
const MESH_DIR := "res://resources/meshes"
const ITEM_DIR := "res://resources/items"
const QUEST_DIR := "res://resources/quests"
const WORLD_DIR := "res://resources/world"
const SCENE_PATH := "res://scenes/demo/demo_level.tscn"

const ItemGen = preload("res://addons/jalura_toolkit/modules/item_converter/item_converter_generator.gd")

func _init() -> void:
	if FileAccess.file_exists(SCENE_PATH):
		print("SAFETY: %s already exists! Generation skipped to protect manual editor changes." % SCENE_PATH)
		quit(0)
		return

	for d in [MAT_DIR, MESH_DIR, ITEM_DIR, QUEST_DIR, WORLD_DIR, "res://scenes/demo", "res://scenes/items"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))

	var checker := _make_checker_material()
	_make_items()
	_make_quest()
	_make_world_map()

	var root := Node3D.new()
	root.name = "DemoLevel"

	_add_env(root)
	_add_geometry(root, checker)
	_add_harbor_and_water(root, checker)
	_add_rail(root)
	_add_trampolines(root)
	_add_interactive_objects(root)
	_add_pickups(root)
	_add_spawns(root)
	_add_player_and_ui(root)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		printerr("Pack fehlgeschlagen: ", err)
		quit(1)
		return
	ResourceSaver.save(packed, SCENE_PATH)
	print("Szene gespeichert: ", SCENE_PATH, " (", err, ")")
	root.free()
	quit(0)


func _make_checker_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/test/checker.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.95
	mat.metallic_specular = 0.15
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5) # 1 Checker-Kachel pro 2 Meter
	var path := "%s/checker.tres" % MAT_DIR
	ResourceSaver.save(mat, path)
	return load(path) as StandardMaterial3D


func _make_items() -> void:
	_make_item("coin", "Coin", "A shiny golden harbor coin.", ItemData.Category.COLLECTIBLE, "res://scenes/objects/coin_model.tscn")
	_make_item("battery", "Battery", "A fully charged power battery. Used as main currency and powers up gear!", ItemData.Category.CURRENCY, "")
	_make_item("glider", "Glider", "Allows the player to glide through the air! Hold [Space] while airborne.", ItemData.Category.TOOL, "res://assets/chars/extras/glider.glb")
	_make_item("rail_shoe", "Rail Shoes", "Special shoes with reinforced grind soles! Allows grinding along rails.", ItemData.Category.TOOL, "res://assets/chars/extras/rail_shoe.glb")
	_make_item("flashlight", "Flashlight", "A sturdy vintage box flashlight with a metal handle. Illuminates dark places with [F].", ItemData.Category.TOOL, "res://assets/items/alte_lampe/alte_lampe.glb")
	_make_item("lamp", "Flashlight", "A sturdy vintage box flashlight with a metal handle. Illuminates dark places with [F].", ItemData.Category.TOOL, "res://assets/items/alte_lampe/alte_lampe.glb")

	ItemGen.create_item_from_model("res://assets/chars/extras/glider.glb", {
		"id": "glider",
		"name": "Glider",
		"category": ItemData.Category.TOOL,
		"max_stack": 1,
		"can_drop": false,
		"is_currency": false,
		"currency_attribute": "",
		"description": "Allows the player to glide through the air! Hold [Space] while airborne."
	})
	ItemGen.create_item_from_model("res://assets/chars/extras/rail_shoe.glb", {
		"id": "rail_shoe",
		"name": "Rail Shoes",
		"category": ItemData.Category.TOOL,
		"max_stack": 1,
		"can_drop": false,
		"is_currency": false,
		"currency_attribute": "",
		"description": "Special shoes with reinforced grind soles! Allows grinding along rails."
	})
	ItemGen.create_item_from_model("res://assets/items/alte_lampe/alte_lampe.glb", {
		"id": "flashlight",
		"name": "Flashlight",
		"category": ItemData.Category.TOOL,
		"max_stack": 1,
		"can_drop": false,
		"is_currency": false,
		"currency_attribute": "",
		"description": "A sturdy vintage box flashlight with a metal handle. Illuminates dark places with [F]."
	})


func _make_item(id: String, title: String, desc: String, cat: ItemData.Category, model := "") -> void:
	var item := ItemData.new()
	item.id = id
	item.name = title
	item.description = desc
	item.category = cat
	if cat == ItemData.Category.TOOL or cat == ItemData.Category.KEY_ITEM:
		item.max_stack = 1
		item.can_drop = false
		item.is_currency = false
		item.currency_attribute = ""
	elif cat == ItemData.Category.CURRENCY:
		item.max_stack = 999
		item.can_drop = false
		item.is_currency = true
		item.currency_attribute = "energy"
	else:
		item.max_stack = 99
		item.can_drop = true
		item.is_currency = false
		item.currency_attribute = ""
	if model != "" and ResourceLoader.exists(model):
		item.model_scene = load(model)
	ResourceSaver.save(item, "%s/%s.tres" % [ITEM_DIR, id])


func _make_quest() -> void:
	var quest := QuestData.new()
	quest.id = "demo_bring_coin"
	quest.title = "A Coin for Mara"
	quest.description = "Mara collects rare coins. Find one in the harbor and bring it to her."
	quest.target_item_id = "coin"
	quest.target_item_count = 1
	quest.energy_reward = 5
	quest.giver_npc_id = "mara"
	quest.offer_dialogue = ["Ahoy! Great to see you.", "I collect rare coins. There is said to be a shiny one atop the high tower or out on the harbor island!", "Could you bring me one?"]
	quest.reminder_dialogue = ["Did you find the coin yet? Check the top of the tower or bounce across the water trampolines!"]
	quest.turn_in_dialogue = ["Wonderful! You found it! Thank you so much!"]
	quest.after_dialogue = ["You are doing great. Be sure to check out the boat and its interior cabin at the harbor pier!"]
	var objective := ItemObjective.new()
	objective.item_id = "coin"
	objective.target_amount = 1
	objective.description = "Find 1 Coin"
	quest.objectives.append(objective)
	ResourceSaver.save(quest, "%s/%s.tres" % [QUEST_DIR, quest.id])


func _make_world_map() -> void:
	var wmap := WorldMap.new()
	wmap.start_scene_id = &"demo_level"

	var room_demo := WorldMapEntry.new(&"demo_level", "Jalura Demo Harbor", "res://scenes/demo/demo_level.tscn", false)
	var room_cabin := WorldMapEntry.new(&"bootskabine", "Ship Cabin", "res://scenes/demo/ship_cabin.tscn", false)

	wmap.scenes = [room_demo, room_cabin]
	ResourceSaver.save(wmap, "%s/world_map.tres" % WORLD_DIR)


func _box(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


func _add_env(root: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.42, 0.72)
	sky_mat.sky_horizon_color = Color(0.55, 0.68, 0.82)
	sky_mat.ground_bottom_color = Color(0.14, 0.15, 0.17)
	sky_mat.ground_horizon_color = Color(0.3, 0.32, 0.35)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.glow_enabled = false
	env.glow_intensity = 0.25
	env.glow_bloom = 0.04
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.0012

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	we.owner = root

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, 38, 0)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	root.add_child(sun)
	sun.owner = root


func _block(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees = rot

	var mesh := _box(size)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var root_owner := parent if parent.owner == null else parent.owner
	parent.add_child(body)
	body.owner = root_owner
	mi.owner = root_owner
	shape.owner = root_owner


func _add_geometry(root: Node3D, mat: Material) -> void:
	var geo := Node3D.new()
	geo.name = "Geometry"
	root.add_child(geo)
	geo.owner = root

	# --------------------------------------------------------------------------
	# 1. Große Haupt-Arena / Plaza im Norden (64m breit, Z = -24 bis +16, Y = 0.0)
	# --------------------------------------------------------------------------
	_block(geo, "Floor", Vector3(64, 3.0, 40), Vector3(0, -1.5, -4), mat)

	# Tiefergelegter Meeresboden für das große Hafenbecken im Süden (Z = +16 bis +56, Y = -3.0)
	_block(geo, "Harbor_Seabed", Vector3(64, 0.8, 40), Vector3(0, -3.4, 36), mat)

	# Solide, 3 Meter dicke Begrenzungsmauern rund um das gesamte 64x80m Areal (keine dünnen Hohlwände!)
	_block(geo, "Wall_North", Vector3(68.0, 5.0, 3.0), Vector3(0, 2.5, -25.5), mat)
	_block(geo, "Wall_South", Vector3(68.0, 5.0, 3.0), Vector3(0, 1.0, 57.5), mat)
	_block(geo, "Wall_East", Vector3(3.0, 5.0, 84.0), Vector3(33.5, 1.75, 16.0), mat)
	_block(geo, "Wall_West", Vector3(3.0, 5.0, 84.0), Vector3(-33.5, 1.75, 16.0), mat)

	# --------------------------------------------------------------------------
	# 2. Aussichtsturm mit solidem Fundamentpfeiler (North-West: X ~ -2, Z ~ -4)
	# --------------------------------------------------------------------------
	_block(geo, "Tower_Pillar", Vector3(5.0, 6.2, 5.0), Vector3(-2, 3.1, -4), mat)
	_block(geo, "Tower_Platform", Vector3(8.5, 0.6, 8.5), Vector3(-2, 6.3, -4), mat)

	var step_defs := [
		{"pos": Vector3(-14, 0.5, -12), "size": Vector3(4.0, 1.0, 4.0)},
		{"pos": Vector3(-11, 1.1, -10), "size": Vector3(4.0, 2.2, 4.0)},
		{"pos": Vector3(-8, 1.7, -8), "size": Vector3(4.0, 3.4, 4.0)},
		{"pos": Vector3(-5, 2.3, -6), "size": Vector3(4.0, 4.6, 4.0)},
		{"pos": Vector3(-2.5, 2.9, -4.5), "size": Vector3(4.0, 5.8, 4.0)},
	]
	for i in step_defs.size():
		var def: Dictionary = step_defs[i]
		_block(geo, "Step_%d" % i, def["size"], def["pos"], mat)

	# --------------------------------------------------------------------------
	# 3. Plattformen auf dem Hauptplatz (mit soliden Stützpfeilern bis zum Boden)
	# --------------------------------------------------------------------------
	_block(geo, "Platform_A_Pillar", Vector3(3.5, 2.2, 3.5), Vector3(8, 1.1, 5), mat)
	_block(geo, "Platform_A", Vector3(7.0, 0.6, 7.0), Vector3(8, 2.2, 5), mat)

	_block(geo, "Platform_B_Pillar", Vector3(3.5, 4.7, 3.5), Vector3(12, 2.35, -4), mat)
	_block(geo, "Platform_B", Vector3(6.0, 0.6, 6.0), Vector3(12, 4.7, -4), mat)

	# --------------------------------------------------------------------------
	# 4. Solide Gangway zum Kutter & Podeste vor dem Spawn
	# --------------------------------------------------------------------------
	_block(geo, "Boat_Gangway", Vector3(3.0, 0.3, 3.6), Vector3(-10.0, 0.10, 30.2), mat)

	_block(geo, "Pedestal_Shoes", Vector3(1.4, 0.35, 1.4), Vector3(-3.2, 0.175, 6.5), mat)
	_block(geo, "Pedestal_Glider", Vector3(1.4, 0.35, 1.4), Vector3(0.0, 0.175, 6.5), mat)
	_block(geo, "Pedestal_Flashlight", Vector3(1.4, 0.35, 1.4), Vector3(3.2, 0.175, 6.5), mat)

	# --------------------------------------------------------------------------
	# 5. Massive Rätsel-Schatzkammer auf dem West-Platz (solide 1.2m dicke Wände)
	# --------------------------------------------------------------------------
	_block(geo, "PuzzleRoom_WallLeft", Vector3(2.2, 3.2, 1.2), Vector3(-22.2, 1.6, 2.0), mat)
	_block(geo, "PuzzleRoom_WallRight", Vector3(2.2, 3.2, 1.2), Vector3(-17.8, 1.6, 2.0), mat)
	_block(geo, "PuzzleRoom_WallBack", Vector3(7.4, 3.2, 1.2), Vector3(-20.0, 1.6, -2.0), mat)
	_block(geo, "PuzzleRoom_SideWest", Vector3(1.2, 3.2, 4.8), Vector3(-23.1, 1.6, 0.0), mat)
	_block(geo, "PuzzleRoom_SideEast", Vector3(1.2, 3.2, 4.8), Vector3(-16.9, 1.6, 0.0), mat)
	_block(geo, "PuzzleRoom_Roof", Vector3(7.4, 0.6, 5.2), Vector3(-20.0, 3.5, 0.0), mat)

	# Große Schatz-Insel im südöstlichen Wasserbecken
	_block(geo, "Harbor_Island_Base", Vector3(12.0, 4.6, 12.0), Vector3(16.0, -0.7, 45.0), mat)
	_block(geo, "Harbor_Island_Upper", Vector3(6.0, 1.4, 6.0), Vector3(16.0, 2.3, 46.5), mat)


func _add_harbor_and_water(root: Node3D, _mat: Material) -> void:
	var harbor := Node3D.new()
	harbor.name = "Harbor"
	root.add_child(harbor)
	harbor.owner = root

	# 1. Wasser-Oberfläche mit dem Legacy-Water-Shader (Z = 16 bis 56, Y = -0.42)
	var water_mesh_inst := MeshInstance3D.new()
	water_mesh_inst.name = "WaterSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(64.0, 40.0)
	plane.subdivide_width = 64
	plane.subdivide_depth = 48
	water_mesh_inst.mesh = plane
	water_mesh_inst.material_override = load("res://assets/shader/water/water_material.tres")
	water_mesh_inst.position = Vector3(0.0, -0.42, 36.0)
	harbor.add_child(water_mesh_inst)
	water_mesh_inst.owner = root

	# 2. WaterZone für Splash- & Respawn-Logik bei tiefem Eintauchen (Y = -0.85)
	var water_scene: PackedScene = load("res://scenes/objects/water_zone.tscn")
	if water_scene:
		var water_zone: Node3D = water_scene.instantiate()
		water_zone.name = "HarborWaterZone"
		water_zone.position = Vector3(0.0, -0.85, 36.0)
		water_zone.set("size", Vector2(62.0, 38.0))
		water_zone.set("zone_name", "harbor_basin")
		water_zone.set("show_debug_mesh", false)
		harbor.add_child(water_zone)
		water_zone.owner = root

	# 3. Begehbarer Original-Hafensteg mit intakter nativer Kollision (39 Shapes)
	var pier_scene: PackedScene = load("res://assets/hauser/hafen/pier.tscn")
	if pier_scene:
		var pier: Node3D = pier_scene.instantiate()
		pier.name = "Pier"
		pier.position = Vector3(-10.0, -0.86, 18.0)
		pier.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		pier.scale = Vector3(1.0, 1.0, 1.0)
		harbor.add_child(pier)
		pier.owner = root

	# 4. Barnabys Fischkutter (fishing_boat.glb) mit nativer Kollision (fishing_boat_collision.tres)
	var boat_scene: PackedScene = load("res://assets/hauser/hafen/fishing_boat.glb")
	if boat_scene:
		var boat: Node3D = boat_scene.instantiate()
		boat.name = "FishingBoat"
		boat.position = Vector3(-10.0, -0.35, 34.2)
		boat.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		boat.scale = Vector3(1.875, 1.875, 1.875)
		harbor.add_child(boat)
		boat.owner = root

		var boat_body := StaticBody3D.new()
		boat_body.name = "StaticBody3D"
		boat.add_child(boat_body)
		boat_body.owner = root

		var boat_col := CollisionShape3D.new()
		boat_col.name = "CollisionShape3D"
		boat_col.shape = load("res://assets/hauser/hafen/fishing_boat_collision.tres")
		boat_body.add_child(boat_col)
		boat_col.owner = root

	# 5. Tür-Trigger in die Schiffskabine (CabinEntrance) auf dem Achterdeck
	var door_trigger_scene: PackedScene = load("res://scenes/objects/door_trigger.tscn")
	if door_trigger_scene:
		var cabin_door: Node3D = door_trigger_scene.instantiate()
		cabin_door.name = "CabinEntrance"
		cabin_door.position = Vector3(-10.0, 0.45, 32.2)
		cabin_door.set("target_scene_id", &"bootskabine")
		cabin_door.set("target_scene_path", "res://scenes/demo/ship_cabin.tscn")
		cabin_door.set("target_spawn_id", &"von_hafen")
		cabin_door.set("return_spawn_position", Vector3(-10.0, 0.5, 14.5))
		cabin_door.set("trigger_mode", 2)
		cabin_door.set("zone_size", Vector3(2.8, 2.5, 2.8))
		cabin_door.set("prompt_text", "Enter Ship Cabin [E]")
		harbor.add_child(cabin_door)
		cabin_door.owner = root

	# 6. Warme Hafen-Laterne am Bootssteg
	var lantern := OmniLight3D.new()
	lantern.name = "BoatLanternLight"
	lantern.position = Vector3(-10.0, 3.2, 30.5)
	lantern.light_color = Color(1.0, 0.86, 0.55)
	lantern.light_energy = 2.5
	lantern.omni_range = 10.0
	harbor.add_child(lantern)
	lantern.owner = root


func _add_rail(root: Node3D) -> void:
	var rail := Path3D.new()
	rail.name = "TestRail"
	rail.set_script(load("res://scripts/world/rail_3d.gd"))
	rail.set("rail_material", load("res://assets/umgebung/plattformen/rail_material.tres"))
	rail.set("pipe_radius", 0.09)
	rail.set("snap_distance", 1.45)

	var curve := Curve3D.new()
	curve.add_point(Vector3(1.8, 6.75, -3.5), Vector3.ZERO, Vector3(3.0, 0.0, 1.0))
	curve.add_point(Vector3(7.0, 5.2, -1.0), Vector3(-2.5, 0.5, -1.5), Vector3(2.5, -0.5, 1.5))
	curve.add_point(Vector3(11.0, 4.0, 3.0), Vector3(-2.0, 0.5, -2.0), Vector3(2.0, -0.5, 2.0))
	curve.add_point(Vector3(13.5, 2.2, 8.0), Vector3(-1.5, 0.5, -2.0), Vector3(1.5, -0.5, 2.0))
	curve.add_point(Vector3(10.0, 0.42, 14.0), Vector3(1.5, 0.3, -2.0), Vector3.ZERO)
	rail.curve = curve

	root.add_child(rail)
	rail.owner = root


func _add_trampolines(root: Node3D) -> void:
	var tramp_scene: PackedScene = load("res://scenes/objects/obj_water_trampoline.tscn")
	if not tramp_scene:
		printerr("obj_water_trampoline.tscn konnte nicht geladen werden!")
		return

	var tramp_group := Node3D.new()
	tramp_group.name = "Trampolines"
	root.add_child(tramp_group)
	tramp_group.owner = root

	var water_tramp_defs := [
		{"name": "WaterTrampoline_1", "pos": Vector3(4.0, -0.35, 20.5), "vel": 17.5, "super": 24.0},
		{"name": "WaterTrampoline_2", "pos": Vector3(11.5, -0.35, 26.5), "vel": 18.0, "super": 24.5},
		{"name": "WaterTrampoline_3", "pos": Vector3(18.0, -0.35, 34.0), "vel": 18.5, "super": 25.0},
		{"name": "WaterTrampoline_4", "pos": Vector3(10.5, -0.35, 41.5), "vel": 18.5, "super": 25.0},
		{"name": "WaterTrampoline_5", "pos": Vector3(0.5, -0.35, 33.0), "vel": 18.0, "super": 24.5},
	]
	for def in water_tramp_defs:
		var wt := _instantiate_node(tramp_group, tramp_scene, def["name"], def["pos"], {
			"bounce_velocity": def["vel"],
			"super_bounce_velocity": def["super"],
			"water_bob_enabled": true,
			"water_bob_height": 0.08,
			"water_bob_speed": 2.0,
			"water_bob_tilt_deg": 5.0
		})
		wt.scale = Vector3(2.15, 2.15, 2.15)

	var land_tramp_defs := [
		{"name": "Trampoline_To_PlatformA", "pos": Vector3(8.0, 0.0, 10.0), "vel": 16.5, "super": 22.5},
		{"name": "Trampoline_To_PlatformB", "pos": Vector3(8.0, 2.5, 3.5), "vel": 17.5, "super": 23.5},
		{"name": "Trampoline_SkyChallenge", "pos": Vector3(-8.0, 0.0, 4.0), "vel": 17.0, "super": 24.5},
		{"name": "Trampoline_To_Tower", "pos": Vector3(-2.0, 0.0, 3.5), "vel": 18.5, "super": 25.0},
	]
	for def in land_tramp_defs:
		var lt := _instantiate_node(tramp_group, tramp_scene, def["name"], def["pos"], {
			"bounce_velocity": def["vel"],
			"super_bounce_velocity": def["super"],
			"water_bob_enabled": true,
			"water_bob_height": 0.03,
			"water_bob_speed": 1.6,
			"water_bob_tilt_deg": 3.0
		})
		lt.scale = Vector3(1.55, 1.55, 1.55)


func _add_interactive_objects(root: Node3D) -> void:
	var objects_group := Node3D.new()
	objects_group.name = "Objects"
	root.add_child(objects_group)
	objects_group.owner = root

	# 1. Mara (Questgeberin NPC)
	var npc_scene: PackedScene = load("res://scenes/objects/obj_npc_grantelbart.tscn")
	if npc_scene:
		var npc: Node3D = npc_scene.instantiate()
		npc.name = "Mara"
		npc.position = Vector3(4.0, 0.0, 11.0)
		npc.rotation_degrees = Vector3(0, -145, 0)
		npc.set("object_id", "npc_mara")
		npc.set("npc_id", "mara")
		npc.set("display_name", "Mara")
		objects_group.add_child(npc)
		npc.owner = root

	# 2. Schatzkisten
	var chest_scene: PackedScene = load("res://scenes/objects/obj_chest.tscn")
	if chest_scene:
		var chest: Node3D = chest_scene.instantiate()
		chest.name = "Chest_PlatformB"
		chest.position = Vector3(12.0, 5.0, -5.5)
		chest.rotation_degrees = Vector3(0, 180, 0)
		chest.set("object_id", "chest_platform_b")
		chest.set("item_id", "coin")
		chest.set("item_count", 3)
		chest.set("open_toast_message", "Found 3 coins in the chest!")
		objects_group.add_child(chest)
		chest.owner = root

		var island_chest: Node3D = chest_scene.instantiate()
		island_chest.name = "Chest_HarborIsland"
		island_chest.position = Vector3(16.0, 3.0, 46.5)
		island_chest.rotation_degrees = Vector3(0, 180, 0)
		island_chest.set("object_id", "chest_harbor_island")
		island_chest.set("item_id", "coin")
		island_chest.set("item_count", 5)
		island_chest.set("open_toast_message", "Treasure Island Discovery! 5 coins collected!")
		objects_group.add_child(island_chest)
		island_chest.owner = root

		var puzzle_chest: Node3D = chest_scene.instantiate()
		puzzle_chest.name = "Chest_PuzzleRoom"
		puzzle_chest.position = Vector3(-20.0, 0.0, -0.5)
		puzzle_chest.rotation_degrees = Vector3(0, 0, 0)
		puzzle_chest.set("object_id", "chest_puzzle_room")
		puzzle_chest.set("item_id", "coin")
		puzzle_chest.set("item_count", 3)
		puzzle_chest.set("open_toast_message", "Puzzle Chamber solved! Found 3 coins!")
		objects_group.add_child(puzzle_chest)
		puzzle_chest.owner = root

	# 3. Interaktives Rätsel in der West-Kammer
	var door_scene: PackedScene = load("res://scenes/objects/obj_door.tscn")
	var lever_scene: PackedScene = load("res://scenes/objects/obj_lever.tscn")
	if door_scene and lever_scene:
		var door: Node3D = door_scene.instantiate()
		door.name = "PuzzleDoor"
		door.position = Vector3(-20.0, 0.0, 2.0)
		door.set("object_id", "puzzle_door")
		objects_group.add_child(door)
		door.owner = root

		var lever: Node3D = lever_scene.instantiate()
		lever.name = "PuzzleLever"
		lever.position = Vector3(-23.5, 0.0, 4.5)
		lever.rotation_degrees = Vector3(0, 90, 0)
		lever.set("object_id", "puzzle_lever")
		lever.set("target_objects", [NodePath("../PuzzleDoor")])
		lever.set("target_method", "toggle")
		lever.set("prompt_text", "Pull Lever")
		objects_group.add_child(lever)
		lever.owner = root

	# 4. Kiste schieben & Druckplatte vor der West-Rätselkammer
	var pushable_scene: PackedScene = load("res://scenes/objects/obj_pushable.tscn")
	var plate_scene: PackedScene = load("res://scenes/objects/obj_pressure_plate.tscn")
	if pushable_scene and plate_scene:
		var plate: Node3D = plate_scene.instantiate()
		plate.name = "PressurePlate"
		plate.position = Vector3(-17.0, 0.02, 5.5)
		plate.set("object_id", "puzzle_plate")
		objects_group.add_child(plate)
		plate.owner = root

		var box: Node3D = pushable_scene.instantiate()
		box.name = "PushableBlock"
		box.position = Vector3(-17.0, 0.0, 9.0)
		box.set("object_id", "pushable_block_1")
		objects_group.add_child(box)
		box.owner = root

	# 5. Wegweiser & Info-Schilder
	var sign_scene: PackedScene = load("res://scenes/objects/obj_sign.tscn")
	if sign_scene:
		_instantiate_sign(objects_group, sign_scene, "Sign_Welcome", Vector3(-2.5, 0.0, 13.0), Vector3(0, 15, 0),
			"Welcome to the Harbor!", [
				"Welcome to the extended Jalura Framework demo level!",
				"Right in front of you on the pedestals you will find your equipment: Rail Shoes, Glider, and Flashlight.",
				"To the south lies the large harbor basin with the pier, your fishing boat, and water trampolines!"
			])

		_instantiate_sign(objects_group, sign_scene, "Sign_Equipment", Vector3(-5.2, 0.0, 6.5), Vector3(0, 35, 0),
			"Equipment & Tools", [
				"Collect the 3 equipment items from the pedestals:",
				"• Rail Shoes: Allow grinding on rails (TestRail).",
				"• Glider: Hold [Space] in mid-air to glide.",
				"• Flashlight: Press [F] to toggle. View all tools with [U] or [I] under '⚙️ Equipment'!"
			])

		_instantiate_sign(objects_group, sign_scene, "Sign_Trampoline", Vector3(5.5, 0.0, 15.2), Vector3(0, 160, 0),
			"Water Trampoline Parkour", [
				"The water trampolines float and bob gently on the waves!",
				"Jump from trampoline to trampoline across the water to reach the treasure island in the southeast.",
				"Tip: Press or hold [Space] as you land for an extra high Super-Bounce!"
			])

		_instantiate_sign(objects_group, sign_scene, "Sign_Boat", Vector3(-6.8, 0.0, 15.5), Vector3(0, 145, 0),
			"Harbor Pier & Ship Cabin", [
				"Here at the stone pier, your fishing boat lies anchored.",
				"Walk across the pier onto the deck to the cabin door (or press [E]) to enter the interior cabin!"
			])

		_instantiate_sign(objects_group, sign_scene, "Sign_Tower", Vector3(-4.5, 6.6, -2.5), Vector3(0, 45, 0),
			"Watchtower & Grind Rail", [
				"The grind rail starts up here!",
				"Once you have equipped the Rail Shoes, jump or run onto the rail tube to grind down to the harbor."
			])


func _instantiate_sign(parent: Node3D, scene: PackedScene, node_name: String, pos: Vector3, rot: Vector3, title: String, lines: Array[String]) -> void:
	var sign_inst: Node3D = scene.instantiate()
	sign_inst.name = node_name
	sign_inst.position = pos
	sign_inst.rotation_degrees = rot
	sign_inst.set("title", title)
	sign_inst.set("lines", lines)
	sign_inst.set("prompt_text", "Read")
	parent.add_child(sign_inst)
	sign_inst.owner = parent.owner


func _add_pickups(root: Node3D) -> void:
	var group := root.get_node_or_null("Objects") as Node3D
	if not group:
		group = root

	var pickup_scene: PackedScene = load("res://scenes/objects/pickable_item.tscn")
	if not pickup_scene:
		return

	# Münze auf dem Turm
	_add_pickup_item(group, pickup_scene, "Coin_Tower", Vector3(-2.0, 6.8, -4.0), "coin", 1)

	# Münze im Himmel über Trampolin
	_add_pickup_item(group, pickup_scene, "Coin_SkyChallenge", Vector3(-8.0, 8.5, 4.0), "coin", 1)

	# Münzen entlang der Grind-Schiene
	_add_pickup_item(group, pickup_scene, "Coin_Rail_1", Vector3(4.0, 5.8, -2.8), "coin", 1)
	_add_pickup_item(group, pickup_scene, "Coin_Rail_2", Vector3(8.8, 4.8, -0.2), "coin", 1)
	_add_pickup_item(group, pickup_scene, "Coin_Rail_3", Vector3(12.6, 3.6, 4.5), "coin", 1)
	_add_pickup_item(group, pickup_scene, "Coin_Rail_4", Vector3(13.0, 2.0, 10.0), "coin", 1)

	# Münzen über den Wasser-Trampolinen
	_add_pickup_item(group, pickup_scene, "Coin_Water_1", Vector3(4.0, 3.8, 20.5), "coin", 1)
	_add_pickup_item(group, pickup_scene, "Coin_Water_2", Vector3(11.5, 4.2, 26.5), "coin", 1)
	_add_pickup_item(group, pickup_scene, "Coin_Water_3", Vector3(18.0, 4.5, 34.0), "coin", 1)
	_add_pickup_item(group, pickup_scene, "Coin_Water_4", Vector3(10.5, 4.2, 41.5), "coin", 1)

	# Ausrüstungs-Items auf den Podesten
	_add_pickup_item(group, pickup_scene, "RailShoePickup", Vector3(-3.2, 0.45, 6.5), "rail_shoe", 1)
	_add_pickup_item(group, pickup_scene, "GliderPickup", Vector3(0.0, 0.45, 6.5), "glider", 1)
	_add_pickup_item(group, pickup_scene, "FlashlightPickup", Vector3(3.2, 0.45, 6.5), "flashlight", 1)

	# Laterne & Batterie
	_add_pickup_item(group, pickup_scene, "LampPickup", Vector3(-14.0, 0.35, 6.5), "lamp", 1)
	_add_pickup_item(group, pickup_scene, "BatteryPickup", Vector3(3.2, 0.35, 4.5), "battery", 2)


func _add_pickup_item(parent: Node3D, scene: PackedScene, node_name: String, pos: Vector3, item_id: String, count: int) -> void:
	var item: Node3D = scene.instantiate()
	item.name = node_name
	item.position = pos
	item.set("item_id", item_id)
	item.set("item_count", count)
	item.set("unique_id", "demo_%s" % node_name.to_lower())
	parent.add_child(item)
	item.owner = parent.owner


func _instantiate_node(parent: Node3D, scene: PackedScene, node_name: String, pos: Vector3, props: Dictionary = {}) -> Node3D:
	var node: Node3D = scene.instantiate()
	node.name = node_name
	node.position = pos
	for k in props:
		if k in node:
			node.set(k, props[k])
	parent.add_child(node)
	node.owner = parent if parent.owner == null else parent.owner
	return node


func _add_spawns(root: Node3D) -> void:
	var spawns := Node3D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	spawns.owner = root

	var spawn_script: Script = load("res://scripts/world/spawn_point.gd")

	var sp_default := Marker3D.new()
	sp_default.name = "Spawn_Default"
	sp_default.position = Vector3(0.0, 0.6, 12.0)
	sp_default.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	sp_default.set_script(spawn_script)
	sp_default.set("spawn_id", &"default")
	sp_default.set("is_default", true)
	spawns.add_child(sp_default)
	sp_default.owner = root

	# Rückkehr-Spawn aus der Kabine: Direkt am festen Ufer/Kai vor dem Steg (Z = 14.5), mit Blick nach Norden!
	var sp_cabin := Marker3D.new()
	sp_cabin.name = "Spawn_FromBootskabine"
	sp_cabin.position = Vector3(-10.0, 0.5, 14.5)
	sp_cabin.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	sp_cabin.set_script(spawn_script)
	sp_cabin.set("spawn_id", &"von_bootskabine")
	sp_cabin.set("is_default", false)
	spawns.add_child(sp_cabin)
	sp_cabin.owner = root


func _add_player_and_ui(root: Node3D) -> void:
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	if player_scene:
		var player: Node3D = player_scene.instantiate()
		player.name = "Player"
		player.position = Vector3(0.0, 0.6, 12.0)
		player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		player.set("item_glider", load("res://resources/items/glider.tres"))
		player.set("item_rail_shoe", load("res://resources/items/rail_shoe.tres"))
		player.set("item_flashlight", load("res://resources/items/flashlight.tres"))
		player.set("rail_grind_unlocked", false)
		player.set("glider_unlocked", false)
		root.add_child(player)
		player.owner = root

	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	if hud_scene:
		var hud: Node = hud_scene.instantiate()
		hud.name = "HUD"
		root.add_child(hud)
		hud.owner = root
