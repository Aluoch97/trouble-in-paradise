class_name DayCycle
extends Node
## Moves the sun from golden hour into night. The game starts at 7:00 PM,
## and night falls a few minutes into the mission.
## Window lights, street lights and headlights come on as the sun goes down.

signal time_changed(hour: float)

@export var sun: DirectionalLight3D
@export var world_env: WorldEnvironment
@export_range(0.0, 24.0) var hour := 19.0
## Game minutes that pass per real second.
@export var minutes_per_second := 0.3
@export var running := true

const DAY_TOP := Color(0.32, 0.52, 0.86)
const DUSK_TOP := Color(0.24, 0.17, 0.4)
const NIGHT_TOP := Color(0.03, 0.04, 0.1)
const DAY_HORIZON := Color(0.78, 0.84, 0.92)
const DUSK_HORIZON := Color(1.0, 0.56, 0.38)
const NIGHT_HORIZON := Color(0.1, 0.09, 0.2)

var night := 0.0 ## 0 = day, 1 = full night


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	if running:
		hour = fmod(hour + delta * minutes_per_second / 60.0, 24.0)
	_apply()
	time_changed.emit(hour)


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


func _apply() -> void:
	if sun == null or world_env == null:
		return
	# Sun height in degrees: up at 7 AM, peaks at noon-ish, sets at 8 PM.
	var elev := sin((hour - 7.0) / 13.0 * PI) * 62.0
	var azimuth := deg_to_rad(lerpf(-110.0, 110.0, clampf((hour - 7.0) / 13.0, 0.0, 1.0)))
	var visible_elev := maxf(elev, 4.0) # keep shadows readable at dusk
	sun.rotation = Vector3(-deg_to_rad(visible_elev), azimuth, 0.0)

	var golden := clampf(1.0 - elev / 32.0, 0.0, 1.0)
	night = clampf((6.0 - elev) / 14.0, 0.0, 1.0)
	var warm := Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.6, 0.34), golden)
	sun.light_color = warm.lerp(Color(0.45, 0.55, 0.85), night)
	sun.light_energy = lerpf(1.05, 0.1, night)

	var env := world_env.environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	var top := DAY_TOP.lerp(DUSK_TOP, golden).lerp(NIGHT_TOP, night)
	var horizon := DAY_HORIZON.lerp(DUSK_HORIZON, golden).lerp(NIGHT_HORIZON, night)
	if sky:
		sky.sky_top_color = top
		sky.sky_horizon_color = horizon
		sky.ground_horizon_color = horizon.darkened(0.25)
		sky.ground_bottom_color = top.darkened(0.6)
	env.ambient_light_energy = lerpf(0.5, 0.22, night)
	env.fog_light_color = horizon.lerp(top, 0.35)

	RenderingServer.global_shader_parameter_set("city_lights", clampf((14.0 - elev) / 16.0, 0.0, 1.0))
	for n in get_tree().get_nodes_in_group("street_light"):
		if n is Light3D:
			(n as Light3D).light_energy = night * 2.2
			(n as Light3D).visible = night > 0.05
	for n in get_tree().get_nodes_in_group("car_lights"):
		n.set_night(night)
