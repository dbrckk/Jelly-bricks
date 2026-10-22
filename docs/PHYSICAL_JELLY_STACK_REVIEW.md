# Jelly Bricks — physical stack experiment and release gate

**22 October 2026 | Draft PR #113 | Not part of the released Android game.**

## Actual engine implementation

- Real **Godot 4.6 `RigidBody3D`** middle and upper bricks, fixed rigid base, a real collision floor, gravity, angular dynamics, friction, restitution, continuous collision detection and contact reporting.
- A small horizontal/rotational impulse from a tap produces **a physical topple**, not keyframed positions. The short middle support and long upper brick use distinct collider sizes.
- Visual gel deformation is initiated by **real body-entered contacts** and decays with a time-based spring; shaders do not act as physical soft bodies. The collision core is a simple convex box approximation of the molded brick and does **not** model stud/socket interlocking accurately.
- Touch restarts the physics cycle; a swipe orbits the camera without restarting it. Previously existing scripted three-layer demo remains separate for deterministic comparisons.
- Prototype-only rendering correction flips the studio stud triangle winding. Prior to this fix, back-face culling made raised pegs look like empty holes. The game and production generator are intentionally left unchanged pending visual acceptance.

## Reproducible checks

The production game still has all 21 original puzzle levels. The experiment is isolated in:

- `native-godot/prototypes/single_brick/physics_stack.gd`
- `native-godot/prototypes/single_brick/physics_stack.tscn`
- `native-godot/prototypes/single_brick/physics_stack_verify.gd`

Run the interactive scene in Godot 4.6 with:

```bash
godot --path native-godot --scene res://prototypes/single_brick/physics_stack.tscn
```

The automated Mesa/OpenGL job executes:

```bash
mkdir -p build/physics-stack
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 720x1280x24" \
  godot --path native-godot --rendering-driver opengl3 \
  --resolution 720x1280 \
  --script res://prototypes/single_brick/physics_stack_verify.gd
```

The test saves four **real GPU frames** to `build/physics-stack/`: `01-static`, `02-first-contact`, `03-collapse`, and `04-settled`. These and five deterministic comparison frames are attached to the workflow artifact `jelly-bricks-three-stack-prototype`.

### Verified in GitHub Actions

Commit **`c279ce405fe9af471c206f1bc9cb5a236e66ab42`**:

- [Godot Android Native APK workflow](https://github.com/dbrckk/Jelly-bricks/actions/runs/39852763835): success, including Godot import, 21-level game test, original 3D reference captures, and new true-physics captures.
- Validation workflows: success.
- Contact measurements in the actual Godot physics process: **12 contact events**, including **10 between bricks**, **61.4 degrees** peak top-brick tilt, **1.02 units** of lateral displacement, **0.90 units** of downward travel. Actual test uses a 60 Hz physics step; the screenshots are engine-produced, not synthetic.
- Previously detected failure was a typed-array attempt to look up `StaticBody3D` in `Array[RigidBody3D]`. This is fixed with a type check before the neighbor lookup. The previous end-frame-only gravity check was replaced by a measured trajectory-wide maximum drop.

## Visual / product acceptance NOT achieved

- Core and coat still look **too much like hard lacquered plastic**. There is no physically correct volumetric refraction, internal light transport, or soft-body mass conservation.
- Collision uses approximated boxes; studs and recesses do not physically interlock, and the base is fixed.
- The four captures show one small three-brick topple, **not** the sustained chaotic pile collapse of the original `reference-media/2824-original.mp4`.
- The four images are **Mesa software rendering**. No FPS/p99, heating, memory, input latency, or visuals were measured on the actual Redmi Android phone.
- The PR remains **draft**. Do not ship the prototype or claim visual equivalence.

## Next gate

Compare the peg-corrected shape and moving stack against the **top half** of the original 2824 video. Improve the material/lighting enough to remove the plastic appearance; then improve multi-brick support and collision shapes. Before inclusion in Android, obtain artistic approval and record device performance.
