"""Forces every generated asset into one art direction.

This exists because of the exact failure it fixes. Thirty card illustrations,
ten enemies and six relics were generated independently, and each one looked
fine on its own -- but together they had thirty different lighting
directions, thirty palettes and thirty levels of rendering detail. That
incoherence is what reads as "cheap AI slop": not that any single image is
bad, but that no two of them look like they came from the same game.

Before the generated art, the game used flat white CC BY glyphs. They looked
cheap and they looked *coherent*, and coherence is the half that reads as
"someone made this". This script gets both.

What it does to every asset, identically:

  1. Strips colour entirely. Divergent palettes are most of the problem and
     nothing survives them.
  2. Normalises levels -- the darkest and lightest few percent are pushed to
     the ends -- so every asset has the same contrast range instead of some
     being murky and some being blown out.
  3. Maps that single luminance channel through the game's own light model:
     shadows go to the cold near-black of the crypt, midtones to stone,
     highlights to warm lantern light. One palette, one light direction,
     across every asset in the game.
  4. Posterises slightly, which pulls photoreal renders back toward
     illustration so they sit with drawn UI instead of fighting it.

The raw generator output is kept in art_previews/raw/ and this always runs
from there, so the treatment can be retuned and re-run without regenerating
anything. Deterministic: same input, same output, every time.

    python tools/art/unify.py              # every set
    python tools/art/unify.py cards        # just one
    python tools/art/unify.py --colour 0.2 # keep a little original hue
"""

import os
import shutil
import sys

try:
    from PIL import Image, ImageOps
except ImportError:
    sys.exit("Pillow is required: run this with C:\\ComfyUI\\venv\\Scripts\\python.exe")

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "art_previews", "raw")

SETS = {
    "cards": "assets/icons/card_art",
    "enemies": "assets/icons/enemies",
    "relics": "assets/icons/relics",
}

# The game's light model, from game/theme/palette.gd. Shadows are cold and
# near-black, highlights are warm lantern -- the same complementary contrast
# the shader and every StoneBox use, so the art belongs to the room it is
# drawn in rather than merely sitting in it.
RAMP = [
    (0.00, (0x04, 0x05, 0x0a)),   # ABYSS
    (0.16, (0x0d, 0x0f, 0x16)),   # STONE
    (0.34, (0x2b, 0x2f, 0x3d)),   # STONE_HIGH
    (0.52, (0x45, 0x4a, 0x5c)),   # STONE_EDGE
    (0.70, (0xc9, 0xa8, 0x6a)),   # EDGE_LIGHT, where it turns warm
    (1.00, (0xf4, 0xef, 0xe4)),   # BONE
]

# Enough to pull a render toward illustration, not so much that it banks.
POSTERISE = 6

# The generated sources are mostly black background with a lit subject, so a
# straight mapping buries the subject in the bottom of the ramp and every
# card reads as a dark rectangle. Lifting the midtones first puts the subject
# in the half of the range the eye can actually read.
GAMMA = 0.62


def ramp_lut():
    """A 256x3 lookup table interpolating RAMP, flattened the way Pillow's
    Image.point wants it for an RGB image."""
    reds, greens, blues = [], [], []
    for i in range(256):
        t = i / 255.0
        lo, hi = RAMP[0], RAMP[-1]
        for a, b in zip(RAMP, RAMP[1:]):
            if a[0] <= t <= b[0]:
                lo, hi = a, b
                break
        span = max(1e-6, hi[0] - lo[0])
        k = (t - lo[0]) / span
        reds.append(round(lo[1][0] + (hi[1][0] - lo[1][0]) * k))
        greens.append(round(lo[1][1] + (hi[1][1] - lo[1][1]) * k))
        blues.append(round(lo[1][2] + (hi[1][2] - lo[1][2]) * k))
    return reds + greens + blues


def stash(set_name, rel_dir):
    """Copies the generator's output aside the first time, so re-running the
    treatment never compounds on an already-treated image."""
    src_dir = os.path.join(ROOT, rel_dir)
    raw_dir = os.path.join(RAW, set_name)
    os.makedirs(raw_dir, exist_ok=True)
    for name in sorted(os.listdir(src_dir)):
        if not name.endswith(".png"):
            continue
        raw = os.path.join(raw_dir, name)
        if not os.path.exists(raw):
            shutil.copy2(os.path.join(src_dir, name), raw)
    return raw_dir, src_dir


def unify(set_name, rel_dir, lut, colour):
    raw_dir, out_dir = stash(set_name, rel_dir)
    count = 0
    for name in sorted(os.listdir(raw_dir)):
        if not name.endswith(".png"):
            continue
        src = Image.open(os.path.join(raw_dir, name)).convert("RGB")
        # Colour goes first: it is most of what makes the set look assembled
        # from different games.
        grey = ImageOps.grayscale(src)
        # Same contrast range for every asset, so none reads as murky next to
        # one that reads as blown out.
        grey = ImageOps.autocontrast(grey, cutoff=1)
        grey = grey.point([min(255, round(255.0 * (i / 255.0) ** GAMMA)) for i in range(256)])
        if POSTERISE:
            grey = ImageOps.posterize(grey, POSTERISE)
        toned = ImageOps.colorize(grey, black="#04050a", white="#f4efe4")
        toned = toned.convert("RGB").point(lut)
        if colour > 0.0:
            toned = Image.blend(toned, src, colour)
        toned.save(os.path.join(out_dir, name))
        count += 1
    print("%-8s %2d assets -> %s" % (set_name, count, rel_dir))
    return count


def main():
    args = sys.argv[1:]
    colour = 0.0
    if "--colour" in args:
        at = args.index("--colour")
        colour = float(args[at + 1])
        del args[at:at + 2]
    wanted = args or list(SETS)
    unknown = [w for w in wanted if w not in SETS]
    if unknown:
        sys.exit("unknown set(s): %s; known: %s" % (", ".join(unknown), ", ".join(SETS)))
    lut = ramp_lut()
    total = 0
    for set_name in wanted:
        total += unify(set_name, SETS[set_name], lut, colour)
    print("unified %d assets at colour=%.2f" % (total, colour))


if __name__ == "__main__":
    main()
