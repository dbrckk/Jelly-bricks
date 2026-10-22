shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform float coat_strength : hint_range(0.0, 1.0) = 0.60;
// Match the underlying gel vertex deformation exactly. Without this, the
// transparent highlight floats above the shrinking body during an impact.
uniform float deformation : hint_range(0.0, 1.0) = 0.0;
uniform float tilt_energy : hint_range(-1.0, 1.0) = 0.0;
uniform float ripple_energy : hint_range(0.0, 1.0) = 0.0;
uniform float ripple_phase : hint_range(0.0, 6.283) = 0.0;
uniform vec2 brick_extent = vec2(2.0, 1.0);
varying vec3 local_position;

void vertex() {
    float w = clamp((VERTEX.y - 0.055) / 0.76, 0.0, 1.0);
    float compressed = 1.0 - deformation * 0.19;
    vec2 away = VERTEX.xz - brick_extent * 0.5;
    VERTEX.xz += away * deformation * 0.10 * (1.0 - w * 0.45);
    VERTEX.y = 0.055 + (VERTEX.y - 0.055) * compressed;
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
        vec3(slope.x, 0.0, slope.y) * max(elastic_normal.y, 0.0));
    local_position = VERTEX;
}
void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 eye = normalize(VIEW);
    vec3 reflection_dir = reflect(-eye, n);
    float sheet = pow(max(dot(reflection_dir,
        normalize(vec3(-0.50, 0.78, 0.40))), 0.0), 9.0);
    float strip = pow(max(dot(reflection_dir,
        normalize(vec3(0.42, 0.58, -0.69))), 0.0), 35.0);
    float silhouette = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 3.0);
    float seam = 1.0 - smoothstep(0.012, 0.054,
        abs(local_position.y - 0.518));
    float cap = smoothstep(0.46, 0.94, n.y);
    float intensity = coat_strength * (
        sheet * 0.30 + strip * 0.52 + silhouette * 0.13 +
        seam * (1.0-cap) * 0.09);
    ALBEDO = light_color.rgb;
    ALPHA = clamp(intensity, 0.0, 0.56);
}
