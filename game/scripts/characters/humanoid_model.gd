@tool
class_name HumanoidModel
extends Node3D
## Stand-in character body built from simple shapes, so the game runs before real
## character models exist. Faces -Z (Godot's forward).
##
## To swap in a real model later: import a rigged .glb, put it under this node's
## parent instead, and keep an animate(speed, delta) function so the player and
## NPC scripts keep working.

@export var shirt_color := Color("f4efe4"):
	set(value):
		shirt_color = value
		_rebuild()
@export var pants_color := Color("2b2333"):
	set(value):
		pants_color = value
		_rebuild()
@export var skin_color := Color("7a4b33"):
	set(value):
		skin_color = value
		_rebuild()
@export var hair_color := Color("1c1418"):
	set(value):
		hair_color = value
		_rebuild()
@export var shoe_color := Color("f2f2f2"):
	set(value):
		shoe_color = value
		_rebuild()
## Long hair for female characters
@export var long_hair := false:
	set(value):
		long_hair = value
		_rebuild()
@export_range(0.85, 1.15) var body_scale := 1.0:
	set(value):
		body_scale = value
		_rebuild()

var _body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _phase := 0.0
var _hop := 0.0


func _ready() -> void:
	_rebuild()


## speed in m/s along the ground. Call every frame.
func animate(speed: float, delta: float, grounded: bool = true) -> void:
	if _body == null:
		return
	var amount := clampf(speed / 3.0, 0.0, 1.0)
	_phase += delta * (3.0 + speed * 1.9)
	var swing := sin(_phase) * 0.8 * amount
	if not grounded:
		_leg_l.rotation.x = 0.5
		_leg_r.rotation.x = -0.3
		_arm_l.rotation.x = -0.9
		_arm_r.rotation.x = -0.9
		return
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.85
	_arm_r.rotation.x = swing * 0.85
	var breathe := sin(Time.get_ticks_msec() * 0.002) * 0.01 * (1.0 - amount)
	_body.position.y = absf(sin(_phase)) * 0.05 * amount + breathe + _hop


## Small jump used by pedestrians diving out of the way.
func set_hop(height: float) -> void:
	_hop = height


func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("generated"):
			remove_child(c)
			c.queue_free()
	# Children are not given an owner, so they are never saved into scenes.
	_body = Node3D.new()
	_body.set_meta("generated", true)
	_body.scale = Vector3.ONE * body_scale
	add_child(_body)

	var shirt := _mat(shirt_color)
	var pants := _mat(pants_color)
	var skin := _mat(skin_color, 0.7)
	var hair := _mat(hair_color, 0.95)
	var shoes := _mat(shoe_color, 0.6)
	var dark := _mat(Color("161015"), 0.4)

	# torso + hips
	_part(_body, _capsule(0.2, 0.68), shirt, Vector3(0, 1.2, 0), Vector3(1.15, 1.0, 0.72))
	_part(_body, _capsule(0.17, 0.36), pants, Vector3(0, 0.92, 0), Vector3(1.2, 1.0, 0.78))
	# neck + head
	_part(_body, _capsule(0.06, 0.16), skin, Vector3(0, 1.53, 0))
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.125
	head_mesh.height = 0.27
	_part(_body, head_mesh, skin, Vector3(0, 1.68, 0))
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.133
	hair_mesh.height = 0.2
	hair_mesh.is_hemisphere = true
	_part(_body, hair_mesh, hair, Vector3(0, 1.71, 0.01))
	if long_hair:
		_part(_body, _capsule(0.11, 0.42), hair, Vector3(0, 1.56, 0.07), Vector3(1.15, 1.0, 0.6))
	# eyes, so you can tell which way someone faces
	var eye := SphereMesh.new()
	eye.radius = 0.018
	eye.height = 0.036
	_part(_body, eye, dark, Vector3(-0.045, 1.7, -0.112))
	_part(_body, eye, dark, Vector3(0.045, 1.7, -0.112))

	# legs (pivot at the hip)
	_leg_l = _limb(Vector3(-0.1, 0.9, 0), _capsule(0.075, 0.86), pants, -0.43, shoes)
	_leg_r = _limb(Vector3(0.1, 0.9, 0), _capsule(0.075, 0.86), pants, -0.43, shoes)
	# arms (pivot at the shoulder)
	_arm_l = _limb(Vector3(-0.29, 1.45, 0), _capsule(0.055, 0.62), shirt, -0.3, skin, true)
	_arm_r = _limb(Vector3(0.29, 1.45, 0), _capsule(0.055, 0.62), shirt, -0.3, skin, true)


func _limb(pivot_pos: Vector3, mesh: Mesh, mat: Material, offset: float, end_mat: Material, is_arm: bool = false) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_body.add_child(pivot)
	_part(pivot, mesh, mat, Vector3(0, offset, 0))
	if is_arm:
		var hand := SphereMesh.new()
		hand.radius = 0.055
		hand.height = 0.11
		_part(pivot, hand, end_mat, Vector3(0, offset * 2.05, 0))
	else:
		var shoe := BoxMesh.new()
		shoe.size = Vector3(0.12, 0.08, 0.26)
		_part(pivot, shoe, end_mat, Vector3(0, offset * 2.0 - 0.02, -0.05))
	return pivot
