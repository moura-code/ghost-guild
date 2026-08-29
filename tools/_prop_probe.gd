extends SceneTree
func _init() -> void:
	await process_frame
	for name in ["gothic_statue","marble_bust_01","wooden_barrels_01","wooden_crate_01","ceramic_vase_01","antique_ceramic_vase_01","boulder_01","wooden_bucket_01"]:
		var path := "res://assets/props/%s/%s.gltf" % [name, name]
		var res := load(path)
		if res == null:
			print("PROP %s : FAILED TO LOAD" % name)
			continue
		var inst: Node3D = (res as PackedScene).instantiate()
		var aabb := AABB()
		var first := true
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = m
			var b := mi.get_aabb()
			b.position += mi.position
			if first:
				aabb = b
				first = false
			else:
				aabb = aabb.merge(b)
		print("PROP %-26s size=%.2f x %.2f x %.2f  meshes=%d" % [name, aabb.size.x, aabb.size.y, aabb.size.z, inst.find_children("*", "MeshInstance3D", true, false).size()])
		inst.free()
	quit()
