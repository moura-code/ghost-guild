class_name Traits
extends RefCounted
## Which trait a Legend carries, and what it is worth in a fight.
##
## Pure and total, and an identity at nothing: `bonus` with no trait returns
## zero, so a guild that has never prestiged plays a game byte-identical to the
## one it played before Legends existed. That is the same property the Blessing
## has and for the same reason -- prestige multiplies everything, so it is the
## feature that most needs to disappear completely when it is absent.


## The trait for a card tag, or null when nothing is authored for it.
static func for_tag(content: Content, tag: String) -> TraitDef:
	if tag == "":
		return null
	for id in content.traits:
		var t: TraitDef = content.traits[id]
		if t.tag == tag:
			return t
	return null


## The trait a Legend carries.
static func of(content: Content, legend: Legend) -> TraitDef:
	return for_tag(content, legend.trait_tag) if legend != null else null


## What a trait adds to one effect on one card.
##
## Zero unless the card carries the trait's tag *and* the effect is the kind
## the trait boosts. Both halves matter: a Poison trait that also made your
## Block cards better would be a global modifier wearing a tag's name.
static func bonus(trait_def: TraitDef, op: String, tags: Array) -> int:
	if trait_def == null or trait_def.op != op:
		return 0
	return trait_def.amount if tags.has(trait_def.tag) else 0


## The Legend the campaign is carrying into its next run, or null.
##
## One per run (spec §6.1: "One Legend can be invoked per run as an extra
## relic"), chosen in the Hall and stored by id rather than by index, because
## the Hall lists them oldest first and a later prestige must not silently
## re-point an invocation at somebody else's grave.
static func invoked(c: Campaign) -> Legend:
	for l in c.legends:
		if l.id == c.invoked_legend:
			return l
	return null
