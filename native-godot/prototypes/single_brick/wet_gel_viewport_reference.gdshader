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
// Extra observable whole-body jelly silhouette, disabled in original
// reference scenes and the 21-level production game.
uniform float silhouette_softness : hint_range(0.0, 1.0) = 0.0;
uniform float momentum_lag : hint_range(-1.0, 1.0) = 0.0;
// Optional analytical incompressibility cue for the v9 dual-gel lab.
// Default zero preserves old projects / screenshots.
uniform float volume_conservation : hint_range(0.0, 1.0) = 0.0;
// v12 opt-in: real height/width geometry squash for the two-brick laboratory.
// Zero preserves every previous studio and production scene.
uniform float gel_malleability : hint_range(0.0, 1.0) = 0.0;
// Local impact point comes from PhysicsDirectBodyState3D, not a guessed
// brick midpoint. All three are zero/no-op in legacy reference scenes.
uniform vec3 impact_local_point = vec3(0.5, 0.1, 0.5);
uniform float impact_local_energy : hint_range(0.0, 1.0) = 0.0;
uniform float impact_local_age : hint_range(0.0, 3.0) = 3.0;
uniform float highlights : hint_range(0.0, 1.0) = 0.78;
// v11 option: reduce oversized WHITE plastic lobes without dulling
// the gel's saturated body. Zero keeps previous reference material.
uniform float highlight_softness : hint_range(0.0, 1.0) = 0.0;
// v13: optional wet, softly scattering optical gel. OFF by default;
// the 21 production levels and previous screenshot presets are untouched.
uniform float organic_gel : hint_range(0.0, 1.0) = 0.0;
uniform float stud_mode : hint_range(0.0, 1.0) = 0.0;
// Optically deeper alternative, activated only for the physics prototype.
// At 0 the validated comparison shots retain their original material.
uniform float bulk_optics : hint_range(0.0, 1.0) = 0.0;
// Optional broad subsurface coloration instead of hard candy translucency.
// Off by default; only the Physics Lab enables it.
uniform float gel_milkiness : hint_range(0.0, 1.0) = 0.0;
// Dense colored transmission approximation without alpha sorting. Only
// enabled on the Physics Lab; original static reference shots stay stable.
uniform float interior_scatter : hint_range(0.0, 1.0) = 0.0;
// Opaque optical baseline: never samples screen color. Godot GL Compatibility
// otherwise puts the body into a transparent pass and exposes its inner
// socket ROOF through the cap even when transmission=0.
// The background comes from a separately rendered SubViewport that contains
// ONLY the studio floor and props. Unlike hint_screen_texture, this shader
// stays in Godot's opaque pipeline; rear socket walls stay hidden by depth.
uniform sampler2D backdrop_tex : filter_linear, repeat_disable;
uniform float backdrop_strength : hint_range(0.0, 1.0) = 0.0;
uniform float refraction_pixels : hint_range(0.0, 12.0) = 4.0;
varying vec3 local_point;
varying vec3 camera_local;

void vertex() {
    // Squash is constrained near the support. The outline widens slightly
    // as the height compresses: an inexpensive volume-preserving cue.
    float w = clamp((VERTEX.y - 0.055) / 0.76, 0.0, 1.0);
    float compressed = 1.0 - deformation *
        mix(0.19, 0.29, gel_malleability);
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
    // Side-wall bulge is strongest through the mid-body and fades to
    // zero near both crown and bearing rim. This preserves the stud/socket
    // silhouette while giving the soft body an observable belly.
    // Signed deformation also gives a small elastic overshoot on rebound.
    float body_band = smoothstep(0.095, 0.22, VERTEX.y) *
        (1.0 - smoothstep(0.42, 0.56, VERTEX.y));
    vec2 outward = VERTEX.xz - brick_extent * 0.5;
    // Mid-body displacement is not a whole-brick rigid scale: the crown
    // and bearing rim flex less while the middle actually bulges.
    float belly = silhouette_softness * deformation * body_band *
        mix(0.17, 0.22, gel_malleability);
    VERTEX.xz += outward * belly;
    // Follow-through: momentum moves the upper mass after the lower rim.
    // Does not move the collision body or the support plane.
    float shoulder = smoothstep(0.07, 0.49, VERTEX.y);
    VERTEX.x += momentum_lag * silhouette_softness * shoulder * 0.095;
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

    float optical_path = 0.0;
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
        optical_path = clamp(min(min(exit_times.x,
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

    if (interior_scatter > 0.001) {
        // Colored light is more likely to survive across thin sections.
        // Thick walls remain deeply dyed. This is a cheap approximation
        // of an illuminated gel interior; it does NOT sample the background
        // or claim actual volumetric refraction.
        float transmission = exp(-1.4 * optical_path);
        vec3 pigment_light = sqrt(max(pigment.rgb, vec3(0.0)));
        vec3 scattered_color = pigment.rgb *
            (0.32 + transmission * 0.40) +
            pigment_light * (0.14 + (1.0 - transmission) * 0.17);
        optical = mix(optical, scattered_color,
            interior_scatter * (0.28 + 0.18 * transmission));
        optical *= 1.0 - interior_scatter * 0.08 *
            (1.0 - transmission) * grazing;
    }

    // Two bounded photographic softboxes reflected in the actual normal,
    // not a fixed texture painted onto the wall. Highlights keep dye tint.
    vec3 r = reflect(-v, n);
    float wide = pow(max(dot(r, normalize(vec3(-0.35, 0.77, 0.53))), 0.0), 10.0);
    float thin = pow(max(dot(r, normalize(vec3(0.61, 0.72, -0.33))), 0.0), 38.0);
    float rim = grazing * (0.25 + 0.75 * smoothstep(0.23, 0.79, local_point.y));
    float reflection = clamp((wide * 0.58 + thin * 0.34 + rim * 0.12) *
        highlights * mix(1.0, 0.66, bulk_optics), 0.0, 0.66);
    // In the real Redmi screenshot the large white triangular highlights
    // made the surface read as hard glazed LEGO instead of wet dyed gel.
    float wet_lobe = mix(reflection,
        min(reflection * 0.48, 0.19), highlight_softness);
    vec3 reflected_tint = mix(pigment.rgb, vec3(1.0, 0.988, 0.97),
        mix(0.79, 0.33, highlight_softness));
    optical = mix(optical, reflected_tint, wet_lobe);
    // The v12 crown looked like an injection-molded opaque LEGO slab.
    // Shape-based color absorption along the rim and colored inner
    // subsurface light give a gel volume appearance with ZERO new passes.
    // Thin edges are luminous in their own pigment, not white plastic.
    if (organic_gel > 0.001) {
        float thin_edge = 1.0 - smoothstep(0.025, 0.42,
            max(optical_path, 0.0));
        float broad_volume = smoothstep(0.035, 0.45,
            optical_path) * (1.0 - 0.43 * grazing);
        vec3 living_dye = pigment.rgb * (
            0.46 + 0.22 * crown + 0.10 * thin_edge);
        vec3 pigment_bounce = sqrt(max(pigment.rgb, vec3(0.0001))) *
            (0.17 + 0.20 * thin_edge + 0.07 * crown);
        vec3 gel_bulk = living_dye + pigment_bounce *
            (0.62 - 0.22 * broad_volume);
        optical = mix(optical, gel_bulk,
            organic_gel * (0.28 + 0.21 * broad_volume));
    }

    // Translucency varies with optical path: edges keep their silhouette,
    // while facing surfaces let the photograph background show through.
    // Caps and collars are part of the same molded gel. Their short
    // cylindrical flanks transmit more light than the thick 2x1 body.
    optical = mix(optical, pigment.rgb * mix(0.77, 0.99, crown),
        stud_mode * 0.46 * (1.0 - reflection * 0.5));
    // Two-render-pass opaque background transmission. The main mesh still
    // writes full depth and never uses ALPHA, eliminating the transparent
    // ordering bug with the hollow underside. This is view-dependent
    // *screen-space approximation*, not multi-interface path tracing.
    if (backdrop_strength > 0.001) {
        vec2 texel = 1.0 / max(vec2(textureSize(backdrop_tex, 0)),
            vec2(1.0));
        // Snell-inspired image offset, scaled by path inside tinted gel.
        vec2 offset = n.xy * texel * refraction_pixels *
            (0.34 + 0.66 * clamp(optical_path, 0.0, 1.4));
        vec2 uv = clamp(SCREEN_UV + offset,
            texel * 0.5, vec2(1.0) - texel * 0.5);
        // A real gelatin interior blurs the scene slightly. Five small
        // linear samples (only on this material, at half target resolution)
        // suppress the checkerboard-on-surface look of a raw screen read.
        float blur = 1.25 + 1.75 * clamp(optical_path, 0.0, 1.0);
        vec2 spread = texel * blur;
        vec3 light_behind = texture(backdrop_tex, uv).rgb * 0.44;
        light_behind += texture(backdrop_tex, clamp(uv +
            vec2(spread.x, 0.0), texel, vec2(1.0) - texel)).rgb * 0.14;
        light_behind += texture(backdrop_tex, clamp(uv -
            vec2(spread.x, 0.0), texel, vec2(1.0) - texel)).rgb * 0.14;
        light_behind += texture(backdrop_tex, clamp(uv +
            vec2(0.0, spread.y), texel, vec2(1.0) - texel)).rgb * 0.14;
        light_behind += texture(backdrop_tex, clamp(uv -
            vec2(0.0, spread.y), texel, vec2(1.0) - texel)).rgb * 0.14;
        // Dye filters ALL transmitted light (including the red channel):
        // otherwise an almost-white floor overexposes the upper crown.
        // Chromatic Beer-Lambert absorption must depend on EACH brick's
        // pigment. The former hard-coded RED absorption was incorrect for
        // blue/green gels and pushed upper layers toward plastic cyan.
        // Pale dyed channels survive; non-pigment channels are absorbed.
        vec3 absorption = mix(
            vec3(2.32), vec3(0.30),
            pow(clamp(pigment.rgb, vec3(0.0), vec3(1.0)),
                vec3(0.72)));
        vec3 beer = exp(-clamp(optical_path, 0.0, 2.5) *
            absorption);
        vec3 dye_filter = mix(
            pigment.rgb,
            sqrt(max(pigment.rgb, vec3(0.0001))), 0.50);
        vec3 transmitted_light = light_behind * beer * dye_filter;
        float passage = exp(-1.24 * optical_path);
        float transmitted_share = backdrop_strength *
            (0.24 + 0.42 * passage) * (1.0 - grazing * 0.65);
        // Organic gelatin is clearest through the front flat volume.
        // Opaque depth and the two-render-pass separation are preserved,
        // while transmitted BACKGROUND content becomes more visible.
        float center_window = smoothstep(0.18, 0.86, facing) *
            (0.66 + 0.34 * exp(-0.75 * optical_path));
        transmitted_share = mix(transmitted_share,
            backdrop_strength * (0.37 + 0.42 * center_window) *
                (1.0 - grazing * 0.35), organic_gel);
        vec3 soft_dye = pigment.rgb * (
            0.43 + 0.14 * exp(-0.9 * optical_path));
        vec3 jelly_transmission = mix(transmitted_light,
            transmitted_light * 0.84 + soft_dye * 0.22,
            organic_gel);
        optical = mix(optical, jelly_transmission,
            clamp(transmitted_share, 0.0, 0.83));
    }
    // Physically inspired dye depth only; never alpha blend the socket.
    ALBEDO = clamp(optical, vec3(0.0), vec3(1.0));
    // Alpha is intentionally absent in this optically dense first-pass test.
    float base_roughness = mix(mix(0.095, 0.20, gel_milkiness),
        0.24, highlight_softness);
    ROUGHNESS = mix(base_roughness, 0.31, organic_gel);
    float base_specular = mix(mix(0.92, 0.64, gel_milkiness),
        0.30, highlight_softness);
    SPECULAR = mix(base_specular, 0.24, organic_gel);
    METALLIC = 0.0;
    // Do not illuminate the entire surface from within like neon plastic.
    float emission_baseline = 0.023 +
        body_wall * internal_window * 0.018 +
        bulk_optics * (0.022 + crown * 0.008);
    EMISSION = pigment.rgb * mix(emission_baseline,
        0.008 + 0.008 * crown, organic_gel);
}
