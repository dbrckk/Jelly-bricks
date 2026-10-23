shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Dedicated optical experiment: NO game-level material changes.
// Object-local geometry is supplied by the existing molded studio generator.
uniform vec4 pigment : source_color = vec4(0.95, 0.065, 0.085, 1.0);
uniform float gel_alpha : hint_range(0.45, 0.98) = 0.93;
uniform float deformation : hint_range(-0.30, 1.0) = 0.0;
uniform float tilt_energy : hint_range(-1.0, 1.0) = 0.0;
uniform float ripple_energy : hint_range(0.0, 1.0) = 0.0;
uniform float ripple_phase : hint_range(0.0, 6.283) = 0.0;
uniform vec2 brick_extent = vec2(2.0, 1.0);
// Additional contact-localized perimeter wobble. Disabled by default so
// the established single-brick and three-stack comparison shots do not change.
uniform float soft_edge_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 soft_edge_axis = vec2(1.0, 0.0);
uniform float highlights : hint_range(0.0, 1.0) = 0.78;
uniform float stud_mode : hint_range(0.0, 1.0) = 0.0;
// Optically deeper alternative, activated only for the physics prototype.
// At 0 the validated comparison shots retain their original material.
uniform float bulk_optics : hint_range(0.0, 1.0) = 0.0;
// Optional broad subsurface coloration instead of hard candy translucency.
// Off by default; only the Physics Lab enables it.
uniform float gel_milkiness : hint_range(0.0, 1.0) = 0.0;
varying vec3 local_point;
varying vec3 camera_local;

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

    // Deforming only vertices leaves the light reflection frozen on a
    // vibrating surface, making soft gel look like solid lacquer. Rebuild
    // the displaced top normal from the exact analytical wave gradient.
    // Keep identical maths in the core and coat so they reflect as one skin.
    float width_scale = 1.0 + deformation * 0.10 * (1.0 - w * 0.45);
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
        edge_push * 0.08);
    local_point = VERTEX;
    // Eye in original brick coordinates; computes view-ray path length
    // through an analytical volume without exposing the inner socket mesh.
    camera_local = (inverse(MODEL_MATRIX) *
        vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
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
    // Depth-biased colored transmission (not an alpha trick): a strong
    // dyed outline contains a lighter but still pigmented gelatin interior.
    // The short path through the upper crown is brightest, while the
    // thicker walls and support meniscus attenuate via Beer-like absorption.
    float thickness = mix(0.33, 1.0, body_wall);
    float path_length = thickness * (1.0 + grazing * 0.58 +
        foot * 0.30);
    float attenuation = exp(-0.52 * path_length);
    vec3 base_dye = pigment.rgb * mix(0.62, 1.02, crown);
    vec3 subsurface = pigment.rgb * (0.15 +
        0.32 * attenuation * internal_window * body_wall);
    // Keep highly saturated reds/blues/greens rather than mixing white
    // directly into ALBEDO on wide faces.
    vec3 optical = base_dye * mix(0.60, 0.98, attenuation) +
        subsurface * 0.43;
    optical *= 1.0 - grazing * 0.10 - foot * 0.10;

    if (bulk_optics > 0.001) {
        // Cheap optical-volume proxy: the visible front surface casts a
        // view ray to the opposite face of the molded body AABB. A short
        // path transmits more broad-spectrum studio light; a long path
        // absorbs channels differentially according to the dye pigment.
        // No screen texture, transparent sorting or additional draw call.
        vec3 direction = normalize(local_point - camera_local);
        vec3 box_min = vec3(0.0, 0.055, 0.0);
        vec3 box_max = vec3(brick_extent.x, 0.57, brick_extent.y);
        vec3 p = clamp(local_point, box_min, box_max);
        vec3 target = vec3(
            direction.x >= 0.0 ? box_max.x : box_min.x,
            direction.y >= 0.0 ? box_max.y : box_min.y,
            direction.z >= 0.0 ? box_max.z : box_min.z);
        vec3 safe_dir = vec3(
            abs(direction.x) >= 0.001 ? direction.x :
                (direction.x >= 0.0 ? 0.001 : -0.001),
            abs(direction.y) >= 0.001 ? direction.y :
                (direction.y >= 0.0 ? 0.001 : -0.001),
            abs(direction.z) >= 0.001 ? direction.z :
                (direction.z >= 0.0 ? 0.001 : -0.001));
        vec3 exit_times = (target - p) / safe_dir;
        float optical_path = clamp(min(min(exit_times.x,
            exit_times.y), exit_times.z), 0.0, 2.5);
        // Beer-Lambert-inspired approximation. Bright pigment passes
        // more light in its channel; weak channels become absorbed.
        vec3 absorption_coeff = mix(vec3(1.65), vec3(0.40),
            pow(clamp(pigment.rgb, vec3(0.0), vec3(1.0)),
                vec3(0.72)));
        vec3 transmitted = exp(-absorption_coeff * optical_path);
        vec3 bulk_color = pigment.rgb * 0.36 + transmitted * 0.31;
        // A little backscatter mimics diffused light at thin edges without
        // painting a flat white gloss over the whole Jelly.
        float rim_scatter = exp(-2.0 * optical_path) * 0.08;
        bulk_color += sqrt(pigment.rgb) * rim_scatter;
        bulk_color *= 0.94 + crown * 0.06;
        optical = mix(optical, bulk_color, bulk_optics);
    }

    if (gel_milkiness > 0.001) {
        // Broad, colored internal light transport APPROXIMATION. It biases
        // very dark side walls and bright thin crowns toward the same
        // coherent dye instead of opaque plastic plus white neon edges.
        // Tint depends on pigment and local depth, never pure white.
        vec3 scattered = sqrt(max(pigment.rgb, vec3(0.0))) *
            (0.24 + 0.15 * (1.0 - body_wall) + 0.10 * internal_window);
        optical = mix(optical,
            optical * (0.76 + 0.13 * crown) + scattered * 0.36,
            gel_milkiness);
    }

    // Two bounded photographic softboxes reflected in the actual normal,
    // not a fixed texture painted onto the wall. Highlights keep dye tint.
    vec3 r = reflect(-v, n);
    float wide = pow(max(dot(r, normalize(vec3(-0.35, 0.77, 0.53))), 0.0), 10.0);
    float thin = pow(max(dot(r, normalize(vec3(0.61, 0.72, -0.33))), 0.0), 38.0);
    float rim = grazing * (0.25 + 0.75 * smoothstep(0.23, 0.79, local_point.y));
    float reflection = clamp((wide * 0.58 + thin * 0.34 + rim * 0.12) *
        highlights * mix(1.0, 0.66, bulk_optics), 0.0, 0.66);
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
    ROUGHNESS = mix(0.095, 0.20, gel_milkiness);
    SPECULAR = mix(0.92, 0.64, gel_milkiness);
    METALLIC = 0.0;
    EMISSION = pigment.rgb * (0.023 + body_wall * internal_window * 0.018 +
        bulk_optics * (0.022 + crown * 0.008));
}
