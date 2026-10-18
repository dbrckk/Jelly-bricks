shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Transmitted color on the WHITE studio floor, not a glowing outline
// attached to the brick. This material remains a single MultiMesh draw
// for ALL ground Jelly pieces (including the photographed 9-tier tower).
// Artist-controlled optical density; regular editor stays subtle, while
// the full-screen photography mode reveals the transmitted gel pigment.
uniform float transmission_energy : hint_range(0.0, 1.0) = 0.74;

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    // Squared distance avoids sqrt() on every fragment of every plane.
    float radius2 = dot(p, p);
    float dyed_core = 1.0 - smoothstep(0.035, 0.40, radius2);
    // A soft displaced peripheral crescent imitates the focused light
    // path through the rounded meniscus of a real candy block. The
    // existing MultiMesh scale stretches it to the TRUE block footprint.
    vec2 focus = p + vec2(-0.12, 0.08);
    float focused_radius2 = dot(focus, focus);
    float refracted_edge = smoothstep(0.16, 0.32, focused_radius2) *
        (1.0 - smoothstep(0.56, 0.91, focused_radius2));
    // The two-sided gradient avoids a stamped concentric perfect circle.
    float asymmetric_focus = clamp(0.91 + p.x * 0.15 -
        p.y * 0.09, 0.65, 1.10);
    ALBEDO = mix(COLOR.rgb, vec3(1.0), 0.06);
    // Low-opacity red/green/blue/yellow transmitted light. Never produce
    // near-opaque saturated blotches on a clean Android product scene.
    ALPHA = clamp((dyed_core * 0.145 +
        refracted_edge * 0.255 * asymmetric_focus) *
        transmission_energy * COLOR.a, 0.0, 0.34);
}
