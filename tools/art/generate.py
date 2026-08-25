"""Generates art previews by driving ComfyUI's HTTP API directly.

No GUI: this starts the server if it is not already up, queues every prompt
in the set, waits for each to finish, and copies the results into
art_previews/. That makes preview generation a command rather than a
click-through, so it can be re-run whenever the art direction shifts.

    python tools/art/generate.py                 # the preview set
    python tools/art/generate.py capsule tower   # just those previews
    python tools/art/generate.py cards --limit 5 # first 5 card arts, SHIPPED
    python tools/art/generate.py enemies         # all 10 enemies, SHIPPED

The output is throwaway. Nothing here is shipped, and nothing in the game
loads from art_previews/ -- see tools/art/PROMPTS.md.
"""

import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

COMFY_ROOT = r"C:\ComfyUI"
HOST = "127.0.0.1:8188"
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "art_previews")

# Learned from the first batch: naming cyan as a colour makes SDXL wash the
# whole frame teal, when the game is near-black stone with cyan only on the
# ghosts. So the palette is described as desaturated stone, and the cyan is
# attached to the ghosts in the individual prompts instead.
STYLE = ("dark fantasy concept art, almost entirely black, desaturated grey stone, "
         "deep shadow, one weak cold light source, dust in the air, subtle, restrained, "
         "atmospheric, full bleed edge to edge")

# The first batch drew a border despite being told not to, and came out teal.
# Both get named several ways here, because one mention is evidently not enough.
NEGATIVE = ("text, letters, watermark, signature, logo, ui, hud, frame, border, framed, "
            "matted, vignette border, white edge, margin, teal, turquoise, saturated, vibrant, "
            "colourful, bright, cheerful, daylight, anime, cartoon, comic, cel shaded, "
            "outlined, illustration border, 3d render, blurry, jpeg artifacts, deformed, "
            "white background, grey background, diagram, blueprint, reference sheet, caption, "
            "label, concept sheet, multiple views, isolated on white")

# name -> (prompt, width, height). The capsule is wide; studies are square.
PROMPTS = {
    # Two failed framings, kept as a warning: "cross-section" reads as a
    # stepped ziggurat, and "cutaway / front wall removed" pulls the whole
    # image toward architectural-diagram conventions -- white background and
    # caption gibberish. SDXL wants a scene as a camera would see it, so the
    # tower is described as a place you are standing inside.
    "capsule": (
        "looking down into an enormous pitch black circular stone well, level after level of "
        "carved stone balconies descending into total darkness, a single small pale glowing "
        "figure standing alone on several of the levels, cold blue-white glow, vast and empty",
        1024, 512),
    "tower": (
        "an endless stone shaft seen from inside, carved floors receding downward into black, "
        "one pale glowing spirit standing on the nearest ledge, dust in the air", 832, 1216),
    "catacombs": (
        "endless ossuary corridors, stacked skulls set into ivory stone walls, cold dust in "
        "still air, one distant lantern", 1024, 576),
    "fungal_deep": (
        "a cavern of pale violet fungus, glowing spore light, wet organic growth over old "
        "stone, oppressive and damp", 1024, 576),
    "the_kiln": (
        "a vast underground forge, cracked orange firelight through black basalt, chains and "
        "slag, heat haze", 1024, 576),
    "ghost": (
        "a translucent pale blue-white spectre of a fallen adventurer, hollow eyes, tattered "
        "shroud, standing patiently in a pitch black crypt, faint inner glow, the only lit "
        "thing in frame", 1024, 1024),
    "card_frame": (
        "an ornate but austere card border, thin bone-white line work on near-black, carved "
        "stone motif, empty centre, symmetrical", 832, 1216),
    "mother_of_bones": (
        "a towering figure of fused skulls and bone, crowned, the mother of an ossuary, "
        "looming in darkness", 1024, 1024),
}


# ---------------------------------------------------------------------------
# Shipped art. Everything above this line is a preview: throwaway, generated
# so Joao can react to a concrete image. Everything below writes into assets/
# and goes in the build, which means Steam's AI-content disclosure applies --
# Joao made that call on 2026-08-24 and it is recorded in the ruling ledger.
#
# The whole constraint on these is size. A card's art slot is 128x82 and an
# enemy is 26px in the fight, so nothing survives but silhouette and one
# focal shape. The prompts ask for exactly that and the negative fights the
# model's instinct to paint a scene.
# The weighting is not decoration. Asked politely for a black background SDXL
# produced a pale studio backdrop with a silhouette on it about half the time,
# which is exactly backwards for art that sits in a dark recessed slot on a
# card. Weighted emphasis plus a negative that names every way it likes to
# say "beige" is what made it stick.
SUBJECT_STYLE = ("a single centred object, dark fantasy game icon, one bold clear silhouette, "
                 "dramatic warm rim light from above, (pitch black background:1.5), "
                 "(dark background:1.3), muted bone and cold stone colours, high contrast, "
                 "simple, uncluttered, low key lighting")
SUBJECT_NEGATIVE = (NEGATIVE + ", busy, cluttered, multiple subjects, full scene, landscape, "
                    "background detail, horizon, floor, wall, several objects, collage, grid, "
                    "(light background:1.4), (pale background:1.4), beige, cream, sepia, tan, "
                    "studio backdrop, product photography, gradient background, soft box, "
                    "bright, washed out, low contrast, overexposed")

# id -> what it is. The card's own name does most of the work; these say what
# the shape should be, because "Ashes" alone gives SDXL a campfire.
CARDS = {
    "ashes": "a drifting cloud of grey ash and embers",
    "bone_shard": "a single jagged splinter of bone, sharp as a blade",
    "bone_spear": "a spear shafted and tipped with bone",
    "bone_wall": "a barricade of stacked femurs and skulls",
    "brace": "a battered iron shield held edge-on",
    "bulwark": "a heavy tower shield planted in stone",
    "cairn": "a balanced stack of flat grave stones",
    "censer_smoke": "a swinging brass censer trailing thick smoke",
    "cold_iron": "a plain cold iron sword, frost on the blade",
    "death_knell": "a cracked iron bell struck once",
    "dig_in": "a spade driven upright into loose earth",
    "exhume": "a hand of bone reaching up out of grave soil",
    "grave_dust": "a fistful of pale grave dust falling",
    "grave_moss": "damp green moss creeping over a headstone",
    "hallowed_strike": "a consecrated blade wreathed in pale holy light",
    "lantern_oil": "a clay flask of oil, wick lit",
    "last_rites": "an open funeral prayer book and a guttering candle",
    "plague_vial": "a stoppered glass vial of sickly green fluid",
    "rat_swarm": "a boiling mass of crypt rats",
    "reaping": "a long curved scythe blade",
    "requiem": "a cracked stone angel singing, mouth open",
    "sanctify": "a censer and a shaft of pale light on stone",
    "second_wind": "a lungful of cold breath in freezing air",
    "sharpen_spade": "a whetstone drawn along a spade's edge, sparks",
    "shovel_swing": "a gravedigger's shovel swung in an arc",
    "shroud": "a hanging burial shroud, empty",
    "strike": "a plain worn sword blade",
    "tolling_bell": "a great crypt bell hanging in darkness",
    "tomb_lantern": "an old iron grave lantern burning low",
    "vigil": "a single candle burning through the night on a tomb",
}

ENEMIES = {
    "mother_of_bones": "a towering crowned figure fused from hundreds of skulls",
    "ossuary_warden": "an armoured skeletal warden with a heavy key and halberd",
    "bone_archer": "a skeletal archer drawing a bone bow",
    "bone_rat": "a skeletal rat, ribs showing, red points for eyes",
    "crypt_spider": "a pale bloated cave spider, long legs",
    "grave_wisp": "a formless cold blue wisp of grave light",
    "hollow_knight": "an empty suit of rusted plate armour standing upright",
    "plague_bearer": "a bloated shrouded corpse leaking green rot",
    "shambler": "a lurching rotted corpse, arms hanging",
    "skull_stack": "a precarious tower of stacked skulls",
}

RELICS = {
    "bone_charm": "a small charm of carved finger bones on a cord",
    "cracked_hourglass": "an hourglass with a cracked glass bulb, sand spilling",
    "grave_coin": "two tarnished obols, coins for the ferryman",
    "lead_censer": "a heavy dull lead censer on chains",
    "ossuary_key": "a long iron key with a skull-shaped bow",
    "sextons_lantern": "a sexton's dented brass lantern, flame inside",
}

# Where each set ships to, and at what size. Sizes are 2x the slot the game
# draws them into, which is as much detail as anything this small can carry
# and keeps thirty of them off the VRAM budget.
SETS = {
    "cards": (CARDS, "assets/icons/card_art", 1216, 832, 256, 164),
    "enemies": (ENEMIES, "assets/icons/enemies", 1024, 1024, 208, 208),
    "relics": (RELICS, "assets/icons/relics", 1024, 1024, 128, 128),
}


def workflow(name, prompt, width, height, seed, style=None, negative=None,
             out_size=None):
    """The same graph the .json workflow describes, built for the API.

    `out_size` adds an ImageScale before the save, so the file that lands in
    assets/ is already the size the game wants -- no Pillow on the caller's
    side, and no 1216x832 texture being downscaled every frame at runtime.
    """
    graph = {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "2": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt + ", " + (style or STYLE), "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode",
              "inputs": {"text": negative or NEGATIVE, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage",
              "inputs": {"width": width, "height": height, "batch_size": 1}},
        "5": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": 30, "cfg": 6.5, "sampler_name": "dpmpp_2m",
                         "scheduler": "karras", "denoise": 1.0, "model": ["1", 0],
                         "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage",
              "inputs": {"filename_prefix": "ghost_guild/" + name, "images": ["6", 0]}},
    }
    if out_size is not None:
        graph["8"] = {"class_type": "ImageScale",
                      "inputs": {"upscale_method": "lanczos", "width": out_size[0],
                                 "height": out_size[1], "crop": "center", "image": ["6", 0]}}
        graph["7"]["inputs"]["images"] = ["8", 0]
    return graph


def server_up():
    try:
        urllib.request.urlopen("http://%s/system_stats" % HOST, timeout=3).read()
        return True
    except Exception:
        return False


def start_server():
    """Starts ComfyUI detached and waits for it to answer. SDXL takes a while
    to load the first time; three minutes is generous but not infinite."""
    if server_up():
        print("comfyui already running")
        return None
    python = os.path.join(COMFY_ROOT, "venv", "Scripts", "python.exe")
    main = os.path.join(COMFY_ROOT, "main.py")
    if not os.path.exists(python):
        sys.exit("ComfyUI not installed at %s - run tools/art/install_comfyui.ps1" % COMFY_ROOT)
    print("starting comfyui")
    log = open(os.path.join(OUT_DIR, "comfyui.log"), "w", encoding="utf-8", errors="replace")
    proc = subprocess.Popen([python, main, "--disable-auto-launch"],
                            cwd=COMFY_ROOT, stdout=log, stderr=subprocess.STDOUT)
    for _ in range(180):
        if server_up():
            print("comfyui up")
            return proc
        if proc.poll() is not None:
            sys.exit("comfyui exited on startup - see art_previews/comfyui.log")
        time.sleep(1)
    sys.exit("comfyui did not come up in 180s - see art_previews/comfyui.log")


def queue(graph):
    body = json.dumps({"prompt": graph}).encode("utf-8")
    req = urllib.request.Request("http://%s/prompt" % HOST, data=body,
                                 headers={"Content-Type": "application/json"})
    try:
        return json.loads(urllib.request.urlopen(req, timeout=30).read())["prompt_id"]
    except urllib.error.HTTPError as e:
        sys.exit("comfyui refused the graph: %s" % e.read().decode("utf-8", "replace")[:400])


def wait(prompt_id, timeout=900):
    """Polls history until the job appears. A 1024 SDXL image is ~20-40s on a
    5080; the timeout is for a first run that also compiles kernels."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            hist = json.loads(urllib.request.urlopen(
                "http://%s/history/%s" % (HOST, prompt_id), timeout=10).read())
        except Exception:
            time.sleep(2)
            continue
        if prompt_id in hist:
            return hist[prompt_id]
        time.sleep(2)
    return None


def collect(record, name, out_dir=None, overwrite=False):
    """Copies whatever the job wrote out under a stable name.

    Previews never overwrite -- a second run of the same prompt should sit
    beside the first so the two can be compared. Shipped art does overwrite,
    because the game looks the file up by id and a `strike_2.png` is not
    anything the loader will ever find.
    """
    target = out_dir or OUT_DIR
    os.makedirs(target, exist_ok=True)
    saved = []
    for node in record.get("outputs", {}).values():
        for image in node.get("images", []):
            src = os.path.join(COMFY_ROOT, "output", image.get("subfolder", ""),
                               image["filename"])
            if not os.path.exists(src):
                continue
            dst = os.path.join(target, "%s.png" % name)
            if not overwrite:
                n = 2
                while os.path.exists(dst):
                    dst = os.path.join(target, "%s_%d.png" % (name, n))
                    n += 1
            shutil.copy2(src, dst)
            saved.append(os.path.basename(dst))
    return saved


ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# The generated art sits in dark slots -- a card's recessed window, an
# enemy's plate -- so a pale backdrop reads as a grey square pasted into the
# UI. SDXL returns one maybe one time in six however hard the prompt leans on
# "pitch black background", so the check is automatic and the fix is another
# roll rather than a human noticing.
EDGE_LUMA_MAX = 60
REROLLS = 4


def edge_luma(path):
    """Mean brightness of the outermost pixels, 0-255. None if Pillow is not
    available, in which case the caller skips the check rather than failing:
    ComfyUI's own venv always has Pillow, a bare system python may not."""
    try:
        from PIL import Image
    except ImportError:
        return None
    im = Image.open(path).convert("L")
    w, h = im.size
    px = im.load()
    vals = []
    for x in range(0, w, 4):
        vals += [px[x, 0], px[x, h - 1]]
    for y in range(0, h, 4):
        vals += [px[0, y], px[w - 1, y]]
    return sum(vals) / len(vals)


def run_set(set_name, only=None, limit=None):
    """Generates a shipped set into assets/. `only` and `limit` exist so the
    first few can be looked at before the other twenty-five are made."""
    table, rel_dir, width, height, out_w, out_h = SETS[set_name]
    ids = [i for i in table if only is None or i in only]
    if limit is not None:
        ids = ids[:limit]
    out_dir = os.path.join(ROOT, rel_dir)
    print("%s -> %s (%d pieces at %dx%d)" % (set_name, rel_dir, len(ids), out_w, out_h))
    start_server()
    for i, ident in enumerate(ids):
        prompt = "%s, %s" % (ident.replace("_", " "), table[ident])
        print("[%d/%d] %s" % (i + 1, len(ids), ident), flush=True)
        started = time.time()
        saved, luma = [], None
        for attempt in range(REROLLS):
            graph = workflow(ident, prompt, width, height, seed=4000 + i + attempt * 977,
                             style=SUBJECT_STYLE, negative=SUBJECT_NEGATIVE,
                             out_size=(out_w, out_h))
            record = wait(queue(graph))
            if record is None:
                print("   TIMED OUT")
                break
            saved = collect(record, ident, out_dir=out_dir, overwrite=True)
            if not saved:
                break
            luma = edge_luma(os.path.join(out_dir, "%s.png" % ident))
            if luma is None or luma <= EDGE_LUMA_MAX:
                break
            print("   edge %d too pale, rerolling" % luma, flush=True)
        note = "" if luma is None else "  edge %d" % luma
        print("   %s%s  (%.0fs)" % (", ".join(saved) if saved else "no image returned",
                                    note, time.time() - started), flush=True)
    print("\ndone - %s in %s" % (set_name, out_dir))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    args = sys.argv[1:]

    # `cards`, `enemies` and `relics` ship into assets/; everything else is a
    # preview. `--limit N` takes the first N of a set, which is how the first
    # handful get looked at before the rest are committed to.
    limit = None
    if "--limit" in args:
        at = args.index("--limit")
        limit = int(args[at + 1])
        del args[at:at + 2]
    for set_name in list(SETS):
        if set_name in args:
            args.remove(set_name)
            run_set(set_name, only=args or None, limit=limit)
            return

    wanted = args or list(PROMPTS)
    unknown = [w for w in wanted if w not in PROMPTS]
    if unknown:
        sys.exit("unknown prompt(s): %s\nknown: %s\nor a set: %s"
                 % (", ".join(unknown), ", ".join(PROMPTS), ", ".join(SETS)))

    start_server()
    for i, name in enumerate(wanted):
        prompt, width, height = PROMPTS[name]
        print("[%d/%d] %s (%dx%d)" % (i + 1, len(wanted), name, width, height), flush=True)
        started = time.time()
        record = wait(queue(workflow(name, prompt, width, height, seed=1000 + i)))
        if record is None:
            print("   TIMED OUT")
            continue
        saved = collect(record, name)
        print("   %s  (%.0fs)" % (", ".join(saved) if saved else "no image returned",
                                  time.time() - started), flush=True)
    print("\ndone - images in %s" % OUT_DIR)


if __name__ == "__main__":
    main()
