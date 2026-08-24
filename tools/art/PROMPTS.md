# Art preview prompts

These generate **placeholder previews**, not shipped assets. The point is to
have something concrete to react to — "warmer", "less busy", "the ghost should
read at 64px" — before an artist or a shader gets committed to.

Anything AI-generated that actually ships must be disclosed on the Steam page,
so treat everything here as a sketch to be replaced.

## The look, in words

Ghost Guild is near-black wet stone, bone-white text, one accent per biome, and
ghosts in translucent cyan. Catacombs is ivory and dust. The references in the
spec are Cultist Simulator, Luck be a Landlord and A Dark Room — restrained,
typographic, more atmosphere than spectacle.

Style suffix to append to every prompt below:

> dark fantasy, near-black background, muted palette, bone white and cold cyan
> accents, dramatic single light source from below, heavy shadow, matte
> painting, no text, no watermark, no border, centred composition

Negative, every time:

> text, watermark, signature, logo, ui, frame, border, bright colours, saturated,
> cheerful, anime, cartoon, 3d render, photorealistic skin, blurry, jpeg artifacts

## 1. Steam capsule — the priority

The capsule is the ghost-filled tower (spec §2), not cards. This is the single
image that decides whether anyone clicks.

> a vertical cross-section of an underground stone tower, ten stacked floors
> descending into darkness, faint translucent cyan ghost figures standing still
> on each floor, cold light rising from the depths, ancient catacomb masonry

## 2. Biome backdrops (one per biome, used behind the ladder)

- **Catacombs** — `endless ossuary corridors, stacked skulls set into ivory
  stone walls, cold dust in still air, one distant lantern`
- **Fungal Deep** — `a cavern of pale violet fungus, glowing spore light,
  wet organic growth over old stone, oppressive and damp`
- **The Kiln** — `a vast underground forge, cracked orange firelight through
  black basalt, chains and slag, heat haze`

## 3. Card frame studies

> an ornate but austere card border, thin bone-white line work on near-black,
> carved stone motif, empty centre, symmetrical, no text

## 4. Enemy studies (to brief an artist, not to ship)

- `a skeletal rat made of yellowed bone, hunched, cold cyan eye light`
- `a hollow suit of ancient armour standing empty, faint cyan glow inside the
  visor, catacomb stone behind`
- `a towering figure of fused skulls and bone, crowned, the mother of an ossuary`

## Settings that work on a 16 GB card

- SDXL base 1.0, 1024×1024 (capsule: 1024×512, then upscale)
- steps 30, cfg 6.5, sampler `dpmpp_2m`, scheduler `karras`
- batch size 1 — SDXL at 1024 uses ~11 GB, and batching will OOM

## Workflow

1. `tools\art\run_comfyui.ps1`
2. open <http://127.0.0.1:8188>
3. load `tools/art/ghost_guild_sdxl.json` (Workflow → Open)
4. edit the positive prompt node, hit Queue Prompt
5. output lands in `C:\ComfyUI\output`

Copy anything worth keeping into `art_previews/` in this repo — **not** into
`assets/`, which is for licensed, shippable material only.

## What the first sessions actually taught

Recorded so the next person does not rediscover it.

- **Naming cyan washes the whole frame teal.** The game is near-black stone
  with cyan *only* on the ghosts. Describe the palette as desaturated grey
  stone and attach the glow to the ghost in the subject clause instead.
- **"Cross-section" reads as a stepped ziggurat.** SDXL has no idea what an
  architectural cross-section is.
- **"Cutaway / front wall removed" is worse** — it pulls the whole image into
  architectural-diagram conventions: white background, caption gibberish along
  the bottom, multiple views side by side.
- **What works is a scene as a camera would see it.** "Looking down into an
  enormous pitch black circular stone well, level after level of carved
  balconies descending" produced a usable image on the first try. Describe a
  place you are standing in, not a diagram you are reading.
- **Borders and text need naming several times in the negative** — one mention
  is not enough. `border, framed, matted, margin, white edge, caption, label,
  diagram, reference sheet` between them held it off.
- **~6-8 s per image** at 1024, 30 steps on a 5080. Fast enough to iterate
  properly rather than treating each generation as precious.

### The honest limit

SDXL is very good at *atmosphere* — corridors, caverns, a lone figure in a vast
dark space — and poor at the specific composition this game's key image needs:
a schematic tower of ten labelled floors, each holding ghosts. That picture is
half diagram, and diffusion models do not do diagrams.

So the realistic use is: **mood references to hand an artist**, and biome
backdrops that might survive as blurred, darkened underlays behind the real UI.
The capsule itself still wants a human.
