shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// One pooled MultiMesh projects muted colored transmission below all
// ground-contact Jelly bricks. UV radial math only: no textures, lights,
// depth/screen reads, extra physics or per-brick scene nodes.
void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float radius = length(p);
    float soft_core = 1.0 - smoothstep(0.18, 0.90, radius);
    float refraction_ring = smoothstep(0.27, 0.43, radius) *
        (1.0 - smoothstep(0.61, 0.88, radius));
    ALBEDO = mix(COLOR.rgb, vec3(1.0), 0.17);
    // Restrained pigmentation: the white packshot stays clean.
    ALPHA = clamp((soft_core * 0.085 +
        refraction_ring * 0.135) * COLOR.a, 0.0, 0.22);
}
