extends SceneTree
## Real Godot 4.6 headless numerical QA, independent of GPU/Android.
const SPRING = preload("res://prototypes/single_brick/coupled_gel_springs.gd")

func _initialize() -> void:
    var coupled := SPRING.new()
    if coupled.active or coupled.red != 0.0 or coupled.blue != 0.0:
        push_error("Coupled gel not at rest when initialized")
        quit(1)
        return
    coupled.strike(1.0)
    var strong_red := false
    var strong_blue := false
    var rebound_red := false
    var rebound_blue := false
    for t in range(480):
        coupled.integrate(1.0 / 120.0)
        if coupled.red > 0.25:
            strong_red = true
        if coupled.blue > 0.21:
            strong_blue = true
        if coupled.red < -0.10:
            rebound_red = true
        if coupled.blue < -0.05:
            rebound_blue = true
        if not is_finite(coupled.red) or not is_finite(coupled.blue) or \
                coupled.red < -0.28 or coupled.red > 0.89 or \
                coupled.blue < -0.28 or coupled.blue > 0.89:
            push_error("Under-damped gel destabilized or left bounded range")
            quit(1)
            return
    if not strong_red or not strong_blue or \
            not rebound_red or not rebound_blue:
        push_error("Missing strong compression/rebound in coupled gel")
        quit(1)
        return
    if coupled.peak_red_compression < 0.25 or \
            coupled.peak_blue_compression < 0.21 or \
            coupled.peak_red_rebound < 0.10 or \
            coupled.peak_blue_rebound < 0.05 or \
            coupled.transmitted_energy_peak < 2.0:
        push_error("Red/blue material did not exchange enough spring energy")
        quit(1)
        return
    if coupled.maximum_volume_error > 0.0001:
        push_error("Analytical width-height incompressibility identity broken")
        quit(1)
        return
    if coupled.active or absf(coupled.red) > 0.015 or \
            absf(coupled.blue) > 0.015:
        push_error("Coupled springs never settled to zero after impact")
        quit(1)
        return
    print("PASS: coupled springs red peak=", coupled.peak_red_compression,
        " blue peak=", coupled.peak_blue_compression,
        " red rebound=", coupled.peak_red_rebound,
        " blue rebound=", coupled.peak_blue_rebound,
        " conservation error=", coupled.maximum_volume_error)
    # Check frame-rate independence of the fixed 120Hz integrator, not exact
    # GPU frame rate (the offscreen CI render is software Mesa).
    var at_30 := SPRING.new()
    var at_60 := SPRING.new()
    at_30.strike(0.8)
    at_60.strike(0.8)
    for i in range(30):
        at_30.integrate(1.0 / 30.0)
    for i in range(60):
        at_60.integrate(1.0 / 60.0)
    if absf(at_30.red - at_60.red) > 0.009 or \
            absf(at_30.blue - at_60.blue) > 0.009:
        push_error("Visual physics depends on Android display FPS")
        quit(1)
        return
    # Repeated phone taps may increase energy, but the solver must remain
    # bounded and must still damp to zero when taps cease.
    coupled.reset()
    for n in range(5):
        coupled.strike(1.35)
        for j in range(16):
            coupled.integrate(1.0 / 120.0)
        if coupled.red > 0.89 or coupled.blue > 0.89:
            push_error("Rapid taps overshot bounded soft material")
            quit(1)
            return
    for j in range(480):
        coupled.integrate(1.0 / 120.0)
    if coupled.active:
        push_error("Repeated impulses did not settle")
        quit(1)
        return
    print("PASS: deterministic 120Hz gel solver; dual compression, overshoot, ",
        "volume identity, bounded repeated impacts, decay and 30/60Hz equivalence")
    quit()
