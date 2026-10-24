shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 shadow_color : source_color = vec4(0.36, 0.042, 0.062, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.62;
void fragment() {
    vec2 pos = (UV - vec2(0.5)) * vec2(2.0, 2.0);
    float radius = dot(pos, pos);
    float blurred = exp(-radius * 3.4);
    float edge = exp(-radius * 12.0);
    ALBEDO = shadow_color.rgb;
    ALPHA = clamp((blurred * 0.22 + edge * 0.34) * intensity, 0.0, 0.68);
}
