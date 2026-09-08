class_name UiContext
extends RefCounted
## Return addresses for optional overlays. RunEngine remains the phase authority.

var callers: Array[Dictionary] = []
var run: RunState
var phase: String = ""


func remember(current: RunState) -> void:
	run = current
	phase = current.phase if current != null else ""


func valid(current: RunState) -> bool:
	return current == run and (current == null or current.phase == phase)


func push(panel: Control, focus: Control) -> void:
	callers.append({"panel": panel, "focus": focus})


func pop() -> Dictionary:
	return callers.pop_back() if not callers.is_empty() else {}


func clear() -> void:
	callers.clear()
