"""Generates art previews by driving ComfyUI's HTTP API directly.

No GUI: this starts the server if it is not already up, queues every prompt
in the set, waits for each to finish, and copies the results into
art_previews/. That makes preview generation a command rather than a
click-through, so it can be re-run whenever the art direction shifts.

    python tools/art/generate.py                 # the whole set
    python tools/art/generate.py capsule tower   # just those

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


def workflow(name, prompt, width, height, seed):
    """The same graph the .json workflow describes, built for the API."""
    return {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "2": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt + ", " + STYLE, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": NEGATIVE, "clip": ["1", 1]}},
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


def collect(record, name):
    """Copies whatever the job wrote into art_previews/ under a stable name."""
    saved = []
    for node in record.get("outputs", {}).values():
        for image in node.get("images", []):
            src = os.path.join(COMFY_ROOT, "output", image.get("subfolder", ""),
                               image["filename"])
            if not os.path.exists(src):
                continue
            dst = os.path.join(OUT_DIR, "%s.png" % name)
            n = 2
            while os.path.exists(dst):
                dst = os.path.join(OUT_DIR, "%s_%d.png" % (name, n))
                n += 1
            shutil.copy2(src, dst)
            saved.append(os.path.basename(dst))
    return saved


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    wanted = sys.argv[1:] or list(PROMPTS)
    unknown = [w for w in wanted if w not in PROMPTS]
    if unknown:
        sys.exit("unknown prompt(s): %s\nknown: %s" % (", ".join(unknown), ", ".join(PROMPTS)))

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
