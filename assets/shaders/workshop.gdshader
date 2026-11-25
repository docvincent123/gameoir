shader_type canvas_item;
uniform vec4 accent : source_color = vec4(0.82,0.93,0.87,1.0);
uniform vec4 base : source_color = vec4(0.94,0.91,1.0,1.0);
void fragment() {
    vec2 p = UV;
    float halo = exp(-4.5 * length((p - vec2(0.5,0.25))*vec2(1.0,1.2)));
    float lower = exp(-3.8 * length(p - vec2(0.85,0.98)));
    vec3 color = mix(vec3(0.90,0.86,0.97),vec3(0.99,0.97,1.0),halo*0.9);
    color = mix(color,accent.rgb,lower*0.20);
    COLOR = vec4(color,1.0);
}
