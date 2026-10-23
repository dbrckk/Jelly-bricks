shader_type spatial;
render_mode unshaded, cull_disabled;

// Strongly colored, unmistakable geometric pattern: if its bars are visible
// through the red gel, the background-only viewport genuinely transmits
// pixels. A fake diffuse pink shader cannot pass this visual diagnostic.
void fragment() {
    vec2 grid = UV * vec2(9.0, 5.0);
    float cells = mod(floor(grid.x) + floor(grid.y), 2.0);
    float x_line = 1.0 - smoothstep(0.0, 0.045,
        abs(fract(grid.x) - 0.5));
    float y_line = 1.0 - smoothstep(0.0, 0.045,
        abs(fract(grid.y) - 0.5));
    vec3 charcoal = vec3(0.075, 0.13, 0.24);
    vec3 ivory = vec3(0.96, 0.93, 0.82);
    ALBEDO = mix(ivory, charcoal, cells);
    ALBEDO = mix(ALBEDO, vec3(0.12, 0.68, 0.87),
        clamp(max(x_line, y_line), 0.0, 1.0) * 0.38);
}