@tool
class_name CarModel
extends Node3D
## Stand-in sedan built from boxes. Faces +Z (the way Godot's VehicleBody3D drives).
## The origin sits at wheel-hub height.
##
## To swap in a real car model: import a .glb, put it next to this node, and
## delete this one. Keep the car body's collision shape about the same size.

@export var body_color := Color("2a8c8c"):
	set(value):
		body_color = value
		_rebuild()
## Draw wheels here. Off for the player car, whose wheels belong to VehicleWheel3D nodes.
@export var show_wheels := true:
	set(value):
		show_wheels = value
		_rebuild()
## Real headlight beams (costs two lights; only the player car uses them).
@export var headlight_beams := false:
	set(value):
		headlight_beams = value
		_rebuild()

var _brake_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _beams: Array[SpotLight3D] = []
var _braking := false


func _ready() -> void:
	_rebuild()


func set_braking(on: bool) -> void:
	if on == _braking or _brake_mat == null:
		return
	_braking = on
	_brake_mat.emission_energy_multiplier = 3.5 if on else 0.8


## 0 = daytime, 1 = full night. Called by the DayCycle through the "lights" group.
func set_night(amount: float) -> void:
	if _head_mat:
		_head_mat.emission_energy_multiplier = lerpf(0.4, 2.5, amount)
	for b in _beams:
		b.light_energy = amount * 3.0
		b.visible = amount > 0.05


func _mat(c: Color, rough: float = 0.5, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.set_meta("generated", true)
	add_child(mi)
	return mi


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("generated"):
			remove_child(c)
			c.queue_free()
	_beams.clear()
	if not is_in_group("car_lights"):
		add_to_group("car_lights")

	var paint := _mat(body_color, 0.42, 0.12)
	var trim := _mat(Color("1d1a22"), 0.6)
	var glass := _mat(Color("1e2638"), 0.08, 0.6)
	var chrome := _mat(Color("d8d8de"), 0.2, 0.9)
	_head_mat = _mat(Color("fff6d8"), 0.3)
	_head_mat.emission_enabled = true
	_head_mat.emission = Color("fff1c4")
	_head_mat.emission_energy_multiplier = 0.4
	_brake_mat = _mat(Color("c3102c"), 0.3)
	_brake_mat.emission_enabled = true
	_brake_mat.emission = Color("ff2440")
	_brake_mat.emission_energy_multiplier = 0.8

	# lower body, hood and trunk lines
	_box(Vector3(1.84, 0.5, 4.5), Vector3(0, 0.12, 0), paint)
	_box(Vector3(1.78, 0.14, 1.25), Vector3(0, 0.42, 1.55), paint) # hood
	_box(Vector3(1.78, 0.14, 0.95), Vector3(0, 0.42, -1.72), paint) # trunk
	# cabin: glass box with a painted roof and pillars
	_box(Vector3(1.6, 0.5, 2.2), Vector3(0, 0.66, -0.15), glass)
	_box(Vector3(1.62, 0.08, 1.9), Vector3(0, 0.94, -0.2), paint) # roof
	for x: float in [-0.78, 0.78]:
		_box(Vector3(0.06, 0.5, 0.12), Vector3(x, 0.66, 0.9), paint)
		_box(Vector3(0.06, 0.5, 0.14), Vector3(x, 0.66, -0.15), paint)
		_box(Vector3(0.06, 0.5, 0.12), Vector3(x, 0.66, -1.2), paint)
	# bumpers + grille
	_box(Vector3(1.9, 0.2, 0.18), Vector3(0, -0.04, 2.26), chrome)
	_box(Vector3(1.9, 0.2, 0.18), Vector3(0, -0.04, -2.26), chrome)
	_box(Vector3(0.9, 0.16, 0.05), Vector3(0, 0.2, 2.25), trim)
	# side skirts
	_box(Vector3(1.88, 0.1, 2.3), Vector3(0, -0.15, 0), trim)
	# lights
	for x: float in [-0.66, 0.66]:
		_box(Vector3(0.36, 0.13, 0.06), Vector3(x, 0.22, 2.25), _head_mat)
		_box(Vector3(0.34, 0.13, 0.06), Vector3(x, 0.24, -2.25), _brake_mat)
	# license plate
	_box(Vector3(0.5, 0.15, 0.03), Vector3(0, 0.02, -2.36), _mat(Color("f3efe2"), 0.7))

	if headlight_beams:
		for x: float in [-0.66, 0.66]:
			var s := SpotLight3D.new()
			s.set_meta("generated", true)
			s.position = Vector3(x, 0.22, 2.3)
			s.rotation = Vector3(deg_to_rad(-6), PI, 0)
			s.spot_range = 28.0
			s.spot_angle = 32.0
			s.light_color = Color("fff1c4")
			s.light_energy = 0.0
			s.visible = false
			add_child(s)
			_beams.append(s)

	if show_wheels:
		var tire := _mat(Color("1a1a1e"), 0.9)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.36
		cyl.bottom_radius = 0.36
		cyl.height = 0.26
		cyl.radial_segments = 14
		var hub := CylinderMesh.new()
		hub.top_radius = 0.2
		hub.bottom_radius = 0.2
		hub.height = 0.28
		hub.radial_segments = 10
		for x: float in [-0.82, 0.82]:
			for z: float in [-1.4, 1.4]:
				for pair in [[cyl, tire], [hub, chrome]]:
					var w := MeshInstance3D.new()
					w.mesh = pair[0]
					w.material_override = pair[1]
					w.position = Vector3(x, -0.05, z)
					w.rotation = Vector3(0, 0, PI / 2.0)
					w.set_meta("generated", true)
					add_child(w)
