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

## Tier cycling (§2: floors past the authored end repeat the biomes at tier 2,
## 3, ... with one mutation per tier) is deliberately not here. `for_floor`
## clamps into the deepest biome instead, and `depth` is the authored end,
## which is what `can_push` stops at. A tier without its mutation modifier is
## just the same floors again with a bigger number on them.
static func for_floor(content: Content, floor: int) -> BiomeDef:
	var best: BiomeDef = null
	for id in content.biomes:
		var b: BiomeDef = content.biomes[id]
		if floor >= b.first_floor and floor <= b.last_floor:
			return b
		if best == null or b.first_floor < best.first_floor:
			best = b
	# Off either end. A floor above everything authored belongs to the deepest
	# biome; anything else to the shallowest. Returning null instead would move
	# the crash to whichever caller was handed the bad floor.
	if floor > depth(content):
		return deepest(content)
	return best


static func depth(content: Content) -> int:
	var deep := 0
	for id in content.biomes:
		deep = maxi(deep, (content.biomes[id] as BiomeDef).last_floor)
	return deep


static func deepest(content: Content) -> BiomeDef:
	var best: BiomeDef = null
	for id in content.biomes:
		var b: BiomeDef = content.biomes[id]
		if best == null or b.last_floor > best.last_floor:
			best = b
	return best


## The biomes with one of the guild's own standing in them (spec §5.6).
##
## Derived from the ladder rather than stored. A stored claim is a second copy
## of a fact the ladder already holds, and the two can disagree -- most obviously
## for a ghost that was already standing in a biome before claims existed, which
## this credits on load for free.
##
## An echo does not claim. §5.6 says the *first true ghost*, and a claim that an
## echo could make would be a claim you could buy.
static func claimed(content: Content, ladder: Ladder) -> Array[String]:
	var out: Array[String] = []
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
static func claimed_pools(content: Content, ladder: Ladder) -> Array[String]:
	var out: Array[String] = []
	for id in claimed(content, ladder):
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
