# M2 Stage 9 — The creatures stop being placeholders

Spec §9. The last thing in the game that was still a stand-in.

## Why this, now

Every stage since the 3D pivot has carried the same line in its notes: *only
the enemy models are placeholders*. The room around them is photoscanned
sandstone with a normal map, a roughness map and ambient occlusion. The thing
trying to kill you was a capsule with a ball on top, and then five silhouettes
of stacked primitives, and the plan was always "a rigged model replaces
`EnemyShape.build` and nothing else changes".

## What the search actually turned up

The plan assumed the blocker was sourcing a rigged CC0 creature. It is not.
There are two good CC0 packs with rigs, animations and glTF exports —
Quaternius's Ultimate Monsters (50 creatures, `Idle`/`Death`/`HitRecieve`/
`Bite_Front`, individually downloadable as GLB from poly.pizza's CDN) and
KayKit's Skeletons (4 characters, 90+ animations) — and **both are chibi**.
Big heads, tiny bodies, glowing anime eyes. That is what the free market for
rigged monsters is, because that is what sells on itch.

Dropping a chibi skeleton into a photoscanned crypt would have made the game
worse than the capsule did. The capsule was honest about being a placeholder;
a cartoon in a photograph is a decision, and the wrong one.

## What the game actually needed

Its own fiction already had the answer. **These creatures are made of parts.**
A skeleton is a skull, a jaw, a cage of ribs and four long bones. A construct
is plates bolted together. Building one out of pieces is not a workaround for
having no model — it is what the thing is, and it is why the pieces can then
move independently, which is the half that reads as alive.

So: three new files, no assets, no artist.

- **`BoneMesh`** — the parts. A skull with a hinged jaw, two sockets and two
  points of light in them; a ribcage of rings you can see the wall through; a
  long bone with a knuckle at each end; horns, plates, mushroom caps, and an
  ember with a halo for the things that are only fire.
- **`CreatureRig`** — the assembly. Parts hang off named joints, the head a
  child of the chest and the jaw a child of the skull, so `rest * offset` from
  a pose table moves them. One joint name may hold several nodes: a beast has
  four legs and two joints.
- **`CreaturePose`** — the motion, and the reason any of this is testable.
  Pure maths: `(archetype, time, phase, hurt, dead) -> {joint: Transform3D}`.

`EnemyShape` keeps only the question the rest of the game asks — *what shape
of thing is this* — and is now the file at the bottom that the other three
point at.

## The part that matters most

Motion used to be tweens on node properties, which a `--headless` run reads
back as the number it just wrote. Nothing about how a creature moved was ever
checked, and the bugs that produces are exactly the ones a still frame cannot
show either. Both of them turned up the moment the maths was testable:

- **A corpse that keeps breathing.** The collapse was composed on top of a
  still-running idle. `pose` fades the idle out with the lights now.
- **A room of three bone rats moving as one animal**, which is worse than
  three still ones because it reads as copy-paste. Each body gets its own
  phase, derived from its index so a fight still replays from its seed.

## What the renders caught, which no test could

- **The creatures were too far away.** The front rank staged 1.6 m *beyond* the
  room's centre, and the player triggers an encounter from wherever the marker
  happens to sit — five to six metres back in a nine-metre room. `ENGAGE`
  closes the distance over half a second: the hero steps up to the fight, which
  is a better half-second than the freeze it replaces, and the camera still
  never cuts.
- **They were unlit.** The fight brings a low warm pool of its own now. The
  first value tried, 2.2, lit the walls as well and the crypt stopped being
  dark, which costs more than legibility buys — the whole threat of this place
  is that you cannot see. 1.1 lights the creature and leaves the room alone.
- **The hulk was a barrel on legs.** A ribcage as wide as the creature is tall
  gives the shoulders nothing narrower to sit above.

## Self-review

The risk here was tone, and it was nearly walked into: the fastest path was a
free rigged pack, and the fastest path would have cost the game its face. The
second risk is that procedural parts read as *programmer art with more steps*.
The defence is that the parts are the fiction — and the check is the render,
because a test can prove a jaw opens and cannot tell you whether the thing
looks like a creature.

The third risk is silent: a pose that names a joint the rig never built does
nothing at all and looks exactly like an animation nobody wrote.
`creature_rig_test` walks every archetype's own idle table and asserts the rig
has each joint it drives.
