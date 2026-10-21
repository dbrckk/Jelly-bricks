shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform float coat_strength : hint_range(0.0, 1.0) = 0.60;
varying vec3 local_position;

void vertex() {
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
