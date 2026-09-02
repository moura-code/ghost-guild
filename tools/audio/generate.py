"""Synthesises the game's sound effects into assets/sfx/*.wav.

Everything here is built rather than sourced: no downloaded asset, no licence
to track, no Steam disclosure to file, and a set that can be re-cut wholesale
when the game changes -- which it has been, once, and that is the reason this
docstring reads the way it does.

The first version of this file was written for a 640x360 pixel-art game, and
it said so: square waves and short envelopes were "the sonic equivalent of a
28-colour palette". That game is on `main`. This one is a first-person crawl
through wet photoreal stone, and square waves under wet photoreal stone are
exactly the coherence failure ART_BRIEF.md calls an asset flip. So the
synthesis stayed and the VOICE changed:

- **Impacts are three parts, never one.** A transient (the surfaces meeting),
  a body (the thing that was hit, resonating) and a sub (the weight behind
  it). Take the transient away and it is a thump; take the body away and it is
  a click. This is what `svf` was added for.
- **Anything struck is inharmonic.** Partials at 1:2:3 are a note on an organ;
  partials at 1:1.5:2.35 are an object in a room. The ratios in `bell` look
  arbitrary because they are chosen not to be harmonic.
- **Nothing is a bare waveform.** Every tonal layer is a sine, and every sine
  has either noise or another partial on it. A naked square wave is the one
  sound that cannot belong to this game.
- **Levels are chosen, not emergent.** Filtering changes level by a factor
  nobody can predict from a recipe, so every sound ends in `normalize` at a
  stated peak and the balance between a footstep, a blow and a menu tick is
  written down. `tests/game/sfx_mix_test.gd` measures the result.

Deterministic: fixed seeds, so re-running produces byte-identical files and a
regenerated sound never silently becomes a different sound. Each `build_*`
takes its OWN stream, so adding a sound never shifts the draws behind an
existing one.

    python tools/audio/generate.py           # everything
    python tools/audio/generate.py hit_heavy # just one
"""

import math
import os
import random
import struct
import sys
import wave

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "sfx")

# Everything is generated from this, so the set never shifts under a re-run.
SEED = 20260824


def env(i, total, attack=0.01, release=0.9, curve=2.0):
    """Attack-decay envelope, 0..1. `attack` and `release` are fractions of
    the sound's length. Sharp attacks are most of what makes a small sound
    read as an impact rather than as a beep."""
    t = i / max(1, total - 1)
    if t < attack:
        return t / attack
    fall = (t - attack) / max(1e-6, release)
    if fall >= 1.0:
        return 0.0
    return (1.0 - fall) ** curve


def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4.0 * abs(p - 0.5) - 1.0


def tone(freq_from, freq_to, seconds, wave_fn=square, gain=0.5,
         attack=0.01, release=0.9, curve=2.0, duty=0.5, vibrato=0.0):
    """A pitch sweep. A falling sweep reads as something dying or landing; a
    rising one reads as something gained. That is most of the vocabulary."""
    total = int(RATE * seconds)
    out = [0.0] * total
    phase = 0.0
    for i in range(total):
        t = i / max(1, total - 1)
        freq = freq_from + (freq_to - freq_from) * t
        if vibrato:
            freq *= 1.0 + vibrato * math.sin(2.0 * math.pi * 6.0 * i / RATE)
        phase += freq / RATE
        value = square(phase, duty) if wave_fn is square else wave_fn(phase)
        out[i] = value * gain * env(i, total, attack, release, curve)
    return out


def noise(seconds, gain=0.5, attack=0.001, release=0.9, curve=2.5, rng=None):
    total = int(RATE * seconds)
    rng = rng or random.Random(SEED)
    out = [0.0] * total
    # One-pole lowpass, so it reads as a thud rather than as static.
    last = 0.0
    for i in range(total):
        white = rng.uniform(-1.0, 1.0)
        last += (white - last) * 0.45
        out[i] = last * gain * env(i, total, attack, release, curve)
    return out


def mix(*layers):
    length = max(len(layer) for layer in layers)
    out = [0.0] * length
    for layer in layers:
        for i, value in enumerate(layer):
            out[i] += value
    return out


def after(first, second, gap=0.0):
    """Plays `second` after `first` -- for two-blip sounds, where the second
    blip is what turns a beep into a confirmation."""
    pad = [0.0] * int(RATE * gap)
    return first + pad + second


def loop_sine(cycles, seconds, gain, phase=0.0):
    """A sine that completes a whole number of cycles in `seconds`.

    That is the entire trick to a seamless loop: any partial whose frequency
    is an integer multiple of 1/length ends exactly where it started, so the
    join is inaudible without a crossfade. Frequencies are therefore chosen
    as cycle counts rather than as hertz.
    """
    total = int(RATE * seconds)
    return [math.sin(2.0 * math.pi * (cycles * i / total + phase)) * gain
            for i in range(total)]


def loop_noise(seconds, gain, rng, colour=0.06):
    """A noise bed that loops. Noise cannot be made periodic, so this
    generates twice the length and crossfades the second half over the first
    -- the join lands in the middle of the fade where both halves are equally
    present and neither is a seam."""
    total = int(RATE * seconds)
    raw = []
    last = 0.0
    for i in range(total * 2):
        last += (rng.uniform(-1.0, 1.0) - last) * colour
        raw.append(last)
    out = [0.0] * total
    for i in range(total):
        t = i / total
        out[i] = (raw[i] * (1.0 - t) + raw[i + total] * t) * gain
    return out


def drip(at, seconds, length, gain, rng):
    """One water drop, placed inside the loop. Kept well clear of both ends:
    a transient crossing the join is the one thing the crossfade cannot
    hide."""
    total = int(RATE * length)
    out = [0.0] * total
    start = int(RATE * at)
    body = int(RATE * seconds)
    phase = 0.0
    for i in range(body):
        if start + i >= total:
            break
        t = i / max(1, body - 1)
        # A drip is a fast downward pitch bend, which is what separates it
        # from a beep.
        freq = 1400.0 - 900.0 * t
        phase += freq / RATE
        out[start + i] = math.sin(2.0 * math.pi * phase) * gain * (1.0 - t) ** 3.0
    return out



def svf(samples, cutoff, q=1.2, mode="low"):
    """A Chamberlin state-variable filter: lowpass, bandpass or highpass in one
    pass.

    This is the part the original set did not have, and it is the difference
    between a sound with a *body* and a beep. Noise on its own is static;
    noise with a resonance is a material -- the same burst at 700 Hz is a boot
    on stone and at 2.6 kHz is the grit it scuffed up.
    """
    f = 2.0 * math.sin(math.pi * min(cutoff, RATE * 0.45) / RATE)
    damp = min(1.0, 1.0 / max(0.5, q))
    low = band = 0.0
    out = []
    for x in samples:
        high = x - low - damp * band
        band += f * high
        low += f * band
        out.append({"low": low, "band": band, "high": high}[mode])
    return out


def burst(seconds, rng, gain=1.0, attack=0.002, release=0.9, curve=3.0):
    """Raw enveloped white noise, before a filter gives it a material."""
    total = int(RATE * seconds)
    return [rng.uniform(-1.0, 1.0) * gain * env(i, total, attack, release, curve)
            for i in range(total)]


def gained(samples, gain):
    return [value * gain for value in samples]


def build_footsteps(rng):
    """A boot on wet stone, three times.

    Three and not one because a corridor is thirty footfalls long and a single
    sample repeating at three per second stops being a footstep and becomes a
    rhythm -- the fastest way to make walking read as a machine. Three
    variants plus the pitch jitter `Sfx.step` adds is enough that the ear
    stops hearing a loop.

    Each is a low body (the heel taking weight, filtered down to where stone
    lives) under a short bright scuff (the grit it drags). The variants differ
    in where the body sits and how much grit there is, which is what makes
    them siblings rather than three unrelated noises.
    """
    out = {}
    for name, body_hz, grit_hz, grit_gain, length in [
        ("step_a", 620.0, 2400.0, 0.16, 0.115),
        ("step_b", 520.0, 2900.0, 0.11, 0.098),
        ("step_c", 720.0, 2150.0, 0.20, 0.126),
    ]:
        body = svf(burst(length, rng, release=0.85, curve=3.2), body_hz, q=1.6, mode="low")
        grit = svf(burst(length * 0.42, rng, release=0.95, curve=4.0), grit_hz, q=2.4, mode="band")
        out[name] = mix(gained(body, 0.42), gained(grit, grit_gain))
    return out




def sine(phase):
    return math.sin(2.0 * math.pi * phase)


def normalize(samples, peak=0.5):
    """Scales a sound to a stated peak.

    The single most useful tool in this file, and the one the first pass did
    not have. Filtering changes level by a factor nobody can predict from the
    recipe, so without this the mix is whatever fell out; with it, every sound
    has a level somebody chose, and the balance between a footstep, a blow and
    a menu tick is a decision written down rather than an accident."""
    top = max(abs(v) for v in samples)
    if top <= 0.0:
        return samples
    return [v * (peak / top) for v in samples]


def svf_sweep(samples, hz_from, hz_to, q=1.2, mode="low"):
    """`svf` with a cutoff that moves over the sound.

    A filter closing is the difference between an object and a tone: it is
    what makes a noise burst read as something falling rather than as static
    fading out."""
    damp = min(1.0, 1.0 / max(0.5, q))
    low = band = 0.0
    out = []
    span = max(1, len(samples) - 1)
    for i, x in enumerate(samples):
        hz = hz_from + (hz_to - hz_from) * (i / span)
        f = 2.0 * math.sin(math.pi * min(max(hz, 20.0), RATE * 0.45) / RATE)
        high = x - low - damp * band
        band += f * high
        low += f * band
        out.append({"low": low, "band": band, "high": high}[mode])
    return out


def bell(freqs, gains, seconds, attack=0.002, release=0.95, curve=2.4):
    """Partials struck together.

    Given ratios that are NOT small whole numbers this is a struck object --
    metal, stone, a bowl. Given 1:2:3 it is a note on an organ. The
    inharmonicity is the whole difference, and it is why the ratios below look
    arbitrary: they are chosen not to be harmonic."""
    return mix(*[tone(f, f, seconds, wave_fn=sine, gain=g, attack=attack,
                      release=release, curve=curve)
                 for f, g in zip(freqs, gains)])


def dc_block(samples, hz=22.0):
    """One-pole highpass at the bottom of hearing.

    A sound built from a low sine under an asymmetric envelope carries a DC
    offset -- `hit_heavy` measured 1.3% of full scale -- and DC is headroom
    spent on something nobody can hear, plus a click at the moment the voice
    stops. Not applied to the loops: the filter's own start transient would
    land at the loop point, which is the one place in a loop a transient
    cannot be hidden."""
    k = math.exp(-2.0 * math.pi * hz / RATE)
    out = []
    last_in = last_out = 0.0
    for x in samples:
        last_out = k * last_out + x - last_in
        last_in = x
        out.append(last_out)
    return out


def pad(samples, seconds):
    """Leading silence, for a layer that lands after the one it is mixed with."""
    return [0.0] * int(RATE * seconds) + samples


def pop(at, seconds, length, gain, hz, rng, q=3.0):
    """One crackle inside a loop. Kept well clear of both ends for the same
    reason `drip` is: a transient crossing the join is the one thing the
    crossfade cannot hide."""
    total = int(RATE * length)
    body = int(RATE * seconds)
    start = int(RATE * at)
    raw = svf(burst(seconds, rng, attack=0.0008, release=0.75, curve=4.5), hz,
              q=q, mode="band")
    out = [0.0] * total
    for i in range(min(body, len(raw))):
        if start + i >= total:
            break
        out[start + i] = raw[i] * gain
    return out


def build_torch(rng):
    """A torch, from two metres away.

    Fire is three sounds at once and it needs all three: a low roar that is
    the flame moving air, a hiss that is the fuel, and pops. Take the pops
    away and it is a hiss; take the roar away and it is a hiss with clicks in
    it. The pops are what the ear identifies as fire, and they have to be
    irregular -- pops on a grid are a Geiger counter.

    Loops in six seconds, which is long enough that the ear does not find the
    period and short enough to keep the file small. `Torches` starts each
    light at its own offset into it, so twenty of these in a room do not comb
    into one voice.
    """
    length = 6.0
    layers = [
        # The roar: heavily lowpassed noise, most of the body.
        gained(svf(loop_noise(length, gain=1.0, rng=rng, colour=0.012), 190.0,
                   q=0.8, mode="low"), 0.55),
        # The fuel: a thin hiss well above it, so the two do not mask.
        gained(svf(loop_noise(length, gain=1.0, rng=rng, colour=0.55), 3400.0,
                   q=0.9, mode="high"), 0.045),
    ]
    # Irregular on purpose, and each at its own brightness: a pop is a
    # different size depending on what just gave way.
    for at, seconds, gain, hz in [
        (0.41, 0.030, 0.30, 2600.0), (0.93, 0.018, 0.17, 4100.0),
        (1.62, 0.042, 0.36, 1750.0), (2.07, 0.021, 0.20, 3300.0),
        (2.88, 0.026, 0.24, 2200.0), (3.44, 0.038, 0.31, 1450.0),
        (3.79, 0.016, 0.14, 5200.0), (4.51, 0.033, 0.28, 2950.0),
        (5.02, 0.023, 0.19, 3800.0), (5.44, 0.029, 0.26, 2050.0),
    ]:
        layers.append(pop(at, seconds, length, gain, hz, rng))
    return {"amb_torch": mix(*layers)}


def build_ambience(rng):
    """Room tone. One eight-second loop, quiet enough to be noticed only when
    it stops -- which is the whole job of ambience. A crypt is not silent, it
    is still, and the difference between the two is what makes a drawn room
    feel occupied rather than merely lit."""
    length = 8.0
    return {
        "amb_crypt": mix(
            # A low drone, two notes a fifth apart, plus a breathing overtone.
            loop_sine(cycles=440, seconds=length, gain=0.055),   # 55 Hz
            loop_sine(cycles=660, seconds=length, gain=0.030),   # 82.5 Hz
            loop_sine(cycles=1320, seconds=length, gain=0.012),
            # Air moving. The bed is what stops the drone reading as a hum.
            loop_noise(length, gain=0.030, rng=rng),
            # Two drips, off the beat from each other so the loop does not
            # announce its own length.
            drip(1.7, 0.22, length, 0.085, rng),
            drip(5.3, 0.19, length, 0.065, rng),
        ),
    }


def build(rng):
    """id -> samples. Kept in one place so the whole palette is visible at
    once and no two sounds accidentally occupy the same register.

    Every sound ends in `normalize` at a stated peak, so the balance between a
    footstep, a blow and a menu tick is a decision somebody made rather than
    whatever fell out of the filters.
    """
    return {
        # UI. Not beeps: a tick is a fingernail on parchment, which is a
        # filtered noise burst with a body under it. These fire constantly and
        # anything with a tail turns a menu into a rattle, so they are short --
        # and they are dry, because `Sfx.bus_for` keeps every one of them off
        # the reverb.
        "click": normalize(mix(
            svf(burst(0.028, rng, release=0.55, curve=5.0), 2000.0, q=3.0, mode="band"),
            gained(svf(burst(0.034, rng, release=0.7, curve=4.0), 380.0, q=1.2, mode="low"), 0.9),
        ), 0.22),
        "hover": normalize(
            svf(burst(0.014, rng, release=0.6, curve=6.0), 3200.0, q=3.4, mode="band"), 0.10),
        # Lower and longer than a click: down reads as leaving.
        "back": normalize(mix(
            svf_sweep(burst(0.050, rng, release=0.7, curve=4.0), 1200.0, 620.0, q=2.4, mode="band"),
            gained(svf(burst(0.055, rng, release=0.8, curve=3.5), 260.0, q=1.1, mode="low"), 1.1),
        ), 0.20),

        # The hand. Card sounds are paper: noise through a filter that MOVES,
        # because a card sliding is a spectrum sweeping and a card landing is
        # one closing.
        "card_draw": normalize(
            svf_sweep(burst(0.11, rng, attack=0.004, release=0.85, curve=2.2),
                      900.0, 4200.0, q=1.6, mode="band"), 0.22),
        "card_take": normalize(
            svf_sweep(burst(0.060, rng, attack=0.003, release=0.8, curve=2.6),
                      1500.0, 3100.0, q=1.8, mode="band"), 0.24),
        # A thwip and then the card arriving: the filter closes rather than
        # opens, and a small low thud lands under it.
        "card_play": normalize(mix(
            svf_sweep(burst(0.085, rng, attack=0.002, release=0.8, curve=2.4),
                      3200.0, 700.0, q=1.7, mode="band"),
            gained(pad(svf(burst(0.06, rng, release=0.75, curve=3.2), 170.0, q=1.3, mode="low"),
                       0.030), 1.6),
        ), 0.32),

        # Blows. Three parts, always in this order, because that is what an
        # impact IS: a transient (the surfaces meeting), a body (the thing
        # that was hit, resonating) and a sub (the weight behind it). Take the
        # transient away and it is a thump; take the body away and it is a
        # click. Light and heavy share the shape at two sizes, which is what
        # lets the heavy one land.
        "hit_light": normalize(mix(
            svf(burst(0.012, rng, release=0.5, curve=5.5), 1900.0, q=2.6, mode="band"),
            gained(svf(burst(0.090, rng, release=0.8, curve=3.0), 320.0, q=1.4, mode="low"), 1.5),
            gained(tone(150.0, 80.0, 0.090, wave_fn=sine, release=0.85, curve=2.4), 0.30),
        ), 0.55),
        "hit_heavy": normalize(mix(
            svf(burst(0.020, rng, release=0.55, curve=5.0), 1250.0, q=2.2, mode="band"),
            gained(svf(burst(0.026, rng, release=0.5, curve=6.0), 2700.0, q=3.0, mode="band"), 0.45),
            gained(svf(burst(0.230, rng, release=0.85, curve=2.4), 180.0, q=1.5, mode="low"), 2.2),
            gained(tone(95.0, 46.0, 0.240, wave_fn=sine, release=0.9, curve=2.0), 0.45),
        ), 0.80),
        # Something hard turning something aside. Metal, so: partials at
        # ratios that are deliberately not whole numbers, over a short scrape.
        "block": normalize(mix(
            bell([1740.0, 2610.0 * 1.021, 3480.0 * 0.987, 5220.0 * 1.013],
                 [0.30, 0.17, 0.10, 0.05], 0.17, attack=0.001, release=0.95, curve=3.0),
            gained(svf(burst(0.045, rng, release=0.7, curve=4.0), 1400.0, q=2.0, mode="band"), 0.55),
        ), 0.42),
        # Yours. Duller and closer than a blow you land, and with no bright
        # transient at all: a hit on you is felt before it is heard.
        "hero_hurt": normalize(mix(
            gained(svf(burst(0.160, rng, release=0.82, curve=2.6), 220.0, q=1.5, mode="low"), 2.0),
            gained(tone(130.0, 68.0, 0.170, wave_fn=sine, release=0.88, curve=2.2), 0.40),
            gained(svf(burst(0.070, rng, release=0.75, curve=3.4), 700.0, q=1.3, mode="band"), 0.55),
        ), 0.62),
        # A fall, then a scatter. The scatter is what makes it a skeleton
        # coming apart rather than a sack going down, and it has to arrive
        # after the body lands rather than with it.
        # The fall carries it and the scatter decorates it. The first pass
        # had them the other way round and measured a spectral centroid of
        # 4.6 kHz -- which is a handful of dry sticks, not a body going down.
        "enemy_die": normalize(mix(
            gained(svf(burst(0.200, rng, release=0.8, curve=2.6), 200.0, q=1.4, mode="low"), 3.4),
            gained(tone(120.0, 52.0, 0.220, wave_fn=sine, release=0.9, curve=2.0), 0.55),
            *[gained(pad(svf(burst(length, rng, release=0.65, curve=4.5), hz, q=3.0, mode="band"), at), 0.42)
              for at, length, hz in [(0.10, 0.030, 1800.0), (0.15, 0.024, 2500.0),
                                     (0.19, 0.034, 1450.0), (0.26, 0.020, 3000.0),
                                     (0.31, 0.028, 2050.0), (0.38, 0.018, 2700.0)]]
        ), 0.70),

        # Structure. A struck bowl rather than two notes on a chip: the
        # partials are inharmonic, so the ear hears an object being hit
        # somewhere in the room and not a melody being played at it.
        "turn_start": normalize(
            bell([392.0, 588.0 * 1.017, 921.0 * 0.993, 1372.0 * 1.008],
                 [0.30, 0.16, 0.09, 0.04], 0.34, attack=0.004, release=0.96, curve=2.6), 0.20),
        # Stone. The longest sound in the game after the epitaph, and the only
        # one that lives mostly below 200 Hz: a descent should be felt through
        # the floor.
        "descend": normalize(mix(
            gained(svf_sweep(burst(0.80, rng, attack=0.10, release=0.9, curve=1.6),
                             420.0, 90.0, q=1.1, mode="low"), 2.4),
            gained(tone(92.0, 36.0, 0.85, wave_fn=sine, attack=0.06, release=0.95, curve=1.5), 0.55),
            gained(svf(burst(0.62, rng, attack=0.14, release=0.9, curve=2.0), 240.0, q=2.2, mode="band"), 0.32),
        ), 0.72),
        # Two strikes on the same bowl, a fifth apart. Resolution, not fanfare.
        "floor_clear": normalize(after(
            bell([523.0, 784.0 * 1.014, 1230.0 * 0.991], [0.30, 0.15, 0.07], 0.20,
                 attack=0.003, release=0.96, curve=2.6),
            bell([784.0, 1176.0 * 1.011, 1845.0 * 0.994], [0.30, 0.15, 0.07], 0.30,
                 attack=0.003, release=0.96, curve=2.6),
            gap=0.055), 0.34),

        # The economy. Rising, because every one of these is something gained.
        # Soul is air and Soul is cold, so it is sine partials with a breath
        # of filtered noise through them rather than anything struck.
        "soul": normalize(mix(
            tone(620.0, 1180.0, 0.30, wave_fn=sine, gain=0.30, attack=0.04,
                 release=0.9, curve=1.8, vibrato=0.012),
            tone(930.0, 1770.0, 0.30, wave_fn=sine, gain=0.13, attack=0.10,
                 release=0.92, curve=1.8, vibrato=0.018),
            gained(svf(burst(0.30, rng, attack=0.10, release=0.9, curve=2.0),
                       2800.0, q=0.9, mode="high"), 0.13),
        ), 0.28),
        # A coin on stone: two clinks, the second brighter and smaller.
        "purchase": normalize(after(
            bell([2100.0, 3150.0 * 1.019, 4200.0 * 0.991], [0.30, 0.14, 0.06], 0.085,
                 attack=0.001, release=0.95, curve=3.4),
            bell([3100.0, 4650.0 * 1.013], [0.22, 0.09], 0.110,
                 attack=0.001, release=0.95, curve=3.4),
            gap=0.030), 0.30),

        # The dead. Slow, low and a minor third apart -- this is the beat the
        # spec calls the emotional centre, and it is the one sound in the game
        # allowed to take a second. Sine and breath, not a chip: the whole
        # point of the moment is that it does not sound like a game noise.
        "epitaph": normalize(mix(
            tone(220.0, 214.0, 1.10, wave_fn=sine, gain=0.30, attack=0.09, release=0.97, curve=1.25),
            tone(261.6, 254.0, 1.10, wave_fn=sine, gain=0.19, attack=0.15, release=0.97, curve=1.25),
            tone(110.0, 107.0, 1.10, wave_fn=sine, gain=0.22, attack=0.05, release=0.97, curve=1.3),
            gained(svf(burst(1.05, rng, attack=0.22, release=0.95, curve=1.4),
                       700.0, q=0.9, mode="low"), 0.45),
        ), 0.58),
        # Rising, airy, and a long way above everything else in the game, so a
        # ghost taking its place is the one bright thing in a dark room.
        "ghost_place": normalize(mix(
            tone(660.0, 990.0, 0.50, wave_fn=sine, gain=0.26, attack=0.18,
                 release=0.94, curve=1.6, vibrato=0.016),
            tone(990.0, 1485.0, 0.50, wave_fn=sine, gain=0.14, attack=0.28,
                 release=0.94, curve=1.6, vibrato=0.022),
            tone(1980.0, 2970.0, 0.50, wave_fn=sine, gain=0.05, attack=0.40,
                 release=0.94, curve=1.6),
            gained(svf(burst(0.50, rng, attack=0.20, release=0.93, curve=1.7),
                       3000.0, q=0.9, mode="high"), 0.20),
        ), 0.34),
    }


## The two files that loop. Everything else gets its DC blocked; these do not,
## because the filter's start transient would land exactly on the loop point.
LOOPS = ("amb_crypt", "amb_torch")


def write(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "%s.wav" % name)
    if name not in LOOPS:
        samples = dc_block(samples)
    frames = bytearray()
    for value in samples:
        clipped = max(-1.0, min(1.0, value))
        frames += struct.pack("<h", int(clipped * 32000))
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(bytes(frames))
    return path, len(samples) / RATE


def main():
    rng = random.Random(SEED)
    sounds = build(rng)
    sounds.update(build_ambience(random.Random(SEED + 1)))
    # Its own stream, so adding a sound never shifts the random draws
    # behind an existing one and silently makes it a different sound.
    sounds.update(build_footsteps(random.Random(SEED + 2)))
    sounds.update(build_torch(random.Random(SEED + 3)))
    wanted = sys.argv[1:] or list(sounds)
    unknown = [w for w in wanted if w not in sounds]
    if unknown:
        sys.exit("unknown sound(s): %s\nknown: %s"
                 % (", ".join(unknown), ", ".join(sorted(sounds))))
    for name in wanted:
        path, seconds = write(name, sounds[name])
        print("%-12s %5.0f ms  %s" % (name, seconds * 1000, os.path.basename(path)))
    print("\n%d sounds in %s" % (len(wanted), OUT_DIR))


if __name__ == "__main__":
    main()
