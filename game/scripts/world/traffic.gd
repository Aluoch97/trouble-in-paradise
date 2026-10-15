extends Node3D
## Town traffic. Cars cruise the lanes from TownLayout.lanes(), stop for
## whatever is in front of them (you, your car, other traffic), and get honked
## into a stop when you hit them. They are kinematic bodies, so they shove
## your car around in a crash.

@export var car_count := 18
@export var cruise_speed := 9.0 ## m/s (about 32 km/h)
@export var wrap_min := -70.0
@export var wrap_max := 230.0

const CAR_SCRIPT := preload("res://scripts/vehicles/car_model.gd")

var _cars: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2018
	var lanes := TownLayout.lanes()
	for i in range(car_count):
		var lane: Dictionary = lanes[i % lanes.size()]
		var body := AnimatableBody3D.new()
		body.name = "TrafficCar%d" % i
		body.sync_to_physics = false
		body.collision_layer = 4
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.8, 1.0, 4.4)
		shape.shape = box
		shape.position = Vector3(0, 0.35, 0)
		body.add_child(shape)
		var model := Node3D.new()
		model.set_script(CAR_SCRIPT)
		model.set("body_color", TownLayout.BLOCK_COLORS[(i * 3 + 1) % TownLayout.BLOCK_COLORS.size()])
		body.add_child(model)
		add_child(body)
		var along := _rng.randf_range(wrap_min, wrap_max)
		_cars.append({"body": body, "lane": lane, "along": along, "speed": cruise_speed, "wait": 0.0})
		_place(_cars.back())


func _place(c: Dictionary) -> void:
	var lane: Dictionary = c.lane
	var pos: Vector3
	var dir: Vector3
	if lane.axis == "x":
		pos = Vector3(c.along, 0.42, lane.line)
		dir = Vector3(lane.dir, 0, 0)
	else:
		pos = Vector3(lane.line, 0.42, c.along)
		dir = Vector3(0, 0, lane.dir)
	var basis := Basis.looking_at(-dir, Vector3.UP) # model faces +Z, looking_at points -Z
	(c.body as AnimatableBody3D).global_transform = Transform3D(basis, pos)


## Positions traffic should stop for. Missions and the player car register via groups.
func _obstacles() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for n in get_tree().get_nodes_in_group("traffic_obstacle"):
		if n is Node3D and (n as Node3D).visible:
			out.append((n as Node3D).global_position)
	for c in _cars:
		out.append((c.body as Node3D).global_position)
	return out


func _physics_process(delta: float) -> void:
	var obstacles := _obstacles()
	var player_car: Car = get_tree().get_first_node_in_group("player_car")
	for c in _cars:
		var body: AnimatableBody3D = c.body
		var lane: Dictionary = c.lane
		var dir := Vector3(lane.dir, 0, 0) if lane.axis == "x" else Vector3(0, 0, lane.dir)
		var want := cruise_speed
		if c.wait > 0.0:
			c.wait -= delta
			want = 0.0
		var here := body.global_position
		for p in obstacles:
			var rel: Vector3 = p - here
			var ahead := rel.dot(dir)
			var side := (rel - dir * ahead).length()
			if ahead > 0.5 and ahead < 9.0 and side < 1.9:
				want = 0.0
				break
		# Got hit by the player: stop and complain.
		if player_car != null and here.distance_to(player_car.global_position) < 3.0 and player_car.linear_velocity.length() > 6.0 and c.wait <= 0.0:
			c.wait = 2.5
			Game.add_drama(0.6, "Someone's filming the crash")
		c.speed = lerpf(c.speed, want, minf(1.0, delta * 3.0))
		c.along += c.speed * delta * lane.dir
		if c.along > wrap_max:
			c.along = wrap_min
		elif c.along < wrap_min:
			c.along = wrap_max
		_place(c)
