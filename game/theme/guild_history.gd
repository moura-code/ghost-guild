class_name GuildHistory
extends RefCounted
## Derived achievements only. No decoration currency or new unlock state.

static func entries(c: Campaign) -> Array:
	var out := []
	var claimed := c.claimed_biomes.duplicate()
	for id in Biomes.claimed(c.content, c.ladder):
		if not claimed.has(id):
			claimed.append(id)
	claimed.sort()
	for id in claimed:
		out.append({"kind": "biome", "key": id, "title": c.content.text("biome." + id + ".name"), "reason": c.content.text("guild.history.biome")})
	for legend in c.legends.slice(maxi(0, c.legends.size() - 3)):
		out.append({"kind": "legend", "key": str(legend.id), "title": legend.name, "reason": c.content.text("guild.history.legend").replace("{n}", str(legend.cycle))})
	if c.expedition_counter > 0:
		out.append({"kind": "expedition", "key": "expedition", "title": c.content.text("guild.history.expedition"), "reason": c.content.text("guild.history.commissioned").replace("{n}", str(c.expedition_counter))})
	return out
