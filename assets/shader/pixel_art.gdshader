shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// ---------------------------------------------------------------------------
// Basis
// Tipp: pixel_size am besten ganzzahlig (3, 4, 5), sonst sind die Pixel
// unterschiedlich gross und das Bild flimmert beim Bewegen.
// ---------------------------------------------------------------------------
group_uniforms basis;
uniform bool enabled = true;
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform int color_depth : hint_range(0, 64) = 20;
// Dithering ist jetzt relativ zur Farbtiefe: 0.5 = volle Stufe, 0 = aus
uniform float dither_strength : hint_range(0.0, 0.5) = 0.3;

// ---------------------------------------------------------------------------
// Look: weich, hell, leicht pastellig
// ---------------------------------------------------------------------------
group_uniforms look;
uniform float brightness : hint_range(0.5, 1.5) = 1.05;
uniform float contrast : hint_range(0.5, 1.5) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.1;

// Farbige statt schwarze Schatten (additiv, hebt die Schwarzwerte an)
uniform vec3 shadow_color : source_color = vec3(0.35, 0.30, 0.60);
uniform float shadow_amount : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_range : hint_range(0.1, 1.0) = 0.5;

// Warme Lichter
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.95, 0.82);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;

// Sehr dezente Vignette
uniform float vignette : hint_range(0.0, 1.0) = 0.15;
group_uniforms;

// 4x4 Bayer Matrix fuer geordnetes Dithering
const float bayer_matrix[16] = float[16](
	 0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	 3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

float get_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	if (!enabled || pixel_size <= 1.05) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		// --- Auf niedrig aufgeloestes Pixelraster snappen ----------------------
		vec2 tex_size = vec2(textureSize(screen_texture, 0));
		vec2 target_res = max(tex_size / pixel_size, vec2(1.0));
		vec2 pixel_coord = floor(SCREEN_UV * target_res);
		vec2 snapped_uv = (pixel_coord + vec2(0.5)) / target_res;

		vec3 col = texture(screen_texture, snapped_uv).rgb;

		// --- Grundlook: Saturation, Kontrast, Helligkeit ----------------------
		float l = get_luma(col);
		col = mix(vec3(l), col, saturation);
		col = (col - 0.5) * contrast + 0.5;
		col *= brightness;
		l = get_luma(col);

		// --- Farbige Schatten: dunkle Bereiche Richtung Lila/Blau ziehen -------
		float shadow_mask = 1.0 - smoothstep(0.0, shadow_range, l);
		col += shadow_color * shadow_mask * shadow_amount;

		// --- Warme Lichter ----------------------------------------------------
		float hi = smoothstep(0.4, 0.9, l);
		col *= mix(vec3(1.0), highlight_tint, hi * tint_strength);
		col = clamp(col, 0.0, 1.0);

		// --- Farbquantisierung mit sanftem Dithering --------------------------
		if (color_depth > 0) {
			int bx = int(mod(pixel_coord.x, 4.0));
			int by = int(mod(pixel_coord.y, 4.0));
			float levels = float(color_depth);
			float dither = (bayer_matrix[by * 4 + bx] - 0.5) * dither_strength * 2.0 / levels;

			col = clamp(col + vec3(dither), 0.0, 1.0);
			col = floor(col * levels + 0.5) / levels;
		}

		// --- Dezente Vignette -------------------------------------------------
		float vig = smoothstep(0.4, 1.0, length((SCREEN_UV - 0.5) * 1.2));
		col *= 1.0 - vig * vignette;

		COLOR = vec4(col, 1.0);
	}
}
