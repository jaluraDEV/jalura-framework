class_name PlayerEffects
extends Node3D

## PlayerEffects
## Modular VFX and procedural game feel manager for Barnaby.
## Handles cartoon dust particles (jump, land, skid, dash, footstep), rail grinding sparks,
## and harmonic spring squash-and-stretch mesh deformation.

@export var particles_enabled: bool = true
@export var squash_stretch_enabled: bool = true

const SQUASH_SPRING_K: float = 340.0
const SQUASH_DAMPING: float = 20.0

var player: CharacterBody3D
var visual: Node3D

# Squash & Stretch state
var _squash_stretch: Vector3 = Vector3.ONE
var _squash_velocity: Vector3 = Vector3.ZERO

# Cartoon Dust Particles
var _dust_jump: CPUParticles3D
var _dust_land: CPUParticles3D
var _dust_skid: CPUParticles3D
var _dust_dash: CPUParticles3D
var _dust_foot: CPUParticles3D

# Rail Grind Sparks
var _sparks_l: CPUParticles3D = null
var _sparks_r: CPUParticles3D = null

func setup(p_player: CharacterBody3D, p_visual: Node3D) -> void:
	player = p_player
	visual = p_visual
	_setup_dust_particles()
	_setup_grind_sparks()

func _setup_dust_particles() -> void:
	if not particles_enabled:
		return

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.12
	sphere_mesh.height = 0.24
	sphere_mesh.radial_segments = 6
	sphere_mesh.rings = 4

	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.albedo_color = Color(0.96, 0.93, 0.86, 0.75)

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.35))
	scale_curve.add_point(Vector2(0.25, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))

	# 1. Jump Dust Ring
	_dust_jump = CPUParticles3D.new()
	_dust_jump.name = "DustJump"
	_dust_jump.emitting = false
	_dust_jump.one_shot = true
	_dust_jump.explosiveness = 0.92
	_dust_jump.lifetime = 0.38
	_dust_jump.amount = 10
	_dust_jump.mesh = sphere_mesh
	_dust_jump.material_override = dust_mat
	_dust_jump.direction = Vector3(0, 0.35, 0)
	_dust_jump.spread = 180.0
	_dust_jump.gravity = Vector3(0, 0.4, 0)
	_dust_jump.initial_velocity_min = 1.4
	_dust_jump.initial_velocity_max = 2.6
	_dust_jump.scale_amount_curve = scale_curve
	_dust_jump.position = Vector3(0, 0.05, 0)
	add_child(_dust_jump)

	# 2. Landing Dust Burst
	_dust_land = CPUParticles3D.new()
	_dust_land.name = "DustLand"
	_dust_land.emitting = false
	_dust_land.one_shot = true
	_dust_land.explosiveness = 0.95
	_dust_land.lifetime = 0.42
	_dust_land.amount = 14
	_dust_land.mesh = sphere_mesh
	_dust_land.material_override = dust_mat
	_dust_land.direction = Vector3(0, 0.25, 0)
	_dust_land.spread = 180.0
	_dust_land.gravity = Vector3(0, 0.5, 0)
	_dust_land.initial_velocity_min = 2.0
	_dust_land.initial_velocity_max = 3.6
	_dust_land.scale_amount_curve = scale_curve
	_dust_land.position = Vector3(0, 0.05, 0)
	add_child(_dust_land)

	# 3. Skid Dust Cloud
	_dust_skid = CPUParticles3D.new()
	_dust_skid.name = "DustSkid"
	_dust_skid.emitting = false
	_dust_skid.one_shot = false
	_dust_skid.lifetime = 0.30
	_dust_skid.amount = 8
	_dust_skid.mesh = sphere_mesh
	_dust_skid.material_override = dust_mat
	_dust_skid.direction = Vector3(0, 0.8, -0.6)
	_dust_skid.spread = 45.0
	_dust_skid.gravity = Vector3(0, 0.6, 0)
	_dust_skid.initial_velocity_min = 0.8
	_dust_skid.initial_velocity_max = 1.8
	_dust_skid.scale_amount_curve = scale_curve
	_dust_skid.position = Vector3(0, 0.05, 0)
	add_child(_dust_skid)

	# 4. Dash Trail Dust
	_dust_dash = CPUParticles3D.new()
	_dust_dash.name = "DustDash"
	_dust_dash.emitting = false
	_dust_dash.one_shot = true
	_dust_dash.explosiveness = 0.88
	_dust_dash.lifetime = 0.35
	_dust_dash.amount = 12
	_dust_dash.mesh = sphere_mesh
	_dust_dash.material_override = dust_mat
	_dust_dash.direction = Vector3(0, 0.4, 1)
	_dust_dash.spread = 35.0
	_dust_dash.gravity = Vector3(0, 0.3, 0)
	_dust_dash.initial_velocity_min = 1.5
	_dust_dash.initial_velocity_max = 3.2
	_dust_dash.scale_amount_curve = scale_curve
	_dust_dash.position = Vector3(0, 0.15, 0)
	add_child(_dust_dash)

	# 5. Footstep Puff
	_dust_foot = CPUParticles3D.new()
	_dust_foot.name = "DustFoot"
	_dust_foot.emitting = false
	_dust_foot.one_shot = true
	_dust_foot.explosiveness = 0.85
	_dust_foot.lifetime = 0.28
	_dust_foot.amount = 3
	_dust_foot.mesh = sphere_mesh
	_dust_foot.material_override = dust_mat
	_dust_foot.direction = Vector3(0, 0.5, 0)
	_dust_foot.spread = 80.0
	_dust_foot.gravity = Vector3(0, 0.3, 0)
	_dust_foot.initial_velocity_min = 0.4
	_dust_foot.initial_velocity_max = 0.9
	_dust_foot.scale_amount_curve = scale_curve
	_dust_foot.position = Vector3(0, 0.05, 0)
	add_child(_dust_foot)

func _setup_grind_sparks() -> void:
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.03
	spark_mesh.height = 0.06
	spark_mesh.radial_segments = 4
	spark_mesh.rings = 2

	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.85, 0.25, 1.0) # Bright golden spark

	for i in [0, 1]:
		var p := CPUParticles3D.new()
		p.name = "GrindSparks_L" if i == 0 else "GrindSparks_R"
		p.emitting = false
		p.amount = 16
		p.lifetime = 0.22
		p.mesh = spark_mesh
		p.material_override = spark_mat
		p.direction = Vector3(0.0, 0.8, -1.0)
		p.spread = 35.0
		p.initial_velocity_min = 2.5
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0.0, -9.8, 0.0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		add_child(p)
		if i == 0:
			_sparks_l = p
		else:
			_sparks_r = p

func emit_jump_dust() -> void:
	if particles_enabled and _dust_jump:
		_dust_jump.restart()
		_dust_jump.emitting = true

func emit_dash_dust() -> void:
	if particles_enabled and _dust_dash:
		_dust_dash.restart()
		_dust_dash.emitting = true

func emit_skid_dust() -> void:
	if particles_enabled and _dust_skid and not _dust_skid.emitting:
		_dust_skid.emitting = true

func stop_skid_dust() -> void:
	if _dust_skid:
		_dust_skid.emitting = false

func emit_foot_dust() -> void:
	if particles_enabled and _dust_foot:
		_dust_foot.restart()
		_dust_foot.emitting = true

func emit_landing_dust() -> void:
	if particles_enabled and _dust_land:
		_dust_land.restart()
		_dust_land.emitting = true

func update_grind_sparks(left_pos: Vector3, right_pos: Vector3, fwd: Vector3) -> void:
	if not particles_enabled:
		stop_grind_sparks()
		return
	if _sparks_l:
		_sparks_l.global_position = left_pos
		_sparks_l.direction = -fwd * 0.8 + Vector3.UP * 0.35
		_sparks_l.emitting = true
	if _sparks_r:
		_sparks_r.global_position = right_pos
		_sparks_r.direction = -fwd * 0.8 + Vector3.UP * 0.35
		_sparks_r.emitting = true

func stop_grind_sparks() -> void:
	if _sparks_l:
		_sparks_l.emitting = false
	if _sparks_r:
		_sparks_r.emitting = false

# --- Procedural Harmonic Spring Squash & Stretch ---

func apply_landing_impact(fall_velocity: float) -> void:
	if squash_stretch_enabled:
		var impact := clampf(absf(fall_velocity) / 20.0, 0.12, 0.36)
		_squash_stretch = Vector3(1.0 + impact * 0.75, 1.0 - impact, 1.0 + impact * 0.75)
		_squash_velocity = Vector3.ZERO

func apply_jump_squash() -> void:
	if squash_stretch_enabled:
		_squash_stretch = Vector3(0.86, 1.25, 0.86) # Takeoff stretch!
		_squash_velocity = Vector3(-4.0, 7.5, -4.0)

func apply_bounce_squash(is_super: bool) -> void:
	if squash_stretch_enabled:
		var stretch_y: float = 1.55 if is_super else 1.35
		var squash_xz: float = 0.72 if is_super else 0.82
		_squash_stretch = Vector3(squash_xz, stretch_y, squash_xz)
		_squash_velocity = Vector3(-5.0, 10.0, -5.0)

func apply_dash_squash() -> void:
	if squash_stretch_enabled:
		_squash_stretch = Vector3(0.82, 0.82, 1.35) # Rocket forward stretch!
		_squash_velocity = Vector3(-3.0, -3.0, 6.0)

func apply_spin_squash() -> void:
	if squash_stretch_enabled:
		_squash_stretch = Vector3(1.18, 0.86, 1.18) # Pirouette spread!
		_squash_velocity = Vector3(4.0, -3.0, 4.0)

func apply_long_jump_squash() -> void:
	if squash_stretch_enabled:
		_squash_stretch = Vector3(0.85, 0.95, 1.25)
		_squash_velocity = Vector3(-3.0, 0.0, 6.0)

func apply_backflip_squash() -> void:
	if squash_stretch_enabled:
		_squash_stretch = Vector3(0.86, 1.32, 0.86)
		_squash_velocity = Vector3(-4.0, 8.0, -4.0)

func apply_rail_grind_squash() -> void:
	if squash_stretch_enabled:
		_squash_stretch = Vector3(1.12, 0.90, 1.12)
		_squash_velocity = Vector3(3.0, -2.5, 3.0)

func apply_glider_squash() -> void:
	if squash_stretch_enabled:
		_squash_stretch = Vector3(1.12, 0.90, 1.12)
		_squash_velocity = Vector3(3.0, -2.5, 3.0)

func update_squash_stretch(delta: float) -> void:
	if not squash_stretch_enabled or not visual:
		return
	var displacement := _squash_stretch - Vector3.ONE
	var spring_force := -SQUASH_SPRING_K * displacement - SQUASH_DAMPING * _squash_velocity
	_squash_velocity += spring_force * delta
	_squash_stretch += _squash_velocity * delta
	visual.scale = _squash_stretch

func reset_squash() -> void:
	_squash_stretch = Vector3.ONE
	_squash_velocity = Vector3.ZERO
	if visual:
		visual.scale = Vector3.ONE
