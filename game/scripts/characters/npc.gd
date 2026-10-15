class_name Npc
extends CharacterBody3D
## A story character: Janae, Samson, Justin, and later Jessica and Brandon.
## Missions tell them where to walk, who to follow, and whether you can talk to them.

signal talked_to(npc: Npc)

@export var npc_id := "janae"
@export var display_name := "Janae"
@export var walk_speed := 3.4
@export var name_tag_range := 10.0
@export_group("Look")
@export var shirt_color := Color("ff6f91")
@export var pants_color := Color("2b2333")
@export var skin_color := Color("8a5a3c")
@export var hair_color := Color("1c1418")
@export var long_hair := false
@export_group("")

## When true, the player sees "Press F to talk to <name>" up close.
var talk_enabled := false
var interact_range := 2.2
var interact_prompt: String:
	get:
		return "Press F to talk to %s" % display_name

var follow_target: Node3D = null
var move_target: Variant = null ## Vector3 or null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _facing := 0.0

@onready var model: HumanoidModel = $Model
@onready var name_label: Label3D = $NameLabel


func _ready() -> void:
	add_to_group("npc")
	add_to_group("interactable")
	name_label.text = display_name.to_upper()
	model.shirt_color = shirt_color
	model.pants_color = pants_color
	model.skin_color = skin_color
	model.hair_color = hair_color
	model.long_hair = long_hair
	_facing = model.rotation.y


func can_interact(_player: Node3D) -> bool:
	return talk_enabled and visible


func interact(_player: Node3D) -> void:
	talked_to.emit(self)


func _physics_process(delta: float) -> void:
	if not visible:
		return
	var dest: Variant = null
	if follow_target != null and is_instance_valid(follow_target):
		var tp := follow_target.global_position
		if global_position.distance_to(tp) > 1.7:
			dest = tp
	elif move_target != null:
		dest = move_target

	var h := Vector3.ZERO
	if dest != null:
		var d: Vector3 = dest - global_position
		d.y = 0.0
		if d.length() > 0.2:
			h = d.normalized() * walk_speed * clampf(d.length(), 0.4, 1.0)
	velocity.x = h.x
	velocity.z = h.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	if h.length() > 0.1:
		_facing = atan2(-h.x, -h.z)
	model.rotation.y = lerp_angle(model.rotation.y, _facing, minf(1.0, 10.0 * delta))
	model.animate(Vector2(velocity.x, velocity.z).length(), delta, true)

	var cam := get_viewport().get_camera_3d()
	if cam:
		name_label.visible = cam.global_position.distance_to(global_position) < name_tag_range + 6.0


func face(point: Vector3) -> void:
	var d := point - global_position
	_facing = atan2(-d.x, -d.z)


func place(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	follow_target = null
	move_target = null
