class_name Relics
extends RefCounted
## Fires relic hooks. A relic is a RelicDef id carried on the FightState.


static func fire(s: FightState, hook: String) -> void:
	for relic_id in s.relics:
		var def: RelicDef = s.content.relics.get(relic_id)
		if def == null or not def.hooks.has(hook):
			continue
		s.emit({"type": "relic_triggered", "relic": relic_id, "hook": hook})
		var ctx := {"target": -1, "card_target": "none", "tags": [], "is_attack": false, "x": 0}
		EffectResolver.resolve(s, def.hooks[hook], {"kind": "relic", "id": relic_id}, ctx)
