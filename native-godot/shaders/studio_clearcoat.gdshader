shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

// Lightweight photo-gallery optical skin. The same native Jelly body
// mesh and stud MultiMesh are reused: no new vertices, textures, HDRI,
// screen-space samples or real-time physics. Never visible in gameplay.
// A studio strip light is clipped in local object space to create a
// photographic wet-lacquer reflection rather than a flat white overlay.
varying vec3 molded_local;

void vertex() {
    molded_local = VERTEX;
    VERTEX += NORMAL * 0.009;
}

void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 eye = normalize(VIEW);
    float grazing = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 2.7);
    float crown_softbox = pow(max(dot(n,
        normalize(vec3(-0.48, 0.80, 0.35))), 0.0), 20.0);
    // Fixed virtual front/right window: the old lights primarily hit
    // the top and studs, leaving every vertical side completely matte.
    float side_box = pow(max(dot(n,
        normalize(vec3(0.48, 0.28, 0.83))), 0.0), 7.0);
    float stripe_position = fract(molded_local.x * 0.19 +
        molded_local.z * 0.11 + 0.27);
    float soft_stripe = 1.0 - smoothstep(0.035, 0.31,
        abs(stripe_position - 0.50));
    float window_reflection = side_box * soft_stripe;
    // A second, narrower lobe tracks the camera as glossy toy varnish
    // would, without expensive environment probes or render textures.
    vec3 reflected_eye = reflect(-eye, n);
    float sharp_glint = pow(max(dot(reflected_eye,
        normalize(vec3(0.48, 0.67, 0.55))), 0.0), 24.0);
    ALBEDO = mix(vec3(1.0, 0.995, 0.99),
        vec3(0.82, 0.93, 1.0), grazing * 0.24);
    ALPHA = clamp(0.006 + grazing * 0.12 +
        crown_softbox * 0.10 + window_reflection * 0.24 +
        sharp_glint * 0.19, 0.0, 0.42);
}
