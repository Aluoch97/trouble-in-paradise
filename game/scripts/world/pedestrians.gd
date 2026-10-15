extends Node3D
## People walking the sidewalks of Paradise. They jump out of the way when you
## drive at them, and someone always gets it on camera (Drama goes up).

@export var count := 24
@export var ground_height := 0.16 ## sidewalk top

const MODEL_SCRIPT := preload("res://scripts/characters/humanoid_model.gd")
const SHIRTS := ["f4efe4", "ffd36e", "86c6e8", "d9a0d6", "9fd49a", "f29a7a", "2f3a56", "c8553d"]
const SKINS := ["5e3a28", "8a5a3c", "c08a62", "a7724e", "6b4430", "e0b394"]
const PANTS := ["2b2333", "3d4a6b", "6b5a45", "1f1f24", "8a8f99"]

var _people: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _layout := TownLayout.new()


func _ready() -> void:
	_rng.seed = 77
	var lines := TownLayout.sidewalk_lines()
	for i in range(count):
		var line: Dictionary = lines[_rng.randi() % lines.size()]
		var model := Node3D.new()
		model.set_script(MODEL_SCRIPT)
		model.set("shirt_color", Color(SHIRTS[i % SHIRTS.size()]))
		model.set("skin_color", Color(SKINS[i % SKINS.size()]))
		model.set("pants_color", Color(PANTS[i % PANTS.size()]))
		model.set("long_hair", i % 3 == 0)
		model.set("body_scale", _rng.randf_range(0.92, 1.06))
		add_child(model)
		_people.append({
			"model": model,
			"line": line,
			"along": _rng.randf_range(0.0, TownLayout.SIZE),
			"dir": 1.0 if _rng.randf() < 0.5 else -1.0,
			"speed": _rng.randf_range(1.1, 1.6),
			"hop": 0.0,
			"panic": 0.0,
		})


func _physics_process(delta: float) -> void:
	var car: Car = get_tree().get_first_node_in_group("player_car")
	for p in _people:
		var model = p.model
		var line: Dictionary = p.line
		var speed: float = p.speed
		if p.panic > 0.0:
			p.panic -= delta
			speed *= 3.0
		p.along += speed * p.dir * delta
		if p.along > TownLayout.SIZE:
			p.along = 0.0
		elif p.along < 0.0:
			p.along = TownLayout.SIZE
		var pos := Vector3(p.along, 0, line.line) if line.axis == "x" else Vector3(line.line, 0, p.along)
		var tx := floori(pos.x / TownLayout.TILE)
		var ty := floori(pos.z / TownLayout.TILE)
		pos.y = 0.0 if _layout.at(tx, ty) == TownLayout.ROAD else ground_height
		model.position = pos
		var move_dir := Vector3(p.dir, 0, 0) if line.axis == "x" else Vector3(0, 0, p.dir)
		model.rotation.y = atan2(-move_dir.x, -move_dir.z)

		if p.hop > 0.0:
			p.hop = maxf(0.0, p.hop - delta * 1.8)
		model.set_hop(sin(p.hop * PI) * 0.7)
		model.animate(speed, delta, p.hop <= 0.0)

		if car != null and car.driver != null and p.hop <= 0.0:
			var d := car.global_position.distance_to(pos)
			if d < 3.2 and car.linear_velocity.length() > 4.0:
				p.hop = 1.0
				p.panic = 2.0
				p.dir = -p.dir
				Game.add_drama(0.35, "Hey! Watch it!")
