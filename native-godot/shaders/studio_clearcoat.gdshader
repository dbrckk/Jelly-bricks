shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

// Optional gallery-only clear gel coat. The coat reuses the exact molded
// brick + stud meshes with normals pushed out a few millimeters. It adds
// a physically suggestive white-box highlight without screen-space
// refraction, compute, HDR bloom, texture assets or new geometry buffers.
// Never enabled in regular Android play: the 2nd pass is gallery-only.

void vertex() {
    VERTEX += NORMAL * 0.012;
}

void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 v = normalize(VIEW);
    float grazing = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 2.6);
    float softbox = pow(max(dot(n,
        normalize(vec3(-0.48, 0.80, 0.35))), 0.0), 17.0);
    float vertical_strip = pow(max(dot(n,
        normalize(vec3(0.64, 0.53, -0.56))), 0.0), 38.0);
    // Ultra-thin transparent optical coating: saturated colored material
    // remains visible below, unlike the old washed-out white reflections.
    ALBEDO = mix(vec3(1.0, 0.995, 0.99),
        vec3(0.78, 0.91, 1.0), grazing * 0.43);
    ALPHA = clamp(0.008 + grazing * 0.19 +
        softbox * 0.11 + vertical_strip * 0.12, 0.0, 0.36);
}
