class_name RoomPresentation
extends RefCounted
## One identity shared by map, compass, doorway signs and interaction prompts.

const KINDS := ["fight", "elite", "event", "rest", "shop", "boss", "entry", "stairs"]
const ACCENTS := {
	"fight": Color(0.94, 0.62, 0.52), "elite": Color(0.97, 0.43, 0.29),
	"event": Color(0.68, 0.63, 0.98), "rest": Color(0.58, 0.85, 0.63),
	"shop": Color(0.97, 0.81, 0.39), "boss": Color(0.98, 0.36, 0.52),
	"entry": Color(0.53, 0.85, 0.95), "stairs": Color(0.53, 0.85, 0.95),
}


static func accent(kind: String) -> Color:
	return ACCENTS.get(kind, Palette.BONE)


static func icon(kind: String) -> Texture2D:
	return Icons.get_icon("node", "exit" if kind in ["entry", "stairs"] else kind)


static func label(content: Content, kind: String) -> String:
	return content.text("room." + kind + ".name")


static func availability(run: RunState, index: int) -> String:
	var record := run.room_record(index)
	if run.nodes[index].get("kind") == "shop":
		if not bool(record.get("available", false)):
			return "unavailable"
		var stock: Dictionary = record.get("shop", {})
		if not stock.is_empty() and stock.get("cards", []).is_empty() and stock.get("relic", "") == "" and stock.get("removed", false):
			return "sold_out"
		return "open"
	return "completed" if run.is_resolved(index) else ("visited" if run.is_visited(index) else "unvisited")


static func describe(run: RunState, index: int) -> String:
	var content := run.content
	var kind := String(run.nodes[index]["kind"])
	var required := bool(run.room_record(index).get("required", true))
	return label(content, kind) + " · " + content.text("room.required" if required else "room.optional") \
		+ "\n" + content.text("room." + kind + ".risk") + "\n" \
		+ content.text("room.state." + availability(run, index))


static func stairs_text(run: RunState) -> String:
	return run.content.text("room.stairs.ready" if run.exit_ready() else "room.stairs.locked").replace("{n}", str(run.remaining_required()))


static func deliberate(kind: String) -> bool:
	return kind in ["elite", "event", "rest", "shop"]
