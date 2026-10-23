shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// A shared molded-gel optical family for the STUDS, not a second plastic
// StandardMaterial. The MultiMesh transforms already provide collision
// recoil, so vertex deformation MUST stay in the caller, not this shader.
uniform vec4 pigment : source_color = vec4(0.83, 0.17, 0.24, 1.0);
uniform float milkiness : hint_range(0.0, 1.0) = 0.42;
uniform float wetness : hint_range(0.0, 1.0) = 0.67;

void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 eye = normalize(VIEW);
    float facing = clamp(dot(n, eye), 0.0, 1.0);
    float rim = pow(1.0 - facing, 2.7);
    // The cap has a short light path, so it must be a touch more softly
    // illuminated than the optically thicker shell without becoming white.
    vec3 subsurface = sqrt(max(pigment.rgb, vec3(0.0)));
    vec3 base_color = pigment.rgb * 0.72 +
        subsurface * (0.11 + milkiness * 0.19);
    // Rounded side walls remain visibly dyed; avoid the bright artificial
    // white lacquer that made the previous StandardMaterial pegs look hard.
    ALBEDO = clamp(base_color * (1.0 - rim * 0.15),
        vec3(0.0), vec3(1.0));
    ROUGHNESS = mix(0.25, 0.12, wetness);
    SPECULAR = mix(0.45, 0.72, wetness);
    METALLIC = 0.0;
    EMISSION = pigment.rgb * 0.011;
}
