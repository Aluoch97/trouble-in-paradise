class_name Car
extends VehicleBody3D
## Drivable car. Physics comes from Godot's VehicleBody3D; this script turns
## player input into throttle, brakes, steering and a handbrake for drifting.
## Forward is +Z.

signal crashed(impact_speed: float)

@export var max_engine_force := 5200.0
@export var max_brake := 70.0
@export var max_steer := 0.52 ## radians at low speed
@export var top_reverse_speed := 9.0 ## m/s
@export var drag := 2.2 ## air resistance; sets the top speed
@export var rear_grip := 2.6
@export var handbrake_grip := 0.85

var driver: Node3D = null ## set while someone is in the driver's seat
var passenger: Node3D = null
var controls_enabled := true

var _steer := 0.0
var _last_velocity := Vector3.ZERO
var _crash_cooldown := 0.0
var _front: Array[VehicleWheel3D] = []
var _teleport_to: Variant = null
var _rear: Array[VehicleWheel3D] = []

@onready var model: CarModel = $Model


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	for c in get_children():
		if c is VehicleWheel3D:
			if c.use_as_steering:
				_front.append(c)
			else:
				_rear.append(c)


## Move the car instantly (mission restarts, cutscenes). Safe to call any time:
## the physics engine applies it on its next step.
func teleport(xform: Transform3D) -> void:
	_teleport_to = xform
	global_transform = xform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _teleport_to != null:
		state.transform = _teleport_to
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_teleport_to = null


func forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func _physics_process(delta: float) -> void:
	_crash_cooldown = maxf(0.0, _crash_cooldown - delta)
	var fwd := forward_speed()
	var throttle := 0.0
	var steer_in := 0.0
	var handbrake := false
	if driver != null and controls_enabled:
		throttle = Input.get_axis("move_back", "move_forward")
		steer_in = Input.get_axis("move_right", "move_left") # positive steering turns left
		handbrake = Input.is_action_pressed("handbrake")

	# Less steering at high speed, like GTA.
	var limit := max_steer * clampf(1.0 - absf(fwd) / 42.0, 0.32, 1.0)
	var steer_rate := 3.0 if absf(steer_in) > 0.05 else 4.0
	_steer = move_toward(_steer, steer_in * limit, delta * steer_rate)

	var engine := 0.0
	var brake_force := 0.0
	if throttle > 0.05:
		if fwd < -1.0:
			brake_force = max_brake * throttle
		else:
			engine = max_engine_force * throttle
	elif throttle < -0.05:
		if fwd > 1.0:
			brake_force = max_brake * -throttle
		elif fwd > -top_reverse_speed:
			engine = max_engine_force * 0.55 * throttle
	else:
		brake_force = 3.0 if driver != null else 12.0 # engine braking / parked

	for w in _front:
		w.steering = _steer
		w.brake = brake_force
		w.engine_force = 0.0
	for w in _rear:
		w.engine_force = engine
		w.brake = brake_force + (max_brake * 0.6 if handbrake else 0.0)
		var grip := handbrake_grip if handbrake else rear_grip
		w.wheel_friction_slip = lerpf(w.wheel_friction_slip, grip, minf(1.0, delta * (10.0 if handbrake else 2.5)))

	# Air drag caps the top speed (about 120 km/h).
	var v := linear_velocity
	apply_central_force(-v * v.length() * drag)
	# Keep the car planted: a little downforce and roll damping.
	apply_central_force(-global_basis.y * v.length() * 18.0)

	if model:
		model.set_braking(brake_force > 6.0 or (throttle < -0.05 and fwd > 1.0))
	_last_velocity = linear_velocity


func _on_body_entered(_body: Node) -> void:
	var impact := (_last_velocity - linear_velocity).length()
	if impact > 5.0 and _crash_cooldown <= 0.0:
		_crash_cooldown = 1.5
		crashed.emit(impact)


## Where someone stepping out of the driver's door should stand. Tries the
## driver side, then the passenger side. Returns null if both are blocked.
func exit_position() -> Variant:
	var space := get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	for side: float in [1.0, -1.0]:
		var p := global_position + global_basis.x * 1.55 * side
		p.y = global_position.y + 0.5
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.6, 0))
		q.collision_mask = 1 | 4
		q.exclude = [get_rid()]
		if space.intersect_shape(q, 1).is_empty():
			return p
	return null
