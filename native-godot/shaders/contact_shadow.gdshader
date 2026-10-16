shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Transparent contact shadow with no shadow map, light probes, texture
// lookup, depth sampling or GPU compute. Small and mobile-compatible.
uniform vec3 shadow_color : source_color = vec3(0.21, 0.29, 0.39);
uniform float strength : hint_range(0.0, 0.5) = 0.23;

void fragment() {
    vec2 distance_from_center = UV * 2.0 - 1.0;
    float radius = length(distance_from_center);
    float feather = 1.0 - smoothstep(0.05, 1.0, radius);
    ALBEDO = shadow_color;
    ALPHA = strength * feather * feather;
}
