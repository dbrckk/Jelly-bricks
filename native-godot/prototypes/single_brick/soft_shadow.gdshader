shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Lightweight studio contact shadows for up to three moving rigid bricks.
// Two triangles per layer, no screen textures, depth buffers or shadow atlas.
uniform vec4 shadow_ink : source_color = vec4(0.14, 0.20, 0.28, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.33;

void fragment() {
    vec2 q = (UV - vec2(0.5)) * 2.0;
    // Rounded square softbox footprint, smooth falloff, no hard rim.
    float elliptical = dot(q, q);
    float falloff = 1.0 - smoothstep(0.08, 0.92, elliptical);
    ALBEDO = shadow_ink.rgb;
    ALPHA = clamp(falloff * shadow_opacity, 0.0, 0.48);
}
