# Synthetic 2D saves

Generated on 2026-09-06 with Godot 4.7.2 from the preserved 2D implementation
`5200eda1607c8a76e4ddd475d983c1c7d211123c`, using
`tools/legacy_fixtures.gd` copied into a detached checkout. Seed 73019,
timestamps 1000, no user campaign files. All JSON is the old implementation's
own `Campaign.to_dict()` output.

The files cover guild, descent, node, fight, reward, event, shop, rest, exit,
ended (unbanked) and completed (banked) states. `fight.json` has phase `node`:
the old serializer deliberately discarded the active fight and decremented
its fight counter so it restarted on reload. Migration cannot recover data
that implementation never wrote. Tests preserve that distinction from exact
schema-3 combat continuation.
