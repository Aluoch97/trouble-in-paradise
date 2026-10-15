extends Node
## Mission 2: Welcome to Paradise (Act I, track 2).
## Drive to the Knox Ridge pool, find Janae with Samson and Justin, choose how
## to handle it, then drive her home to Quarry Trail. Dialogue lives in
## res://data/dialogue/welcome_to_paradise.json.
##
## Where things happen comes from the Marker3D nodes under Town/Markers, so the
## level designers can move them in the editor without touching this script.

const DIALOGUE_PATH := "res://data/dialogue/welcome_to_paradise.json"
const MISSION_NAME := "2. Welcome to Paradise"

enum Stage { TITLE, TO_CAR, DRIVE_TO_POOL, FIND_JANAE, POOL_SCENE, BACK_TO_CAR, DRIVE_HOME, HOME_SCENE, PASSED, FREE_ROAM }

var stage := Stage.TITLE
var elapsed := 0.0
var lines := {}

var player: Player
var car: Car
var janae: Npc
var samson: Npc
var justin: Npc
var hud: Hud
var rig: CameraRig
var checkpoint: Checkpoint
var radio: Radio
var markers: Node3D

var _title_angle := 0.0
var _last_district := ""
var _complain_cooldown := 0.0
var _left_car_warned := false


func _ready() -> void:
	var f := FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	if f:
		lines = JSON.parse_string(f.get_as_text())
	var main := get_parent()
	player = main.get_node("Player")
	car = main.get_node("Car")
	janae = main.get_node("Janae")
	samson = main.get_node("Samson")
	justin = main.get_node("Justin")
	hud = main.get_node("HUD")
	rig = main.get_node("CameraRig")
	checkpoint = main.get_node("Checkpoint")
	radio = main.get_node("Radio")
	markers = main.get_node("Town/Markers")

	hud.player = player
	hud.rig = rig
	hud.day_cycle = main.get_node("Town/DayCycle")
	hud.radar.player = player
	hud.radar.rig = rig
	hud.play_pressed.connect(start)
	hud.replay_pressed.connect(start)
	hud.keep_driving_pressed.connect(_free_roam)
	player.entered_vehicle.connect(_on_entered_vehicle)
	player.exited_vehicle.connect(_on_exited_vehicle)
	radio.station_changed.connect(hud.radio)
	car.crashed.connect(_on_crash)
	janae.talked_to.connect(_on_talked_to_janae)

	_reset_positions()
	stage = Stage.TITLE
	player.controls_enabled = false
	hud.show_title_screen()


func _marker(marker_name: String) -> Vector3:
	return (markers.get_node(marker_name) as Node3D).global_position


func _reset_positions() -> void:
	if player.vehicle != null:
		player.vehicle.driver = null
		player.vehicle = null
		player.visible = true
		player.get_node("CollisionShape3D").set_deferred("disabled", false)
	player.place(_marker("PlayerSpawn"), _marker("CarSpawn"))
	var car_spot := markers.get_node("CarSpawn") as Node3D
	car.teleport(car_spot.global_transform)
	car.passenger = null
	janae.visible = true
	janae.place(_marker("JanaeSpot"))
	samson.place(_marker("SamsonSpot"))
	justin.place(_marker("JustinSpot"))
	janae.face(_marker("SamsonSpot"))
	samson.face(_marker("JanaeSpot"))
	justin.face(_marker("JanaeSpot"))
	janae.talk_enabled = false


func start() -> void:
	hud.hide_overlay()
	get_tree().paused = false
	Game.reset()
	hud.clear_subs()
	_reset_positions()
	rig.end_cinematic()
	player.controls_enabled = true
	car.controls_enabled = true
	elapsed = 0.0
	_left_car_warned = false
	hud.title_card("Welcome to Paradise", "Act I  ·  Track 2")
	_say_all(lines.get("intro_subtitles", []))
	_set_stage(Stage.TO_CAR)


func _set_stage(s: Stage) -> void:
	stage = s
	match s:
		Stage.TO_CAR:
			hud.set_mission(MISSION_NAME, "Get in your car.")
			checkpoint.show_arrow(car)
			hud.radar.target = car
		Stage.DRIVE_TO_POOL:
			hud.set_mission(MISSION_NAME, "Drive to the Knox Ridge pool to pick up Janae.")
			checkpoint.show_beam(_marker("PoolStop"), 3.2)
			hud.radar.target = _marker("PoolStop")
		Stage.FIND_JANAE:
			hud.set_mission(MISSION_NAME, "Get out and find Janae by the pool.")
			checkpoint.show_arrow(janae)
			hud.radar.target = janae
			janae.talk_enabled = true
		Stage.BACK_TO_CAR:
			hud.set_mission(MISSION_NAME, "Walk back to the car with Janae.")
			checkpoint.show_arrow(car)
			hud.radar.target = car
		Stage.DRIVE_HOME:
			hud.set_mission(MISSION_NAME, "Drive Janae home to Quarry Trail.")
			checkpoint.show_beam(_marker("HomeStop"), 3.2)
			hud.radar.target = _marker("HomeStop")
		Stage.FREE_ROAM:
			hud.set_mission("Free roam", "")
			checkpoint.hide_marker()
			hud.radar.target = null
		_:
			checkpoint.hide_marker()


func _physics_process(delta: float) -> void:
	_complain_cooldown = maxf(0.0, _complain_cooldown - delta)
	if stage == Stage.TITLE:
		_title_camera(delta)
		return
	if stage == Stage.PASSED:
		return
	elapsed += delta
	_update_district()

	match stage:
		Stage.DRIVE_TO_POOL:
			if player.global_position.distance_to(_marker("PoolStop")) < 9.0:
				_set_stage(Stage.FIND_JANAE)
				_say_all(lines.get("arrive_pool_subtitles", []))
		Stage.BACK_TO_CAR:
			# Janae walks to the car with you, then gets in once you're in.
			janae.follow_target = car if player.vehicle == car else player
			if player.vehicle == car and janae.global_position.distance_to(car.global_position) < 2.8:
				janae.visible = false
				janae.follow_target = null
				car.passenger = janae
				_set_stage(Stage.DRIVE_HOME)
				_car_argument()
		Stage.DRIVE_HOME:
			if player.vehicle == null:
				if not _left_car_warned:
					_left_car_warned = true
					hud.set_mission(MISSION_NAME, "Get back in the car. Janae's waiting.")
			elif player.global_position.distance_to(_marker("HomeStop")) < 8.0:
				if car.linear_velocity.length() < 3.5:
					_home_scene()
				elif not hud.subs_busy():
					hud.help("Slow down to stop at the house.", 2.0)


func _update_district() -> void:
	var d := TownLayout.district_at(player.global_position)
	if d != _last_district:
		_last_district = d
		hud.district(d)


func _title_camera(delta: float) -> void:
	_title_angle += delta * 0.06
	var center := _marker("JanaeSpot")
	var from := center + Vector3(cos(_title_angle) * 38.0, 22.0, sin(_title_angle) * 38.0)
	rig.cinematic(from, center + Vector3(0, 2, 0), not rig.is_cinematic())


func _on_entered_vehicle(c: Car) -> void:
	radio.turn_on()
	if stage == Stage.TO_CAR and c == car:
		_set_stage(Stage.DRIVE_TO_POOL)
	if stage == Stage.DRIVE_HOME and c == car:
		hud.set_mission(MISSION_NAME, "Drive Janae home to Quarry Trail.")
		_left_car_warned = false


func _on_exited_vehicle(_c: Car) -> void:
	radio.turn_off()


func _on_crash(impact: float) -> void:
	if car.driver == null:
		return
	Game.add_drama(0.6, "Someone's filming the crash")
	if car.passenger == janae and _complain_cooldown <= 0.0 and impact > 6.0:
		_complain_cooldown = 6.0
		var options: Array = lines.get("crash_complaints", [])
		if not options.is_empty():
			var l: Dictionary = options.pick_random()
			hud.say(l.who, l.text, 1.8)
		Game.add_trust("janae", -2)


func _on_talked_to_janae(_npc: Npc) -> void:
	if stage != Stage.FIND_JANAE:
		return
	_pool_scene()


func _pool_scene() -> void:
	stage = Stage.POOL_SCENE
	janae.talk_enabled = false
	checkpoint.hide_marker()
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	var j := janae.global_position
	# Nick walks up beside her; cut to a low two-shot like the music video.
	var side := (player.global_position - j)
	side.y = 0.0
	if side.length() < 0.1:
		side = Vector3(-1, 0, 0)
	player.place(j + side.normalized() * 1.4, j)
	janae.face(player.global_position)
	var mid := (player.global_position + j) * 0.5 + Vector3(0, 1.45, 0)
	var across := side.normalized().cross(Vector3.UP)
	rig.cinematic(mid + across * 3.6 + Vector3(0, 0.25, 0), mid)
	hud.run_dialogue(lines.get("pool_scene", []), _apply_effects, _after_pool_scene)


func _after_pool_scene() -> void:
	rig.end_cinematic()
	player.controls_enabled = true
	janae.follow_target = player
	_set_stage(Stage.BACK_TO_CAR)


func _car_argument() -> void:
	var which: String = Game.flags.get("pool_choice", "private")
	_say_all(lines.get("car_argument", {}).get(which, []))


func _home_scene() -> void:
	stage = Stage.HOME_SCENE
	checkpoint.hide_marker()
	car.controls_enabled = false
	player.controls_enabled = false
	var c := car.global_position
	# Wide shot from the street: the car in the driveway, the house behind it.
	rig.cinematic(c + car.global_basis.z * 9.0 + car.global_basis.x * 3.5 + Vector3(0, 2.4, 0), c + Vector3(0, 1.3, 0) - car.global_basis.z * 2.0)
	hud.run_dialogue(lines.get("home_scene", []), _apply_effects, _mission_passed)


func _mission_passed() -> void:
	stage = Stage.PASSED
	var seconds := int(elapsed)
	var which: String = Game.flags.get("pool_choice", "private")
	var stats := [
		"Janae trust  %d" % int(Game.trust.janae),
		"Peak drama  %.1f  ·  Time  %d:%02d" % [Game.drama_peak, seconds / 60, seconds % 60],
		String(lines.get("passed_text", {}).get(which, "")),
	]
	hud.show_mission_passed(stats, "Next: 3. Scene II: Now. \"Are you coming inside?\"")


func _free_roam() -> void:
	rig.end_cinematic()
	car.controls_enabled = true
	player.controls_enabled = true
	# Janae goes inside.
	janae.visible = false
	car.passenger = null
	_set_stage(Stage.FREE_ROAM)


func _apply_effects(effects: Dictionary) -> void:
	for who in effects.get("trust", {}):
		Game.add_trust(who, float(effects.trust[who]))
	if effects.has("drama"):
		Game.add_drama(float(effects.drama), "Everybody at the pool is filming")
	for key in effects.get("set", {}):
		Game.flags[key] = effects.set[key]


func _say_all(list: Array) -> void:
	for l in list:
		hud.say(l.who, l.text)
