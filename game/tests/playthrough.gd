extends Node
## Automated playthrough of mission 2. Drives the car, runs the pool scene,
## brings Janae home, and checks that the mission passes. Exits with code 1 on failure.
##
##   godot --headless --path game res://tests/playthrough.tscn
##
## Run it with a window (no --headless) to also save screenshots to
## the user data folder (user://screenshots).

var main: Node3D
var mission: Node
var player: Player
var car: Car
var hud: Hud
var failures: PackedStringArray = []
var shots := false


func _ready() -> void:
	shots = DisplayServer.get_name() != "headless"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	mission = main.get_node("Mission")
	player = main.get_node("Player")
	car = main.get_node("Car")
	hud = main.get_node("HUD")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures.append(what)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/%s.png" % shot_name
	get_viewport().get_texture().get_image().save_png(path)
	print("  saved ", ProjectSettings.globalize_path(path))


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _marker(n: String) -> Vector3:
	return (main.get_node("Town/Markers/" + n) as Node3D).global_position


func _run() -> void:
	print("Playthrough: 2. Welcome to Paradise")
	await _wait(1.5)
	_check(mission.stage == mission.Stage.TITLE, "title screen shows on launch")
	await _shot("01_title")

	mission.start()
	await _wait(1.0)
	_check(mission.stage == mission.Stage.TO_CAR, "mission starts at 'Get in your car'")
	await _shot("02_start")

	# Walk toward the car using real input.
	var start_pos := player.global_position
	Input.action_press("move_forward")
	await _wait(0.8)
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start_pos) > 1.0, "Nick walks (moved %.1f m)" % player.global_position.distance_to(start_pos))

	player.global_position = car.global_position + car.global_basis.x * 1.8
	await _wait(0.3)
	await _press("interact")
	await _wait(0.3)
	_check(player.vehicle == car, "F gets Nick into the car")
	_check(mission.stage == mission.Stage.DRIVE_TO_POOL, "objective switches to driving to the pool")

	# Driving checks on the long straight north road, with traffic parked out of the way.
	var traffic := main.get_node("Traffic")
	traffic.process_mode = Node.PROCESS_MODE_DISABLED
	for body in traffic.get_children():
		(body as Node3D).global_position.y -= 200.0
	car.teleport(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(20, 0.6, 6)))
	await _wait(0.6)
	_check(car.global_position.y > 0.1 and car.global_position.y < 1.0, "car rests on the road (y = %.2f)" % car.global_position.y)
	var fwd := car.global_basis.z
	var p0 := car.global_position
	Input.action_press("move_forward")
	await _wait(2.5)
	var moved := car.global_position - p0
	_check(moved.dot(fwd) > 8.0, "car drives forward (%.1f m in 2.5 s, now %.0f km/h)" % [moved.dot(fwd), car.speed_kmh()])
	await _shot("03_driving")
	await _wait(3.5)
	var top := car.speed_kmh()
	_check(top > 70.0 and top < 160.0, "top speed is GTA-ish (%.0f km/h after 6 s)" % top)
	Input.action_press("move_left")
	var yaw0 := car.global_rotation.y
	await _wait(0.5)
	Input.action_release("move_left")
	var turned := wrapf(car.global_rotation.y - yaw0, -PI, PI)
	_check(turned > 0.05, "A steers left (%.2f rad)" % turned)
	Input.action_release("move_forward")
	_check(car.global_basis.y.y > 0.9, "car stays upright through a fast turn")
	var before_brake := car.speed_kmh()
	Input.action_press("move_back")
	await _wait(2.0)
	Input.action_release("move_back")
	_check(car.speed_kmh() < 20.0, "brakes stop the car (%.0f -> %.0f km/h)" % [before_brake, car.speed_kmh()])
	traffic.process_mode = Node.PROCESS_MODE_INHERIT

	# Arrive at the pool.
	var stop := _marker("PoolStop")
	car.teleport(Transform3D(Basis(), stop + Vector3(0, 0.6, -4)))
	await _wait(0.6)
	_check(mission.stage == mission.Stage.FIND_JANAE, "arriving at the pool triggers 'find Janae'")
	await _press("interact")
	await _wait(0.4)
	_check(player.vehicle == null, "F gets Nick out of the car")
	player.global_position = _marker("JanaeSpot") + Vector3(-1.8, 0.2, 0.3)
	await _wait(0.5)
	_check(player.current_prompt().contains("talk to Janae"), "prompt says 'Press F to talk to Janae'")
	await _shot("04_pool")
	await _press("interact")
	await _wait(0.6)
	_check(mission.stage == mission.Stage.POOL_SCENE and hud.dialogue_active(), "talking to Janae starts the pool scene")
	await _shot("05_pool_scene")

	var guard := 0
	while not hud._choosing and hud.dialogue_active() and guard < 20:
		hud.advance_dialog()
		hud.advance_dialog()
		await _wait(0.1)
		guard += 1
	_check(hud._choosing, "the pool scene reaches the choice")
	await _shot("06_choice")
	hud.choose(1) # make a scene
	await _wait(0.1)
	guard = 0
	while hud.dialogue_active() and guard < 20:
		hud.advance_dialog()
		hud.advance_dialog()
		await _wait(0.1)
		guard += 1
	_check(Game.flags.get("pool_choice") == "scene", "the choice is remembered")
	_check(Game.drama >= 1.5, "making a scene raises Drama (%.1f)" % Game.drama)
	_check(Game.trust.janae < 60.0, "making a scene costs Janae trust (%d)" % Game.trust.janae)
	_check(mission.stage == mission.Stage.BACK_TO_CAR, "after the scene: walk back to the car")

	# Janae follows Nick, then gets in.
	player.global_position = car.global_position + car.global_basis.x * 1.8
	await _wait(0.2)
	await _press("interact")
	guard = 0
	while mission.stage == mission.Stage.BACK_TO_CAR and guard < 60:
		await _wait(0.25)
		guard += 1
	_check(mission.stage == mission.Stage.DRIVE_HOME, "Janae walks to the car and gets in (%.1f s)" % (guard * 0.25))
	await _wait(1.0)
	await _shot("07_drive_home")

	# Drive home.
	var home := _marker("HomeStop")
	car.teleport(Transform3D(Basis(Vector3.UP, -PI / 2.0), home + Vector3(2.0, 0.6, 0)))
	await _wait(1.0)
	_check(mission.stage == mission.Stage.HOME_SCENE, "stopping at the house starts the last scene")
	await _shot("08_home")
	guard = 0
	while hud.dialogue_active() and guard < 20:
		hud.advance_dialog()
		hud.advance_dialog()
		await _wait(0.1)
		guard += 1
	await _wait(0.5)
	_check(mission.stage == mission.Stage.PASSED, "Mission passed")
	await _shot("09_passed")

	hud.keep_driving_pressed.emit()
	hud.hide_overlay()
	await _wait(0.5)
	_check(mission.stage == mission.Stage.FREE_ROAM and car.controls_enabled, "Keep driving returns control")

	print("")
	if failures.is_empty():
		print("PLAYTHROUGH PASSED")
	else:
		print("PLAYTHROUGH FAILED: %d check(s)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
