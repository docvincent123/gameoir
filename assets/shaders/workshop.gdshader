shader_type canvas_item;

uniform vec4 accent : source_color = vec4(0.34, 0.16, 0.49, 1.0);
uniform vec4 base : source_color = vec4(0.085, 0.041, 0.145, 1.0);

void fragment() {
	vec2 p = UV;
	float wash = exp(-3.1 * length((p - vec2(0.68, 0.20)) * vec2(1.0, 1.45)));
	float lower = exp(-4.0 * length((p - vec2(0.08, 0.84)) * vec2(1.0, 1.4)));
	float grain = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	vec3 color = mix(base.rgb, accent.rgb, wash * 0.92 + lower * 0.29);
	COLOR = vec4(color + grain * 0.024, 1.0);
}
