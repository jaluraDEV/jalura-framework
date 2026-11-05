class_name PlayerEquipment
extends Node

## PlayerEquipment
## Modular equipment controller for Barnaby.
## Handles Flashlight, Glider, and Rail Shoes attachments, 3D models,
## visibility states, and inventory synchronization.

var player: CharacterBody3D
var visual: Node3D
var skel: Skeleton3D
var animator: Node

# ==============================================================================
# EXPORT GROUPS
# ==============================================================================

@export_group("Items (ItemData)")
@export var item_flashlight: ItemData = preload("res://resources/items/flashlight.tres")
@export var item_glider: ItemData = preload("res://resources/items/glider.tres")
@export var item_rail_shoe: ItemData = preload("res://resources/items/rail_shoe.tres")

@export_group("Flashlight")
@export var flashlight_enabled: bool = false
@export var flashlight_energy: float = 4.2
@export var flashlight_range: float = 24.0
@export var flashlight_angle: float = 32.0
@export var flashlight_color: Color = Color(1.0, 0.98, 0.92)

@export_group("Glider")
@export var glider_offset: Vector3 = Vector3(0.0, 1.88, -0.36)
@export var glider_scale: Vector3 = Vector3(1.15, 1.15, 1.15)

@export_group("Rail Shoes")
@export var rail_shoe_scale: Vector3 = Vector3(0.11, 0.11, 0.11)
@export var rail_shoe_left_offset: Vector3 = Vector3(0.0, 0.085, 0.022)
@export var rail_shoe_left_rotation: Vector3 = Vector3(0.0, 90.0, 126.0)
@export var rail_shoe_right_offset: Vector3 = Vector3(0.0238, 0.0859, 0.0054)
@export var rail_shoe_right_rotation: Vector3 = Vector3(0.0, 160.0, 126.0)
@export var rail_shoe_offset: Vector3 = Vector3(0.0, 0.085, 0.022)     ## Backward compatibility alias for left shoe offset
@export var rail_shoe_rotation: Vector3 = Vector3(0.0, 90.0, 126.0)    ## Backward compatibility alias for left shoe rotation

# ==============================================================================
# RUNTIME ATTACHMENTS & MODELS
# ==============================================================================

var hand_bone_attachment: BoneAttachment3D
var hand_lamp_model: Node3D
var hand_flashlight: SpotLight3D
var hand_lens_glow: MeshInstance3D

var glider_model: Node3D

var left_foot_attachment: BoneAttachment3D
var left_shoe_model: Node3D
var right_foot_attachment: BoneAttachment3D
var right_shoe_model: Node3D

# ==============================================================================
# SETUP & INITIALIZATION
# ==============================================================================

func setup(p_player: CharacterBody3D, p_visual: Node3D, p_animator: Node) -> void:
	player = p_player
	visual = p_visual
	animator = p_animator

	if player:
		skel = player.find_child("Skeleton3D", true, false) as Skeleton3D

	setup_hand_flashlight()
	setup_glider_model()
	setup_rail_shoes()
	setup_grind_sparks()

	# Connect to InventoryManager signal
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_updated"):
		if not inv.inventory_updated.is_connected(on_inventory_updated):
			inv.inventory_updated.connect(on_inventory_updated)

# ==============================================================================
# ITEM CHECK HELPERS
# ==============================================================================

func has_item(item: ItemData, fallback_id: String) -> bool:
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return false
	var target_id := item.id if item and item.id != "" else fallback_id
	return inv.has_item(target_id)

func has_glider() -> bool:
	if player and player.get("glider_unlocked") == true:
		return true
	return has_item(item_glider, "glider")

func has_rail_shoes() -> bool:
	if player and player.get("rail_grind_unlocked") == true:
		return true
	return has_item(item_rail_shoe, "rail_shoe")

func has_flashlight() -> bool:
	return has_item(item_flashlight, "flashlight") or has_item(null, "lamp")

func _get_fade_alpha() -> float:
	if player and player.has_method("_get_fade_alpha"):
		return player._get_fade_alpha()
	return 1.0

# ==============================================================================
# FLASHLIGHT
# ==============================================================================

func setup_hand_flashlight() -> void:
	if not skel:
		return

	var hand_idx := skel.find_bone("mixamorig_RightHand")
	if hand_idx < 0:
		return

	# Create BoneAttachment3D for mixamorig_RightHand
	hand_bone_attachment = BoneAttachment3D.new()
	hand_bone_attachment.name = "RightHandAttachment"
	hand_bone_attachment.bone_name = "mixamorig_RightHand"
	hand_bone_attachment.bone_idx = hand_idx
	skel.add_child(hand_bone_attachment)

	# Instantiate lamp model from ItemData or fallbacks
	var lamp_scene: PackedScene = null
	if item_flashlight and item_flashlight.model_scene:
		lamp_scene = item_flashlight.model_scene
	if not lamp_scene:
		lamp_scene = load("res://assets/items/alte_lampe/alte_lampe.glb") as PackedScene
	if not lamp_scene:
		return

	hand_lamp_model = lamp_scene.instantiate() as Node3D
	hand_lamp_model.name = "old_flashlight"

	var bone_scale: float = skel.get_bone_global_pose(hand_idx).basis.get_scale().x
	if bone_scale < 0.05:
		hand_lamp_model.scale = Vector3(24.0, 24.0, 24.0)
		hand_lamp_model.position = Vector3(-8.59, 9.44, -1.92)
		hand_lamp_model.quaternion = Quaternion(0.712672, 0.472173, 0.488718, -0.174086)
	else:
		hand_lamp_model.scale = Vector3(0.24, 0.24, 0.24)
		hand_lamp_model.position = Vector3(-0.08, 0.09, -0.02)
		hand_lamp_model.quaternion = Quaternion(0.712672, 0.472173, 0.488718, -0.174086)

	hand_lamp_model.visible = false
	hand_bone_attachment.add_child(hand_lamp_model)

	# Create SpotLight3D on front lens (+X in alte_lampe space)
	hand_flashlight = SpotLight3D.new()
	hand_flashlight.name = "Flashlight"
	hand_flashlight.position = Vector3(0.505, -0.113, 0.011)
	hand_flashlight.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	hand_flashlight.light_color = flashlight_color
	hand_flashlight.light_energy = flashlight_energy
	hand_flashlight.spot_range = flashlight_range
	hand_flashlight.spot_angle = flashlight_angle
	hand_flashlight.spot_angle_attenuation = 1.3
	hand_flashlight.shadow_enabled = true
	hand_flashlight.light_bake_mode = Light3D.BAKE_DISABLED
	hand_flashlight.visible = false
	hand_lamp_model.add_child(hand_flashlight)

	# Create glowing lens mesh
	hand_lens_glow = MeshInstance3D.new()
	hand_lens_glow.name = "LensGlow"
	hand_lens_glow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.13
	cyl.bottom_radius = 0.13
	cyl.height = 0.02
	hand_lens_glow.mesh = cyl
	hand_lens_glow.position = Vector3(0.505, -0.113, 0.011)
	hand_lens_glow.rotation_degrees = Vector3(0.0, 0.0, 90.0)

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = flashlight_color
	glow_mat.emission_enabled = true
	glow_mat.emission = flashlight_color
	glow_mat.emission_energy_multiplier = 4.0
	hand_lens_glow.material_override = glow_mat
	hand_lens_glow.visible = false
	hand_lamp_model.add_child(hand_lens_glow)

	apply_flashlight_state()

func toggle_flashlight() -> void:
	var has_fl := has_flashlight()
	if not flashlight_enabled:
		if not has_fl:
			var hud = null
			if player and player.is_inside_tree():
				hud = player.get_tree().root.find_child("HUD", true, false)
			if hud and hud.has_method("show_toast"):
				hud.show_toast("NOTICE", "Flashlight", "You do not have a flashlight yet!")
			return
		flashlight_enabled = true
	else:
		flashlight_enabled = false

	if player:
		player.set("flashlight_enabled", flashlight_enabled)

	apply_flashlight_state()

func apply_flashlight_state() -> void:
	var has_fl := has_flashlight()
	var is_active := flashlight_enabled and has_fl
	var fade_alpha := _get_fade_alpha()

	if hand_flashlight:
		hand_flashlight.visible = is_active
	if hand_lens_glow:
		hand_lens_glow.visible = is_active and (fade_alpha > 0.01)

	var target_blend := 1.0 if is_active else 0.0

	if is_active and hand_lamp_model:
		hand_lamp_model.visible = (fade_alpha > 0.01)

	if animator and animator.has_method("tween_arm_blend"):
		animator.tween_arm_blend(target_blend, 0.2, func():
			if not is_active and hand_lamp_model:
				hand_lamp_model.visible = false
		)
	else:
		if not is_active and hand_lamp_model:
			hand_lamp_model.visible = false

# ==============================================================================
# GLIDER
# ==============================================================================

func setup_glider_model() -> void:
	if not visual:
		return

	var glider_scene: PackedScene = null
	if item_glider and item_glider.model_scene:
		glider_scene = item_glider.model_scene
	if not glider_scene:
		glider_scene = load("res://assets/chars/extras/glider.glb") as PackedScene
	if not glider_scene:
		return

	glider_model = glider_scene.instantiate() as Node3D
	glider_model.name = "GliderModel"
	glider_model.position = glider_offset
	glider_model.scale = glider_scale
	glider_model.visible = false
	visual.add_child(glider_model)

func set_glider_visible(is_visible: bool) -> void:
	if glider_model:
		glider_model.visible = is_visible

# ==============================================================================
# RAIL SHOES
# ==============================================================================

func setup_rail_shoes() -> void:
	if not skel:
		return

	var lf_idx := skel.find_bone("mixamorig_LeftFoot")
	var rf_idx := skel.find_bone("mixamorig_RightFoot")
	if lf_idx < 0 or rf_idx < 0:
		return

	var shoe_scene: PackedScene = null
	if item_rail_shoe and item_rail_shoe.model_scene:
		shoe_scene = item_rail_shoe.model_scene
	if not shoe_scene:
		shoe_scene = load("res://assets/chars/extras/rail_shoe.glb") as PackedScene
	if not shoe_scene:
		return

	# Left foot attachment
	left_foot_attachment = BoneAttachment3D.new()
	left_foot_attachment.name = "LeftFootShoeAttachment"
	left_foot_attachment.bone_name = "mixamorig_LeftFoot"
	left_foot_attachment.bone_idx = lf_idx
	skel.add_child(left_foot_attachment)

	left_shoe_model = shoe_scene.instantiate() as Node3D
	left_shoe_model.name = "LeftRailShoe"
	left_shoe_model.position = rail_shoe_left_offset
	left_shoe_model.rotation_degrees = rail_shoe_left_rotation
	left_shoe_model.scale = rail_shoe_scale
	left_shoe_model.visible = false
	left_foot_attachment.add_child(left_shoe_model)

	# Right foot attachment
	right_foot_attachment = BoneAttachment3D.new()
	right_foot_attachment.name = "RightFootShoeAttachment"
	right_foot_attachment.bone_name = "mixamorig_RightFoot"
	right_foot_attachment.bone_idx = rf_idx
	skel.add_child(right_foot_attachment)

	right_shoe_model = shoe_scene.instantiate() as Node3D
	right_shoe_model.name = "RightRailShoe"
	right_shoe_model.position = rail_shoe_right_offset
	right_shoe_model.rotation_degrees = rail_shoe_right_rotation
	right_shoe_model.scale = rail_shoe_scale
	right_shoe_model.visible = false
	right_foot_attachment.add_child(right_shoe_model)

	apply_shoe_state()

func apply_shoe_state() -> void:
	var unlocked := has_rail_shoes()
	var fade_alpha := _get_fade_alpha()
	if left_shoe_model:
		left_shoe_model.visible = unlocked and (fade_alpha > 0.01)
	if right_shoe_model:
		right_shoe_model.visible = unlocked and (fade_alpha > 0.01)

	# Dynamically sync procedural FootIK ground offset for flush sole contact
	if player and player.get("foot_ik") != null:
		var ik = player.get("foot_ik")
		if ik.has_method("set_shoes_equipped"):
			ik.set_shoes_equipped(unlocked)
		elif "foot_offset" in ik:
			ik.foot_offset = 0.195 if unlocked else 0.05

# ==============================================================================
# GRIND SPARKS
# ==============================================================================

func setup_grind_sparks() -> void:
	if player and player.get("effects") != null and player.effects.has_method("setup_grind_sparks"):
		player.effects.setup_grind_sparks(player, left_shoe_model, right_shoe_model)

# ==============================================================================
# INVENTORY SYNC
# ==============================================================================

func on_inventory_updated() -> void:
	var has_fl := has_flashlight()
	if not has_fl and flashlight_enabled:
		flashlight_enabled = false
		if player:
			player.set("flashlight_enabled", false)
		apply_flashlight_state()

	if player:
		# If gliding but lost glider
		if player.current_state == 13 and not has_glider(): # State.GLIDE = 13
			if player.has_method("_exit_glide"):
				player._exit_glide()

		apply_shoe_state()

		# If grinding but lost rail shoes
		if player.current_state == 14 and not has_rail_shoes(): # State.RAIL_GRIND = 14
			if player.has_method("_exit_rail_grind"):
				player._exit_rail_grind()
