shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 candy_tint : source_color = vec4(1.0, 0.4, 0.6, 1.0);
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 1.0) = 1.0;
varying vec3 jelly_local;

void vertex() {
    jelly_local = VERTEX;
    float ripple = sin(VERTEX.x * 8.4 + VERTEX.z * 5.1 + TIME * 0.0);
    VERTEX.y += impact * ripple * (0.055 + abs(VERTEX.y) * 0.035);
    VERTEX.x += impact * cos(VERTEX.z * 6.3) * 0.035;
}

void fragment() {
    float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
    float density = sin(jelly_local.x * 6.0 + jelly_local.z * 3.0) *
        cos(jelly_local.z * 7.0 - jelly_local.y * 4.0);
    float fleck = pow(max(sin(jelly_local.x * 30.0) *
        sin(jelly_local.z * 33.0), 0.0), 16.0);
    ALBEDO = candy_tint.rgb * (0.83 + density * 0.028 + jelly_local.y * 0.19);
    ALBEDO = mix(ALBEDO, vec3(1.0), rim * (0.21 + detail * 0.11));
    ALBEDO += vec3(0.08) * fleck * detail;
    METALLIC = 0.035;
    ROUGHNESS = mix(0.22, 0.105, detail);
    SPECULAR = 0.95;
    EMISSION = candy_tint.rgb * 0.045 + vec3(0.16, 0.20, 0.34) * rim * 0.42;
}
