shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float t = TIME * 6.0;
	vec3 rainbow = 0.5 + 0.5 * vec3(sin(t), sin(t + 2.094), sin(t + 4.188));
	COLOR = vec4(mix(col.rgb, rainbow, strength * col.a), col.a);
}
