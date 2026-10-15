class_name Player
extends CharacterBody3D
## Nick on foot: walk, run, sprint, jump, get in and out of cars, talk to people.
## Movement is relative to the camera, like San Andreas.

signal entered_vehicle(car: Car)
signal exited_vehicle(car: Car)

@export var walk_speed := 2.0
@export var run_speed := 4.6
@export var sprint_speed := 7.2
@export var jump_velocity := 4.6
@export var enter_range := 3.0

var controls_enabled := true
var vehicle: Car = null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _facing := 0.0

@onready var model: HumanoidModel = $Model
@onready var _shape: CollisionShape3D = $CollisionShape3D


func _physics_process(delta: float) -> void:
	if vehicle != null:
		global_position = vehicle.global_position
		return

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam and input.length() > 0.05:
		var yaw := cam.global_rotation.y
		dir = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)

	var speed := run_speed
	if controls_enabled and Input.is_action_pressed("sprint"):
		speed = sprint_speed
	elif controls_enabled and Input.is_action_pressed("walk"):
		speed = walk_speed
	var target := dir.normalized() * speed * minf(1.0, input.length())
	var accel := 12.0 if is_on_floor() else 2.5
	velocity.x = lerpf(velocity.x, target.x, minf(1.0, accel * delta))
	velocity.z = lerpf(velocity.z, target.z, minf(1.0, accel * delta))

	if is_on_floor():
		if controls_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta
	move_and_slide()

	if dir.length() > 0.1:
		_facing = atan2(-dir.x, -dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, _facing, minf(1.0, 12.0 * delta))
	model.animate(Vector2(velocity.x, velocity.z).length(), delta, is_on_floor())


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or not event.is_action_pressed("interact"):
		return
	if vehicle != null:
		exit_vehicle()
		get_viewport().set_input_as_handled()
		return
	var thing = nearest_interactable()
	if thing != null:
		thing.interact(self)
		get_viewport().set_input_as_handled()
		return
	var car := nearest_car()
	if car != null:
		enter_vehicle(car)
		get_viewport().set_input_as_handled()


## Something nearby that can be talked to or used (group "interactable",
## with can_interact(player) and interact(player) functions).
func nearest_interactable() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node.can_interact(self):
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d < node.interact_range and d < best_d:
			best = node
			best_d = d
	return best


func nearest_car() -> Car:
	var best: Car = null
	var best_d := enter_range
	for n in get_tree().get_nodes_in_group("enterable_car"):
		var car := n as Car
		if car == null or car.driver != null:
			continue
		var d := global_position.distance_to(car.global_position)
		if d < best_d:
			best = car
			best_d = d
	return best


## What the HUD should tell the player they can do right now.
func current_prompt() -> String:
	if not controls_enabled:
		return ""
	if vehicle != null:
		return ""
	var thing = nearest_interactable()
	if thing != null:
		return thing.interact_prompt
	if nearest_car() != null:
		return "Press F to get in the car"
	return ""


func enter_vehicle(car: Car) -> void:
	vehicle = car
	car.driver = self
	velocity = Vector3.ZERO
	visible = false
	_shape.set_deferred("disabled", true)
	entered_vehicle.emit(car)


func exit_vehicle() -> void:
	var car := vehicle
	var spot: Variant = car.exit_position()
	if spot == null:
		Game.notice.emit("No room to get out here", Color("d9c3ad"))
		return
	vehicle = null
	car.driver = null
	global_position = spot
	velocity = Vector3.ZERO
	_facing = atan2(-car.global_basis.z.x, -car.global_basis.z.z) + PI
	model.rotation.y = _facing
	visible = true
	_shape.set_deferred("disabled", false)
	exited_vehicle.emit(car)


## Snap to a spot and face a point (used when missions place the player).
func place(pos: Vector3, look_at_point: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	face(look_at_point)


func face(point: Vector3) -> void:
	var d := point - global_position
	_facing = atan2(-d.x, -d.z)
	model.rotation.y = _facing
