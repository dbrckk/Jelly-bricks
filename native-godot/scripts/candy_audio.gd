extends RefCounted
## Lightweight, reproducible candy SFX synthesized once as 16-bit PCM.
## No imports, network requests, run-time audio thread or external assets.
const SAMPLE_RATE := 22050
const EVENTS := ["select", "rotate", "place", "wrong", "reject", "undo", "hint", "win"]

static func make_clip(kind: String) -> AudioStreamWAV:
    var duration: float = 0.095
    var start_hz: float = 500.0
    var end_hz: float = 380.0
    var amplitude: float = 0.24
    match kind:
        "select":
            duration = 0.065
            start_hz = 620.0
            end_hz = 750.0
            amplitude = 0.17
        "rotate":
            duration = 0.110
            start_hz = 340.0
            end_hz = 680.0
            amplitude = 0.20
        "place":
            duration = 0.145
            start_hz = 540.0
            end_hz = 260.0
            amplitude = 0.29
        "wrong":
            duration = 0.155
            start_hz = 310.0
            end_hz = 220.0
            amplitude = 0.18
        "reject":
            duration = 0.10
            start_hz = 255.0
            end_hz = 145.0
            amplitude = 0.17
        "undo":
            duration = 0.115
            start_hz = 280.0
            end_hz = 490.0
            amplitude = 0.19
        "hint":
            duration = 0.150
            start_hz = 570.0
            end_hz = 790.0
            amplitude = 0.17
        "win":
            duration = 0.34
            start_hz = 520.0
            end_hz = 1040.0
            amplitude = 0.27
        _:
            push_error("Unknown Jelly Bricks audio event: " + kind)
            return null

    var count: int = maxi(1, int(ceil(duration * float(SAMPLE_RATE))))
    var pcm := PackedByteArray()
    pcm.resize(count * 2)
    var phase: float = 0.0
    for i in range(count):
        var fraction: float = float(i) / float(count)
        var attack: float = minf(1.0, float(i) / (0.004 * float(SAMPLE_RATE)))
        var tail: float = pow(maxf(0.0, 1.0 - fraction), 2.0)
        var hz: float = lerpf(start_hz, end_hz, fraction)
        phase += TAU * hz / float(SAMPLE_RATE)
        # Small harmonic bloom suggests a soft, elastic candy impact.
        var tone: float = sin(phase) * 0.79 + sin(phase * 2.0) * 0.15
        if kind == "win":
            tone += sin(phase * 1.5) * 0.16
        var sample: float = clampf(tone * attack * tail * amplitude, -0.9, 0.9)
        pcm.encode_s16(i * 2, int(round(sample * 32767.0)))
    var sound := AudioStreamWAV.new()
    sound.format = AudioStreamWAV.FORMAT_16_BITS
    sound.mix_rate = SAMPLE_RATE
    sound.stereo = false
    sound.data = pcm
    return sound
