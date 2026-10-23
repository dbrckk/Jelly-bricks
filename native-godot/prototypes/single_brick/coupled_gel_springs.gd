extends RefCounted
## Two coupled UNDERDAMPED visual spring degrees of freedom.
## This is an inexpensive elastic surface model (NOT a rigid-body collision
## solver, XPBD, FEM or actual deformation of collision geometry).
##
## One predictable fixed 120 Hz timestep for replay and Android comparisons.
## Spring energies travel between the red foundation and the lighter blue cap.
const STEP := 1.0 / 120.0
const RED_OMEGA := 17.0
const BLUE_OMEGA := 22.0
const RED_DAMPING_RATIO := 0.24
const BLUE_DAMPING_RATIO := 0.29
const COUPLING := 44.0
const MAX_DT := 0.0666667
const MAX_DEF := 0.88
const MIN_DEF := -0.27

var red: float = 0.0
var blue: float = 0.0
var red_velocity: float = 0.0
var blue_velocity: float = 0.0
var simulation_time: float = 0.0
var impact_count: int = 0
var peak_red_compression: float = 0.0
var peak_blue_compression: float = 0.0
var peak_red_rebound: float = 0.0
var peak_blue_rebound: float = 0.0
var transmitted_energy_peak: float = 0.0
var maximum_volume_error: float = 0.0
var active: bool = false
var accumulator: float = 0.0

func reset() -> void:
    red = 0.0
    blue = 0.0
    red_velocity = 0.0
    blue_velocity = 0.0
    simulation_time = 0.0
    peak_red_compression = 0.0
    peak_blue_compression = 0.0
    peak_red_rebound = 0.0
    peak_blue_rebound = 0.0
    transmitted_energy_peak = 0.0
    maximum_volume_error = 0.0
    accumulator = 0.0
    active = false

func strike(strength: float = 1.0) -> void:
    # Impulse, not a canned pose/tween. The cap is lighter than the base,
    # so its initial deformation speed is slightly larger.
    var e := clampf(strength, 0.2, 1.35)
    red_velocity = clampf(red_velocity + 8.1 * e, -14.0, 14.0)
    blue_velocity = clampf(blue_velocity + 10.2 * e, -16.0, 16.0)
    impact_count += 1
    active = true

func integrate(delta: float) -> bool:
    if not active:
        return false
    accumulator += clampf(delta, 0.0, MAX_DT)
    var loops := 0
    while accumulator >= STEP and loops < 9:
        _substep(STEP)
        accumulator -= STEP
        loops += 1
    if simulation_time > 2.2 and \
            absf(red) + absf(blue) < 0.008 and \
            absf(red_velocity) + absf(blue_velocity) < 0.10:
        red = 0.0
        blue = 0.0
        red_velocity = 0.0
        blue_velocity = 0.0
        accumulator = 0.0
        active = false
    return true

func _substep(dt: float) -> void:
    # Semi-implicit integration avoids the instability of explicit Euler
    # with short high-frequency gel oscillations.
    var difference := blue - red
    var acceleration_red: float = (
        -RED_OMEGA * RED_OMEGA * red -
        2.0 * RED_DAMPING_RATIO * RED_OMEGA * red_velocity +
        COUPLING * difference)
    var acceleration_blue: float = (
        -BLUE_OMEGA * BLUE_OMEGA * blue -
        2.0 * BLUE_DAMPING_RATIO * BLUE_OMEGA * blue_velocity -
        COUPLING * difference)
    red_velocity += acceleration_red * dt
    blue_velocity += acceleration_blue * dt
    red = clampf(red + red_velocity * dt, MIN_DEF, MAX_DEF)
    blue = clampf(blue + blue_velocity * dt, MIN_DEF, MAX_DEF)
    # Guard extreme repeated taps without letting deformation diverge.
    if red == MAX_DEF or red == MIN_DEF:
        red_velocity *= 0.66
    if blue == MAX_DEF or blue == MIN_DEF:
        blue_velocity *= 0.66
    simulation_time += dt
    peak_red_compression = maxf(peak_red_compression, red)
    peak_blue_compression = maxf(peak_blue_compression, blue)
    peak_red_rebound = maxf(peak_red_rebound, -red)
    peak_blue_rebound = maxf(peak_blue_rebound, -blue)
    transmitted_energy_peak = maxf(transmitted_energy_peak,
        absf(COUPLING * difference))
    # For a homogeneous gel (ignoring studs and the hollow socket),
    # height * cross section approximates incompressible bulk volume.
    # The shader corrects the width scale toward 1/sqrt(height_scale).
    var height_scale := 1.0 - 0.19 * red
    var width_scale := 1.0 / sqrt(maxf(height_scale, 0.68))
    maximum_volume_error = maxf(maximum_volume_error,
        absf(height_scale * width_scale * width_scale - 1.0))
