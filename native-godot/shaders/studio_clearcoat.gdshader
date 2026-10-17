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
    // A front-facing rectangular white-box reflection brings definition
    // to the long molded *sidewalls*, which were almost matte in 0.9.33.
    // Restrict it to body walls, not the small tenon caps, so we retain
    // clearly tinted surfaces rather than wash every piece into pastel.
    float front_facing = pow(max(dot(n,
        normalize(vec3(0.10, 0.16, 0.98))), 0.0), 3.0);
    float lower_wall = smoothstep(0.10, 0.24, molded_local.y);
    float upper_wall = 1.0 - smoothstep(0.44, 0.57, molded_local.y);
    float wall = lower_wall * upper_wall;
    float light_panel = front_facing * wall *
        (0.075 + soft_stripe * 0.32);
    // A very narrow upper wet edge gives the rectangular molded brick
    // the fine glossy bead visible in the reference. This is geometry-
    // local, does not require a screen texture, and adds no draw calls.
    float top_bead = 1.0 - smoothstep(0.012, 0.074,
        abs(molded_local.y - 0.535));
    float bead_reflection = front_facing * top_bead * 0.11;
    // A second, narrower lobe tracks the camera as glossy toy varnish
    // would, without expensive environment probes or render textures.
    vec3 reflected_eye = reflect(-eye, n);
    float sharp_glint = pow(max(dot(reflected_eye,
        normalize(vec3(0.48, 0.67, 0.55))), 0.0), 24.0);
    ALBEDO = mix(vec3(1.0, 0.995, 0.99),
        vec3(0.82, 0.93, 1.0), grazing * 0.24);
    ALPHA = clamp(0.006 + grazing * 0.12 +
        crown_softbox * 0.10 + window_reflection * 0.16 +
        light_panel + bead_reflection +
        sharp_glint * 0.19, 0.0, 0.42);
}
