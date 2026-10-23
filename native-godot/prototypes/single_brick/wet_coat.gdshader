shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform float coat_strength : hint_range(0.0, 1.0) = 0.60;
// Match the underlying gel vertex deformation exactly. Without this, the
// transparent highlight floats above the shrinking body during an impact.
uniform float deformation : hint_range(-0.30, 1.0) = 0.0;
uniform float tilt_energy : hint_range(-1.0, 1.0) = 0.0;
uniform float ripple_energy : hint_range(0.0, 1.0) = 0.0;
uniform float ripple_phase : hint_range(0.0, 6.283) = 0.0;
uniform vec2 brick_extent = vec2(2.0, 1.0);
// Additional contact-localized perimeter wobble. Disabled by default so
// the established single-brick and three-stack comparison shots do not change.
uniform float soft_edge_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 soft_edge_axis = vec2(1.0, 0.0);
// Identical whole-body silhouette deformation to wet_gel.gdshader.
uniform float silhouette_softness : hint_range(0.0, 1.0) = 0.0;
uniform float momentum_lag : hint_range(-1.0, 1.0) = 0.0;
// Optional analytical incompressibility cue for the v9 dual-gel lab.
// Default zero preserves old projects / screenshots.
uniform float volume_conservation : hint_range(0.0, 1.0) = 0.0;
// Local impact point comes from PhysicsDirectBodyState3D, not a guessed
// brick midpoint. All three are zero/no-op in legacy reference scenes.
uniform vec3 impact_local_point = vec3(0.5, 0.1, 0.5);
uniform float impact_local_energy : hint_range(0.0, 1.0) = 0.0;
uniform float impact_local_age : hint_range(0.0, 3.0) = 3.0;
varying vec3 local_position;

void vertex() {
    float w = clamp((VERTEX.y - 0.055) / 0.76, 0.0, 1.0);
    float compressed = 1.0 - deformation * 0.19;
    vec2 away = VERTEX.xz - brick_extent * 0.5;
    float baseline_width = 1.0 +
        deformation * 0.10 * (1.0 - w * 0.45);
    // For incompressible volume, width² * height ~= 1. Applied to both
    // glossy coat and tinted core with exactly the SAME coefficients.
    float conserved_width = inversesqrt(max(compressed, 0.68));
    float blended_width = mix(baseline_width, conserved_width,
        volume_conservation * (0.75 + 0.25 * w));
    VERTEX.xz += away * (blended_width - 1.0);
    VERTEX.y = 0.055 + (VERTEX.y - 0.055) * compressed;
    // Same mid-body inflation and inertial follow-through as the core.
    float body_band = smoothstep(0.095, 0.22, VERTEX.y) *
        (1.0 - smoothstep(0.42, 0.56, VERTEX.y));
    vec2 outward = VERTEX.xz - brick_extent * 0.5;
    float belly = silhouette_softness * deformation * body_band * 0.17;
    VERTEX.xz += outward * belly;
    float shoulder = smoothstep(0.07, 0.49, VERTEX.y);
    VERTEX.x += momentum_lag * silhouette_softness * shoulder * 0.095;
    VERTEX.x += tilt_energy * w * w * 0.11;
    // Short, spatially traveling deformation around the top wall.
    // The same spring drives coat and core; only the affected top 65%
    // ripples. Rest is exactly zero. No texture or physics allocation.
    float wave_x = VERTEX.x * 8.0 - ripple_phase;
    float wave_z = VERTEX.z * 5.2 + ripple_phase * 0.35;
    float crest = sin(wave_x) * cos(wave_z);
    float envelope = smoothstep(0.31, 0.82, w);
    float wave_height = ripple_energy * envelope * 0.026;
    VERTEX.y += wave_height * crest;

    // The wet corners respond laterally to a contact, instead of simply
    // shrinking as a rigid capsule. This sidewall band is strongest above
    // the bottom bearing rim. The SAME displacement is used in the core
    // and the clearcoat, so the reflective skin cannot slide off the gel.
    // Default strength zero keeps previously approved reference poses exact.
    float edge_band = smoothstep(0.05, 0.36, w) *
        (1.0 - smoothstep(0.84, 1.20, w));
    vec2 relative = (VERTEX.xz - brick_extent * 0.5) /
        max(brick_extent * 0.5, vec2(0.5));
    vec2 edge_direction = normalize(relative + vec2(0.00001));
    float edge_wave = sin(dot(relative, soft_edge_axis) * 4.2 -
        ripple_phase * 1.5);
    float edge_push = soft_edge_strength * edge_band *
        (0.5 + 0.5 * edge_wave);
    VERTEX.xz += edge_direction * (edge_push * 0.044);
    VERTEX.y += edge_push * 0.010;

    // Contact-origin deformation: a local pinch followed by an expanding
    // ring along the gel surface. This is an approximation of soft material;
    // rigid-body mass and collision remain owned by Godot.
    // Formulas must stay IDENTICAL for the tinted body and glossy coat.
    vec3 from_hit = VERTEX - impact_local_point;
    float contact_radius = length(vec3(from_hit.x,
        from_hit.y * 0.80, from_hit.z));
    float center_weight = exp(-13.0 * contact_radius * contact_radius);
    float wavefront = contact_radius - impact_local_age * 1.62;
    float ring_weight = exp(-26.0 * wavefront * wavefront) *
        exp(-impact_local_age * 3.8);
    float ring = sin(wavefront * 19.0) * ring_weight;
    vec2 radial_direction = normalize(from_hit.xz + vec2(0.0001));
    float contact_push = impact_local_energy * (
        center_weight * 0.085 + ring * 0.030);
    VERTEX.xz += radial_direction * contact_push * 0.72;
    float axial_sign = impact_local_point.y < 0.38 ? 1.0 : -1.0;
    VERTEX.y += impact_local_energy * axial_sign *
        (center_weight * 0.045 + ring * 0.018);

    // Deforming only vertices leaves the light reflection frozen on a
    // vibrating surface, making soft gel look like solid lacquer. Rebuild
    // the displaced top normal from the exact analytical wave gradient.
    // Keep identical maths in the core and coat so they reflect as one skin.
    float width_scale = blended_width * (1.0 + belly);
    vec3 elastic_normal = normalize(vec3(
        NORMAL.x / width_scale,
        NORMAL.y / max(compressed, 0.25),
        NORMAL.z / width_scale));
    vec2 slope = wave_height * vec2(
        8.0 * cos(wave_x) * cos(wave_z),
        -5.2 * sin(wave_x) * sin(wave_z));
    NORMAL = normalize(elastic_normal -
        vec3(slope.x, 0.0, slope.y) * max(elastic_normal.y, 0.0) +
        vec3(edge_direction.x, 0.0, edge_direction.y) *
        edge_push * 0.08 +
        vec3(radial_direction.x, 0.0, radial_direction.y) *
        contact_push * 0.22);
    local_position = VERTEX;
}
void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 eye = normalize(VIEW);
    vec3 reflection_dir = reflect(-eye, n);
    float sheet = pow(max(dot(reflection_dir,
        normalize(vec3(-0.50, 0.78, 0.40))), 0.0), 9.0);
    float strip = pow(max(dot(reflection_dir,
        normalize(vec3(0.42, 0.58, -0.69))), 0.0), 35.0);
    float silhouette = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 3.0);
    float seam = 1.0 - smoothstep(0.012, 0.054,
        abs(local_position.y - 0.518));
    float cap = smoothstep(0.46, 0.94, n.y);
    float intensity = coat_strength * (
        sheet * 0.30 + strip * 0.52 + silhouette * 0.13 +
        seam * (1.0-cap) * 0.09);
    ALBEDO = light_color.rgb;
    ALPHA = clamp(intensity, 0.0, 0.56);
}
