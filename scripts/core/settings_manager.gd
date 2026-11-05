extends Node

signal settings_changed(setting_name: String)

const CONFIG_PATH: String = "user://settings.cfg"

# Audio
var master_volume: float = 1.0
var music_volume: float = 0.75
var sfx_volume: float = 0.85

# Video / Window
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720)
]
var window_mode: int = 0 # 0: Fenster, 1: Randlos Vollbild, 2: Vollbild
var resolution_idx: int = 0
var vsync_enabled: bool = true
var fps_limit_enabled: bool = false
var max_fps: int = 60
var show_fps: bool = false

# Graphics Details
var shadow_quality: int = 2 # 0: Aus, 1: Mittel, 2: Hoch
var volumetric_fog_enabled: bool = true
var glow_enabled: bool = true
var dof_enabled: bool = true

# Global Mesh LOD
# 0: Niedrig (3.0), 1: Mittel (1.5), 2: Hoch (1.0 = Standard), 3: Ultra (0.0 = kein LOD Wechsel)
const LOD_THRESHOLDS: Array[float] = [3.0, 1.5, 1.0, 0.0]
var lod_quality: int = 2

# Clutter / Deko Visibility Range Culling
# 0: Nah (35m), 1: Mittel (55m), 2: Weit (85m), 3: Maximal (0.0 = kein Culling)
const CLUTTER_DISTANCES: Array[float] = [35.0, 55.0, 85.0, 0.0]
var clutter_culling_idx: int = 1

# Retro 3D Pixel Art Filter
# 0: Aus (Nativ HD), 1: Sanft, 2: Klassisch (360p), 3: Nostalgie (PS1 / 240p)
var pixel_art_mode: int = 0

# Anti-Aliasing (Kantenglättung)
# 0: Aus, 1: FXAA, 2: MSAA 2x, 3: MSAA 4x, 4: TAA, 5: Ultra (TAA + FXAA + MSAA 4x)
var anti_aliasing_mode: int = 3
var scaling_3d_scale: float = 1.0

# Graphics Presets
# 0: Kartoffel (Potato), 1: Niedrig, 2: Mittel, 3: Hoch, 4: Ultra, 5: Benutzerdefiniert
var graphics_preset: int = 3

const PRESET_NAMES: Array[String] = [
	"🥔 Potato",
	"Low",
	"Medium",
	"High",
	"Ultra",
	"Custom"
]

const AA_NAMES: Array[String] = [
	"Off (No AA)",
	"FXAA (Fast)",
	"MSAA 2x (Balanced)",
	"MSAA 4x (Sharp)",
	"TAA (Cinematic Smooth)",
	"Ultra (TAA + FXAA + MSAA 4x)"
]

const PRESETS: Array[Dictionary] = [
	{ # 0: Potato
		"shadow_quality": 0,
		"lod_quality": 0,
		"clutter_culling_idx": 0,
		"volumetric_fog_enabled": false,
		"glow_enabled": false,
		"dof_enabled": false,
		"anti_aliasing_mode": 0,
		"scaling_3d": 0.75
	},
	{ # 1: Low
		"shadow_quality": 1,
		"lod_quality": 0,
		"clutter_culling_idx": 1,
		"volumetric_fog_enabled": false,
		"glow_enabled": true,
		"dof_enabled": false,
		"anti_aliasing_mode": 1,
		"scaling_3d": 1.0
	},
	{ # 2: Medium
		"shadow_quality": 1,
		"lod_quality": 1,
		"clutter_culling_idx": 1,
		"volumetric_fog_enabled": true,
		"glow_enabled": true,
		"dof_enabled": false,
		"anti_aliasing_mode": 2,
		"scaling_3d": 1.0
	},
	{ # 3: High
		"shadow_quality": 2,
		"lod_quality": 2,
		"clutter_culling_idx": 2,
		"volumetric_fog_enabled": true,
		"glow_enabled": true,
		"dof_enabled": true,
		"anti_aliasing_mode": 3,
		"scaling_3d": 1.0
	},
	{ # 4: Ultra
		"shadow_quality": 2,
		"lod_quality": 3,
		"clutter_culling_idx": 3,
		"volumetric_fog_enabled": true,
		"glow_enabled": true,
		"dof_enabled": true,
		"anti_aliasing_mode": 5,
		"scaling_3d": 1.0
	}
]

func get_matching_preset() -> int:
	if pixel_art_mode != 0:
		return 5
	for i in range(PRESETS.size()):
		var p: Dictionary = PRESETS[i]
		if shadow_quality == p.shadow_quality and \
		   lod_quality == p.lod_quality and \
		   clutter_culling_idx == p.clutter_culling_idx and \
		   volumetric_fog_enabled == p.volumetric_fog_enabled and \
		   glow_enabled == p.glow_enabled and \
		   dof_enabled == p.dof_enabled and \
		   anti_aliasing_mode == p.anti_aliasing_mode:
			return i
	return 5

func apply_preset(idx: int) -> void:
	if idx < 0 or idx >= PRESETS.size():
		graphics_preset = 5
		return
	var p: Dictionary = PRESETS[idx]
	shadow_quality = p.shadow_quality
	lod_quality = p.lod_quality
	clutter_culling_idx = p.clutter_culling_idx
	volumetric_fog_enabled = p.volumetric_fog_enabled
	glow_enabled = p.glow_enabled
	dof_enabled = p.dof_enabled
	anti_aliasing_mode = p.anti_aliasing_mode
	pixel_art_mode = 0
	scaling_3d_scale = p.get("scaling_3d", 1.0)
	graphics_preset = idx
	apply_graphics_settings()
	settings_changed.emit("graphics")
	settings_changed.emit("preset")

func apply_fps_limit() -> void:
	if fps_limit_enabled and max_fps > 0:
		Engine.max_fps = max_fps
	else:
		Engine.max_fps = 0
	settings_changed.emit("video")

func _ready() -> void:
	load_settings()
	apply_all_settings()
	get_tree().node_added.connect(_on_node_added)

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err != OK:
		# First run, use defaults
		return
		
	# Audio
	master_volume = config.get_value("audio", "master_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 0.75)
	sfx_volume = config.get_value("audio", "sfx_volume", 0.85)
	
	# Display
	window_mode = config.get_value("video", "window_mode", 0)
	resolution_idx = config.get_value("video", "resolution_idx", 0)
	vsync_enabled = config.get_value("video", "vsync_enabled", true)
	fps_limit_enabled = config.get_value("video", "fps_limit_enabled", false)
	max_fps = config.get_value("video", "max_fps", 60)
	show_fps = config.get_value("video", "show_fps", false)
	
	# Graphics
	shadow_quality = config.get_value("graphics", "shadow_quality", 2)
	volumetric_fog_enabled = config.get_value("graphics", "volumetric_fog_enabled", true)
	glow_enabled = config.get_value("graphics", "glow_enabled", true)
	lod_quality = config.get_value("graphics", "lod_quality", 2)
	clutter_culling_idx = config.get_value("graphics", "clutter_culling_idx", 1)
	pixel_art_mode = config.get_value("graphics", "pixel_art_mode", 0)
	anti_aliasing_mode = config.get_value("graphics", "anti_aliasing_mode", 3)
	dof_enabled = config.get_value("graphics", "dof_enabled", true)
	scaling_3d_scale = config.get_value("graphics", "scaling_3d_scale", 1.0)
	graphics_preset = config.get_value("graphics", "graphics_preset", 3)
	graphics_preset = get_matching_preset()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	
	config.set_value("video", "window_mode", window_mode)
	config.set_value("video", "resolution_idx", resolution_idx)
	config.set_value("video", "vsync_enabled", vsync_enabled)
	config.set_value("video", "fps_limit_enabled", fps_limit_enabled)
	config.set_value("video", "max_fps", max_fps)
	config.set_value("video", "show_fps", show_fps)
	
	config.set_value("graphics", "shadow_quality", shadow_quality)
	config.set_value("graphics", "volumetric_fog_enabled", volumetric_fog_enabled)
	config.set_value("graphics", "glow_enabled", glow_enabled)
	config.set_value("graphics", "lod_quality", lod_quality)
	config.set_value("graphics", "clutter_culling_idx", clutter_culling_idx)
	config.set_value("graphics", "pixel_art_mode", pixel_art_mode)
	config.set_value("graphics", "anti_aliasing_mode", anti_aliasing_mode)
	config.set_value("graphics", "dof_enabled", dof_enabled)
	config.set_value("graphics", "scaling_3d_scale", scaling_3d_scale)
	config.set_value("graphics", "graphics_preset", get_matching_preset())
	
	config.save(CONFIG_PATH)

func apply_all_settings() -> void:
	apply_audio_settings()
	apply_display_settings()
	apply_fps_limit()
	apply_graphics_settings()

func apply_audio_settings() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	settings_changed.emit("audio")

func _set_bus_volume(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		if volume <= 0.001:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			AudioServer.set_bus_volume_db(idx, linear_to_db(volume))

func apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
		
	match window_mode:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if resolution_idx >= 0 and resolution_idx < RESOLUTIONS.size():
				DisplayServer.window_set_size(RESOLUTIONS[resolution_idx])
		1: # Borderless Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: # Exclusive Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	settings_changed.emit("video")

func apply_graphics_settings() -> void:
	var root := get_tree().root
	if not root:
		return
		
	# 3D Resolution Scaling (e.g. 75% for Potato, 100% standard)
	root.scaling_3d_scale = scaling_3d_scale
		
	# 1. Global Viewport Mesh LOD Threshold (affects every mesh in the game)
	var clamped_lod := clampi(lod_quality, 0, LOD_THRESHOLDS.size() - 1)
	root.mesh_lod_threshold = LOD_THRESHOLDS[clamped_lod]
	
	# 2. Clutter & Deko Distance Culling
	_apply_clutter_culling()
		
	# 3. WorldEnvironment (Fog, Glow, SSR, SSIL, DoF)
	var env_node := root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if env_node:
		if env_node.environment:
			env_node.environment.volumetric_fog_enabled = volumetric_fog_enabled
			env_node.environment.glow_enabled = glow_enabled
			# SSR and SSIL are always on when glow is on (high-quality mode)
			env_node.environment.ssr_enabled = glow_enabled
			env_node.environment.ssil_enabled = glow_enabled
			
		# Depth of Field (DoF) via CameraAttributesPractical
		if not env_node.camera_attributes:
			var ca := CameraAttributesPractical.new()
			ca.dof_blur_far_distance = 28.0
			ca.dof_blur_far_transition = 18.0
			ca.dof_blur_amount = 0.12
			env_node.camera_attributes = ca
			
		if env_node.camera_attributes is CameraAttributesPractical:
			var ca := env_node.camera_attributes as CameraAttributesPractical
			ca.dof_blur_far_enabled = dof_enabled
			ca.dof_blur_far_distance = 28.0
			ca.dof_blur_far_transition = 18.0
			ca.dof_blur_amount = 0.12
		
	# 4. DirectionalLight Shadows
	var sun := root.find_child("SunLight", true, false) as DirectionalLight3D
	if sun:
		sun.shadow_enabled = (shadow_quality > 0)
		if shadow_quality == 1:
			sun.directional_shadow_max_distance = 60.0
		elif shadow_quality == 2:
			sun.directional_shadow_max_distance = 120.0

	# 5. Anti-Aliasing (MSAA, TAA, FXAA, Debanding)
	root.use_debanding = true
	match anti_aliasing_mode:
		0: # Aus
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = false
		1: # FXAA
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			root.use_taa = false
		2: # MSAA 2x
			root.msaa_3d = Viewport.MSAA_2X
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = false
		3: # MSAA 4x
			root.msaa_3d = Viewport.MSAA_4X
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = false
		4: # TAA
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = true
		5: # Ultra (TAA + FXAA + MSAA 4x)
			root.msaa_3d = Viewport.MSAA_4X
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			root.use_taa = true
			
	settings_changed.emit("graphics")
	settings_changed.emit("pixel_art")

func _apply_clutter_culling() -> void:
	var dist: float = CLUTTER_DISTANCES[clampi(clutter_culling_idx, 0, CLUTTER_DISTANCES.size() - 1)]
	var nodes := get_tree().get_nodes_in_group("clutter")
	for node in nodes:
		if node is GeometryInstance3D:
			_configure_geometry_culling(node as GeometryInstance3D, dist)

func _configure_geometry_culling(geom: GeometryInstance3D, dist: float) -> void:
	if dist > 0.0:
		geom.visibility_range_end = dist
		geom.visibility_range_end_margin = minf(dist * 0.2, 12.0)
		geom.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	else:
		geom.visibility_range_end = 0.0 # Disabled / Infinite

func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		call_deferred("apply_graphics_settings")
	elif node.is_in_group("clutter") and node is GeometryInstance3D:
		var dist: float = CLUTTER_DISTANCES[clampi(clutter_culling_idx, 0, CLUTTER_DISTANCES.size() - 1)]
		_configure_geometry_culling(node as GeometryInstance3D, dist)
