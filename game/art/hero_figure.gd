class_name HeroFigure
extends Node3D
## Living guild members, built with the production models' mesh helpers.

var class_id: String
var hero_name: String


static func create(hero: Hero) -> HeroFigure:
	var figure := HeroFigure.new()
	figure.class_id = hero.class_id
	figure.hero_name = hero.name
	figure.name = "Hero_" + hero.class_id
	figure._build()
	return figure


static func material(colour: Color, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.metallic = metal
	mat.roughness = 0.42 if metal > 0.0 else 0.9
	return mat


func _build() -> void:
	var hexer := class_id == "hexer"
	var cloth := material(Color("45485d") if hexer else Color("49413a"))
	var leather := material(Color("27282e"))
	var skin := material(Color("bdac94"))
	var iron := material(Color("777d86"), 0.7)
	var brass := material(Color("b39867"), 0.7)
	var coat := BoneMesh.loft([Vector2(0.30, 0.22), Vector2(0.32, 0.40),
		Vector2(0.23, 0.80), Vector2(0.22, 1.03), Vector2(0.31, 1.27),
		Vector2(0.18, 1.36)], 24, 0.07)
	BoneMesh._part(self, "Coat", coat, cloth, Vector3.ZERO).scale.z = 0.72
	for side in [-1.0, 1.0]:
		BoneMesh.ellipsoid(self, "Boot", Vector3(side * 0.14, 0.13, -0.06), Vector3(0.17, 0.26, 0.29), leather)
		BoneMesh.link(self, "Sleeve", Vector3(side * 0.27, 1.22, 0), Vector3(side * 0.42, 0.84, -0.05), 0.105, cloth)
		BoneMesh.ellipsoid(self, "Glove", Vector3(side * 0.43, 0.77, -0.055), Vector3(0.10, 0.15, 0.11), leather)
	BoneMesh.ellipsoid(self, "Face", Vector3(0, 1.49, -0.055), Vector3(0.24, 0.30, 0.20), skin)
	var shadow := material(Color("332d2c"))
	for side in [-1.0, 1.0]:
		BoneMesh.ellipsoid(self, "Eye", Vector3(side * 0.056, 1.53, -0.152), Vector3(0.033, 0.022, 0.013), shadow)
		BoneMesh.link(self, "Brow", Vector3(side * 0.03, 1.56, -0.147), Vector3(side * 0.085, 1.55, -0.136), 0.013, leather)
		BoneMesh.link(self, "CoatSeam", Vector3(side * 0.14, 1.26, -0.19), Vector3(side * 0.1, 0.91, -0.17), 0.009, brass)
	BoneMesh.ellipsoid(self, "Nose", Vector3(0, 1.48, -0.162), Vector3(0.042, 0.07, 0.045), skin)
	BoneMesh.link(self, "Mouth", Vector3(-0.035, 1.42, -0.146), Vector3(0.035, 1.42, -0.146), 0.006, shadow)
	for i in 5:
		BoneMesh.ellipsoid(self, "CoatButton", Vector3(0, 0.97 + i * 0.065, -0.19), Vector3.ONE * 0.027, brass)
	var hood := BoneMesh.loft([Vector2(0.23, 1.29), Vector2(0.245, 1.48),
		Vector2(0.18, 1.69), Vector2(0.015, 1.94 if hexer else 1.74)], 24, 0.03)
	BoneMesh._part(self, "Cowl", hood, cloth, Vector3(0, 0, 0.095)).scale.z = 0.78
	BoneMesh.ellipsoid(self, "Belt", Vector3(0, 0.86, 0), Vector3(0.49, 0.075, 0.35), leather)
	BoneMesh.ellipsoid(self, "Buckle", Vector3(0, 0.86, -0.19), Vector3(0.08, 0.09, 0.025), brass)
	if hexer:
		# The thimble and a long ritual needle distinguish the caster from
		# the Sexton's broad spade and low lantern.
		BoneMesh.link(self, "Needle", Vector3(-0.44, 0.4, -0.04), Vector3(-0.50, 1.75, -0.04), 0.015, iron)
		BoneMesh.ellipsoid(self, "Thimble", Vector3(0.44, 0.81, -0.12), Vector3(0.09, 0.10, 0.085), brass)
		for i in 5:
			BoneMesh.ellipsoid(self, "Charm", Vector3(-0.17 + i * 0.085, 1.16 - sin(i * 0.7) * 0.1, -0.23), Vector3.ONE * 0.042, brass)
	else:
		BoneMesh.link(self, "SpadeHandle", Vector3(-0.43, 0.17, -0.03), Vector3(-0.43, 1.25, -0.03), 0.025, leather)
		BoneMesh.ellipsoid(self, "Spade", Vector3(-0.43, 0.22, -0.03), Vector3(0.23, 0.34, 0.06), iron)
		var cage := BoxMesh.new()
		cage.size = Vector3(0.20, 0.27, 0.20)
		var glass := BoneMesh.eye_material(Palette.LANTERN)
		glass.emission_energy_multiplier = 0.8
		BoneMesh._part(self, "Lantern", cage, glass, Vector3(0.44, 0.48, -0.06))
		for x in [-0.10, 0.10]:
			for z in [-0.10, 0.10]:
				BoneMesh.link(self, "LanternFrame", Vector3(0.44 + x, 0.32, z - 0.06), Vector3(0.44 + x, 0.65, z - 0.06), 0.018, iron)
		BoneMesh.link(self, "LanternHandle", Vector3(0.44, 0.64, -0.06), Vector3(0.44, 0.78, -0.06), 0.016, iron)
