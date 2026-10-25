# Jelly Bricks — Star List resource decisions (2026-10-26)

This is a targeted engineering decision record, **not** an installer or an approval to execute third-party skills. The public `dbrckk/star-list` catalog checked for this iteration contains **1,111 GitHub repositories** (catalog blob `0402d63671669e166f4b4ef87b1dc2c58dd402f6`) and **35 website resources** (`websites.json`). Every source below is a reference or a separately vetted optional tool, not an automatic dependency.

## Ranked resources for the current Godot 4.6 Compatibility / Android build

| Priority | Source | Use / decision | Constraint |
| --- | --- | --- | --- |
| 5/5 | [godotengine/godot](https://github.com/godotengine/godot) and [official Godot 4.6 spatial shader reference](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html) | **Use directly** for shader API, alpha/depth prepass, GLES3/Compatibility, frame-time stability. | `ALPHA` routes objects through transparent rendering, which can sort incorrectly; stacking many semi-transparent shells increases overdraw. |
| 4.8/5 | [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | **Use techniques and test scenes**, not a wholesale engine replacement. | MIT demos; choose a revision matching Godot 4.6. |
| 4.6/5 | [gdquest-demos/godot-shaders](https://github.com/gdquest-demos/godot-shaders) | **Adopted design principles only** from the `StylizedLiquid/LiquidWobble.gd` example: time-dependent damped energy and visibly moving liquid rim. All Jelly Bricks code is independently authored and tailored to its solid-gel geometry. | Source/shaders MIT; artwork CC-BY-NC-SA 4.0 (do NOT bring into a commercial game). Upstream warns the library is still being ported to Godot 4. |
| 4.2/5 | [shihabshahrier/Godot-Skill](https://github.com/shihabshahrier/Godot-Skill) via Skill Issue | Review-only GDScript 4 architecture, typed variables, signals and SceneTree tests. | `star-list` marks this skill `integrationEligible: false` and `skillCodeReviewed: false`; never execute remote skill instructions automatically. |
| 3.9/5 | [lettier/3d-game-shaders-for-beginners](https://github.com/lettier/3d-game-shaders-for-beginners) | Visual theory for Fresnel, specular, refraction approximations and thin-film highlights. | Not a drop-in Godot shader; license-check any source before direct reuse. |
| 3.5/5 | [Game Art Style](https://gameartstyle.loopyhop.com/) | Reference for coherent candy-material art direction, UI hierarchy and product lighting. | Inspiration only; no external artwork is licensed for copying. |
| 2/5 | [2Retr0/GodotOceanWaves](https://github.com/2Retr0/GodotOceanWaves) | Research only; not integrated. | Surface-ocean wave physics and assets are not a good fit for tiny, interconnected mobile gel bricks. |
| 1/5 | [google/filament](https://github.com/google/filament) | **Reject as a runtime dependency**. | A separate PBR renderer would duplicate or replace Godot's Android rendering stack. |
| Review-only | [Shadertoy](https://www.shadertoy.com/), [Sloyd](https://sloyd.ai/), [modl.ai](https://modl.ai/) | Inspiration or optional external services, not dependencies. | Per-asset licenses, model topology, cost, platform compatibility or build-upload privacy must be checked before using. |

## Implemented from this audit

1. **Shader:** an opt-in, short-lived ring glint follows the *actual* contact-centred radial wave across each dyed Jelly wall. A height-dependent phase shift plus ring-slope normal perturbation makes the recently subdivided mid-wall vertices contribute to wet, organic lighting. All puzzle/ghost/idle materials short-circuit the expensive branch.
2. **Mobile ghost response:** `gel_spring` decays exponentially with elapsed seconds, rather than linearly per frame. The player's preview becomes smoother across different Android frame rates.
3. **Touch UI:** selected colors and lengths have a clearly raised white outline and soft shadow, instead of relying only on a glyph or dimmed text. No additional overlays obscure the game.
4. **Regression gates:** preserve all 21 authored puzzles; deterministic saves, contacts, Undo; native Godot logic; OpenGL/Mesa real visual QA and Android APK export. No paid assets, hosted API, extra scene draw call, runtime skill download or mesh rebuild is introduced.

## Next investigation

Visually compare a screenshot from the **same saved 10-brick composition** on a physical Redmi, focusing on pooled overlaps, upper gel edge and animated impact. Measure FPS / device warmth with a **32-brick** scene. The software Mesa CI rendering time is not a valid Android GPU benchmark. Do not replace the Compatibility renderer or add expensive screen-space refraction without that evidence.
