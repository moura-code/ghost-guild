class_name GuildRoom
extends Node3D
## The walkable guild: an upgrade table, a séance circle, the hero's desk, the
## ladder down, and the well you look into to see your dead.
##
## Hand-placed rather than generated. It is one room the player returns to a
## thousand times and it is the shot the store page opens on, so it is
## authored -- a seeded guild would be a different room every time you came
## home, which is the opposite of what a home is for.

## Stations, in the order they are placed. Ids are what Interactable reports
## and what Crawl matches on.
const TABLE := "table"
const CIRCLE := "circle"
const DESK := "desk"
## The well is both the view down and the way down: spec §8 says looking into
## it shows the tower of your dead and walking into it starts the descent.
## They are the same object seen two ways, so it is one station, not two.
const WELL := "well"
## The Hall of Legends (spec §6.1). A wall, not a table: it is the one station
## you read rather than spend at.
const HALL := "hall"

## In cells, like a dungeon floor, so the kit's metres stay the only metres.
const WIDTH := 9
const DEPTH := 9
## The well is a hole in the middle of the floor.
const WELL_CELL := Vector2i(4, 4)
## Waist-high, so you lean over it rather than see over it.
const WELL_RIM := 0.85
const WELL_THICK := 0.35

var layout: FloorLayout
var stations: Array[Interactable] = []
var well: WellView

var _by_id: Dictionary = {}
var history: Node3D
var _banners: Array[Node3D] = []
var _ambient_time: float = 0.0


## The guild's floor plan, as the same FloorLayout a dungeon uses -- so the
## same builder, the same kit and the same collision apply, and the guild
## cannot drift into a different physical scale from the crypt below it.
static func plan() -> FloorLayout:
	var l := FloorLayout.create(WIDTH + 2, DEPTH + 2)
	for y in range(1, DEPTH + 1):
		for x in range(1, WIDTH + 1):
			l.set_cell(x, y, FloorLayout.Cell.FLOOR)
	LayoutGenerator.add_walls(l)
	# The well is punched AFTER the wall pass, or add_walls sees a void cell
	# surrounded by floor and fills it in -- which turns the well into a solid
	# pillar in the middle of the room. A hole has to stay a hole.
	l.set_cell(WELL_CELL.x, WELL_CELL.y, FloorLayout.Cell.VOID)
	l.rooms = [{"x": 1, "y": 1, "w": WIDTH, "h": DEPTH}]
	l.entry_room = 0
	l.stairs_room = 0
	# Torches on the four walls, so the room is lit in pools like everywhere
	# else rather than evenly like a menu.
	l.torch_anchors = [
		Vector2i(0, 3), Vector2i(0, DEPTH - 1),
		Vector2i(WIDTH + 1, 3), Vector2i(WIDTH + 1, DEPTH - 1),
		Vector2i(3, 0), Vector2i(WIDTH - 1, DEPTH + 1),
	]
	return l


## Where each station stands, in cells. Spread to the four sides so walking
## between them is walking across a room, not turning on the spot.
static func station_cells() -> Dictionary:
	return {
		TABLE: Vector2i(2, 2),
		CIRCLE: Vector2i(WIDTH - 1, 2),
		DESK: Vector2i(2, DEPTH - 1),
		HALL: Vector2i(WIDTH - 1, DEPTH - 1),
		WELL: WELL_CELL,
	}


static func spawn_cell() -> Vector2i:
	return Vector2i(WIDTH / 2 + 1, DEPTH)


func build(campaign: Campaign) -> void:
	layout = plan()
	DungeonBuilder.build(layout, self)
	add_child(Grade.world_environment_guild())

	var cells := station_cells()
	for id in [TABLE, CIRCLE, DESK, HALL, WELL]:
		var reach := 2.4 if id == WELL else Interactable.REACH
		var it := Interactable.create(String(id), Kit.cell_to_world(cells[id]), "ui.use.%s" % id, reach)
		add_child(it)
		stations.append(it)
		_by_id[id] = it
		if id != WELL:
			add_child(_plinth(Kit.cell_to_world(cells[id]), String(id)))

	_architecture(campaign)

	_build_well_head()
	_patch_ceiling_over_the_well()

	well = WellView.new()
	well.name = "Well"
	well.position = Kit.cell_to_world(WELL_CELL)
	add_child(well)
	well.build(campaign)
	refresh_history(campaign)


## A waist-high ring of stone around the hole. It is what makes the well a
## well: you can lean over it and look down, and you cannot walk into it. It
## also does the job the missing floor tile would otherwise leave undone --
## the builder's ground slab runs under the whole room, so without the rim the
## player would stand on invisible collision in mid-air over the shaft.
func _build_well_head() -> void:
	var body := StaticBody3D.new()
	body.name = "WellHead"
	body.collision_layer = DungeonBuilder.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)

	var centre := Kit.cell_to_world(WELL_CELL)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.34, 0.31)
	m.roughness = 0.92
	var half := Kit.CELL * 0.5
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		# A segment runs across the side it sits on: thin along the direction
		# it faces, a full cell wide the other way.
		var size := Vector3(Kit.CELL, WELL_RIM, WELL_THICK) if step.x == 0 else Vector3(WELL_THICK, WELL_RIM, Kit.CELL)
		var at := centre + Vector3(float(step.x) * (half - WELL_THICK * 0.5), WELL_RIM * 0.5, float(step.y) * (half - WELL_THICK * 0.5))

		var box := BoxMesh.new()
		box.size = size
		var inst := MeshInstance3D.new()
		inst.mesh = box
		inst.material_override = m
		inst.position = at
		body.add_child(inst)

		var shape := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		# Full height on the collider even though the stone is waist-high: the
		# rim has to stop a body, and a 0.9 m box is something a character
		# controller will climb given a running start.
		solid.size = Vector3(size.x, Kit.WALL_H, size.z)
		shape.shape = solid
		shape.position = Vector3(at.x, Kit.WALL_H * 0.5, at.z)
		body.add_child(shape)


## The builder gives a ceiling tile to every FLOOR cell, and the well is not
## one, so without this there is a square hole in the ceiling directly above
## the well -- a skylight in a crypt.
func _patch_ceiling_over_the_well() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(Kit.CELL, Kit.CELL)
	var inst := MeshInstance3D.new()
	inst.name = "CeilingPatch"
	inst.mesh = plane
	inst.material_override = Kit.ceiling_material()
	inst.position = Kit.cell_to_world(WELL_CELL) + Vector3(0.0, Kit.WALL_H, 0.0)
	inst.rotation = Vector3(PI, 0.0, 0.0)
	add_child(inst)


func station(id: String) -> Interactable:
	return _by_id.get(id, null)


func spawn_point() -> Vector3:
	return Kit.cell_to_world(spawn_cell())


## Something to stand at. A station that is only a trigger volume is a station
## the player cannot see from across the room, which turns the guild into a
## hunt for invisible hotspots.
func _plinth(at: Vector3, id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Plinth_" + id
	root.position = at
	var stone := HeroFigure.material(Color("494648"))
	var wood := HeroFigure.material(Color("4a342a"))
	var metal := HeroFigure.material(Color("b99d67"), 0.65)
	var parchment := HeroFigure.material(Color("b7a17a"))
	var tint := BoneMesh.eye_material(Palette.SOUL if id == CIRCLE else Palette.LANTERN)
	tint.emission_energy_multiplier = 0.35
	if id == CIRCLE:
		for radius in [0.65, 0.9]:
			var ring := TorusMesh.new()
			ring.inner_radius = radius - 0.025
			ring.outer_radius = radius
			BoneMesh._part(root, "RiteCircle", ring, tint, Vector3(0, 0.025, 0))
		for i in 6:
			var angle := i * TAU / 6
			var point := Vector3(cos(angle) * 0.8, 0.1, sin(angle) * 0.8)
			BoneMesh.link(root, "Candle", point, point + Vector3.UP * 0.22, 0.04, parchment)
			BoneMesh.ellipsoid(root, "Flame", point + Vector3.UP * 0.25, Vector3(0.05, 0.11, 0.05), tint)
	elif id == HALL:
		_box(root, "Monument", Vector3(1.3, 1.9, 0.3), Vector3(0, 0.95, 0), stone)
		for i in 3:
			_box(root, "LegendPlaque", Vector3(0.92, 0.34, 0.04), Vector3(0, 0.47 + i * 0.5, -0.18), metal)
			BoneMesh.ellipsoid(root, "Seal", Vector3(0, 0.47 + i * 0.5, -0.22), Vector3(0.15, 0.21, 0.035), tint)
	else:
		_box(root, "Table", Vector3(1.2, 0.12, 0.85), Vector3(0, 0.85, 0), wood)
		for x in [-0.5, 0.5]:
			for z in [-0.32, 0.32]:
				_box(root, "Leg", Vector3(0.10, 0.83, 0.1), Vector3(x, 0.42, z), wood)
		if id == DESK:
			_box(root, "Ledger", Vector3(0.56, 0.05, 0.38), Vector3(0, 0.96, 0), parchment)
			BoneMesh.link(root, "Quill", Vector3(0.35, 0.92, 0), Vector3(0.45, 1.25, 0), 0.012, parchment)
		else:
			_box(root, "Anvil", Vector3(0.47, 0.2, 0.27), Vector3(-0.1, 1.03, 0), metal)
			BoneMesh.link(root, "Hammer", Vector3(0.3, 0.95, -0.18), Vector3(0.3, 0.95, 0.18), 0.035, wood)
			_box(root, "HammerHead", Vector3(0.23, 0.09, 0.1), Vector3(0.3, 0.96, 0.18), metal)
	if id != CIRCLE:
		var body := StaticBody3D.new()
		body.collision_layer = DungeonBuilder.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.3, 1.9, 0.3) if id == HALL else Vector3(1.2, 0.9, 0.85)
		shape.shape = box
		shape.position.y = box.size.y * 0.5
		body.add_child(shape)
		root.add_child(body)
	return root


func _box(parent: Node3D, name: String, size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var box := BoxMesh.new()
	box.size = size
	BoneMesh._part(parent, name, box, material, at)


func _architecture(campaign: Campaign) -> void:
	var stone := RoomComposition.material(Color("514d4d"))
	var brass := RoomComposition.material(Color("9b7947"), 0.65)
	var cold := RoomComposition.material(Color("4c8eaf"), 0.2, 0.25)
	var wood := RoomComposition.material(Color("493226"))
	var center := Kit.cell_to_world(WELL_CELL)
	# A canopy frames the arrival view and protects the overlook. Columns sit
	# outside the well rim; the approach and all five station lanes stay open.
	for x in [-2.3, 2.3]:
		for z in [-2.3, 2.3]:
			var at := center + Vector3(x, 0, z)
			RoomComposition.box(self, "WellPillar", Vector3(0.34, 2.8, 0.34), at + Vector3.UP * 1.4, stone, true)
			_box(self, "Capital", Vector3(0.62, 0.2, 0.62), at + Vector3.UP * 2.82, brass)
	for z in [-2.3, 2.3]:
		_box(self, "WellArch", Vector3(5.1, 0.20, 0.44), center + Vector3(0, 2.97, z), stone)
		for x in [-1.0, 1.0]:
			var brace := RoomComposition.box(self, "ArchShoulder", Vector3(1.2, 0.22, 0.38), center + Vector3(x * 1.85, 2.73, z), brass)
			brace.rotation.z = x * 0.35
	var shaft_light := OmniLight3D.new()
	shaft_light.name = "WellOverlookLight"
	shaft_light.position = center + Vector3.UP * 1.7
	shaft_light.light_color = Color("69b8dd")
	shaft_light.light_energy = 1.8
	shaft_light.omni_range = 7.0
	shaft_light.shadow_enabled = false
	add_child(shaft_light)
	# Inlaid edges and ribs turn the hall into four purposeful bays.
	for x in [1.4, 9.1]:
		_box(self, "FloorBorder", Vector3(0.12, 0.018, 24), Vector3(x * Kit.CELL, 0.018, 15), brass)
	for z in [1.4, 9.1]:
		_box(self, "FloorBorder", Vector3(23.2, 0.018, 0.12), Vector3(15, 0.018, z * Kit.CELL), brass)
	for z in [8.5, 20.5]:
		_box(self, "CeilingRib", Vector3(26, 0.15, 0.36), Vector3(15, Kit.WALL_H - 0.09, z), stone)
	for x in [3.0, 27.0]:
		for z in [12.0, 18.0]:
			RoomComposition.box(self, "WallPilaster", Vector3(0.5, 2.85, 0.55), Vector3(x, 1.42, z), stone, true)
	var cells := station_cells()
	for id in [TABLE, DESK, CIRCLE, HALL]:
		var at := Kit.cell_to_world(cells[id])
		var carpet := RoomComposition.material(Color("343c50") if id == CIRCLE else Color("443039"))
		_box(self, "StationInlay", Vector3(3.4, 0.012, 2.8), at + Vector3.UP * 0.016, carpet)
		var title := _caption(campaign.content.text("guild.station." + id), at + Vector3(0, 2.5, 0), 0.007)
		title.modulate = Palette.SOUL if id == CIRCLE else Palette.LANTERN
		if id == TABLE:
			_box(self, "CoalHearth", Vector3(1.2, 0.35, 0.6), at + Vector3(-1.4, 0.18, -0.35), stone)
			_box(self, "Embers", Vector3(0.85, 0.04, 0.4), at + Vector3(-1.4, 0.38, -0.35), RoomComposition.material(Color("c56735"), 0, 0.4))
		elif id == DESK:
			for i in 5:
				_box(self, "ClassBooks", Vector3(0.4, 0.08, 0.3), at + Vector3(-0.4, 1.0 + 0.08 * i, -0.1), brass if i % 2 == 0 else wood)
		elif id == CIRCLE:
			for x in [-1.15, 1.15]:
				RoomComposition.box(self, "RitualPedestal", Vector3(0.28, 0.8, 0.28), at + Vector3(x, 0.4, 0), stone, true)
				RoomComposition.sphere(self, "SpiritVessel", Vector3(0.26, 0.42, 0.26), at + Vector3(x, 1.0, 0), cold)
	_caption(campaign.content.text("guild.station.well"), center + Vector3(0, 1.35, 0), 0.007)


func _caption(text: String, at: Vector3, pixels: float, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UiTheme.body_font()
	label.font_size = 42
	label.pixel_size = pixels
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	label.modulate = Palette.BONE
	(self if parent == null else parent).add_child(label)
	return label


func refresh_history(campaign: Campaign) -> void:
	if history != null:
		history.free()
	_banners.clear()
	history = Node3D.new()
	history.name = "GuildHistory"
	add_child(history)
	var entries := GuildHistory.entries(campaign)
	# A kept welcome inscription is present before anything has been earned.
	_caption(campaign.content.text("guild.history.welcome"), Vector3(15, 2.35, 3.4), 0.009, history)
	var brass := RoomComposition.material(Color("9b7947"), 0.6)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var at := Vector3(4.5 + i * 3.2, 0, 4.1)
		var colour := Color("364c67") if entry["kind"] == "legend" else Color("553541")
		var banner := RoomComposition.box(history, "EarnedBanner", Vector3(1.55, 1.6, 0.035), at + Vector3.UP * 1.7, RoomComposition.material(colour))
		banner.set_meta("achievement", entry.duplicate(true))
		_banners.append(banner)
		_box(history, "BannerRail", Vector3(1.85, 0.06, 0.10), at + Vector3.UP * 2.52, brass)
		if entry["kind"] == "biome":
			if entry["key"] == "fungal_deep":
				_box(history, "TrophyStem", Vector3(0.10, 0.38, 0.12), at + Vector3(0, 1.82, 0.12), brass)
				RoomComposition.sphere(history, "TrophyCap", Vector3(0.58, 0.22, 0.30), at + Vector3(0, 2.0, 0.12), RoomComposition.material(Color("668460")))
			elif entry["key"] == "the_kiln":
				_box(history, "TrophyHammer", Vector3(0.54, 0.22, 0.20), at + Vector3(0, 2.0, 0.12), brass)
				_box(history, "TrophyHandle", Vector3(0.10, 0.45, 0.10), at + Vector3(0, 1.78, 0.12), brass)
			else:
				RoomComposition.sphere(history, "TrophySkull", Vector3(0.42, 0.48, 0.30), at + Vector3(0, 1.9, 0.10), brass)
				for x in [-0.09, 0.09]:
					RoomComposition.sphere(history, "TrophyEye", Vector3(0.08, 0.09, 0.04), at + Vector3(x, 1.94, 0.25), RoomComposition.material(Color("15191d")))
		elif entry["kind"] == "expedition":
			_box(history, "ExpeditionCompass", Vector3(0.40, 0.40, 0.12), at + Vector3(0, 1.9, 0.10), brass)
		var inscription := _caption(entry["title"] + "\n" + entry["reason"], at + Vector3(0, 1.2, 0.12), 0.0022, history)
		inscription.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inscription.width = 650


func _process(delta: float) -> void:
	_ambient_time += delta
	var camera := get_viewport().get_camera_3d()
	for i in _banners.size():
		var banner := _banners[i]
		if Settings.motion_reduced:
			banner.rotation.z = 0
		elif camera != null and camera.global_position.distance_squared_to(banner.global_position) < 400:
			banner.rotation.z = sin(_ambient_time * 0.55 + i) * 0.012
