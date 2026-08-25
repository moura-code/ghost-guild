"""Synthesises the game's sound effects into assets/sfx/*.wav.

Ghost Guild had no audio at all -- not one AudioStream anywhere -- which on a
game whose whole feel rests on a restrained art direction was the largest
remaining gap in how it plays. This fills it without a single downloaded
asset, licence to track, or Steam disclosure to file.

Synthesised rather than sourced on purpose. The game is pixel art at 640x360
with a 28-colour palette; square waves and short envelopes are the sonic
equivalent of that, and a library sample of a real sword would sit against it
the way a photograph sits against a sprite. Everything here is built from
square, triangle, sine and noise through an envelope -- the same handful of
parts a sound chip had, which is why they sound like they belong together.

Deterministic: a fixed seed, so re-running produces byte-identical files and
a regenerated sound never silently becomes a different sound.

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


def build(rng):
    """id -> samples. Kept in one place so the whole palette is visible at
    once and no two sounds accidentally occupy the same register."""
    return {
        # UI. Quiet and short: these fire constantly and anything with a tail
        # turns a menu into a rattle.
        "click": tone(880, 660, 0.045, gain=0.22, release=0.6, duty=0.25),
        "hover": tone(1500, 1500, 0.018, gain=0.07, release=0.9, duty=0.12),
        "back": tone(520, 380, 0.06, gain=0.18, release=0.7, duty=0.25),

        # The hand.
        "card_play": tone(520, 980, 0.07, wave_fn=triangle, gain=0.30, release=0.8),
        "card_draw": noise(0.09, gain=0.16, release=0.85, rng=rng),
        "card_take": after(tone(660, 880, 0.05, gain=0.24, duty=0.3),
                           tone(990, 990, 0.07, gain=0.20, duty=0.3)),

        # Blows. Light and heavy share a shape so they read as the same verb
        # at two strengths, which is what lets the heavy one land.
        "hit_light": mix(noise(0.10, gain=0.34, rng=rng),
                         tone(200, 90, 0.10, gain=0.30, release=0.7, curve=2.5)),
        "hit_heavy": mix(noise(0.20, gain=0.45, rng=rng),
                         tone(150, 60, 0.22, gain=0.42, release=0.8, curve=2.0)),
        "block": mix(tone(420, 380, 0.13, gain=0.26, duty=0.35, release=0.75),
                     tone(632, 590, 0.13, gain=0.14, duty=0.35, release=0.75)),
        "enemy_die": mix(tone(560, 80, 0.34, gain=0.34, release=0.95, curve=1.6),
                         noise(0.30, gain=0.20, release=0.95, rng=rng)),
        "hero_hurt": mix(tone(300, 120, 0.16, gain=0.34, release=0.8),
                         noise(0.12, gain=0.22, rng=rng)),

        # Structure.
        "turn_start": after(tone(660, 660, 0.07, wave_fn=triangle, gain=0.22),
                            tone(880, 880, 0.11, wave_fn=triangle, gain=0.20), gap=0.02),
        "descend": mix(tone(240, 70, 0.55, gain=0.30, release=0.95, curve=1.4),
                       noise(0.50, gain=0.18, release=0.95, rng=rng)),
        "floor_clear": after(tone(523, 523, 0.08, wave_fn=triangle, gain=0.22),
                             tone(784, 784, 0.16, wave_fn=triangle, gain=0.22), gap=0.02),

        # The economy. Rising, because every one of these is something gained.
        "soul": tone(620, 1180, 0.10, wave_fn=triangle, gain=0.20, release=0.85),
        "purchase": after(tone(740, 740, 0.05, gain=0.22, duty=0.3),
                          tone(1110, 1110, 0.10, gain=0.20, duty=0.3), gap=0.015),

        # The dead. Slow, low and in a minor third -- this is the beat the
        # spec calls the emotional centre, and it is the one sound in the game
        # allowed to take a whole second.
        "epitaph": mix(tone(220, 208, 0.95, wave_fn=triangle, gain=0.26,
                            attack=0.06, release=0.98, curve=1.3),
                       tone(262, 247, 0.95, wave_fn=triangle, gain=0.18,
                            attack=0.10, release=0.98, curve=1.3)),
        "ghost_place": mix(tone(880, 1320, 0.42, wave_fn=triangle, gain=0.16,
                                attack=0.15, release=0.95, vibrato=0.02),
                           tone(1320, 1760, 0.42, wave_fn=triangle, gain=0.09,
                                attack=0.25, release=0.95, vibrato=0.03)),
    }


def write(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "%s.wav" % name)
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
