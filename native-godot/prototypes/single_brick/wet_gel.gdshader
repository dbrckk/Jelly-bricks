shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Dedicated optical experiment: NO game-level material changes.
// Object-local geometry is supplied by the existing molded studio generator.
uniform vec4 pigment : source_color = vec4(0.95, 0.065, 0.085, 1.0);
uniform float gel_alpha : hint_range(0.45, 0.98) = 0.93;
uniform float deformation : hint_range(0.0, 1.0) = 0.0;
uniform float tilt_energy : hint_range(-1.0, 1.0) = 0.0;
uniform vec2 brick_extent = vec2(2.0, 1.0);
uniform float highlights : hint_range(0.0, 1.0) = 0.78;
uniform float stud_mode : hint_range(0.0, 1.0) = 0.0;
varying vec3 local_point;

void vertex() {
    // Squash is constrained near the support. The outline widens slightly
    // as the height compresses: an inexpensive volume-preserving cue.
    float w = clamp((VERTEX.y - 0.055) / 0.76, 0.0, 1.0);
    float compressed = 1.0 - deformation * 0.19;
    vec2 away = VERTEX.xz - brick_extent * 0.5;
    VERTEX.xz += away * deformation * 0.10 * (1.0 - w * 0.45);
    VERTEX.y = 0.055 + (VERTEX.y - 0.055) * compressed;
    // Small lag concentrated on the upper body; physical pose remains
    // defined by the animation, not perturbed saved-grid coordinates.
    VERTEX.x += tilt_energy * w * w * 0.11;
    local_point = VERTEX;
}

void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 v = normalize(VIEW);
    float facing = clamp(dot(n, v), 0.0, 1.0);
    float grazing = pow(1.0 - facing, 2.4);
    float crown = smoothstep(0.35, 0.90, n.y);
    float body_wall = 1.0 - smoothstep(0.28, 0.78, abs(n.y));

    // Pigment is thickest at the vertical side / lower meniscus and thin
    // across the crown. Avoid pale white overlays over the entire brick.
    float foot = 1.0 - smoothstep(0.085, 0.215, local_point.y);
    float internal_window = smoothstep(0.12, 0.26, local_point.y) *
        (1.0 - smoothstep(0.39, 0.51, local_point.y));
    vec3 deep_dye = pigment.rgb * mix(0.38, 0.85, crown);
    vec3 luminous = mix(pigment.rgb, vec3(1.0, 0.95, 0.90), 0.23);
    vec3 optical = deep_dye + luminous * (body_wall * internal_window * 0.15);
    optical *= 1.0 - grazing * 0.20 - foot * 0.13;

    // Two bounded photographic softboxes reflected in the actual normal,
    // not a fixed texture painted onto the wall. Highlights keep dye tint.
    vec3 r = reflect(-v, n);
    float wide = pow(max(dot(r, normalize(vec3(-0.35, 0.77, 0.53))), 0.0), 10.0);
    float thin = pow(max(dot(r, normalize(vec3(0.61, 0.72, -0.33))), 0.0), 38.0);
    float rim = grazing * (0.25 + 0.75 * smoothstep(0.23, 0.79, local_point.y));
    float reflection = clamp((wide * 0.58 + thin * 0.34 + rim * 0.12) *
        highlights, 0.0, 0.66);
    vec3 reflected_tint = mix(pigment.rgb, vec3(1.0, 0.988, 0.97), 0.79);
    optical = mix(optical, reflected_tint, reflection);

    // Translucency varies with optical path: edges keep their silhouette,
    // while facing surfaces let the photograph background show through.
    // Caps and collars are part of the same molded gel. Their short
    // cylindrical flanks transmit more light than the thick 2x1 body.
    optical = mix(optical, pigment.rgb * mix(0.77, 0.99, crown),
        stud_mode * 0.46 * (1.0 - reflection * 0.5));
    ALBEDO = clamp(optical, vec3(0.0), vec3(1.0));
    // Alpha is intentionally absent in this optically dense first-pass test.
    ROUGHNESS = 0.095;
    SPECULAR = 0.92;
    METALLIC = 0.0;
    EMISSION = pigment.rgb * (0.023 + body_wall * internal_window * 0.018);
}
