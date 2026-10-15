extends Node
## Builds the game's scenes from code: the town of Paradise, the car, Nick,
## the NPC template and the main scene. It also writes the input map.
##
## You only need this to rebuild from scratch. Day to day, open the .tscn
## files in the Godot editor and edit them there.
##
##   godot --headless --path game res://tools/generate_scenes.tscn
##
## Add "-- --town-only" at the end to rebuild just town.tscn (keeps your edits to the others).

const BUILDING_SHADER := preload("res://shaders/building.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const T := TownLayout.TILE
const SLAB := 0.12 ## sidewalk / block height

var layout := TownLayout.new()
var rng := RandomNumberGenerator.new()
var mats := {}


func _ready() -> void:
	rng.seed = 2018
	var town_only := "--town-only" in OS.get_cmdline_user_args()
	_setup_project()
	_save(_build_town(), "res://scenes/world/town.tscn")
	if not town_only:
		_save(_build_player(), "res://scenes/characters/player.tscn")
		_save(_build_npc(), "res://scenes/characters/npc.tscn")
		_save(_build_car(), "res://scenes/vehicles/car.tscn")
		_save(_build_main(), "res://scenes/main.tscn")
	print("Scenes generated.")
	get_tree().quit()


# ------------------------------------------------------------------ helpers

func _save(root: Node, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Could not pack %s (%d)" % [path, err])
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Could not save %s (%d)" % [path, err])
	print("  wrote ", path)
	root.free()


## Add `child` under `parent` and make it part of `owner_node`'s saved scene.
func _own(parent: Node, child: Node, owner_node: Node, child_name: String = "") -> Node:
	if child_name != "":
		child.name = child_name
	parent.add_child(child)
	child.owner = owner_node
	return child


func _mat(key: String, color: Color, rough: float = 0.9) -> StandardMaterial3D:
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.resource_name = key
		m.albedo_color = color
		m.roughness = rough
		mats[key] = m
	return mats[key]


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _mesh(parent: Node, owner_node: Node, mesh: Mesh, mat: Material, pos: Vector3, mesh_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_own(parent, mi, owner_node, mesh_name)
	return mi


## A solid box you can stand on and crash into.
func _solid_box(parent: Node, owner_node: Node, size: Vector3, pos: Vector3, mat: Material, body_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	_own(parent, body, owner_node, body_name)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	_own(body, shape, owner_node, "CollisionShape3D")
	if mat != null:
		_mesh(body, owner_node, _box_mesh(size), mat, Vector3.ZERO, "Mesh")
	return body


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e


func _joy_button(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = b
	return e


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e


func _action(action_name: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.2, "events": events})


# ------------------------------------------------------------------ project

func _setup_project() -> void:
	_action("move_forward", [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("move_back", [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("look_left", [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("look_right", [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("look_up", [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("look_down", [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action("jump", [_key(KEY_SPACE), _joy_button(JOY_BUTTON_X)])
	_action("handbrake", [_key(KEY_SPACE), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("sprint", [_key(KEY_SHIFT), _joy_button(JOY_BUTTON_A)])
	_action("walk", [_key(KEY_CTRL)])
	_action("interact", [_key(KEY_F), _key(KEY_E), _joy_button(JOY_BUTTON_Y)])
	_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _joy_button(JOY_BUTTON_START)])
	_action("radio_next", [_key(KEY_R), _joy_button(JOY_BUTTON_DPAD_RIGHT)])
	ProjectSettings.set_setting("shader_globals/city_lights", {"type": "float", "value": 0.0})
	ProjectSettings.save()
	print("  wrote input map and shader globals to project.godot")


# ------------------------------------------------------------------ town

func _build_town() -> Node3D:
	var town := Node3D.new()
	town.name = "Town"
	_build_environment(town)
	_build_ground(town)
	_build_roads(town)
	_build_blocks(town)
	_build_buildings(town)
	_build_pool_props(town)
	_build_home(town)
	_build_trees(town)
	_build_parked_cars(town)
	_build_street_lights(town)
	_build_forest(town)
	_build_bounds(town)
	_build_markers(town)
	return town


func _build_environment(town: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.5
	env.fog_enabled = true
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	_own(town, we, town, "WorldEnvironment")

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 1.5
	_own(town, sun, town, "Sun")

	var day := DayCycle.new()
	_own(town, day, town, "DayCycle")
	day.sun = sun
	day.world_env = we


func _build_ground(town: Node3D) -> void:
	var ground := StaticBody3D.new()
	_own(town, ground, town, "Ground")
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	_own(ground, shape, town, "CollisionShape3D")
	var plane := PlaneMesh.new()
	plane.size = Vector2(800, 800)
	_mesh(ground, town, plane, _mat("grass", Color("6f8a3c"), 1.0), Vector3(80, 0, 80), "Grass")


func _build_roads(town: Node3D) -> void:
	var roads := Node3D.new()
	_own(town, roads, town, "Roads")
	var asphalt := _mat("asphalt", Color("3b3742"), 0.92)
	var length := 520.0
	for r: int in TownLayout.ROAD_LINES:
		var c := (r + 1.0) * T
		_mesh(roads, town, _box_mesh(Vector3(length, 0.04, 2 * T)), asphalt, Vector3(80, 0.02, c), "RoadEastWest%d" % r)
		_mesh(roads, town, _box_mesh(Vector3(2 * T, 0.041, length)), asphalt, Vector3(c, 0.02, 80), "RoadNorthSouth%d" % r)

	# dashed center lines, skipping the intersections
	var dash := _box_mesh(Vector3(0.16, 0.01, 2.4))
	var line_mat := _mat("lane_line", Color("e8cf7a"), 0.6)
	var xforms: Array[Transform3D] = []
	for r: int in TownLayout.ROAD_LINES:
		var c := (r + 1.0) * T
		var along := -170.0
		while along < 340.0:
			var in_crossing := false
			for q: int in TownLayout.ROAD_LINES:
				if absf(along - (q + 1.0) * T) < T + 1.5:
					in_crossing = true
			if not in_crossing:
				xforms.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(along, 0.046, c)))
				xforms.append(Transform3D(Basis(), Vector3(c, 0.046, along)))
			along += 6.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dash
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = line_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(roads, mmi, town, "LaneLines")


## Sidewalk slabs, one per block, with a hole for the pool. Then the ground
## cover inside each block (grass, parking lots, pool deck).
func _build_blocks(town: Node3D) -> void:
	var blocks := Node3D.new()
	_own(town, blocks, town, "Blocks")
	var walk := _mat("sidewalk", Color("a8987e"), 0.95)
	for by in range(4):
		for bx in range(4):
			var x0 := (bx * 10 + 2) * T
			var z0 := (by * 10 + 2) * T
			var w := 8 * T
			var block_name := "Block_%d_%d" % [bx, by]
			if Vector2i(bx, by) == TownLayout.KNOX_RIDGE:
				# four slabs around the pool water (tiles 14-17 x 15-16)
				var hx0 := 14 * T
				var hx1 := 18 * T
				var hz0 := 15 * T
				var hz1 := 17 * T
				_slab(blocks, town, Rect2(x0, z0, w, hz0 - z0), walk, block_name + "_N")
				_slab(blocks, town, Rect2(x0, hz1, w, z0 + w - hz1), walk, block_name + "_S")
				_slab(blocks, town, Rect2(x0, hz0, hx0 - x0, hz1 - hz0), walk, block_name + "_W")
				_slab(blocks, town, Rect2(hx1, hz0, x0 + w - hx1, hz1 - hz0), walk, block_name + "_E")
			else:
				_slab(blocks, town, Rect2(x0, z0, w, w), walk, block_name)

	# ground cover, one MultiMesh per surface
	var cover := {
		TownLayout.GRASS: ["lawn", Color("779444"), []],
		TownLayout.TREE: ["lawn", Color("779444"), []],
		TownLayout.LOT: ["lot", Color("57505e"), []],
		TownLayout.DECK: ["deck", Color("c9ad86"), []],
	}
	var tile_top := _box_mesh(Vector3(T, 0.012, T))
	for y in range(TownLayout.N):
		for x in range(TownLayout.N):
			var k := layout.at(x, y)
			if cover.has(k):
				cover[k][2].append(Transform3D(Basis(), Vector3((x + 0.5) * T, SLAB + 0.006, (y + 0.5) * T)))
	var merged := {}
	for k in cover:
		var key: String = cover[k][0]
		if not merged.has(key):
			merged[key] = [cover[k][1], []]
		merged[key][1].append_array(cover[k][2])
	for key in merged:
		var list: Array = merged[key][1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tile_top
		mm.instance_count = list.size()
		for i in range(list.size()):
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat(key, merged[key][0], 0.95)
		_own(blocks, mmi, town, "Cover_" + key)

	# parking lot stripes
	var stripe := _box_mesh(Vector3(0.12, 0.01, 2.8))
	var stripes: Array[Transform3D] = []
	for y in range(TownLayout.N):
		for x in range(TownLayout.N):
			if layout.at(x, y) == TownLayout.LOT and x % 2 == 0 and (layout.at(x, y - 1) != TownLayout.LOT or layout.at(x, y + 1) != TownLayout.LOT):
				stripes.append(Transform3D(Basis(), Vector3(x * T, SLAB + 0.014, (y + 0.5) * T)))
	var smm := MultiMesh.new()
	smm.transform_format = MultiMesh.TRANSFORM_3D
	smm.mesh = stripe
	smm.instance_count = stripes.size()
	for i in range(stripes.size()):
		smm.set_instance_transform(i, stripes[i])
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = smm
	smi.material_override = _mat("stripe", Color("e9e4d8"), 0.7)
	_own(blocks, smi, town, "LotStripes")


func _slab(parent: Node, owner_node: Node, r: Rect2, mat: Material, slab_name: String) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	_solid_box(parent, owner_node, Vector3(r.size.x, SLAB, r.size.y), Vector3(r.get_center().x, SLAB / 2.0, r.get_center().y), mat, slab_name)


func _building_mat(tint: int) -> ShaderMaterial:
	var key := "building_%d" % tint
	if not mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = BUILDING_SHADER
		m.set_shader_parameter("base_color", TownLayout.BLOCK_COLORS[tint])
		mats[key] = m
	return mats[key]


func _build_buildings(town: Node3D) -> void:
	var bnode := Node3D.new()
	_own(town, bnode, town, "Buildings")
	var roof_box := _mat("roof_unit", Color("8e8a92"), 0.8)
	var count := 0
	for y in range(TownLayout.N):
		var x := 0
		while x < TownLayout.N:
			if layout.at(x, y) != TownLayout.BUILDING or (floori(x / 10.0) == 3 and floori(y / 10.0) == 3):
				x += 1
				continue
			var h := layout.height_at(x, y)
			var c := layout.tint_at(x, y)
			var start := x
			while x < TownLayout.N and layout.at(x, y) == TownLayout.BUILDING and layout.height_at(x, y) == h and layout.tint_at(x, y) == c:
				x += 1
			var w := (x - start) * T
			var height := h * 3.2
			var pos := Vector3(start * T + w / 2.0, SLAB + height / 2.0, (y + 0.5) * T)
			count += 1
			var b := _solid_box(bnode, town, Vector3(w, height, T), pos, _building_mat(c), "Building%d" % count)
			# rooftop AC units and a parapet line
			if rng.randf() < 0.7:
				_mesh(b, town, _box_mesh(Vector3(1.2, 0.8, 1.0)), roof_box, Vector3(rng.randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0), height / 2.0 + 0.4, rng.randf_range(-1.0, 1.0)), "RoofUnit")
			_mesh(b, town, _box_mesh(Vector3(w + 0.1, 0.25, T + 0.1)), _mat("parapet_%d" % c, TownLayout.BLOCK_COLORS[c].darkened(0.25), 0.9), Vector3(0, height / 2.0 + 0.12, 0), "Parapet")
	print("  %d buildings" % count)


func _build_pool_props(town: Node3D) -> void:
	var pool := Node3D.new()
	_own(town, pool, town, "KnoxRidgePool")
	var water_mat := ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	var water_rect := Rect2(14 * T, 15 * T, 4 * T, 2 * T)
	var water := _mesh(pool, town, _box_mesh(Vector3(water_rect.size.x, 0.02, water_rect.size.y)), water_mat, Vector3(water_rect.get_center().x, 0.06, water_rect.get_center().y), "Water")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# pool walls (tile edge) + an invisible fence so nobody walks on water
	var tile_mat := _mat("pool_tile", Color("f2f0ea"), 0.4)
	var c := water_rect.get_center()
	for side in [[Vector3(water_rect.size.x + 0.4, 0.2, 0.2), Vector3(c.x, SLAB + 0.02, water_rect.position.y - 0.1)],
			[Vector3(water_rect.size.x + 0.4, 0.2, 0.2), Vector3(c.x, SLAB + 0.02, water_rect.end.y + 0.1)],
			[Vector3(0.2, 0.2, water_rect.size.y), Vector3(water_rect.position.x - 0.1, SLAB + 0.02, c.y)],
			[Vector3(0.2, 0.2, water_rect.size.y), Vector3(water_rect.end.x + 0.1, SLAB + 0.02, c.y)]]:
		_mesh(pool, town, _box_mesh(side[0]), tile_mat, side[1], "PoolEdge")
	_solid_box(pool, town, Vector3(water_rect.size.x, 1.2, water_rect.size.y), Vector3(c.x, 0.6, c.y), null, "PoolFence")

	# loungers and umbrellas on the deck
	var lounger_mat := _mat("lounger", Color("fff4e6"), 0.6)
	var umbrella_mats := [_mat("umbrella_pink", Color("ff6f91"), 0.7), _mat("umbrella_gold", Color("ffc65c"), 0.7)]
	for i in range(4):
		var lx := 14.4 * T + i * 3.2
		_mesh(pool, town, _box_mesh(Vector3(0.7, 0.3, 1.9)), lounger_mat, Vector3(lx, SLAB + 0.15, 14.4 * T), "Lounger%d" % i)
		if i % 2 == 0:
			var pole := CylinderMesh.new()
			pole.top_radius = 0.04
			pole.bottom_radius = 0.04
			pole.height = 2.4
			_mesh(pool, town, pole, lounger_mat, Vector3(lx + 1.6, SLAB + 1.2, 14.2 * T), "UmbrellaPole%d" % i)
			var top := CylinderMesh.new()
			top.top_radius = 0.05
			top.bottom_radius = 1.4
			top.height = 0.5
			_mesh(pool, town, top, umbrella_mats[(i / 2) % 2], Vector3(lx + 1.6, SLAB + 2.45, 14.2 * T), "Umbrella%d" % i)

	# building sign facing the pool
	var sign_text := Label3D.new()
	sign_text.text = "KNOX RIDGE"
	sign_text.font_size = 160
	sign_text.pixel_size = 0.01
	sign_text.modulate = Color("fff4e6")
	sign_text.outline_size = 24
	sign_text.outline_modulate = Color("8e2f55")
	sign_text.position = Vector3(15.5 * T + 2.0, SLAB + 7.4, 14 * T + 0.08)
	if ResourceLoader.exists("res://assets/fonts/Shrikhand-Regular.woff2"):
		sign_text.font = load("res://assets/fonts/Shrikhand-Regular.woff2")
	_own(pool, sign_text, town, "KnoxRidgeSign")


## Nick and Brandon's place on Quarry Trail: a two-story house with a pitched roof.
func _build_home(town: Node3D) -> void:
	var home := Node3D.new()
	_own(town, home, town, "QuarryTrailHouse")
	var x0 := 35 * T
	var z0 := 35 * T
	var w := 3 * T
	var height := 6.0
	var center := Vector3(x0 + w / 2.0, SLAB + height / 2.0, z0 + w / 2.0)
	_solid_box(home, town, Vector3(w, height, w), center, _building_mat(5), "House")
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 1.2, 3.0, w + 1.0)
	_mesh(home, town, roof, _mat("house_roof", Color("6b3d4a"), 0.85), Vector3(center.x, SLAB + height + 1.5, center.z), "Roof")
	# front door facing the driveway (west)
	_mesh(home, town, _box_mesh(Vector3(0.1, 2.2, 1.1)), _mat("door", Color("3b2433"), 0.6), Vector3(x0 - 0.05, SLAB + 1.1, z0 + w / 2.0), "FrontDoor")
	_mesh(home, town, _box_mesh(Vector3(1.6, 0.25, 2.4)), _mat("porch", Color("b9a487"), 0.9), Vector3(x0 - 0.8, SLAB + 0.12, z0 + w / 2.0), "Porch")
	var porch_light := OmniLight3D.new()
	porch_light.position = Vector3(x0 - 0.4, SLAB + 2.6, z0 + w / 2.0 + 0.9)
	porch_light.omni_range = 7.0
	porch_light.light_color = Color("ffcf8a")
	porch_light.light_energy = 0.0
	porch_light.add_to_group("street_light", true)
	_own(home, porch_light, town, "PorchLight")
	var mailbox := Label3D.new()
	mailbox.text = "2350"
	mailbox.font_size = 64
	mailbox.pixel_size = 0.01
	mailbox.outline_size = 12
	mailbox.position = Vector3(x0 - 0.06, SLAB + 2.6, z0 + w / 2.0 - 1.0)
	mailbox.rotation.y = -PI / 2.0
	_own(home, mailbox, town, "HouseNumber")


func _tree_parts() -> Array:
	if not mats.has("_tree_meshes"):
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.16
		trunk.bottom_radius = 0.24
		trunk.height = 3.0
		trunk.radial_segments = 8
		var canopy := SphereMesh.new()
		canopy.radius = 1.9
		canopy.height = 3.4
		canopy.radial_segments = 12
		canopy.rings = 6
		mats["_tree_meshes"] = [trunk, canopy]
	return mats["_tree_meshes"]


func _build_trees(town: Node3D) -> void:
	var trees := Node3D.new()
	_own(town, trees, town, "Trees")
	var parts := _tree_parts()
	var bark := _mat("bark", Color("6b4a34"), 0.95)
	var leaves := [_mat("leaves_a", Color("4f7a35"), 0.9), _mat("leaves_b", Color("628c3a"), 0.9), _mat("leaves_c", Color("3f6a32"), 0.9)]
	var n := 0
	for y in range(TownLayout.N):
		for x in range(TownLayout.N):
			if layout.at(x, y) != TownLayout.TREE:
				continue
			n += 1
			var pos := Vector3((x + 0.5) * T + rng.randf_range(-0.6, 0.6), SLAB, (y + 0.5) * T + rng.randf_range(-0.6, 0.6))
			var body := StaticBody3D.new()
			body.position = pos
			_own(trees, body, town, "Tree%d" % n)
			var shape := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.35
			cyl.height = 3.0
			shape.shape = cyl
			shape.position.y = 1.5
			_own(body, shape, town, "CollisionShape3D")
			var s := rng.randf_range(0.85, 1.25)
			var trunk := _mesh(body, town, parts[0], bark, Vector3(0, 1.5 * s, 0), "Trunk")
			trunk.scale = Vector3(1, s, 1)
			var canopy := _mesh(body, town, parts[1], leaves[n % 3], Vector3(0, 3.6 * s, 0), "Canopy")
			canopy.scale = Vector3.ONE * s


func _build_parked_cars(town: Node3D) -> void:
	var parked := Node3D.new()
	_own(town, parked, town, "ParkedCars")
	var i := 0
	for p in layout.parked:
		i += 1
		var pos: Vector2 = p.pos * T
		var body := StaticBody3D.new()
		body.position = Vector3(pos.x, SLAB + 0.41, pos.y)
		body.rotation.y = 0.0 if p.facing > 0.0 else PI
		body.collision_layer = 4
		_own(parked, body, town, "ParkedCar%d" % i)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.84, 1.0, 4.5)
		shape.shape = box
		shape.position.y = 0.35
		_own(body, shape, town, "CollisionShape3D")
		var model := CarModel.new()
		model.body_color = p.color
		_own(body, model, town, "Model")


func _build_street_lights(town: Node3D) -> void:
	var lights := Node3D.new()
	_own(town, lights, town, "StreetLights")
	var pole_mat := _mat("pole", Color("2e2a33"), 0.5)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color("fff1c4")
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("ffcf8a")
	lamp_mat.emission_energy_multiplier = 2.0
	var pole := CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.11
	pole.height = 6.0
	var n := 0
	for rx: int in TownLayout.ROAD_LINES:
		for rz: int in TownLayout.ROAD_LINES:
			n += 1
			var base := Vector3((rx + 2) * T + 0.7, SLAB, (rz + 2) * T + 0.7)
			var body := StaticBody3D.new()
			body.position = base
			_own(lights, body, town, "StreetLight%d" % n)
			var shape := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.15
			cyl.height = 6.0
			shape.shape = cyl
			shape.position.y = 3.0
			_own(body, shape, town, "CollisionShape3D")
			_mesh(body, town, pole, pole_mat, Vector3(0, 3.0, 0), "Pole")
			_mesh(body, town, _box_mesh(Vector3(0.12, 0.12, 2.0)), pole_mat, Vector3(-0.6, 5.9, -0.6), "Arm").rotation.y = PI / 4.0
			_mesh(body, town, _box_mesh(Vector3(0.5, 0.14, 0.5)), lamp_mat, Vector3(-1.25, 5.82, -1.25), "Lamp")
			var light := OmniLight3D.new()
			light.position = Vector3(-1.25, 5.4, -1.25)
			light.omni_range = 13.0
			light.light_color = Color("ffcf8a")
			light.light_energy = 0.0
			light.add_to_group("street_light", true)
			_own(body, light, town, "Light")


## Thick woods around town so the world doesn't end at a cliff. No collision:
## the invisible walls in Bounds keep players out.
func _build_forest(town: Node3D) -> void:
	var parts := _tree_parts()
	var xforms: Array[Transform3D] = []
	var road_centers: Array[float] = []
	for r: int in TownLayout.ROAD_LINES:
		road_centers.append((r + 1.0) * T)
	var tries := 0
	while xforms.size() < 900 and tries < 20000:
		tries += 1
		var p := Vector2(rng.randf_range(-130, 290), rng.randf_range(-130, 290))
		var inside := p.x > -16 and p.x < 176 and p.y > -16 and p.y < 176
		if inside:
			continue
		var on_road := false
		for c in road_centers:
			if absf(p.x - c) < 7.0 or absf(p.y - c) < 7.0:
				on_road = true
		if on_road:
			continue
		var s := rng.randf_range(1.0, 1.8)
		xforms.append(Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y)))
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = parts[0]
	trunk_mm.instance_count = xforms.size()
	var canopy_mm := MultiMesh.new()
	canopy_mm.transform_format = MultiMesh.TRANSFORM_3D
	canopy_mm.mesh = parts[1]
	canopy_mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		var t: Transform3D = xforms[i]
		var s := t.basis.get_scale().x
		trunk_mm.set_instance_transform(i, t.translated(Vector3(0, 1.5 * s, 0)))
		canopy_mm.set_instance_transform(i, t.translated(Vector3(0, 3.6 * s, 0)))
	var forest := Node3D.new()
	_own(town, forest, town, "Forest")
	var a := MultiMeshInstance3D.new()
	a.multimesh = trunk_mm
	a.material_override = _mat("bark", Color("6b4a34"), 0.95)
	_own(forest, a, town, "Trunks")
	var b := MultiMeshInstance3D.new()
	b.multimesh = canopy_mm
	b.material_override = _mat("leaves_forest", Color("3d6230"), 0.95)
	_own(forest, b, town, "Canopies")


func _build_bounds(town: Node3D) -> void:
	var bounds := Node3D.new()
	_own(town, bounds, town, "Bounds")
	var lo := -15.0
	var hi := 175.0
	var mid := (lo + hi) / 2.0
	var len := hi - lo + 4.0
	_solid_box(bounds, town, Vector3(2, 12, len), Vector3(lo, 6, mid), null, "WestWall")
	_solid_box(bounds, town, Vector3(2, 12, len), Vector3(hi, 6, mid), null, "EastWall")
	_solid_box(bounds, town, Vector3(len, 12, 2), Vector3(mid, 6, lo), null, "NorthWall")
	_solid_box(bounds, town, Vector3(len, 12, 2), Vector3(mid, 6, hi), null, "SouthWall")


## Mission locations. Move these in the editor to re-stage the mission.
func _build_markers(town: Node3D) -> void:
	var markers := Node3D.new()
	_own(town, markers, town, "Markers")
	var spots := {
		"PlayerSpawn": Vector3(34.6 * T, SLAB + 0.1, 36.6 * T),
		"PoolStop": Vector3(11.2 * T, 0.0, 17.5 * T),
		"JanaeSpot": Vector3(15.6 * T, SLAB + 0.1, 17.6 * T),
		"SamsonSpot": Vector3(16.7 * T, SLAB + 0.1, 17.3 * T),
		"JustinSpot": Vector3(17.5 * T, SLAB + 0.1, 17.8 * T),
		"HomeStop": Vector3(33.6 * T, SLAB, 35.6 * T),
	}
	for spot_name in spots:
		var m := Marker3D.new()
		m.position = spots[spot_name]
		m.gizmo_extents = 1.5
		_own(markers, m, town, spot_name)
	# The car starts in the driveway, nose toward the street (west).
	var car_spawn := Marker3D.new()
	car_spawn.position = Vector3(33.8 * T, SLAB + 0.5, 35.0 * T)
	car_spawn.rotation.y = -PI / 2.0
	car_spawn.gizmo_extents = 2.0
	_own(markers, car_spawn, town, "CarSpawn")


# ------------------------------------------------------------------ characters

func _character_body(root: CharacterBody3D) -> void:
	root.collision_layer = 2
	root.collision_mask = 1 | 2 | 4
	root.floor_max_angle = deg_to_rad(60.0)
	root.floor_snap_length = 0.35
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	_own(root, shape, root, "CollisionShape3D")


func _build_player() -> Node:
	var p := Player.new()
	p.name = "Player"
	_character_body(p)
	var model := HumanoidModel.new()
	model.shirt_color = Color("f4efe4")
	model.pants_color = Color("2b2f45")
	model.skin_color = Color("6e4430")
	_own(p, model, p, "Model")
	return p


func _build_npc() -> Node:
	var n := Npc.new()
	n.name = "Npc"
	_character_body(n)
	var model := HumanoidModel.new()
	_own(n, model, n, "Model")
	var label := Label3D.new()
	label.text = "NAME"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.font_size = 36
	label.outline_size = 10
	label.modulate = Color("fff4e6")
	label.position.y = 2.15
	if ResourceLoader.exists("res://assets/fonts/BarlowCondensed-ExtraBold.woff2"):
		label.font = load("res://assets/fonts/BarlowCondensed-ExtraBold.woff2")
	_own(n, label, n, "NameLabel")
	return n


# ------------------------------------------------------------------ car

func _build_car() -> Node:
	var car := Car.new()
	car.name = "Car"
	car.mass = 1250.0
	car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	car.center_of_mass = Vector3(0, -0.25, 0.1)
	car.collision_layer = 4
	car.collision_mask = 1 | 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.84, 0.95, 4.5)
	shape.shape = box
	shape.position.y = 0.36
	_own(car, shape, car, "CollisionShape3D")
	var model := CarModel.new()
	model.body_color = Color("2a8c8c")
	model.show_wheels = false
	model.headlight_beams = true
	_own(car, model, car, "Model")

	var tire := _mat("tire", Color("1a1a1e"), 0.9)
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color("d8d8de")
	rim.metallic = 0.9
	rim.roughness = 0.25
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = 0.36
	tire_mesh.bottom_radius = 0.36
	tire_mesh.height = 0.26
	tire_mesh.radial_segments = 16
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.21
	rim_mesh.bottom_radius = 0.21
	rim_mesh.height = 0.28
	rim_mesh.radial_segments = 10
	for wheel_def in [["FrontLeft", Vector3(0.82, 0.12, 1.4), true], ["FrontRight", Vector3(-0.82, 0.12, 1.4), true],
			["RearLeft", Vector3(0.82, 0.12, -1.4), false], ["RearRight", Vector3(-0.82, 0.12, -1.4), false]]:
		var w := VehicleWheel3D.new()
		w.position = wheel_def[1]
		w.use_as_steering = wheel_def[2]
		w.use_as_traction = not wheel_def[2]
		w.wheel_radius = 0.36
		w.wheel_rest_length = 0.22
		w.suspension_travel = 0.25
		w.suspension_stiffness = 45.0
		w.suspension_max_force = 14000.0
		w.damping_compression = 0.9
		w.damping_relaxation = 1.1
		w.wheel_friction_slip = 3.0 if wheel_def[2] else 2.6
		w.wheel_roll_influence = 0.05
		_own(car, w, car, wheel_def[0])
		var t := _mesh(w, car, tire_mesh, tire, Vector3.ZERO, "Tire")
		t.rotation.z = PI / 2.0
		var r := _mesh(w, car, rim_mesh, rim, Vector3.ZERO, "Rim")
		r.rotation.z = PI / 2.0
	return car


# ------------------------------------------------------------------ main

func _build_main() -> Node:
	var main := Node3D.new()
	main.name = "Main"
	var town: Node3D = load("res://scenes/world/town.tscn").instantiate()
	_own(main, town, main, "Town")

	var player: Node3D = load("res://scenes/characters/player.tscn").instantiate()
	_own(main, player, main, "Player")
	player.add_to_group("player", true)
	player.add_to_group("traffic_obstacle", true)

	var car: Node3D = load("res://scenes/vehicles/car.tscn").instantiate()
	_own(main, car, main, "Car")
	car.add_to_group("player_car", true)
	car.add_to_group("enterable_car", true)
	car.add_to_group("traffic_obstacle", true)

	var npc_scene: PackedScene = load("res://scenes/characters/npc.tscn")
	var cast := [
		["Janae", "janae", Color("ff6f91"), Color("e9e2d6"), Color("8a5a3c"), true],
		["Samson", "samson", Color("5aa9a0"), Color("2b2333"), Color("6b4430"), false],
		["Justin", "justin", Color("e0b04a"), Color("3d4a6b"), Color("a7724e"), false],
	]
	for c in cast:
		var n: Node3D = npc_scene.instantiate()
		n.set("display_name", c[0])
		n.set("npc_id", c[1])
		n.set("shirt_color", c[2])
		n.set("pants_color", c[3])
		n.set("skin_color", c[4])
		n.set("long_hair", c[5])
		_own(main, n, main, c[0])
		n.add_to_group("traffic_obstacle", true)

	var traffic := Node3D.new()
	traffic.set_script(load("res://scripts/world/traffic.gd"))
	_own(main, traffic, main, "Traffic")
	var peds := Node3D.new()
	peds.set_script(load("res://scripts/world/pedestrians.gd"))
	_own(main, peds, main, "Pedestrians")

	var rig := CameraRig.new()
	_own(main, rig, main, "CameraRig")
	var arm := SpringArm3D.new()
	arm.spring_length = 4.4
	arm.margin = 0.3
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	arm.shape = sphere
	_own(rig, arm, main, "SpringArm3D")
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 600.0
	_own(arm, cam, main, "Camera3D")
	var cine := Camera3D.new()
	cine.fov = 45.0
	cine.far = 600.0
	_own(rig, cine, main, "CinematicCamera")
	rig.target = player

	var cp := Checkpoint.new()
	_own(main, cp, main, "Checkpoint")
	var radio := Radio.new()
	_own(main, radio, main, "Radio")
	var hud := Hud.new()
	_own(main, hud, main, "HUD")
	var mission := Node.new()
	mission.set_script(load("res://scripts/missions/mission_welcome_to_paradise.gd"))
	_own(main, mission, main, "Mission")
	return main
