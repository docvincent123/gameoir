shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D footprint : filter_nearest, repeat_disable;
uniform float pressure : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec2 cell = fract(UV * 7.0);
    float active = texture(footprint, UV).r;
    vec2 delta = cell - vec2(0.5);
    float falloff = 1.0 - smoothstep(0.18, 0.49, length(delta));
    vec2 warp = delta * falloff * pressure * 0.012;
    vec3 original = texture(screen_tex, SCREEN_UV).rgb;
    vec3 compressed = texture(screen_tex, clamp(SCREEN_UV + warp, vec2(0.0), vec2(1.0))).rgb;
    float shadow = falloff * pressure * 0.14;
    float rim = exp(-pow((length(delta) - 0.34) * 18.0, 2.0)) * pressure * 0.07;
    COLOR = vec4(mix(original, compressed, falloff) * (1.0 - shadow) + rim, active * falloff);
}
