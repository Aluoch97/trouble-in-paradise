class_name Checkpoint
extends Node3D
## Mission marker. "beam" = glowing column on the ground (drive or walk into it).
## "arrow" = bouncing arrow over a person or car (go to them).

const BEAM_SHADER := preload("res://shaders/beam.gdshader")
const PINK := Color("ff6f91")

var follow: Node3D = null
var radius := 3.0

var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _arrow: MeshInstance3D
var _mode := ""
var _t := 0.0


func _ready() -> void:
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 1.0
	beam_mesh.bottom_radius = 1.0
	beam_mesh.height = 8.0
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	mat.set_shader_parameter("color", PINK)
	_beam = MeshInstance3D.new()
	_beam.mesh = beam_mesh
	_beam.material_override = mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = 4.0
	add_child(_beam)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.92
	ring_mesh.outer_radius = 1.0
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = PINK
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	_ring.material_override = glow
	_ring.position.y = 0.2
	add_child(_ring)

	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 0.0
	cone.height = 0.36
	_arrow = MeshInstance3D.new()
	_arrow.mesh = cone
	_arrow.material_override = glow
	add_child(_arrow)
	hide_marker()


func show_beam(pos: Vector3, r: float = 3.0) -> void:
	_mode = "beam"
	follow = null
	radius = r
	global_position = Vector3(pos.x, 0.0, pos.z)
	_beam.scale = Vector3(r, 1.0, r)
	_ring.scale = Vector3(r, 1.0, r)
	_beam.visible = true
	_ring.visible = true
	_arrow.visible = false
	visible = true


func show_arrow(target: Node3D) -> void:
	_mode = "arrow"
	follow = target
	_beam.visible = false
	_ring.visible = false
	_arrow.visible = true
	visible = true


func hide_marker() -> void:
	_mode = ""
	follow = null
	visible = false


func is_active() -> bool:
	return _mode != ""


func _process(delta: float) -> void:
	_t += delta
	if _mode == "arrow" and follow != null and is_instance_valid(follow):
		var h := 2.7 if follow is Car else 2.55
		global_position = follow.global_position + Vector3(0, h + sin(_t * 3.0) * 0.12, 0)
		_arrow.rotation.y = _t * 2.0
	elif _mode == "beam":
		_ring.rotation.y = _t * 0.6
