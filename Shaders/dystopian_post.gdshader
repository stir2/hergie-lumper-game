shader_type canvas_item;

uniform sampler2D screen_texture :
	hint_screen_texture,
	repeat_disable,
	filter_nearest;

uniform float color_levels : hint_range(2.0, 8.0, 1.0) = 8.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.8;
uniform float saturation : hint_range(0.0, 2.0) = 0.75;
uniform float contrast : hint_range(0.5, 2.0) = 1.15;
uniform float palette_strength : hint_range(0.0, 1.0) = 0.65;
uniform float grain_strength : hint_range(0.0, 0.15) = 0.015;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.10;

// Orange-accent controls.
// These are tuned to make carrot-orange pixels stand out from dirt/rust colors.
uniform float carrot_boost : hint_range(0.0, 1.0) = 0.80;
uniform float carrot_brightness : hint_range(0.0, 0.5) = 0.16;
uniform float carrot_dither_reduction : hint_range(0.0, 1.0) = 0.50;
uniform vec3 carrot_accent : source_color = vec3(0.95, 0.30, 0.035);


float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}


float bayer4x4(ivec2 pixel) {
	int x = pixel.x & 3;
	int y = pixel.y & 3;

	int index = x + y * 4;

	float values[16] = float[](
		0.0,  8.0,  2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0,  9.0,
		15.0, 7.0, 13.0, 5.0
	);

	return (values[index] + 0.5) / 16.0;
}


// Detect orange pixels before the global desaturation/palette pass.
// This is color-based, so other strongly orange objects will also receive the accent.
float orange_mask(vec3 color) {
	float red_over_green = color.r - color.g;
	float green_over_blue = color.g - color.b;

	float warm_red = smoothstep(
		0.10,
		0.38,
		red_over_green
	);

	float not_red_or_pink = smoothstep(
		0.025,
		0.24,
		green_over_blue
	);

	float enough_color = smoothstep(
		0.28,
		0.72,
		max(color.r, max(color.g, color.b))
			- min(color.r, min(color.g, color.b))
	);

	float enough_red = smoothstep(
		0.30,
		0.72,
		color.r
	);

	return warm_red
		* not_red_or_pink
		* enough_color
		* enough_red;
}


vec3 dystopian_palette(vec3 source) {
	float lightness = luminance(source);

	float warmth = smoothstep(
		-0.10,
		0.30,
		source.r - source.b
	);

	vec3 shadow = vec3(0.03, 0.04, 0.055);
	vec3 cool_mid = vec3(0.16, 0.18, 0.20);
	vec3 rust_mid = vec3(0.52, 0.24, 0.07);
	vec3 warm_highlight = vec3(0.72, 0.54, 0.32);
	vec3 pale = vec3(0.86, 0.83, 0.73);

	vec3 middle = mix(
		cool_mid,
		rust_mid,
		warmth
	);

	if (lightness < 0.35) {
		return mix(
			shadow,
			middle,
			lightness / 0.35
		);
	}

	if (lightness < 0.70) {
		return mix(
			middle,
			warm_highlight,
			(lightness - 0.35) / 0.35
		);
	}

	return mix(
		warm_highlight,
		pale,
		(lightness - 0.70) / 0.30
	);
}


float random_value(vec2 position) {
	return fract(
		sin(dot(position, vec2(12.9898, 78.233))) * 43758.5453
	);
}


void fragment() {
	vec2 uv = SCREEN_UV;

	vec2 screen_size = vec2(textureSize(screen_texture, 0));
	vec2 pixel_position = floor(uv * screen_size);

	vec3 raw_source = textureLod(
		screen_texture,
		uv,
		0.0
	).rgb;

	// Save the orange classification before desaturation changes the hue.
	float carrot_mask = orange_mask(raw_source);

	vec3 source = raw_source;

	// Desaturate and increase contrast.
	float source_lightness = luminance(source);

	source = mix(
		vec3(source_lightness),
		source,
		saturation
	);

	source = (source - 0.5) * contrast + 0.5;
	source = clamp(source, vec3(0.0), vec3(1.0));

	// Push the image toward the cold/rust dystopian palette.
	vec3 graded = dystopian_palette(source);

	vec3 color = mix(
		source,
		graded,
		palette_strength
	);

	// Pull recognized orange regions back toward a clearer carrot-orange.
	// This keeps them from collapsing into the same brown/rust tone as the ground.
	vec3 carrot_color = mix(
		color,
		carrot_accent,
		0.58
	);

	color = mix(
		color,
		carrot_color,
		carrot_mask * carrot_boost
	);

	// Give carrot-orange pixels a small luminance lift.
	color += vec3(
		carrot_mask * carrot_brightness
	);

	color = clamp(
		color,
		vec3(0.0),
		vec3(1.0)
	);

	// 4x4 Bayer ordered dithering.
	float threshold = bayer4x4(
		ivec2(pixel_position)
	);

	// Reduce dithering somewhat on orange pixels so the carrot silhouette
	// remains more coherent and readable.
	float local_dither_strength = mix(
		dither_strength,
		dither_strength * (1.0 - carrot_dither_reduction),
		carrot_mask
	);

	float dither_offset =
		(threshold - 0.5)
		* local_dither_strength
		/ max(color_levels - 1.0, 1.0);

	color += vec3(dither_offset);

	// Quantize after applying the threshold.
	color = floor(
		color * (color_levels - 1.0) + 0.5
	) / (color_levels - 1.0);

	// Re-introduce a little orange separation after quantization.
	// This preserves the dither pattern while avoiding muddy brown carrots.
	color = mix(
		color,
		max(color, carrot_accent * 0.72),
		carrot_mask * carrot_boost * 0.28
	);

	// Very light grain so the result is not perfectly digital.
	float noise = random_value(
		pixel_position
	);

	color += (
		noise - 0.5
	) * grain_strength;

	// Mild vignette.
	vec2 centered = uv * 2.0 - 1.0;

	float vignette = smoothstep(
		0.25,
		1.35,
		dot(centered, centered)
	);

	color *= 1.0 - vignette * vignette_strength;

	COLOR = vec4(
		clamp(color, vec3(0.0), vec3(1.0)),
		1.0
	);
}
