shader_type spatial;
render_mode depth_draw_always, cull_back;

uniform sampler2D texture_normal : hint_normal, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform vec4 shallow_color : source_color = vec4(0.15, 0.75, 0.85, 0.85);
uniform vec4 deep_color : source_color = vec4(0.04, 0.22, 0.50, 0.96);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);

uniform float depth_distance : hint_range(0.1, 30.0) = 5.0;
uniform float foam_distance : hint_range(0.01, 3.0) = 0.45;

uniform vec2 wave_direction1 = vec2(1.0, 0.3);
uniform vec2 wave_direction2 = vec2(-0.3, 0.9);
uniform float wave_scale : hint_range(0.01, 10.0) = 0.8;
uniform float wave_speed : hint_range(0.01, 2.0) = 0.06;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.0;

uniform float wave_amplitude : hint_range(0.0, 1.0) = 0.06;
uniform float wave_frequency : hint_range(0.01, 2.0) = 0.12;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin(world_pos.x * wave_frequency + TIME * 1.5) * cos(world_pos.z * wave_frequency + TIME * 1.2);
	VERTEX.y += w1 * wave_amplitude;
}

void fragment() {
	vec2 uv_world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz * 0.08;
	
	vec2 uv1 = uv_world * wave_scale + wave_direction1 * (TIME * wave_speed);
	vec2 uv2 = uv_world * (wave_scale * 1.25) + wave_direction2 * (TIME * wave_speed * 0.85);
	
	vec3 n1 = texture(texture_normal, uv1).rgb * 2.0 - 1.0;
	vec3 n2 = texture(texture_normal, uv2).rgb * 2.0 - 1.0;
	vec3 wave_normal = normalize(n1 + n2);
	
	NORMAL_MAP = wave_normal;
	NORMAL_MAP_DEPTH = normal_strength;
	
	// Depth & shoreline foam
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_depth = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_depth.xyz /= view_depth.w;
	float linear_depth = -view_depth.z;
	float water_depth = max(0.0, linear_depth + VERTEX.z);
	
	float depth_factor = clamp(water_depth / depth_distance, 0.0, 1.0);
	vec4 water_col = mix(shallow_color, deep_color, depth_factor);
	
	// Foam along coastlines
	float foam_factor = clamp(1.0 - (water_depth / max(foam_distance, 0.01)), 0.0, 1.0);
	float foam_noise = (n1.r + n2.g) * 0.5;
	float foam_mask = smoothstep(0.35, 0.65, foam_factor + foam_noise * 0.25);
	
	vec3 final_albedo = mix(water_col.rgb, foam_color.rgb, foam_mask);
	float final_alpha = mix(water_col.a, 1.0, foam_mask);
	
	// Fresnel shine
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	final_albedo = mix(final_albedo, vec3(0.65, 0.88, 1.0), fresnel * 0.35);
	
	ALBEDO = final_albedo;
	ROUGHNESS = mix(0.08, 0.3, foam_mask);
	SPECULAR = 0.6;
	ALPHA = final_alpha;
}
