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
varying vec3 jelly_local;

void vertex() {
    jelly_local = VERTEX;
    float ripple = sin(VERTEX.x * 8.4 + VERTEX.z * 5.1 +
        VERTEX.y * 3.2);
    VERTEX.y += impact * ripple * (0.05 + abs(VERTEX.y) * 0.04);
    VERTEX.x += impact * cos(VERTEX.z * 6.3 + VERTEX.y * 4.4) * 0.038;
    // Real volume-level reaction rather than only rotating a rigid brick.
    // Anchor the lower surface while the upper gel bulges and ripples.
    // The effect is disabled for every legacy puzzle (gel_spring=0).
    float height_weight = smoothstep(.055, .82, jelly_local.y);
    float oscillation = sin(TIME * 22.0 + jelly_local.x * 1.9 +
        jelly_local.z * 1.3);
    float spring = gel_spring * studio_glass * height_weight;
    VERTEX.x += spring * oscillation * .050;
    VERTEX.z += spring * cos(TIME * 18.0 +
        jelly_local.z * 2.15 - jelly_local.x) * .032;
    VERTEX.y -= spring * .029 * (0.62 + 0.38 * oscillation);
}

void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 eye = normalize(VIEW);
    float facing = clamp(dot(n, eye), 0.0, 1.0);
    float fresnel = pow(1.0 - facing, 2.25);
    float height_grad = smoothstep(0.01, 0.45, jelly_local.y);
    float dense = sin(jelly_local.x * 5.8 + jelly_local.z * 3.6) *
        cos(jelly_local.z * 7.3 - jelly_local.y * 5.0);
    float inner_glow = smoothstep(.02, .4, jelly_local.y);
    float bubble = pow(max(sin(jelly_local.x * 23.0) *
        sin(jelly_local.z * 25.0), 0.0), 18.0);
    float softbox = pow(max(dot(n,
        normalize(vec3(-.38, .65, .65))), 0.0), 19.0);
    // Studio lighting must separate the glossy upper surface from the
    // dense, light-absorbing sides. Without this the whole brick looks like
    // a pale flat rectangle on a white backdrop.
    float top_light = smoothstep(.12, .90, n.y);
    float side_absorption = mix(.62, 1.04, top_light);
    vec3 base = candy_tint.rgb *
        (0.84 + height_grad * .11 + dense * .032) * side_absorption;
    base = mix(base, vec3(1.0, .99, 1.0), fresnel * .18);
    base += bubble * detail * .065;
    base += softbox * detail * .21 * (0.5 + top_light * .5);
    // A slow, thin studio-light reflection travels across the sculpted
    // candy surface. Uses local coordinates and TIME; no textures, extra
    // lights, screen sampling or per-frame script updates on Android.
    float sweep = fract(TIME * .125 + jelly_local.x * .20 +
        jelly_local.z * .075);
    float polished_strip = 1.0 - smoothstep(.0, .15, abs(sweep - .55));
    float glint = polished_strip * sheen * detail *
        (0.09 + height_grad * .13) * smoothstep(.17, .85, facing);
    base += vec3(.96, .98, 1.0) * glint;
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
    float studio_key = pow(max(dot(n,
        normalize(vec3(-.48, .81, .33))), 0.0), 10.0);
    float studio_fill = pow(max(dot(n,
        normalize(vec3(.65, .55, -.36))), 0.0), 17.0);
    jelly_color += studio_glass * (
        vec3(1.0, .99, .98) * studio_key * .17 +
        vec3(.82, .92, 1.0) * studio_fill * .095);
    // Two broad product-photography highlights and a narrower white edge
    // catch make curved bevels read as molded, optically dense jelly.
    float lens_reflection = pow(max(dot(reflect(-eye, n),
        normalize(vec3(-.54, .69, .49))), 0.0), 6.0);
    float white_line = pow(max(dot(n,
        normalize(vec3(.14, .68, .72))), 0.0), 31.0);
    jelly_color += studio_glass *
        (vec3(1.0, .99, 1.0) * lens_reflection * .14 +
        vec3(.91, .96, 1.0) * white_line * .10);
    // Slightly darker color transmission through deep sidewalls prevents
    // pale, weightless slabs against the white cyclorama.
    jelly_color *= 1.0 - studio_glass * (1.0 - top_light) * .052;
    ALBEDO = jelly_color;
    METALLIC = .015;
    ROUGHNESS = mix(mix(.25, .115, detail), .085, studio_glass * .56);
    SPECULAR = .98;
    EMISSION = candy_tint.rgb * (.018 + inner_glow * .023) +
        vec3(.34, .42, .65) * fresnel * .19 +
        vec3(1.0, .95, 1.0) * softbox * detail * .12 +
        vec3(.98, .44, .06) * mismatch * (fresnel * .36 + .035);
    // Product gel is dyed, not a neon LED: reduce unwanted washed-out
    // emission while leaving the existing puzzle material untouched.
    EMISSION *= 1.0 - studio_glass * .30;
    // Native gel has real alpha; the outline becomes more solid as the
    // viewing angle becomes glancing, a common candy/glass cue.
    ALPHA = clamp(gel_opacity + fresnel * (.023 + studio_glass * .08)
        - studio_glass * facing * .075, 0.0, 1.0);
}
