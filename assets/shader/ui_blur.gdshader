shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.8;
uniform vec4 tint_color : source_color = vec4(0.04, 0.05, 0.07, 0.52);

void fragment() {
	// Multi-sampled Gaussian-like mipmap blur
	vec4 col = textureLod(screen_texture, SCREEN_UV, blur_amount);
	
	// Smooth radial vignette
	vec2 uv = SCREEN_UV - 0.5;
	float vignette = smoothstep(0.1, 0.75, length(uv));
	
	// Blend tint, backdrop blur and subtle vignette
	float alpha = clamp(tint_color.a + vignette * 0.28, 0.0, 0.95);
	COLOR = mix(col, tint_color, alpha);
}
