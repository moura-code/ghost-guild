class_name Classes
extends RefCounted
## Which classes the guild can send down (spec §3.4, §5.6).
##
## The starting class is a rule, not a name: it is the class nothing has to be
## unlocked for. It was written as the string `"sexton"` in `Ghost.founder`,
## `CampaignEngine.new_hero`, `Expeditions.hero_for` and the three demo tools,
## which is correct exactly as long as there is one class.
##
## Everything else is unlocked by claiming a biome -- §5.6: the Hexer arrives
## with the first true ghost in the Fungal Deep. Derived from the ladder rather
## than stored, for the same reason claims are: a stored unlock can disagree
## with the ghosts, and the ghosts are the truth.


## The class a new guild starts with. Falls back to the first id in the data
## rather than to a literal, so a content file that forgets `unlocked_by`
## produces a playable game and a failing test rather than a crash.
static func starting(content: Content) -> String:
	var ids: Array = content.classes.keys()
	ids.sort()
	for id in ids:
		if (content.classes[id] as ClassDef).unlocked_by == "":
			return String(id)
	return String(ids[0]) if not ids.is_empty() else ""


## Every class available to this guild, sorted, starting class first.
static func unlocked(content: Content, ladder: Ladder) -> Array[String]:
	var claimed := Biomes.claimed(content, ladder)
	var first := starting(content)
	var out: Array[String] = []
	if first != "":
		out.append(first)
	var ids: Array = content.classes.keys()
	ids.sort()
	for id in ids:
		var klass: ClassDef = content.classes[id]
		if klass.unlocked_by != "" and claimed.has(klass.unlocked_by):
			out.append(String(id))
	return out


static func is_unlocked(content: Content, ladder: Ladder, class_id: String) -> bool:
	return unlocked(content, ladder).has(class_id)


## The biome that opens this class, or "" if nothing does. For the UI, which
## has to say *why* a class is locked -- a greyed-out row with no reason is
## worse than no row at all.
static func locked_behind(content: Content, class_id: String) -> String:
	if not content.classes.has(class_id):
		return ""
	return (content.classes[class_id] as ClassDef).unlocked_by
