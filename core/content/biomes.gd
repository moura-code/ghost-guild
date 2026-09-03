class_name Biomes
extends RefCounted
## Which biome a floor is in, how deep the dungeon goes, and which biomes the
## guild has claimed (spec §2, §5.6).
##
## The campaign and the run each used to carry one `biome_id`, set once when
## they started. Every projection in the game -- an echo's strength, an
## expedition's survival, a ghost's yield, the next floor's difficulty -- is
## handed a *floor* and read that one field, which is correct exactly as long
## as there is one biome. Two biomes and every one of those prices the wrong
## enemy table, silently, for a floor it was told about.
##
## So a floor answers the question, and nothing stores the answer.

## Which cycle of the dungeon a floor is in (§2): floors past the authored end
## repeat the biomes at tier 2, 3, and so on for ever. Tier 1 is the dungeon as
## it was authored, and everything above floor 0 is tier 1 too, because a
## `reach` calculation can hand this a zero.
static func tier_of(content: Content, floor: int) -> int:
	var span := depth(content)
	if span <= 0 or floor <= span:
		return 1
	return (floor - 1) / span + 1


## The floor's position within its own tier: 1..depth, whatever tier it is in.
static func in_tier(content: Content, floor: int) -> int:
	var span := depth(content)
	if span <= 0:
		return maxi(1, floor)
	return (floor - 1) % span + 1 if floor > 0 else 1


## The biome a floor is in. Past the authored end the biomes cycle rather than
## clamping, so floor 31 is the Catacombs again at tier 2 -- which is what
## makes a prestige a new descent rather than the same thirty floors with a
## bigger multiplier on them (§6.1).
static func for_floor(content: Content, floor: int) -> BiomeDef:
	var wrapped := in_tier(content, floor)
	var best: BiomeDef = null
	for id in content.biomes:
		var b: BiomeDef = content.biomes[id]
		if wrapped >= b.first_floor and wrapped <= b.last_floor:
			return b
		if best == null or b.first_floor < best.first_floor:
			best = b
	# A gap in the authored ranges. `slice_content_test` forbids one, so this
	# is the answer to corrupt data rather than to a floor number: returning
	# null would move the crash to whichever caller was handed it.
	return best


static func depth(content: Content) -> int:
	var deep := 0
	for id in content.biomes:
		deep = maxi(deep, (content.biomes[id] as BiomeDef).last_floor)
	return deep


## The biomes with one of the guild's own standing in them (spec §5.6).
##
## Derived from the ladder rather than stored. A stored claim is a second copy
## of a fact the ladder already holds, and the two can disagree -- most obviously
## for a ghost that was already standing in a biome before claims existed, which
## this credits on load for free.
##
## An echo does not claim. §5.6 says the *first true ghost*, and a claim that an
## echo could make would be a claim you could buy.
## `banked` carries claims from earlier prestige cycles. A claim is derived
## from the ladder and prestige wipes the ladder, so without it the rite would
## silently re-lock every biome the guild had reached -- and §6.1 lists biome
## claims among the things a prestige keeps.
static func claimed(content: Content, ladder: Ladder, banked: Array = []) -> Array[String]:
	var out: Array[String] = []
	for id in banked:
		if content.biomes.has(id) and not out.has(String(id)):
			out.append(String(id))
	for g in ladder.ghosts:
		var ghost := g as Ghost
		if not ghost.is_true():
			continue
		var id := for_floor(content, ghost.floor).id
		if not out.has(id):
			out.append(id)
	out.sort()
	return out


## The card pools those claims open, for the Descent draft and for shops.
static func claimed_pools(content: Content, ladder: Ladder, banked: Array = []) -> Array[String]:
	var out: Array[String] = []
	for id in claimed(content, ladder, banked):
		var pool := (content.biomes[id] as BiomeDef).card_pool
		if pool != "" and not out.has(pool):
			out.append(pool)
	return out


## Everywhere a card offer can be drawn from: the hero's class, every claimed
## biome, and the floor being stood on -- that last one unconditionally,
## because the first descent into a new biome has to be able to offer its
## cards before anyone has claimed it.
##
## One function because there are two callers with the same rule: a live run's
## rewards and shops, and the expedition hero's auto-draft. They were the same
## six lines twice, which is how a claimed biome ends up opening its pool for
## the player and not for the guild.
##
## Deduplicated: `Rewards.card_offer` draws uniformly across the union of the
## pools it is handed, so a pool listed twice would quietly have double the
## odds.
static func pools_for(content: Content, class_pool: String, claimed_card_pools: Array,
		floor: int) -> Array:
	var out: Array = [class_pool]
	for pool in claimed_card_pools:
		if not out.has(pool):
			out.append(pool)
	var here := for_floor(content, floor).card_pool
	if here != "" and not out.has(here):
		out.append(here)
	return out
