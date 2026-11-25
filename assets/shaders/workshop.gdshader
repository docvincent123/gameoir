shader_type canvas_item;

uniform vec4 accent : source_color = vec4(0.82, 0.93, 0.87, 1.0);
uniform vec4 base : source_color = vec4(1.0, 0.965, 0.914, 1.0);

void fragment() {
	vec2 p = UV;
	float upper = exp(-3.7 * length((p - vec2(0.88, 0.075)) * vec2(1.0, 1.75)));
	float lower = exp(-4.1 * length((p - vec2(0.01, 0.88)) * vec2(1.0, 1.25)));
	float blush = exp(-4.0 * length((p - vec2(0.98, 0.62)) * vec2(1.0, 1.55)));
	float grain = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	vec3 color = mix(vec3(1.0, 0.91, 0.76), accent.rgb, clamp(upper * 1.25 + lower * 0.95, 0.0, 1.0));
	float ribbon = exp(-95.0 * pow(p.x - (0.90 - 0.30 * sin(p.y * 5.0)), 2.0));
	color = mix(color, vec3(0.39, 0.68, 0.49), ribbon * 0.13);
	color = mix(color, vec3(1.0, 0.849, 0.82), blush * 0.36);
	COLOR = vec4(color + grain * 0.018, 1.0);
}
