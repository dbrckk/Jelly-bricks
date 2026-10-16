shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural glossy gel: softly transparent center, opaque-looking bright
// Fresnel edges, layered candy tint and camera-facing specular highlights.
// Designed for Godot 4 Compatibility (OpenGL ES 3); no external textures.
uniform vec4 candy_tint : source_color = vec4(1.0, 0.4, 0.6, 1.0);
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 1.0) = 1.0;
uniform float gel_opacity : hint_range(0.0, 1.0) = 0.94;
varying vec3 jelly_local;

void vertex() {
    jelly_local = VERTEX;
    float ripple = sin(VERTEX.x * 8.4 + VERTEX.z * 5.1 +
        VERTEX.y * 3.2);
    VERTEX.y += impact * ripple * (0.05 + abs(VERTEX.y) * 0.04);
    VERTEX.x += impact * cos(VERTEX.z * 6.3 + VERTEX.y * 4.4) * 0.038;
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
    float light_strip = pow(max(dot(n,
        normalize(vec3(.75, .32, .58))), 0.0), 34.0);
    vec3 base = candy_tint.rgb *
        (0.71 + height_grad * .22 + dense * .042);
    base = mix(base, vec3(1.0, .985, 1.0), fresnel * .32);
    base += bubble * detail * .065;
    base += softbox * detail * .24;
    ALBEDO = base;
    METALLIC = .015;
    ROUGHNESS = mix(.23, .095, detail);
    SPECULAR = .98;
    EMISSION = candy_tint.rgb * (.045 + inner_glow * .045) +
        vec3(.34, .42, .65) * fresnel * .19 +
        vec3(1.0, .95, 1.0) * softbox * detail * .12 +
        vec3(.92, .96, 1.0) * light_strip * detail * .14;
    // Extra glossy coat responds to the real smoothed 3D bevel normals.
    // No environment-texture download or animated rendering needed.
    CLEARCOAT = .86;
    CLEARCOAT_GLOSS = .88;
    // Native gel has real alpha; the outline becomes more solid as the
    // viewing angle becomes glancing, a common candy/glass cue.
    ALPHA = clamp(gel_opacity + fresnel * .065, 0.0, 1.0);
}
