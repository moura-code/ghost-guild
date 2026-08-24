# Ghost Guild — art brief

Everything below is **already wired**. The game reads these folders at
startup and falls back to a placeholder when a file is missing, so a
delivered asset appears in the build with no code change and no rebuild of
anything else. Deliver one file, see it in the game.

Run the game and look at it before starting: `godot --path .` — the
placeholders are in place at the right sizes, so the composition, the
palette and the space each piece has to fill are all visible.

## The look, in one paragraph

An underground card game about dying on purpose. Near-black wet stone,
bone-white text, one accent colour per biome, and ghosts in translucent
cyan — the only genuinely bright thing on screen. Restrained and
typographic rather than spectacular. References: Cultist Simulator, Luck be
a Landlord, Darkest Dungeon's palette without its line weight.

### Palette (exact, from `game/theme/palette.gd`)

| Role | Hex |
|---|---|
| Stone (background) | `#0b0d10` |
| Stone raised (panels) | `#14181d` |
| Stone edge (borders) | `#232a31` |
| Bone (primary text) | `#e8e2d4` |
| Bone dim | `#8f8a7e` |
| Soul (currency, highlights) | `#cfe8ff` |
| Ghost (spirits) | `rgba(107,235,255,0.72)` |
| Prepared (gold) | `#ffdb73` |
| Restless (warning) | `#ff7359` |
| Danger | `#d9534f` |
| Catacombs accent | `#cfc6a8` |

## What is needed, in priority order

### 1. Card art — 30 pieces

**Drop into `assets/icons/card_art/<card_id>.png`.**

- **122 x 74 px** at 1x, deliver at 2x (244 x 148) — a wide letterbox slot
  above the card name.
- PNG with transparency, or a full-bleed image; both work.
- Must read at 122 px wide. That is the whole constraint: no fine detail
  survives, so silhouette and one clear focal shape.
- Currently shows the card's type icon as a stand-in.

| id | type | rarity | name |
|---|---|---|---|
| `ashes` | skill | uncommon | Ashes |
| `bone_shard` | attack | common | Bone Shard |
| `bone_spear` | attack | uncommon | Bone Spear |
| `bone_wall` | skill | common | Bone Wall |
| `brace` | skill | basic | Brace |
| `bulwark` | power | rare | Bulwark |
| `cairn` | skill | rare | Cairn |
| `censer_smoke` | skill | common | Censer Smoke |
| `cold_iron` | attack | common | Cold Iron |
| `death_knell` | power | rare | Death Knell |
| `dig_in` | skill | common | Dig In |
| `exhume` | skill | uncommon | Exhume |
| `grave_dust` | skill | common | Grave Dust |
| `grave_moss` | skill | common | Grave Moss |
| `hallowed_strike` | attack | uncommon | Hallowed Strike |
| `lantern_oil` | skill | common | Lantern Oil |
| `last_rites` | attack | basic | Last Rites |
| `plague_vial` | skill | uncommon | Plague Vial |
| `rat_swarm` | attack | common | Rat Swarm |
| `reaping` | attack | common | Reaping |
| `requiem` | attack | rare | Requiem |
| `sanctify` | skill | uncommon | Sanctify |
| `second_wind` | skill | rare | Second Wind |
| `sharpen_spade` | skill | uncommon | Sharpen Spade |
| `shovel_swing` | attack | common | Shovel Swing |
| `shroud` | skill | common | Shroud |
| `strike` | attack | basic | Strike |
| `tolling_bell` | skill | uncommon | Tolling Bell |
| `tomb_lantern` | skill | uncommon | Tomb Lantern |
| `vigil` | power | uncommon | Vigil |

### 2. Enemy art — 10 pieces

**Drop into `assets/icons/enemies/<enemy_id>.png`** (replaces the current
CC BY silhouettes).

- **26 x 26 px** at 1x in the fight, deliver at 4x (104 x 104) so there is
  room to enlarge later.
- Flat silhouette or near-silhouette. The game tints these: they grey out
  when the enemy dies, so avoid baked-in colour that fights a tint.
- Bosses and elites are marked; they can carry more detail since they get
  more screen time.

| id | kind | name |
|---|---|---|
| `mother_of_bones` | boss | Mother of Bones |
| `ossuary_warden` | elite | Ossuary Warden |
| `bone_archer` | regular | Bone Archer |
| `bone_rat` | regular | Bone Rat |
| `crypt_spider` | regular | Crypt Spider |
| `grave_wisp` | regular | Grave Wisp |
| `hollow_knight` | regular | Hollow Knight |
| `plague_bearer` | regular | Plague Bearer |
| `shambler` | regular | Shambler |
| `skull_stack` | regular | Skull Stack |

### 3. Relic art — 6 pieces

**`assets/icons/relics/<relic_id>.png`**, same treatment as enemies,
**32 x 32** at 1x.

- `bone_charm` — Bone Charm
- `cracked_hourglass` — Cracked Hourglass
- `grave_coin` — Grave Coin
- `lead_censer` — Lead Censer
- `ossuary_key` — Ossuary Key
- `sextons_lantern` — Sexton's Lantern

### 4. The ghost

The single most important piece, and currently drawn in code as a dome with
a wavy hem. Every dead hero becomes one; they stand in rows on the tower and
they are what the game is about.

- **14 x 20 px** at 1x on the tower — it must read at that size.
- Four states, ideally one shape with variations: **true** (cyan),
  **echo** (paler, bluer), **prepared** (gold), **restless** (red).
- It bobs slowly on its own phase, so a single static shape is fine.

### 5. The Steam capsule

Separate job, and the one worth the most. Per the design spec the capsule is
**the ghost-filled tower** — a cross-section of ten stone floors descending
into blackness, a cyan spirit standing on each — not cards and not a hero.
Sizes Steam wants: 616x353 (main), 460x215 (small), 1920x620 (hero),
374x448 (vertical).

## What is NOT needed

- **UI frames, buttons, panels, bars** — all drawn in code and reactive.
- **Backgrounds** — a shader draws lit stone that responds to depth.
- **Fonts and icons** — Cinzel, Inter, and 57 game-icons.net pieces are in
  and credited in `ATTRIBUTION.md`.
- **Animation** — motion is code: hit flash, squash, death fade, card fan
  and deal, screen shake, wipes. Deliver static art; the game moves it.

## Placeholders currently in the build

`assets/backdrops/` holds three AI-generated biome stills, heavily darkened
and blurred, used as faint underlays. They are placeholders and are
flagged as such — see `assets/backdrops/README.md`. If you would rather
supply real ones the slot is `<biome_id>.webp`, 1280x720.

## Delivery

Filenames must match the ids above exactly — that is the whole wiring. PNG
throughout except backdrops (WebP). If a file is absent the game falls back
silently, so partial deliveries are safe to drop in and look at.
