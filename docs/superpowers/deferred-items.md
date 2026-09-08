# Deferred items and measured limits

Audited against the hybrid through 2026-09-08. The previous milestone list mixed
historical defects with features already delivered on `3d-pivot`.

## Still relevant

- Enemy intent uses `EnemyAI.intent_of`; a full future-damage preview that
  accounts for status expiry, retaliation and interrupted multi-hit attacks
  remains follow-up work. Card inspection explicitly distinguishes authored
  base/upgraded rules from current modifiers and engine resolution.
- `hash()`-derived RNG streams are not guaranteed across Godot versions.
  Stay on 4.7.2; schema 3 persists live fight stream states, but changing the
  engine still requires a compatibility review for future seeded content.
- Banking a ghost still calculates its recorded strength synchronously.
  Exit projections use a private snapshot on a worker; changing the banked
  calculation or its sample count requires an economy comparison.
- `GameRoot.drain_events` exists; long idle sessions should be profiled for
  retained event history as content expands.
- An unknown killer id still needs a deliberate fallback epitaph policy.
- `RunAutopilot` shop selection is a broad affordability policy. A smarter
  purchase policy would change balance measurements and deserves its own work.
- Complete controller support and key rebinding, a creature compendium,
  additional authored character detail and any 2D-only/Compatibility edition
  are outside this integration.
- Performance is measured on the development RTX 4070 laptop with Forward+.
  Establish a measured lower-spec target before advertising one. See the
  hybrid validation record for frame-time and memory results.

## Historical entries resolved or superseded

| Old item | Current evidence |
| --- | --- |
| Balance simulator deliberately exits 1 | Superseded by the M2 balance pass (`237c31a`); exit 0 is required. Final hybrid result is recorded with validation. |
| One biome, missing true-ghost helper | `Biomes` cycles all three biomes through unbounded tiers; `Ghost.is_true` covers expedition ghosts. Deep boundary and walkthrough tests cover progression. |
| Save rotation precedes a failed open; hardcoded v1; missing backup tests | Schema 3, validated temporary writes, atomic replacement, both backup levels and missing-primary/import regressions. |
| No combat/death animation | `FightAnimator3D`, `EnemyBody`, `GhostFigure` and paced epitaphs are live; pause/resume and reduced motion are covered. |
| Exit UI blocks the frame for simulations | `ExitScreen` computes ahead on a private snapshot, bounds preview samples, rejects stale results and joins tasks during teardown. |
| No accrual-before-spend rule | GameRoot wrappers settle before guild mutations; CampaignEngine settles start/finish/load. These remain the only UI mutation entry points. |
| Missing event drain API | `GameRoot.drain_events` exists; retention policy is noted above. |
| Baked ghost epitaphs | Ghost records store `epitaph_key`, name, floor and killer; text resolves from Content. |
| Empty encounter validation absent | `Validator._biome` validates encounter groups, elites, bosses and node patterns. |
| Guild navigation requires walking | G/tabs and stations now use the same persistent panels. |
| Legacy/current saves share automated-test directories | Linux and Windows test wrappers isolate user data; edition launch profiles and copy import are documented. |

The earlier broad suggestions about adding audio, a second class, expeditions,
hauntings and prestige are implemented content, not an outstanding work queue.
Engine shutdown assertions and process status are recorded separately in the
hybrid evidence; a historical crash is not treated as permission to ignore a
new one.
