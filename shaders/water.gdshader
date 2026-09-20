shader_type canvas_item;

uniform vec4 deep_color : source_color = vec4(0.08, 0.32, 0.38, 0.52);
uniform vec4 foam_color : source_color = vec4(0.55, 0.95, 0.88, 0.55);

void fragment() {
	float wave = sin(UV.x * 28.0 + TIME * 2.2) * 0.018 + sin(UV.x * 11.0 - TIME * 1.4) * 0.01;
	float surface = smoothstep(0.0, 0.08, UV.y + wave);
	vec3 col = mix(foam_color.rgb, deep_color.rgb, surface);
	float sparkle = pow(0.5 + 0.5 * sin(UV.x * 40.0 + TIME * 5.0), 8.0) * (1.0 - UV.y);
	col += sparkle * 0.25;
	float alpha = mix(foam_color.a, deep_color.a, UV.y) * 0.95;
	COLOR = vec4(col, alpha);
}
