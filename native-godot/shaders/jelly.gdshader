shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural glossy gel: softly transparent center, opaque-looking bright
// Fresnel edges, layered candy tint and camera-facing specular highlights.
// Designed for Godot 4 Compatibility (OpenGL ES 3); no external textures.
uniform vec4 candy_tint : source_color = vec4(1.0, 0.4, 0.6, 1.0);
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 1.0) = 1.0;
uniform float gel_opacity : hint_range(0.0, 1.0) = 0.94;
uniform float mismatch : hint_range(0.0, 1.0) = 0.0;
uniform float sheen : hint_range(0.0, 1.0) = 0.42;
uniform float studio_glass : hint_range(0.0, 1.0) = 0.0;
uniform float gel_spring : hint_range(0.0, 1.0) = 0.0;
// Short lived, signed viscoelastic compression. The impulse is delayed
// until the brick actually contacts its support: positive squash, then
// a small negative elastic overshoot, finally a decayed resting pose.
uniform float studio_squash : hint_range(-1.0, 1.0) = 0.0;
// Optional strain-localization for a contact-driven solid-gel pressure
// well. Kept at zero for ghosts and all 21 puzzle materials; enabling it
// on real studio solids costs nothing when studio_squash == 0.
uniform float studio_pressure_strength : hint_range(0.0, 1.0) = 0.0;
// Light travels through a changing optical path when a real gel body is
// squeezed: a pressure dent gets slightly thinner/translucent while
// displaced gel around its mid-wall gets optically thicker/darker.
// Opt-in only for the finished studio, not for puzzles or translucent
// placement ghosts. No screen reads, textures or rendering passes.
uniform float studio_strain_optics : hint_range(0.0, 1.0) = 0.0;
// Impact wave on the real studio body only. A phase of zero is idle;
// the shared shader skips the expensive radial math for 21 puzzles/ghosts.
uniform float studio_wave_phase : hint_range(0.0, 1.0) = 0.0;
uniform float studio_wave_gain : hint_range(0.0, 1.0) = 0.0;
// A slower second gel eigenmode, driven by each IMPACT'S own tween clock.
// No global TIME: two bricks hit at different times must not immediately
// snap into the same fast rubber vibration. Resting studio and the original
// 21 puzzle materials keep both uniforms at zero.
uniform float studio_jiggle_phase : hint_range(0.0, 1.0) = 0.0;
uniform float studio_jiggle_gain : hint_range(0.0, 1.0) = 0.0;
// Local X/Z origin in the RECEIVING brick's footprint (not world space).
uniform vec2 studio_wave_center = vec2(0.5, 0.5);
// Independent authored-puzzle landing compression, zero for placement
// ghosts and for studio bricks. Geometry is deformed about its actual
// rotated bounding footprint; no collision, logical cell or save changes.
uniform float puzzle_squash : hint_range(-1.0, 1.0) = 0.0;
// LOCAL X/Z drag vector, shared by studio and puzzle translucent ghosts.
// Placed bricks and idle previews keep this at zero; no extra GPU pass.
// One existing vertex shader path, no extra geometry or draw passes.
uniform vec2 studio_drag = vec2(0.0, 0.0);
// TRUE body footprint (1/2/3 cells, X or Z). Centre-aware bulging
// prevents long bars drifting sideways when the gel compresses.
uniform vec2 studio_span = vec2(1.0, 1.0);
uniform float studio_pigment : hint_range(0.0, 1.0) = 0.0;
uniform float optical_depth : hint_range(0.0, 1.0) = 0.0;
// Opt-in studio pigment absorption through the existing rounded walls.
// The authored puzzles and translucent placement ghosts stay at zero.
// A single-pass thickness approximation, NOT physical ray refraction.
uniform float gel_depth_optics : hint_range(0.0, 1.0) = 0.0;
uniform float studio_finish : hint_range(0.0, 1.0) = 0.0;
// Independent, camera-reactive lacquer bead along molded bevels.
// Defaults to zero for all 21 puzzle levels and legacy materials.
uniform float studio_wet_edge : hint_range(0.0, 1.0) = 0.0;
// A virtual product-photo window that visibly bends across molded wall
// normals. Zero for puzzles and translucent placement ghosts.
uniform float studio_light_card : hint_range(0.0, 1.0) = 0.0;
// Lens-like gel beneath each physical stud and between supported layers.
// Zero for all puzzle materials and for placement ghosts. A tiny local
// calculation on existing meshes: no extra alpha layers or draw calls.
uniform float studio_interlock : hint_range(0.0, 1.0) = 0.0;
// Subtle dye bleeding at an ACTUAL stacked interface: upper brick receives
// the weighted pigments of its directly supporting cells. All zero at rest
// for loose bricks, preview ghosts and the 21 classic puzzle levels.
uniform vec4 studio_contact_dye : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 studio_contact_center = vec2(0.5, 0.5);
uniform float studio_contact_extent : hint_range(0.0, 2.0) = 0.0;
// 0: long dimension along X; 1: long dimension along Z. Even 1-cell bricks
// use this so the two real stud lanes always meet the correct optical roots.
uniform float studio_stud_axis : hint_range(0.0, 1.0) = 0.0;
// Video-directed pigmented gel transmission: a subtly brighter body core
// with a deeper dyed silhouette. Isolated from puzzles and ghost previews.
// Built into the existing fragment pass; no screen texture or refraction.
uniform float studio_transmission : hint_range(0.0, 1.0) = 0.0;
// Premium lacquer for placed puzzle pieces. Preview ghosts and the studio
// use their existing independent material paths; no extra draw calls.
uniform float puzzle_lacquer : hint_range(0.0, 1.0) = 0.0;
varying vec3 jelly_local;
varying vec3 jelly_surface_normal;
// Interpolated physical strain from the ACTUAL vertex deformation. This
// prevents a separate procedural fragment pattern from drifting off the
// 3D geometry. Negative: dent/thinner cap. Positive: material thickening.
varying float jelly_optic_strain;

void vertex() {
    jelly_local = VERTEX;
    jelly_optic_strain = 0.0;
    // Preserve volume on impact rather than scaling a solid block like
    // rubber. The true supporting underside is anchored; the middle
    // expands outwards as the raised top and studs squash vertically.
    // Body vertices are authored in 1/2/3-cell local coordinates, while
    // instanced studs have their own little +/-0.136 local footprint.
    // Apply radial deformation about the body centre ONLY to the shell;
    // tenons bulge about their own local origin instead of sliding away.
    // All 21 puzzle materials and idle studio Jelly skip this whole branch.
    float compression = studio_glass > .001 ? studio_squash :
        (puzzle_lacquer > .5 ? puzzle_squash : 0.0);
    if (abs(compression) > .001) {
        float normalized_y = clamp((jelly_local.y - .055) / .75, 0.0, 1.0);
        float side_bulge = sin(normalized_y * PI);
        float volume_change = compression * .145;
        VERTEX.y -= volume_change * normalized_y;
        if (jelly_local.y < .59) {
            // The shell spans the FULL rotated body. An impact on one end
            // of a three-cell brick must not inflate the opposite end as
            // strongly as the contacting wall. Keep the SAME vertical
            // profile and stud deformation as the established gel shader;
            // only the shell's side bulge receives a local falloff.
            // The wave centre is set before tweens begin, even for
            // multiple supports. At rest there is no extra fragment cost.
            float local_squash = 1.0;
            if (studio_glass > .001 && studio_wave_gain > .001) {
                float impact_span = max(studio_span.x, studio_span.y);
                float contact_radius = .26 + impact_span * .42;
                float away = length(jelly_local.xz - studio_wave_center);
                float concentrated = 1.0 - smoothstep(.12,
                    contact_radius, away);
                local_squash = mix(.42, 1.0, concentrated);
            }
            VERTEX.xz += (jelly_local.xz - studio_span * .5) *
                compression * .14 * side_bulge * local_squash;
        } else {
            // Physical studs use a separate instanced local mesh. Never
            // sample the full-body contact centre on their small +/-X/Z
            // positions, or a displaced tenon would detach from its root.
            VERTEX.xz += jelly_local.xz * compression *
                .08 * side_bulge;
        }
        NORMAL = normalize(vec3(
            NORMAL.x * (1.0 - compression * .11 * side_bulge),
            NORMAL.y * (1.0 + compression * .15),
            NORMAL.z * (1.0 - compression * .11 * side_bulge)));
        // A real gel contact also dents the UPPER surface. The existing
        // squash scaled the entire body nearly uniformly: its crown
        // looked rigid and plastic while the side expanded. Give the
        // compression a bounded, localized pressure well and redistribute
        // a little of that material into the neighbouring mid-wall.
        // The real lower socket (<.12) stays fixed; no CPU soft-body
        // simulation, new geometry or fragment pass is required.
        // The 21 puzzle materials and translucent ghost are unchanged.
        if (studio_glass > .001 && studio_pigment > .82 &&
                studio_pressure_strength > .001) {
            float stud_domain = step(.586, jelly_local.y);
            // Each actual stud's root position was encoded by the
            // Godot MultiMesh, unlike the body, which uses its mesh XZ.
            // Sharing this coordinate makes an indentation on the crown
            // continue directly through the roots of adjacent studs.
            vec2 pressure_xz = jelly_local.xz +
                INSTANCE_CUSTOM.rg * (4.0 * stud_domain);
            vec2 pressure_vector = pressure_xz - studio_wave_center;
            float pressure_distance = length(pressure_vector);
            vec2 pressure_direction = pressure_vector /
                (pressure_distance + .0001);
            float pressure_radius = .39 +
                .135 * max(studio_span.x, studio_span.y);
            float pressure_footprint = 1.0 - smoothstep(.085,
                pressure_radius, pressure_distance);
            float pressure_crown = smoothstep(.405, .567, jelly_local.y);
            float upper_skin = mix(pressure_crown, 1.0, stud_domain);
            // Approximate viscoelastic strain: near the real support,
            // the broad cap dips by at most .033 while the nearby walls
            // swell by at most .023. It naturally reverses during the
            // small negative rebound and becomes exactly zero at rest.
            float pressure_well = compression * studio_pressure_strength *
                pressure_footprint * upper_skin;
            VERTEX.y -= .033 * pressure_well;
            float side_release = smoothstep(.105, .215,
                jelly_local.y) * (1.0 - smoothstep(.39, .515,
                jelly_local.y)) * (1.0 - stud_domain);
            float volume_return = compression * studio_pressure_strength *
                pressure_footprint * side_release;
            VERTEX.xz += pressure_direction * (.023 * volume_return);
            // Store just one signed scalar; the GPU interpolates it
            // across the same pressure-deformed triangles. Outer-wall
            // dye travels a little farther through expelled jelly.
            // Inner crown becomes optically thinner and clearer.
            jelly_optic_strain = clamp(volume_return * .85 -
                pressure_well * .72, -.90, .90);
            // The indentation changes surface *slope*, not just
            // position: wet speculars bend inward around the pressure
            // well and outward where material bulges along the wall.
            NORMAL = normalize(NORMAL +
                vec3(-pressure_direction.x, 0.0,
                    -pressure_direction.y) * (.095 * pressure_well) +
                vec3(pressure_direction.x, 0.0,
                    pressure_direction.y) * (.045 * volume_return));
        }
    }
    // A bounded contact ripple travels across the molded SIDE WALL from
    // the actual support footprint. Keep both the bottom socket and the
    // top crown fixed so studs never detach from their parent shell.
    // Only a live studio material evaluates this branch; no new draw pass,
    // mesh, screen buffer, physical collider or global TIME-dependent wobble.
    if (studio_glass > .001 && studio_wave_gain > .001 &&
            studio_wave_phase > .001 && studio_wave_phase < .999 &&
            jelly_local.y < .57) {
        // Keep the socket firmly anchored while allowing the softened
        // upper bevel to lag behind the mid-wall. The molded stud roots
        // remain fixed: the studio body/tenon meshes are separate draws.
        float side_band = smoothstep(.095, .205, jelly_local.y) *
            (1.0 - smoothstep(.475, .565, jelly_local.y));
        vec2 radial = jelly_local.xz - studio_wave_center;
        float radial_distance = length(radial);
        vec2 radial_direction = radial / (radial_distance + .0001);
        // A height-dependent phase offset gives the dense wall rows a
        // soft traveling crest rather than moving the whole face at once.
        float wave_radius = studio_wave_phase *
            (max(studio_span.x, studio_span.y) * .69 + .42) -
            (jelly_local.y - .30) * .115;
        float wave_delta = radial_distance - wave_radius;
        float moving_ring = 1.0 - smoothstep(.075, .42,
            abs(wave_delta));
        float wave_time = sin(studio_wave_phase * PI);
        float damped_pulse = wave_time *
            moving_ring * side_band * studio_wave_gain;
        VERTEX.xz += radial_direction * (damped_pulse * .082);
        VERTEX.y -= damped_pulse * .018;
        // Change wet-gel wall normals around the ring's SLOPE as well
        // as moving vertices. The previous normal only brightened the
        // outer extremities of three-cell bars and hid the moving crest.
        float radial_slope = clamp(wave_delta / .30, -1.0, 1.0) *
            moving_ring * side_band * studio_wave_gain * wave_time;
        NORMAL = normalize(NORMAL +
            vec3(radial_direction.x, 0.0, radial_direction.y) *
            (damped_pulse * .12 + radial_slope * .19));
    }
    // Secondary viscous standing wave: ~1.1 s after actual contact.
    // Two coherent spatial modes operate inside this SINGLE active branch.
    // 1. Local radial swell in the middle walls, anchored at the socket.
    // 2. A delayed, much smaller bending of the upper crown + studs.
    // The studio's stud MeshInstance is a shared MultiMesh: its own mesh
    // has local XZ around zero, not the true 1/2/3-cell footprint. Every
    // instance carries its real root XZ in INSTANCE_CUSTOM.rg / 4.0.
    // This keeps every tip driven by the same spatial impulse as the
    // crown immediately underneath it, including rotated long bars.
    // Puzzle materials, ghosts and resting studios skip the entire path.
    if (studio_glass > .001 && studio_pigment > .82 &&
            studio_jiggle_gain > .001 && studio_jiggle_phase > .001 &&
            studio_jiggle_phase < .999) {
        float viscous_decay = exp(-studio_jiggle_phase * 3.2);
        float separation = max(studio_span.x, studio_span.y);
        // Crown and stud origins must be expressed in the SAME brick
        // coordinates. Stud roots begin at y=.592 while the highest
        // crown centre ends at y=.578, so these domains never overlap.
        float stud_domain = step(.586, jelly_local.y);
        vec2 footprint_xz = jelly_local.xz +
            INSTANCE_CUSTOM.rg * (4.0 * stud_domain);
        vec2 impact_vector = footprint_xz - studio_wave_center;
        float impact_distance = length(impact_vector);
        float near_support = 1.0 - smoothstep(.25,
            separation * .75 + .25, impact_distance);
        if (stud_domain < .5) {
            float anchored_wall = smoothstep(.085, .215, jelly_local.y) *
                (1.0 - smoothstep(.445, .557, jelly_local.y));
            vec2 normal_direction = impact_vector /
                (impact_distance + .0001);
            float lag_phase = studio_jiggle_phase * TAU * 2.65 -
                impact_distance * 1.55;
            float oscillation = sin(lag_phase) * viscous_decay *
                studio_jiggle_gain * anchored_wall *
                mix(.36, 1.0, near_support);
            VERTEX.xz += normal_direction * (.068 * oscillation);
            VERTEX.y -= .015 * oscillation;
            NORMAL = normalize(NORMAL +
                vec3(normal_direction.x, 0.0, normal_direction.y) *
                (.16 * oscillation));
        }
        // The one-ring crown mesh bends rather than moving as a single
        // triangle fan. A tiny shared displacement crosses seamlessly
        // from upper shoulder (y>.44) to stud roots (y=.592).
        // Additional elastic lag affects ONLY the stud upper portion,
        // keeping each real root seated in the moving jelly surface.
        // The onset envelope starts at zero so no airborne/impact pop.
        float upper_weight = smoothstep(.438, .568, jelly_local.y);
        float tip_weight = smoothstep(.613, .789, jelly_local.y) *
            stud_domain;
        vec2 sway_axis = normalize(
            impact_vector * .26 + vec2(.43, -.34));
        float delayed_mode = sin(studio_jiggle_phase * TAU * 2.65 - .38) *
            smoothstep(.001, .09, studio_jiggle_phase) *
            viscous_decay * studio_jiggle_gain;
        float top_energy = delayed_mode * mix(.58, 1.0, near_support);
        VERTEX.xz += sway_axis * top_energy *
            (.014 * upper_weight + .011 * tip_weight);
        VERTEX.y += top_energy *
            (.006 * upper_weight + .002 * tip_weight);
        NORMAL = normalize(NORMAL +
            vec3(sway_axis.x, 0.0, sway_axis.y) *
            (.10 * top_energy * upper_weight));
    }
    // Resting jelly should not evaluate two trigonometric functions for
    // every vertex on every frame. Only a real impact enables this path.
    if (impact > .001) {
        float ripple = sin(VERTEX.x * 8.4 + VERTEX.z * 5.1 +
            VERTEX.y * 3.2);
        VERTEX.y += impact * ripple * (0.05 + abs(VERTEX.y) * 0.04);
        VERTEX.x += impact * cos(VERTEX.z * 6.3 + VERTEX.y * 4.4) * 0.038;
    }
    // Real volume-level reaction rather than only rotating a rigid brick.
    // Anchor the lower surface while the upper gel bulges and ripples.
    // The effect is disabled for every legacy puzzle (gel_spring=0).
    // Uniform branch skips both trigonometric waves completely for idle
    // jelly and all 21 resting authored puzzle pieces on mobile GPUs.
    // The translucent puzzle ghost shares the studio's low-cost gel motion.
    // The placed studio uses the deterministic damped mode above;
    // retain legacy TIME-driven elasticity exclusively for placement
    // ghosts and classic puzzle previews. Otherwise the simultaneous
    // 18/22 rad/s rubber buzz overwhelms the slower gelatin inertia.
    if (gel_spring > .001 && (studio_glass > .001 || gel_opacity < .60) &&
            !(studio_glass > .001 && studio_pigment > .82 &&
            studio_jiggle_gain > .001)) {
        float height_weight = smoothstep(.055, .82, jelly_local.y);
        float oscillation = sin(TIME * 22.0 + jelly_local.x * 1.9 +
            jelly_local.z * 1.3);
        float spring = gel_spring * height_weight *
            (studio_glass > .001 ? studio_glass : .58);
        VERTEX.x += spring * oscillation * .050;
        VERTEX.z += spring * cos(TIME * 18.0 +
            jelly_local.z * 2.15 - jelly_local.x) * .032;
        VERTEX.y -= spring * .029 * (0.62 + 0.38 * oscillation);
    }
    // A light, direction-aware viscous lag. The foot stays planted while
    // the upper gelatin and its actual studs trail the finger. At rest,
    // both the dot-product branch and all deformation vanish.
    if ((studio_glass > .001 || gel_opacity < .60) &&
            dot(studio_drag, studio_drag) > .000001) {
        float drag_height = smoothstep(.12, .78, jelly_local.y);
        VERTEX.xz -= studio_drag * (.105 * drag_height);
        NORMAL = normalize(NORMAL + vec3(
            studio_drag.x * .06 * drag_height,
            0.0,
            studio_drag.y * .06 * drag_height));
    }
    // Keep material thickness/crown masks in object space. NORMAL in
    // fragment() is view-space and changes when the camera orbits.
    jelly_surface_normal = NORMAL;
}

void fragment() {
    // Studio's recessed underside socket is physically modeled for stud
    // clearance and real shadow-caster geometry. However, its downward
    // interior ceiling and pocket walls show THROUGH 0.94-alpha dyed gel
    // as huge dark, angular chevrons when viewed from above (user's
    // Android screenshot). Their sharply triangulated silhouette is not
    // a visible outer surface of a filled gelatin brick.
    // Suppress ONLY the inward/downward socket triangles in the color
    // pass: y=.055..265, explicitly flat downward normals. Exterior
    // bevels (-.84 normal Y), all real studs, shadows, and the 21 puzzle
    // materials remain intact. The pocket remains in the mesh to seat studs.
    if (studio_glass > .001 && jelly_surface_normal.y < -.985 &&
            jelly_local.y > .054 && jelly_local.y < .267) {
        discard;
    }
    vec3 n = normalize(NORMAL);
    vec3 eye = normalize(VIEW);
    // Preserve the legacy puzzle finish; studio geometry uses its own up.
    vec3 surface_normal = normalize(jelly_surface_normal);
    float surface_up = mix(n.y, surface_normal.y, step(.001, studio_glass));
    float facing = clamp(dot(n, eye), 0.0, 1.0);
    float fresnel = pow(1.0 - facing, 2.25);
    float height_grad = smoothstep(0.01, 0.45, jelly_local.y);
    // The finished molded candy deliberately replaces almost all of
    // this high-frequency cloudy pigment. Skip its sin/cos pair on
    // polished bricks; retain the legacy cloud for the 21 puzzle levels
    // and the translucent placement preview.
    float dense = 0.0;
    if (studio_finish < .75 && puzzle_lacquer < .5) {
        dense = sin(jelly_local.x * 5.8 + jelly_local.z * 3.6) *
            cos(jelly_local.z * 7.3 - jelly_local.y * 5.0);
    }
    float inner_glow = smoothstep(.02, .4, jelly_local.y);
    // The photographed molded studio has a clean lacquer skin. Avoid
    // evaluating two high-frequency sines + pow on all its settled pixels.
    // Retain the original microbubbles only in the 21 puzzle materials
    // and the faint placement ghost, where the original look is desired.
    float bubble = 0.0;
    if (studio_finish < 0.75 && puzzle_lacquer < .5) {
        bubble = pow(max(sin(jelly_local.x * 23.0) *
            sin(jelly_local.z * 25.0), 0.0), 18.0);
    }
    float softbox = pow(max(dot(n,
        normalize(vec3(-.38, .65, .65))), 0.0), 19.0);
    // Studio lighting must separate the glossy upper surface from the
    // dense, light-absorbing sides. Without this the whole brick looks like
    // a pale flat rectangle on a white backdrop.
    float top_light = smoothstep(.12, .90, surface_up);
    float side_absorption = mix(.62, 1.04, top_light);
    vec3 base = candy_tint.rgb *
        (0.84 + height_grad * .11 + dense * .032) * side_absorption;
    base = mix(base, vec3(1.0, .99, 1.0), fresnel * .18);
    // The former high-frequency white bubble print looked like dust on
    // solid-color candy. Preserve it for the puzzle; the photo studio
    // gets clean, injection-molded glossy skin instead.
    base += bubble * detail * .065 * (1.0 - studio_finish);
    base += softbox * detail * .21 * (0.5 + top_light * .5) *
        (1.0 - studio_finish * .65);
    // A slow, thin studio-light reflection travels across the sculpted
    // candy surface. Uses local coordinates and TIME; no textures, extra
    // lights, screen sampling or per-frame script updates on Android.
    // Studio materials have no moving glint. Avoid evaluating TIME,
    // fract and its band smoothsteps in their fragment shader path.
    if (studio_glass < .001) {
        float sweep = fract(TIME * .125 + jelly_local.x * .20 +
            jelly_local.z * .075);
        float polished_strip = 1.0 - smoothstep(.0, .15,
            abs(sweep - .55));
        float glint = polished_strip * sheen * detail *
            (0.09 + height_grad * .13) * smoothstep(.17, .85, facing);
        base += vec3(.96, .98, 1.0) * glint;
    }
    // A misplaced piece stays recognizably its own candy color.
    // Only its rim takes a restrained, amber backlit accent.
    // Studio pieces have slightly denser dyed sides, a polished top and
    // a milky meniscus along the grazing edge. The authored puzzle remains
    // unchanged at studio_glass=0.
    vec3 jelly_color = mix(base, vec3(1.0, .64, .20),
        mismatch * fresnel * .38);
    jelly_color *= 1.0 - studio_glass * (1.0 - top_light) * .13;
    jelly_color += vec3(.94, .97, 1.0) * studio_glass * fresnel * .095;
    // Two broad photographic softboxes, using surface normals rather than
    // extra shadow-casting lights or a texture: no mobile GPU memory cost.
    // Uniform branch: avoid FOUR expensive pow() highlights on the
    // original 21-level puzzle shader and any non-studio geometry.
    if (studio_glass > .001) {
        float studio_key = pow(max(dot(n,
            normalize(vec3(-.48, .81, .33))), 0.0), 10.0);
        float studio_fill = pow(max(dot(n,
            normalize(vec3(.65, .55, -.36))), 0.0), 17.0);
        jelly_color += studio_glass * (
            vec3(1.0, .99, .98) * studio_key * .17 +
            vec3(.82, .92, 1.0) * studio_fill * .095);
        // Wide white studio streak plus a narrower crisp beveled catch.
        float lens_reflection = pow(max(dot(reflect(-eye, n),
            normalize(vec3(-.54, .69, .49))), 0.0), 6.0);
        float white_line = pow(max(dot(n,
            normalize(vec3(.14, .68, .72))), 0.0), 31.0);
        jelly_color += studio_glass *
            (vec3(1.0, .99, 1.0) * lens_reflection * .14 +
            vec3(.91, .96, 1.0) * white_line * .10);
    }
    // Slightly darker color transmission through deep sidewalls prevents
    // pale, weightless slabs against the white cyclorama.
    jelly_color *= 1.0 - studio_glass * (1.0 - top_light) * .052;
    // The previous studio brick was pastel because multiple white
    // highlights plus white background overwhelmed the candy tint. Reapply
    // an optically denser dyed core while leaving glossy rims alone.
    float dye_density = studio_pigment * (1.0 - fresnel * .52);
    vec3 pigment_body = candy_tint.rgb *
        mix(.68, .91, top_light) * (1.0 + height_grad * .045);
    jelly_color = mix(jelly_color, pigment_body, dye_density * .46);
    // Molded stud top: a narrow translucent raised rim catches the
    // softbox and separates the real tenons from generic plastic cylinders.
    // Only stud vertices reach local height > .68; no branch or texture.
    if (studio_pigment > .001 && jelly_local.y > .63) {
        float stud_mask = smoothstep(.64, .70, jelly_local.y);
        float stud_radius = length(jelly_local.xz);
        float crown_ring = 1.0 - smoothstep(.006, .030,
            abs(stud_radius - .108));
        jelly_color += vec3(.95, .98, 1.0) *
            crown_ring * stud_mask * studio_pigment *
            (.13 + .13 * studio_wet_edge);
        // Each real tenon in the video has a compact glassy highlight
        // moving across its rounded cap, not a uniformly bright white disk.
        // The narrow lens uses the same surface normals as the actual
        // authored stud mesh; it remains dyed and is disabled for ghosts.
        if (studio_transmission > .001) {
            float stud_cap = smoothstep(.72, .77, jelly_local.y);
            float light_lens = pow(max(dot(n,
                normalize(vec3(-.30, .88, .36))), 0.0), 14.0);
            vec3 cap_window = mix(candy_tint.rgb,
                vec3(1.0, .99, .97), .65);
            jelly_color = mix(jelly_color, cap_window,
                stud_cap * light_lens * studio_transmission * .26);
        }
    }
    // Single-pass approximation of color absorption through gelatin.
    // The rounded sides carry a longer apparent optical path than the
    // upward-facing cap; a weaker colored core keeps it candy-like rather
    // than painted plastic. Defaults to 0 for all 21 authored puzzles.
    // No screen texture/refraction, ray marches or additional draw calls.
    if (optical_depth > .001 && studio_glass > .001) {
        float side_path = 1.0 - smoothstep(-.12, .75, surface_up);
        float grazing_path = pow(1.0 - facing, 1.5);
        float path_length = clamp(.20 + side_path * .47 +
            grazing_path * .33, .0, 1.0);
        float absorption = optical_depth * path_length;
        vec3 dense_gel = candy_tint.rgb *
            mix(.63, .89, top_light);
        jelly_color = mix(jelly_color, dense_gel,
            absorption * .42 * (1.0 - fresnel * .30));
        // A thin internal meniscus catches diffused light at the
        // curvature of the genuine rounded studio mesh.
        jelly_color += vec3(.89, .96, 1.0) *
            optical_depth * fresnel * (1.0 - side_path * .50) * .085;
    }
    // Layered, subsurface-like light diffusion inside the sculpted volume.
    // All calculations are local and run only on the free 3D studio pieces.
    // Tiny, broad cloudy pockets are much more gel-like than sharp
    // procedural speckles; the color stays pigment-led, never whitewashed.
    // The photographed molded shell is deliberately optically clean.
    // Skip three trigonometric clouds per fragment on all solid bricks;
    // preserve the soft diffusion only on the translucent studio ghost.
    if (studio_glass > .001 && studio_finish < .75) {
        float cloud = sin(jelly_local.x * 3.7 + jelly_local.y * 4.1) *
            sin(jelly_local.z * 4.3 - jelly_local.y * 3.2);
        float slow_cloud = sin(jelly_local.x * 2.1 +
            jelly_local.z * 1.8 + jelly_local.y * 3.6);
        float milk = smoothstep(.08, .87,
            cloud * .42 + slow_cloud * .25 + .48);
        float center_light = smoothstep(.06, .38, jelly_local.y) *
            (1.0 - fresnel) * (1.0 - top_light * .48);
        vec3 inner_scatter = mix(candy_tint.rgb,
            vec3(.97, .97, 1.0), .28);
        jelly_color = mix(jelly_color, inner_scatter,
            studio_glass * center_light * milk * .095);
        // Narrow internal colored rim along the lower meniscus.
        // This is a cheap material cue, not screen-space refraction.
        float lower_edge = 1.0 - smoothstep(.065, .17, jelly_local.y);
        jelly_color += candy_tint.rgb *
            lower_edge * (1.0 - top_light) * studio_glass * .038;
    }
    // Art-directed candy finish, isolated from the 21 puzzle shapes.
    // The earlier studio shader accumulated five white light lobes and
    // then white clearcoat, washing saturated red/blue/green into pastel.
    // Restore a pigmented gel core, concentrating white into sharp
    // photographic highlights instead of coating every visible face.
    if (studio_finish > .001 && studio_glass > .001) {
        float top_face = smoothstep(.08, .90, surface_up);
        float polish = studio_finish * studio_glass;
        vec3 molded_pigment = candy_tint.rgb *
            mix(.73, .90, top_face);
        jelly_color = mix(jelly_color, molded_pigment,
            polish * .73 * (1.0 - fresnel * .28));
        // Two smooth environment-like softbox reflections calculated from
        // view and normal: no texture, extra scene light, or screen access.
        vec3 reflected_eye = reflect(-eye, n);
        float key_spec = pow(max(dot(reflected_eye,
            normalize(vec3(-.42, .75, .52))), 0.0), 13.0);
        float crisp_spec = pow(max(dot(reflected_eye,
            normalize(vec3(.57, .64, -.47))), 0.0), 36.0);
        jelly_color += vec3(1.0, .995, .98) *
            polish * (key_spec * .22 + crisp_spec * .15);
        // Colored thickness remains at the silhouette, where polished
        // gelatin looks visibly denser than a uniformly shaded plastic.
        jelly_color += candy_tint.rgb * polish * fresnel * .032;
    }
    // A narrow, continuous meniscus of white-box reflection follows the
    // REAL upper molded bevel (top ring y=.56, bevel y=.497-.538). Unlike
    // a screen-space halo it sticks to each moving jelly surface and
    // reacts to the actual camera angle and the smooth mesh normals.
    // Its small coverage preserves the saturated candy body underneath.
    if (studio_wet_edge > .001 && studio_glass > .001) {
        float bevel_height = 1.0 - smoothstep(.010, .070,
            abs(jelly_local.y - .522));
        float side_bevel = 1.0 - smoothstep(.58, .95, surface_up);
        float visible = smoothstep(.05, .48, facing);
        vec3 mirror = reflect(-eye, n);
        float light_direction = pow(max(dot(mirror,
            normalize(vec3(-.24, .16, .95))), 0.0), 6.0);
        float upper_liquid_rim = bevel_height * side_bevel *
            visible * (0.34 + light_direction * .66) *
            studio_wet_edge;
        // A broad, soft rectangular window on the vertical wall is
        // essential: the reference reflects actual white studio cards
        // *inside* the colored Jelly, not just a pencil-thin top line.
        // Use the surface's molded coordinates, not SCREEN_UV, so each
        // pane slides and sways WITH the 3D brick in the photo tower.
        float window_u = fract(jelly_local.x * .29 +
            jelly_local.z * .21 + .38);
        float soft_window = 1.0 - smoothstep(.045, .31,
            abs(window_u - .50));
        float lower_wall = smoothstep(.14, .24, jelly_local.y);
        float upper_wall = 1.0 - smoothstep(.39, .52, jelly_local.y);
        // Restrict to genuine vertical walls rather than relying on
        // eye-facing normals: the orbital camera can make a physically
        // visible colored wall nearly perpendicular to VIEW. In that
        // position the old angle gate erased the highlight entirely.
        float front_wall = 1.0 - smoothstep(.35, .82, abs(surface_up));
        float transmitted_window = soft_window * lower_wall *
            upper_wall * front_wall * studio_wet_edge;
        // Real dyed gel transmits part of its own pigment into white-box
        // reflections. A tinted card avoids the blown-out white patches
        // seen on yellow/coral in the first OpenGL QA iteration.
        vec3 photographic_white = mix(candy_tint.rgb,
            vec3(1.0, .99, .975), .78);
        jelly_color = mix(jelly_color, photographic_white,
            clamp(upper_liquid_rim * .50 +
                transmitted_window * .27, 0.0, .43));
    }
    // A dyed transparent Jelly block must reflect a large studio light
    // card ACROSS its vertical walls, not just on the rounded top.
    // Sample object-local coordinates: the stripe follows moving geometry
    // as a real reflection would, including the nine-layer sway animation.
    // The normal selects the direction ALONG the current wall. This avoids
    // putting the same diagonal, semi-random band on every rotated brick.
    // No texture reads, screen-space refraction, lights or draw calls.
    // The uniform branch skips this entirely for puzzle bricks and ghosts.
    if (studio_light_card > .001 && studio_glass > .001) {
        float wall_normal = 1.0 - smoothstep(.19, .70, abs(surface_up));
        float along_wall = mix(jelly_local.x, jelly_local.z,
            step(abs(surface_normal.z), abs(surface_normal.x)));
        float pane_position = fract(along_wall * .31 + .13);
        float wide_window = smoothstep(.11, .22, pane_position) *
            (1.0 - smoothstep(.44, .57, pane_position));
        float fine_window = smoothstep(.58, .62, pane_position) *
            (1.0 - smoothstep(.68, .72, pane_position));
        float body_height = smoothstep(.17, .23, jelly_local.y) *
            (1.0 - smoothstep(.43, .50, jelly_local.y));
        float photo_card = wall_normal * body_height *
            smoothstep(.12, .55, facing) * studio_light_card;
        // Keep the body candy-colored: even the bright window transmits
        // some pigment, rather than bleaching blue/green/yellow to white.
        vec3 window_tint = mix(candy_tint.rgb,
            vec3(.99, .995, 1.0), .76);
        jelly_color = mix(jelly_color, window_tint,
            clamp(photo_card * (wide_window * .46 +
                fine_window * .22), 0.0, .46));
        // Narrow color-rich shadow below the translucent inner wall:
        // gives the molded candy perceptible thickness above each socket.
        float bottom_density = 1.0 - smoothstep(.115, .26,
            jelly_local.y);
        jelly_color *= 1.0 - bottom_density * wall_normal *
            studio_light_card * .12;
        // Actual product-camera framing exposes the large flat TOP of each
        // brick far more than its small side walls. Add a wide rectangular
        // overhead reflection on that true molded crown (y=.56-.598),
        // feathered on both axes like a studio softbox. Studs at y>.64
        // receive no artificial painted patch. This fixes the old uniformly
        // matte candy slabs in the nine-floor reference photograph.
        float crown_only = smoothstep(.74, .98, surface_up) *
            (1.0 - smoothstep(.61, .70, jelly_local.y));
        float ceiling_u = fract(jelly_local.x * .25 + .13);
        float ceiling_v = fract(jelly_local.z * .42 + .22);
        float ceiling_panel = smoothstep(.10, .21, ceiling_u) *
            (1.0 - smoothstep(.71, .85, ceiling_u)) *
            smoothstep(.13, .25, ceiling_v) *
            (1.0 - smoothstep(.49, .69, ceiling_v));
        jelly_color = mix(jelly_color, window_tint,
            clamp(crown_only * ceiling_panel * studio_light_card *
                .34, 0.0, .34));
    }
    // The 21 puzzle bricks were diffuse pink/blue slabs with dotted noise.
    // Their REAL curved mesh already has y=.523 molded bevels and y=.56 tops.
    // Keep saturated dye in the volume; place white light ONLY in focused,
    // camera-dependent lacquer reflections and at the real rounded rim.
    // Uniform branch is disabled on preview ghosts and studio/gallery Jelly.
    if (puzzle_lacquer > .001 && studio_glass < .001) {
        float top_cap = smoothstep(.12, .88, surface_up);
        float dyed_side = mix(.66, .91, top_cap);
        vec3 candy_body = candy_tint.rgb * dyed_side;
        jelly_color = mix(jelly_color, candy_body,
            puzzle_lacquer * .70 * (1.0 - fresnel * .24));
        vec3 reflected_eye = reflect(-eye, n);
        float broad_card = pow(max(dot(reflected_eye,
            normalize(vec3(-.45, .76, .47))), 0.0), 13.0);
        float slim_card = pow(max(dot(reflected_eye,
            normalize(vec3(.58, .63, -.51))), 0.0), 32.0);
        float molded_bevel = 1.0 - smoothstep(.016, .075,
            abs(jelly_local.y - .523));
        float wall_bevel = 1.0 - smoothstep(.58, .94, surface_up);
        float rim = molded_bevel * wall_bevel *
            smoothstep(.035, .40, facing);
        jelly_color += puzzle_lacquer * (
            vec3(1.0, .995, .97) * broad_card * .23 +
            vec3(.92, .96, 1.0) * slim_card * .14 +
            vec3(.92, .98, 1.0) * rim * .16);
        // Restore the amber error rim after the pigment polish; otherwise
        // the smoother shader could hide an incorrect gameplay placement.
        jelly_color = mix(jelly_color, vec3(1.0, .58, .16),
            mismatch * fresnel * .38);
    }
    // The physical gel tenons must look embedded in the molded cap, rather
    // than independent plastic buttons sitting on a flat colored tile.
    // Studio meshes place two studs per segment at +/- .235 across the
    // short axis. Match those REAL MultiMesh positions in local object
    // space; frac() repeats the same optical roots for 1/2/3-cell bricks.
    // Using squared distance avoids an expensive sqrt per fragment.
    // Photo mode enhances the effect; ghost and 21 puzzles skip it entirely.
    if (studio_interlock > .001 && studio_glass > .001) {
        float along = mix(jelly_local.x, jelly_local.z,
            studio_stud_axis);
        float across = mix(jelly_local.z, jelly_local.x,
            studio_stud_axis);
        vec2 from_stud = vec2(fract(along) - .5,
            abs(across - .5) - .235);
        float stud_radius2 = dot(from_stud, from_stud);
        // y=.56-.598 is the continuous molded crown; at y>.61 the
        // raised actual stud has begun. Never paint a fake circle on studs.
        float crown = smoothstep(.78, .97, surface_up) *
            (1.0 - smoothstep(.61, .68, jelly_local.y));
        float seating = smoothstep(.019, .029, stud_radius2) *
            (1.0 - smoothstep(.052, .082, stud_radius2));
        float milky_halo = 1.0 - smoothstep(.039, .128,
            stud_radius2);
        vec3 dyed_meniscus = mix(candy_tint.rgb,
            vec3(.96, .99, 1.0), .47);
        // Dark dyed depression directly at the stud root, a broad
        // transmitted-light bloom outside it. Both track the true pose.
        jelly_color = mix(jelly_color, candy_tint.rgb * .70,
            crown * seating * studio_interlock * .25);
        jelly_color += dyed_meniscus * crown * milky_halo *
            studio_interlock * .115;
        // Cheap interior light diffusion through the mid-height, thick
        // vertical wall. We do NOT lower alpha: Android depth prepass
        // remains deterministic when 32 translucent Jelly bricks overlap.
        float wall = 1.0 - smoothstep(.30, .78, abs(surface_up));
        float inner_height = smoothstep(.17, .28, jelly_local.y) *
            (1.0 - smoothstep(.40, .50, jelly_local.y));
        vec3 inner_light = mix(candy_tint.rgb,
            vec3(.98, .995, 1.0), .39);
        jelly_color = mix(jelly_color, inner_light,
            wall * inner_height * (1.0 - fresnel * .67) *
            studio_interlock * .13);
    }
    // Candy-like optical thickness: a bright yet COLORED translucent
    // center and a denser silhouette. The previous stack was nearly opaque
    // because solid body alpha was .985, so its inner pigment variation and
    // contact refraction cues could not read against another jelly brick.
    // Approximate light transport in one Compatibility/GLES3 pass: avoid
    // expensive screen-space refraction, environment capture or raymarch.
    if (studio_transmission > .001 && studio_glass > .001) {
        float sidewall = 1.0 - smoothstep(.30, .83, abs(surface_up));
        float middle = smoothstep(.16, .28, jelly_local.y) *
            (1.0 - smoothstep(.42, .53, jelly_local.y));
        float center_window = sidewall * middle *
            smoothstep(.12, .86, facing) * studio_transmission;
        // Jelly must remain saturated, not wash to white. This tinted
        // inner light makes the translucent heart distinct from its rim.
        vec3 glowing_core = mix(candy_tint.rgb * .96,
            vec3(.99, .98, 1.0), .30);
        jelly_color = mix(jelly_color, glowing_core,
            center_window * .29);
        // Light travels farther through the side at grazing angles:
        // denser dye on the soft bevels makes real volumetric thickness
        // legible, even on a white studio cyclorama.
        float long_path = sidewall * middle *
            (1.0 - smoothstep(.05, .78, facing));
        vec3 absorbed_edge = candy_tint.rgb * .58;
        jelly_color = mix(jelly_color, absorbed_edge,
            long_path * studio_transmission * .22);
        // The molded LOWER meniscus accumulates concentrated pigment
        // without drawing a second fake shadow or changing geometry.
        float foot = 1.0 - smoothstep(.085, .20, jelly_local.y);
        jelly_color = mix(jelly_color, candy_tint.rgb * .67,
            sidewall * foot * studio_transmission * .14);
    }
    // The original reference video has a very thin glossy mold seam running
    // ACROSS each upright colored wall, where its top bevel begins. Our
    // 0.9.57 photos lost that line and read as flat extruded soap. Shade the
    // actual y=.473 ring on the existing mesh, not a floating overlay.
    // The lower fillet catches a smaller pigment-rich reflection, making
    // colored blocks appear to have a dense rounded shell.
    if (studio_transmission > .001 && studio_wet_edge > .5) {
        float vertical_wall = 1.0 - smoothstep(.31, .79, abs(surface_up));
        float upper_joint = 1.0 - smoothstep(.004, .045,
            abs(jelly_local.y - .474));
        float lower_joint = 1.0 - smoothstep(.006, .047,
            abs(jelly_local.y - .130));
        float legibility = smoothstep(.08, .55, facing);
        vec3 seam_white = mix(candy_tint.rgb,
            vec3(1.0, .995, .97), .74);
        jelly_color = mix(jelly_color, seam_white,
            clamp(upper_joint * vertical_wall * legibility *
                studio_wet_edge * .43, 0.0, .43));
        jelly_color += candy_tint.rgb * vertical_wall *
            lower_joint * studio_wet_edge * .085;
    }
    // Final *tinted* wet reflections are kept AFTER the pigment mixing.
    // Native PBR CLEARCOAT made solid Jelly turn opaque grey/white on the
    // actual Mesa Compatibility renderer. Never rely on that output for
    // mobile translucency. Instead, two bounded colored photographic
    // glints remain in the existing pigment shader and follow the real
    // vertex normals and camera. No new material pass or opaque overlay.
    if (studio_transmission > .001 && studio_glass > .001) {
        vec3 liquid_mirror = reflect(-eye, n);
        float wide_glint = pow(max(dot(liquid_mirror,
            normalize(vec3(-.43, .73, .53))), 0.0), 8.0);
        float tight_glint = pow(max(dot(liquid_mirror,
            normalize(vec3(.59, .62, -.52))), 0.0), 26.0);
        vec3 tinted_window = mix(candy_tint.rgb,
            vec3(1.0, .998, .99), .80);
        jelly_color = mix(jelly_color, tinted_window,
            clamp(studio_transmission * (wide_glint * .27 +
                tight_glint * .19), 0.0, .34));
    }
    // With outward faces restored, the old stacked white lobes bleach the
    // now-visible crown. Retain a dense dyed volume under wet highlights.
    if (studio_glass > .001) {
        vec3 volume_pigment = candy_tint.rgb * mix(.68, .93, top_light);
        jelly_color = mix(jelly_color, volume_pigment,
            studio_finish * .90 * (1.0 - fresnel * .60));
    }
    // The previous .085 studio GGX roughness and .50 specular added a
    // continuous WHITE plastic reflection on top of the hand-tinted light
    // cards. Widen and lower that native lobe, leaving the small tinted
    // shader reflections and the puzzle/ghost materials unchanged.
    // Approximate dyed light attenuation across an upright gel wall.
    // Uses existing object-local height and normals, no extra texture,
    // draw pass, screen read, ray march or per-frame CPU uniform updates.
    float depth_mix = gel_depth_optics * studio_glass;
    if (depth_mix > .001) {
        float wall = 1.0 - smoothstep(.22, .82, abs(surface_up));
        float mid_body = smoothstep(.10, .23, jelly_local.y) *
            (1.0 - smoothstep(.40, .54, jelly_local.y));
        float path_length = wall * (.36 + .48 * (1.0 - facing)) *
            (.54 + .46 * mid_body);
        // Optical thickness follows the interpolated deformation, not
        // world TIME: the displaced mid-wall holds more pigment while
        // the pressed crown transmits a little farther. The bounded
        // multiplier preserves the original pigmented resting image.
        // Multiplication executes only in the existing opt-in studio
        // depth branch; zero for every preview and authored puzzle.
        if (studio_strain_optics > .001 &&
                abs(jelly_optic_strain) > .001) {
            path_length *= clamp(1.0 + jelly_optic_strain *
                studio_strain_optics * .78, .60, 1.40);
        }
        // Rational attenuation is bounded and inexpensive on GLES3.
        // Each tint channel loses light in proportion to its dye
        // absorption, so red/blue walls stay saturated, not milky gray.
        vec3 extinction = (vec3(1.0) - candy_tint.rgb) *
            (.44 + path_length * .58);
        vec3 through_gel = candy_tint.rgb / (vec3(1.0) + extinction);
        jelly_color = mix(jelly_color, through_gel,
            clamp(depth_mix * wall * (.14 + path_length * .30),
                0.0, .40));
    }
    // A squeezed dyed-gel cap scatters a little more light through its
    // thinner skin, whereas the volume gathered in its neighbouring
    // middle wall looks deeper. Match the volume's exact vertex-strain
    // profile; avoid adding any white LED glow or artificial particles.
    // Idle / ghost / puzzles remain identical bit-for-bit via this gate.
    if (studio_glass > .001 && studio_pigment > .82 &&
            studio_strain_optics > .001 &&
            abs(jelly_optic_strain) > .001) {
        float thinner_cap = max(-jelly_optic_strain, 0.0) *
            studio_strain_optics;
        float denser_wall = max(jelly_optic_strain, 0.0) *
            studio_strain_optics;
        // Purely dyed transmission: lighter crown core, deeper sides.
        // The first version used blend weights <.10 on most vertices;
        // real Mesa screenshots showed no measurable optical variation.
        // Intensify ONLY the short-lived strain response while keeping
        // hues colored (never mix toward unpigmented white/grey).
        vec3 refracted_dye = candy_tint.rgb *
            (1.14 + .10 * top_light);
        jelly_color = mix(jelly_color, refracted_dye,
            clamp(thinner_cap * .46, 0.0, .37));
        jelly_color = mix(jelly_color, candy_tint.rgb * .42,
            clamp(denser_wall * .53, 0.0, .38));
    }
    // Two differently dyed jelly volumes transmit a faint mixture through
    // the lower sidewall of the upper brick, close to their REAL overlapping
    // grid cells. Deliberately no second material pass or fake white halo.
    // Upper studs are y>.59; they never receive this effect. The uniform
    // branch is idle for ghosts, loose pieces and classic puzzles.
    if (studio_glass > .001 && studio_contact_dye.a > .001) {
        float joining_wall = 1.0 - smoothstep(.30, .77, abs(surface_up));
        float joining_height = 1.0 - smoothstep(.095, .255, jelly_local.y);
        float radius = length(jelly_local.xz - studio_contact_center);
        float overlap_falloff = 1.0 - smoothstep(
            studio_contact_extent * .46,
            studio_contact_extent + .24, radius);
        float join_strength = joining_wall * joining_height *
            overlap_falloff * studio_contact_dye.a;
        vec3 mixed_dye = mix(candy_tint.rgb,
            candy_tint.rgb * studio_contact_dye.rgb, .46);
        jelly_color = mix(jelly_color, mixed_dye,
            clamp(join_strength * .47, 0.0, .40));
    }
    // A small tinted wet sheen rides the same *real* moving wavefront.
    // Enabled for less than a second after an actual studio impact;
    // no fragment cost on resting pieces, the 21 puzzles or ghosts.
    if (studio_glass > .001 && studio_wave_gain > .001 &&
            studio_wave_phase > .001 && studio_wave_phase < .999) {
        float ripple_wall = 1.0 - smoothstep(.30, .82, abs(surface_up));
        float ripple_height = smoothstep(.12, .22, jelly_local.y) *
            (1.0 - smoothstep(.42, .56, jelly_local.y));
        float ripple_distance = length(jelly_local.xz - studio_wave_center);
        float ripple_radius = studio_wave_phase *
            (max(studio_span.x, studio_span.y) * .69 + .42) -
            (jelly_local.y - .30) * .115;
        float ripple_band = 1.0 - smoothstep(.06, .34,
            abs(ripple_distance - ripple_radius));
        float ripple_intensity = ripple_wall * ripple_height *
            ripple_band * studio_wave_gain * sin(studio_wave_phase * PI);
        vec3 tinted_wave_glint = mix(candy_tint.rgb,
            vec3(.98, .99, 1.0), .24);
        jelly_color = mix(jelly_color, tinted_wave_glint,
            clamp(ripple_intensity * .12, 0.0, .12));
    }
    ALBEDO = jelly_color;
    METALLIC = .015;
    float base_roughness = mix(mix(mix(.25, .115, detail), .085,
        studio_glass * .56), .11, puzzle_lacquer);
    ROUGHNESS = mix(base_roughness, .215, depth_mix);
    SPECULAR = mix(mix(.98, .50, studio_glass), .17, depth_mix);
    // Real wet gel becomes momentarily slicker when stretched and
    // released. A tiny, pigment-safe roughness change follows the
    // same bounded independent oscillation, then settles exactly back.
    // This is a uniform-only scalar on the existing fragment pass.
    if (studio_glass > .001 && studio_pigment > .82 &&
            studio_jiggle_gain > .001 && studio_jiggle_phase > .001 &&
            studio_jiggle_phase < .999) {
        float transient_wet = studio_jiggle_gain *
            (1.0 - smoothstep(0.0, .92, studio_jiggle_phase));
        ROUGHNESS = max(.16, ROUGHNESS - transient_wet * .045);
    }
    EMISSION = candy_tint.rgb * (.018 + inner_glow * .023) +
        vec3(.34, .42, .65) * fresnel * .19 +
        vec3(1.0, .95, 1.0) * softbox * detail * .12 +
        vec3(.98, .44, .06) * mismatch * (fresnel * .36 + .035);
    // Product gel is dyed, not a neon LED: reduce unwanted washed-out
    // emission while leaving the existing puzzle material untouched.
    EMISSION *= 1.0 - studio_glass * .30 - puzzle_lacquer * .37;
    // The actual 2824.mp4 reference has optically different dyes: amber
    // and lemon transmit light farther, while royal blue and ruby retain
    // much denser silhouettes. A single uniform opacity for every color
    // made the five photographed candies look like the same plastic.
    // Compute pigment absorption from the EXISTING tint (no new uniforms,
    // textures, draw passes or color-specific mesh variants).
    float optical_dye = 0.0;
    // Shared shader is also used for 21 classic puzzles. Their optical
    // uniforms stay zero, so skip all pigment classification operations.
    if (studio_glass > .001 && studio_transmission > .001) {
        float golden_pigment = smoothstep(.68, .96, candy_tint.r) *
            smoothstep(.53, .82, candy_tint.g) *
            (1.0 - smoothstep(.45, .80, candy_tint.b));
        float royal_pigment = smoothstep(.54, .88, candy_tint.b) *
            (1.0 - smoothstep(.38, .75, candy_tint.r));
        float ruby_pigment = smoothstep(.78, .96, candy_tint.r) *
            (1.0 - smoothstep(.30, .66, candy_tint.g));
        optical_dye = studio_transmission *
            (royal_pigment * .032 + ruby_pigment * .014 -
            golden_pigment * .042);
    }
    // Native gel has real alpha; the outline becomes more solid as the
    // viewing angle becomes glancing, a common candy/glass cue.
    // Studio candy must appear deeply colored, not fade into its white
    // background. Keep modest transmission in front-facing surfaces and
    // almost-solid rounded edges. No expensive screen-space refraction.
    float studio_alpha = gel_opacity + fresnel *
        mix(.06, .16, studio_transmission) -
        facing * (1.0 - studio_pigment) * .065;
    float puzzle_alpha = gel_opacity + fresnel * .023;
    float light_path_alpha = optical_depth * studio_glass *
        (1.0 - top_light) * .025;
    // Alpha must also carry the visual thickness of a molded gel wall.
    // On the studio body only, the central upright face transmits more
    // light than the thicker corners and the top/bottom meniscus.
    // Preserve the original 21 puzzles, ghost previews, studs and
    // collision/contact logic. No screen read or additional draw pass.
    float body_wall = 1.0 - smoothstep(.25, .78, abs(surface_up));
    float central_height = smoothstep(.13, .28, jelly_local.y) *
        (1.0 - smoothstep(.40, .54, jelly_local.y));
    float straight_view = smoothstep(.22, .88, facing);
    float central_transmission = body_wall * central_height *
        straight_view * studio_transmission * studio_glass;
    float thickness_opacity = body_wall * (1.0 - facing) *
        studio_transmission * studio_glass;
    float tinted_alpha = mix(puzzle_alpha, studio_alpha, studio_glass) +
        light_path_alpha + optical_dye -
        central_transmission * .048 + thickness_opacity * .016;
    // Denser compressed gel looks less transparent at its sides; the
    // indented cap slightly increases transmission. Small signed alpha
    // variation only during a real physical squeeze. Do not turn it into
    // an opaque plastic sheet when two bricks overlap.
    if (studio_glass > .001 && studio_pigment > .82 &&
            studio_strain_optics > .001) {
        tinted_alpha += jelly_optic_strain *
            studio_strain_optics * .036;
    }
    ALPHA = clamp(tinted_alpha, 0.0, 1.0);
    // The stud and its rounded side are molded from the SAME pigmented
    // solid gel as the body, not a thin hollow glass cylinder. In the
    // existing 0.94-alpha material, the stud's rear wall shone THROUGH its
    // front wall and made a dark open ring in real Android/Mesa renders.
    // Fill only the upper 3D stud volume progressively after its root:
    // the shell's actual top stops below y=.599, whereas every stud
    // extends from y=.592 to .798. This preserves the wet root join while
    // suppressing rear-face/double-wall outlines on the upper stud.
    // Ghosts have studio_pigment=.72, so their transparent preview is
    // unchanged. All classic puzzle materials have studio_glass=0.
    if (studio_glass > .001 && studio_pigment > .82 &&
            jelly_local.y > .599) {
        float stud_filled = smoothstep(.602, .655, jelly_local.y);
        ALPHA = mix(ALPHA, .998, stud_filled);
    }
}
