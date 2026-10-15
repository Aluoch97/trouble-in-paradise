class_name CameraRig
extends Node3D
## San Andreas-style third-person camera: orbit with the mouse or right stick,
## swings in behind the car when you drive, pulls back and widens with speed.
## Missions can cut to cinematic angles with cinematic() / end_cinematic().

@export var target: Node3D
@export var mouse_sensitivity := 0.0028
@export var stick_speed := 2.6
@export var foot_distance := 4.4
@export var car_distance := 7.8

var yaw := 0.0
var pitch := -0.28

var _idle := 10.0
var _cine := false
var _cine_from := Vector3.ZERO
var _cine_to := Vector3.ZERO

@onready var arm: SpringArm3D = $SpringArm3D
@onready var cam: Camera3D = $SpringArm3D/Camera3D
@onready var cine_cam: Camera3D = $CinematicCamera


func _ready() -> void:
	arm.collision_mask = 1 # only the world pushes the camera in, not people or cars
	cam.current = true


func _unhandled_input(event: InputEvent) -> void:
	if _cine:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.25, 0.3)
		_idle = 0.0


func _process(delta: float) -> void:
	if _cine:
		cine_cam.global_position = cine_cam.global_position.lerp(_cine_from, minf(1.0, delta * 2.0))
		cine_cam.look_at(_cine_to)
		return
	if target == null:
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.15:
		yaw -= look.x * stick_speed * delta
		pitch = clampf(pitch - look.y * stick_speed * 0.6 * delta, -1.25, 0.3)
		_idle = 0.0
	_idle += delta

	var car := target as Car
	var follow := target
	var speed := 0.0
	if car == null and target is Player and (target as Player).vehicle != null:
		car = (target as Player).vehicle
		follow = car
	if car != null:
		speed = car.linear_velocity.length()
		# Swing in behind the car after a moment without camera input.
		if _idle > 1.0 and speed > 2.0:
			var heading := atan2(car.global_basis.z.x, car.global_basis.z.z)
			if car.forward_speed() < -1.0:
				heading += PI
			yaw = lerp_angle(yaw, heading + PI, minf(1.0, delta * 2.4))
			pitch = lerpf(pitch, -0.2, minf(1.0, delta * 1.5))

	var height := 1.7 if car == null else 1.5
	var goal := follow.global_position + Vector3(0, height, 0)
	global_position = global_position.lerp(goal, minf(1.0, delta * 16.0))
	rotation = Vector3(pitch, yaw, 0.0)
	var dist := car_distance + clampf(speed / 30.0, 0.0, 1.0) * 2.0 if car != null else foot_distance
	arm.spring_length = lerpf(arm.spring_length, dist, minf(1.0, delta * 3.0))
	var fov := 70.0 + clampf(speed / 32.0, 0.0, 1.0) * 14.0
	cam.fov = lerpf(cam.fov, fov, minf(1.0, delta * 3.0))


## Snap behind whatever the camera follows (after teleports and cutscenes).
func snap_behind() -> void:
	var node := target
	if target is Player and (target as Player).vehicle != null:
		node = (target as Player).vehicle
	if node is Car:
		yaw = atan2(node.global_basis.z.x, node.global_basis.z.z) + PI
	elif node is Player:
		yaw = (node as Player).model.rotation.y
	global_position = node.global_position + Vector3(0, 1.6, 0)
	rotation = Vector3(pitch, yaw, 0.0)
	_idle = 10.0


## Cut to a fixed cinematic angle: camera at `from`, looking at `look_at_point`.
func cinematic(from: Vector3, look_at_point: Vector3, cut: bool = true) -> void:
	_cine = true
	_cine_from = from
	_cine_to = look_at_point
	if cut:
		cine_cam.global_position = from
	cine_cam.look_at(look_at_point)
	cine_cam.current = true


func end_cinematic() -> void:
	_cine = false
	cam.current = true
	snap_behind()


func is_cinematic() -> bool:
	return _cine
