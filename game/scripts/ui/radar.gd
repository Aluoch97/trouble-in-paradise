class_name Radar
extends Control
## Round radar in the bottom-left corner, San Andreas-style: it turns with the
## camera, shows streets, buildings and the pool, and points to the mission target.

@export var radius := 96.0
@export var range_on_foot := 70.0 ## meters from center to edge
@export var range_in_car := 125.0

var player: Player
var rig: CameraRig
var target: Variant = null ## Vector3 or Node3D the mission wants you to go to

var _layout := TownLayout.new()
var _buildings: Array[Rect2] = [] ## in meters
var _water: Array[Rect2] = []
var _range := 70.0
var _map: Control


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY # the circle drawn below masks the map
	_map = Control.new()
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.size = size
	_map.draw.connect(_draw_map)
	add_child(_map)
	_collect_shapes()


func _collect_shapes() -> void:
	var t := TownLayout.TILE
	for y in range(TownLayout.N):
		var x := 0
		while x < TownLayout.N:
			var kind := _layout.at(x, y)
			if kind == TownLayout.BUILDING or kind == TownLayout.WATER:
				var start := x
				while x < TownLayout.N and _layout.at(x, y) == kind:
					x += 1
				var r := Rect2(start * t, y * t, (x - start) * t, t)
				if kind == TownLayout.BUILDING:
					_buildings.append(r)
				else:
					_water.append(r)
			else:
				x += 1


func _process(delta: float) -> void:
	if player == null:
		return
	var want := range_in_car if player.vehicle != null else range_on_foot
	_range = lerpf(_range, want, minf(1.0, delta * 2.0))
	queue_redraw()
	_map.queue_redraw()


func _draw() -> void:
	# The mask: everything the map draws outside this circle is hidden.
	draw_circle(Vector2(radius, radius), radius, Color(1, 1, 1, 1))


func _to_radar(world: Vector3) -> Vector2:
	var center := player.global_position
	var rel := Vector2(world.x - center.x, world.z - center.z)
	var yaw := rig.yaw if rig != null else 0.0
	return Vector2(radius, radius) + rel.rotated(yaw) * (radius / _range)


func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		_to_radar(Vector3(r.position.x, 0, r.position.y)),
		_to_radar(Vector3(r.end.x, 0, r.position.y)),
		_to_radar(Vector3(r.end.x, 0, r.end.y)),
		_to_radar(Vector3(r.position.x, 0, r.end.y)),
	])


func _draw_map() -> void:
	if player == null:
		return
	var m := _map
	m.draw_rect(Rect2(Vector2.ZERO, size), Color("54663a"))
	# town ground
	m.draw_colored_polygon(_rect_poly(Rect2(0, 0, TownLayout.SIZE, TownLayout.SIZE)), Color("6f7d4a"))
	# roads, running out of town in all four directions
	var s := radius / _range
	var road_w := TownLayout.TILE * 2.0 * s
	for r: int in TownLayout.ROAD_LINES:
		var c := (r + 1.0) * TownLayout.TILE
		m.draw_line(_to_radar(Vector3(-80, 0, c)), _to_radar(Vector3(240, 0, c)), Color("e9dcc4"), road_w)
		m.draw_line(_to_radar(Vector3(c, 0, -80)), _to_radar(Vector3(c, 0, 240)), Color("e9dcc4"), road_w)
	for b in _buildings:
		m.draw_colored_polygon(_rect_poly(b), Color("3e3350"))
	for w in _water:
		m.draw_colored_polygon(_rect_poly(w), Color("3fc3cc"))

	# mission blip, pinned to the rim when off-radar
	if target != null:
		var tp: Vector3 = target.global_position if target is Node3D else target
		var p := _to_radar(tp)
		var c := Vector2(radius, radius)
		var off := p - c
		if off.length() > radius - 9.0:
			p = c + off.normalized() * (radius - 9.0)
		m.draw_circle(p, 7.5, Color("1b1424"))
		m.draw_circle(p, 6.0, Color("ff6f91"))

	# player arrow: points where Nick (or the car) is facing, relative to the camera
	var heading := 0.0
	if player.vehicle != null:
		var f := player.vehicle.global_basis.z
		heading = atan2(f.x, -f.z)
	else:
		heading = -player.model.rotation.y
	var yaw := rig.yaw if rig != null else 0.0
	var a := heading + yaw
	var pts := PackedVector2Array([Vector2(0, -11), Vector2(7, 8), Vector2(0, 4), Vector2(-7, 8)])
	for i in range(pts.size()):
		pts[i] = pts[i].rotated(a) + Vector2(radius, radius)
	m.draw_colored_polygon(pts, Color("ffc65c"))
	pts.append(pts[0])
	m.draw_polyline(pts, Color("1b1424"), 1.5, true)
	# rim
	m.draw_arc(Vector2(radius, radius), radius - 2.0, 0, TAU, 64, Color("1b1424"), 4.0, true)
	m.draw_arc(Vector2(radius, radius), radius - 5.0, 0, TAU, 64, Color(1, 0.96, 0.9, 0.55), 1.5, true)
	# north marker
	var north := Vector2(0, -(radius - 12.0)).rotated(yaw) + Vector2(radius, radius)
	m.draw_circle(north, 8.0, Color("1b1424"))
	m.draw_string(get_theme_default_font(), north + Vector2(-4.5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
