class_name Hud
extends CanvasLayer
## Everything on screen: radar, clock, Drama and Trust meters, help box,
## subtitles, dialogue choices, title screen, pause menu and "Mission passed".
## Built in code so it is easy to restyle in one place (see the COLORS and fonts below).

signal play_pressed
signal keep_driving_pressed
signal replay_pressed

const INK := Color("fff4e6")
const DIM := Color("d9c3ad")
const SUN := Color("ffc65c")
const PINK := Color("ff6f91")
const TEAL := Color("7fd0c3")
const NIGHT := Color("1b1424")
const PANEL := Color(0.106, 0.078, 0.141, 0.86)
const SPEAKER_COLORS := {
	"Nick": "ffc65c", "Janae": "ff6f91", "Samson": "7fd0c3", "Justin": "e0b04a",
	"Jessica": "c3aef0", "Brandon": "9cc3ef",
}
const TRACKS := [
	["I", "Scene I: Summer '10"], ["I", "Welcome to Paradise"], ["I", "Scene II: Now"], ["I", "Falling Apart"],
	["II", "Scene III: Hold On"], ["II", "The Calm"], ["II", "The Storm"], ["II", "Morning Dew"],
	["II", "Summer Mo Interlude"], ["II", "Scene IV: Promise"], ["II", "Cali Luv (feat. Marlinda)"], ["II", "Driving to L.A."],
]

var player: Player
var rig: CameraRig
var day_cycle: DayCycle
var radar: Radar

var font_display: Font
var font_hud: Font
var font_hud_bold: Font
var font_body: Font

var _root: Control
var _clock: Label
var _phones: Control
var _trust_bar: ProgressBar
var _help: PanelContainer
var _help_label: Label
var _help_time := 0.0
var _mission_box: VBoxContainer
var _mission_name: Label
var _mission_obj: Label
var _subs: RichTextLabel
var _sub_queue: Array[Dictionary] = []
var _sub_time := 0.0
var _objective_big: Label
var _objective_time := 0.0
var _district: Label
var _district_time := 0.0
var _radio: Label
var _radio_time := 0.0
var _notice: Label
var _notice_time := 0.0
var _card: VBoxContainer
var _card_title: Label
var _card_sub: Label
var _card_time := 0.0
var _dialog: PanelContainer
var _dialog_who: Label
var _dialog_line: Label
var _dialog_choices: VBoxContainer
var _dialog_next: Label
var _overlay: Control
var _overlay_box: VBoxContainer

var _steps: Array = []
var _step_i := -1
var _typed := 0.0
var _full_line := ""
var _choosing := false
var _on_effects: Callable
var _on_done: Callable
var _drama_shown := -1
var _prompt := ""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_display = _font("Shrikhand-Regular")
	font_hud_bold = _font("BarlowCondensed-ExtraBold")
	font_hud = _font("BarlowCondensed-SemiBold")
	font_body = _font("Barlow-Medium")
	_build()
	Game.drama_changed.connect(_on_drama)
	Game.trust_changed.connect(_on_trust)
	Game.notice.connect(notice)


func _font(file: String) -> Font:
	var path := "res://assets/fonts/%s.woff2" % file
	if ResourceLoader.exists(path):
		return load(path)
	return ThemeDB.fallback_font


# ---------------------------------------------------------------- building

func _label(text: String, font: Font, size: int, color: Color, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel_style(alpha: float = 0.86, border: Color = Color(1, 0.78, 0.36, 0.3)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL, alpha)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	return sb


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_hud_bold)
	b.add_theme_font_size_override("font_size", 26)
	b.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(40)
	normal.content_margin_left = 30
	normal.content_margin_right = 30
	normal.content_margin_top = 10
	normal.content_margin_bottom = 12
	if primary:
		normal.bg_color = SUN
		normal.shadow_color = Color("b8456a")
		normal.shadow_offset = Vector2(0, 5)
		normal.shadow_size = 1
		b.add_theme_color_override("font_color", NIGHT)
		b.add_theme_color_override("font_hover_color", NIGHT)
		b.add_theme_color_override("font_focus_color", NIGHT)
		b.add_theme_color_override("font_pressed_color", NIGHT)
	else:
		normal.bg_color = Color(1, 1, 1, 0.04)
		normal.set_border_width_all(2)
		normal.border_color = Color(INK, 0.45)
		b.add_theme_color_override("font_color", INK)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Color.WHITE
	focus.set_border_width_all(3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.12) if primary else Color(1, 1, 1, 0.1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("focus", focus)
	return b


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# radar, bottom-left
	radar = Radar.new()
	_root.add_child(radar)
	radar.anchor_left = 0.0
	radar.anchor_right = 0.0
	radar.anchor_top = 1.0
	radar.anchor_bottom = 1.0
	radar.offset_left = 34
	radar.offset_right = 34 + radar.radius * 2.0
	radar.offset_top = -40 - radar.radius * 2.0
	radar.offset_bottom = -40

	# clock + meters, top-right
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -300
	tr.offset_right = -34
	tr.offset_top = 26
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.add_theme_constant_override("separation", 6)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tr)
	_clock = _label("6:40 PM", font_hud_bold, 46, INK, 8)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_clock)
	_phones = Control.new()
	_phones.custom_minimum_size = Vector2(266, 30)
	_phones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phones.draw.connect(_draw_phones)
	tr.add_child(_phones)
	var trust_row := HBoxContainer.new()
	trust_row.alignment = BoxContainer.ALIGNMENT_END
	trust_row.add_theme_constant_override("separation", 10)
	trust_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(trust_row)
	trust_row.add_child(_label("JANAE", font_hud_bold, 18, DIM, 5))
	_trust_bar = ProgressBar.new()
	_trust_bar.custom_minimum_size = Vector2(150, 14)
	_trust_bar.show_percentage = false
	_trust_bar.value = 60
	_trust_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(7)
	bg.set_border_width_all(2)
	bg.border_color = Color(0, 0, 0, 0.8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = PINK
	fill.set_corner_radius_all(7)
	_trust_bar.add_theme_stylebox_override("background", bg)
	_trust_bar.add_theme_stylebox_override("fill", fill)
	trust_row.add_child(_trust_bar)

	# help box + current mission, top-left
	var tl := VBoxContainer.new()
	tl.position = Vector2(34, 28)
	tl.custom_minimum_size = Vector2(430, 0)
	tl.add_theme_constant_override("separation", 12)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tl)
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", _panel_style(0.8, Color(0, 0, 0, 0)))
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_label = _label("", font_body, 21, INK, 0)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.custom_minimum_size = Vector2(390, 0)
	_help.add_child(_help_label)
	_help.visible = false
	tl.add_child(_help)
	_mission_box = VBoxContainer.new()
	_mission_box.add_theme_constant_override("separation", 0)
	_mission_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission_name = _label("", font_hud_bold, 17, SUN, 5)
	_mission_obj = _label("", font_hud, 24, INK, 6)
	_mission_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_obj.custom_minimum_size = Vector2(430, 0)
	_mission_box.add_child(_mission_name)
	_mission_box.add_child(_mission_obj)
	tl.add_child(_mission_box)

	# radio station, top-center
	_radio = _label("", font_hud_bold, 34, SUN, 8)
	_radio.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_radio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_radio.offset_left = -400
	_radio.offset_right = 400
	_radio.offset_top = 26
	_radio.modulate.a = 0
	_root.add_child(_radio)

	# subtitles + objective, bottom-center
	var bc := VBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.anchor_top = 1.0
	bc.anchor_bottom = 1.0
	bc.offset_left = -520
	bc.offset_right = 520
	bc.offset_top = -210
	bc.offset_bottom = -40
	bc.alignment = BoxContainer.ALIGNMENT_END
	bc.add_theme_constant_override("separation", 10)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bc)
	_subs = RichTextLabel.new()
	_subs.bbcode_enabled = true
	_subs.fit_content = true
	_subs.scroll_active = false
	_subs.add_theme_font_override("normal_font", font_hud)
	_subs.add_theme_font_override("bold_font", font_hud_bold)
	_subs.add_theme_font_size_override("normal_font_size", 30)
	_subs.add_theme_font_size_override("bold_font_size", 30)
	_subs.add_theme_constant_override("outline_size", 7)
	_subs.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_subs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bc.add_child(_subs)
	_objective_big = _label("", font_hud, 30, SUN, 7)
	_objective_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_big.modulate.a = 0
	bc.add_child(_objective_big)

	# district name, bottom-right
	_district = _label("", font_display, 58, SUN, 10)
	_district.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_district.anchor_left = 1.0
	_district.anchor_top = 1.0
	_district.offset_left = -700
	_district.offset_right = -40
	_district.offset_top = -120
	_district.offset_bottom = -36
	_district.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_district.add_theme_color_override("font_outline_color", Color("8e2f55"))
	_district.modulate.a = 0
	_root.add_child(_district)

	# floating notices, center
	_notice = _label("", font_hud_bold, 30, PINK, 7)
	_notice.set_anchors_preset(Control.PRESET_CENTER)
	_notice.offset_left = -500
	_notice.offset_right = 500
	_notice.offset_top = 40
	_notice.offset_bottom = 80
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.modulate.a = 0
	_root.add_child(_notice)

	# mission title card, center
	_card = VBoxContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -700
	_card.offset_right = 700
	_card.offset_top = -190
	_card.offset_bottom = -40
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_sub = _label("", font_hud_bold, 24, INK, 6)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title = _label("", font_display, 92, SUN, 12)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_color_override("font_outline_color", Color("8e2f55"))
	_card.add_child(_card_sub)
	_card.add_child(_card_title)
	_card.modulate.a = 0
	_root.add_child(_card)

	# dialogue panel
	_dialog = PanelContainer.new()
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.anchor_top = 1.0
	_dialog.anchor_bottom = 1.0
	_dialog.offset_left = -440
	_dialog.offset_right = 440
	_dialog.offset_top = -250
	_dialog.offset_bottom = -34
	_dialog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialog.add_theme_stylebox_override("panel", _panel_style())
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	_dialog.add_child(dv)
	_dialog_who = _label("", font_hud_bold, 22, SUN, 0)
	_dialog_line = _label("", font_body, 25, INK, 0)
	_dialog_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_line.custom_minimum_size = Vector2(800, 64)
	_dialog_choices = VBoxContainer.new()
	_dialog_choices.add_theme_constant_override("separation", 8)
	_dialog_next = _label("F / Space / click to continue", font_hud, 17, DIM, 0)
	_dialog_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dv.add_child(_dialog_who)
	dv.add_child(_dialog_line)
	dv.add_child(_dialog_choices)
	dv.add_child(_dialog_next)
	_dialog.visible = false
	_dialog.gui_input.connect(_on_dialog_click)
	_root.add_child(_dialog)

	# full-screen menus (title, pause, mission passed)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(NIGHT, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	_overlay_box = VBoxContainer.new()
	_overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.add_theme_constant_override("separation", 14)
	center.add_child(_overlay_box)
	_root.add_child(_overlay)


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if day_cycle:
		_clock.text = day_cycle.clock_text()
	_tick_subs(delta)
	_tick_dialog(delta)
	_help_time -= delta
	if _help_time <= 0.0 and _prompt == "":
		_help.visible = false
	if player and not _overlay.visible and not _dialog.visible:
		var p := player.current_prompt()
		if p != _prompt:
			_prompt = p
			if p != "":
				_help_label.text = p
				_help.visible = true
	_fade(_objective_big, delta, _objective_time if not _dialog.visible else 0.0)
	_objective_time -= delta
	_fade(_district, delta, _district_time)
	_district_time -= delta
	_fade(_radio, delta, _radio_time)
	_radio_time -= delta
	_fade(_notice, delta, _notice_time)
	_notice_time -= delta
	_fade(_card, delta, _card_time)
	_card_time -= delta
	_update_mouse()


func _fade(c: CanvasItem, delta: float, time_left: float) -> void:
	var want := 1.0 if time_left > 0.0 else 0.0
	c.modulate.a = move_toward(c.modulate.a, want, delta * 2.5)


func _update_mouse() -> void:
	var free := _overlay.visible or _choosing
	var want := Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED
	if DisplayServer.get_name() != "headless" and Input.mouse_mode != want:
		Input.mouse_mode = want


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _dialog.visible and not _choosing and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump")):
		advance_dialog()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- meters

func _on_drama(_v: float) -> void:
	var n := ceili(Game.drama - 0.01)
	if n != _drama_shown:
		_drama_shown = n
		_phones.queue_redraw()


func _draw_phones() -> void:
	var n := ceili(Game.drama - 0.01)
	for i in range(5):
		var x := _phones.size.x - (5 - i) * 30.0
		var r := Rect2(x, 2, 20, 28)
		var on := i < n
		_phones.draw_rect(r.grow(2), Color(0, 0, 0, 0.85))
		_phones.draw_rect(r, PINK if on else Color(0.1, 0.07, 0.14, 0.7))
		_phones.draw_rect(Rect2(x + 4, 6, 12, 16), INK if on else Color(1, 1, 1, 0.12))


func _on_trust(who: String, value: float, _change: float) -> void:
	if who == "janae":
		var t := create_tween()
		t.tween_property(_trust_bar, "value", value, 0.6)


# ---------------------------------------------------------------- messages

func help(text: String, seconds: float = 6.0) -> void:
	_help_label.text = text
	_help.visible = true
	_help_time = seconds


func set_mission(mission_name: String, objective: String) -> void:
	_mission_name.text = mission_name.to_upper()
	_mission_obj.text = objective
	_mission_box.visible = objective != ""
	if objective != "":
		_objective_big.text = objective
		_objective_time = 5.0


func district(text: String) -> void:
	_district.text = text
	_district_time = 3.5


func radio(station: String, track: String) -> void:
	_radio.text = "%s\n%s" % [station, track]
	_radio_time = 3.5


func notice(text: String, color: Color = PINK) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)
	_notice.modulate.a = 0.0
	_notice_time = 2.2


func title_card(title: String, sub: String, seconds: float = 4.0) -> void:
	_card_title.text = title
	_card_sub.text = sub.to_upper()
	_card_time = seconds


## Queue a subtitle line. Plays after any lines already queued.
func say(who: String, text: String, seconds: float = -1.0) -> void:
	if seconds < 0.0:
		seconds = maxf(2.4, text.length() * 0.065)
	_sub_queue.append({"who": who, "text": text, "time": seconds})


func clear_subs() -> void:
	_sub_queue.clear()
	_sub_time = 0.0
	_subs.text = ""


func subs_busy() -> bool:
	return _sub_time > 0.0 or not _sub_queue.is_empty()


func _tick_subs(delta: float) -> void:
	if _sub_time > 0.0:
		_sub_time -= delta
		if _sub_time <= 0.0:
			_subs.text = ""
		return
	if _sub_queue.is_empty():
		return
	var s: Dictionary = _sub_queue.pop_front()
	_sub_time = s.time
	var col: String = SPEAKER_COLORS.get(s.who, "fff4e6")
	_subs.text = "[center][b][color=#%s]%s:[/color][/b] %s[/center]" % [col, s.who, s.text]


# ---------------------------------------------------------------- dialogue

## steps: [{who, text}, {choice: [{label, note, effects, then: [...]}]}, {effects: {...}}]
func run_dialogue(steps: Array, on_effects: Callable, on_done: Callable) -> void:
	clear_subs()
	_steps = steps.duplicate(true)
	_step_i = -1
	_on_effects = on_effects
	_on_done = on_done
	_dialog.visible = true
	_help.visible = false
	_next_step()


func dialogue_active() -> bool:
	return _dialog.visible


func _next_step() -> void:
	_step_i += 1
	for c in _dialog_choices.get_children():
		c.queue_free()
	_choosing = false
	if _step_i >= _steps.size():
		_dialog.visible = false
		var done := _on_done
		_on_done = Callable()
		if done.is_valid():
			done.call()
		return
	var s: Dictionary = _steps[_step_i]
	if s.has("effects") and not s.has("choice"):
		_on_effects.call(s.effects)
		_next_step()
		return
	if s.has("choice"):
		_choosing = true
		_dialog_who.text = "YOUR MOVE"
		_dialog_who.add_theme_color_override("font_color", DIM)
		_dialog_line.text = ""
		_dialog_line.visible = false
		_dialog_next.visible = false
		var first: Button = null
		for opt in s.choice:
			var b := Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = "%s\n%s" % [opt.label, opt.get("note", "")]
			b.add_theme_font_override("font", font_body)
			b.add_theme_font_size_override("font_size", 23)
			var sb := _panel_style(0.0, Color(INK, 0.3))
			sb.bg_color = Color(1, 1, 1, 0.05)
			var sbf := sb.duplicate() as StyleBoxFlat
			sbf.border_color = SUN
			sbf.set_border_width_all(2)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sbf)
			b.add_theme_stylebox_override("focus", sbf)
			b.add_theme_stylebox_override("pressed", sbf)
			b.pressed.connect(_pick.bind(opt))
			_dialog_choices.add_child(b)
			if first == null:
				first = b
		if first:
			first.call_deferred("grab_focus")
		return
	_dialog_line.visible = true
	_dialog_next.visible = true
	_dialog_who.text = String(s.who).to_upper()
	_dialog_who.add_theme_color_override("font_color", Color(SPEAKER_COLORS.get(s.who, "fff4e6")))
	_full_line = s.text
	_typed = 0.0
	_dialog_line.text = ""


func _pick(opt: Dictionary) -> void:
	if opt.has("effects"):
		_on_effects.call(opt.effects)
	var then: Array = opt.get("then", [])
	for i in range(then.size()):
		_steps.insert(_step_i + 1 + i, then[i])
	_next_step()


func advance_dialog() -> void:
	if not _dialog.visible or _choosing:
		return
	if _typed < _full_line.length():
		_typed = _full_line.length()
		_dialog_line.text = _full_line
		return
	_next_step()


## Pick a dialogue option by index (used by the automated test).
func choose(i: int) -> void:
	if _choosing and i < _dialog_choices.get_child_count():
		(_dialog_choices.get_child(i) as Button).pressed.emit()


func _tick_dialog(delta: float) -> void:
	if not _dialog.visible or _choosing or _typed >= _full_line.length():
		return
	_typed = minf(_full_line.length(), _typed + delta * 50.0)
	_dialog_line.text = _full_line.substr(0, int(_typed))


func _on_dialog_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_dialog()


# ---------------------------------------------------------------- menus

func _clear_overlay() -> void:
	for c in _overlay_box.get_children():
		c.queue_free()


func _center(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


func show_title_screen() -> void:
	_clear_overlay()
	_set_gameplay_hud(false)
	var k := _label("NURENAISSANCE PRESENTS", font_hud_bold, 22, DIM, 4)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(k)
	var t := _label("Trouble in Paradise", font_display, 120, SUN, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color("8e2f55"))
	_overlay_box.add_child(t)
	var s := _label("STARRING NICÓLAS SOUL", font_hud_bold, 26, INK, 5)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(s)
	_overlay_box.add_child(Control.new())
	var play := _button("Play  ·  2. Welcome to Paradise", true)
	play.pressed.connect(func(): play_pressed.emit())
	_overlay_box.add_child(_center(play))
	var h := _label("WASD move  ·  Mouse look  ·  F get in / out / talk  ·  Space jump / handbrake  ·  Shift sprint  ·  R next track  ·  Esc pause\nGamepad works too.", font_hud, 21, DIM, 4)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(h)
	_overlay_box.add_child(_track_list())
	_overlay.visible = true
	play.call_deferred("grab_focus")


func _track_list() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in range(6):
		for col in range(2):
			var idx := i + col * 6
			var live := idx == 1
			var txt := "%2d   %s%s" % [idx + 1, TRACKS[idx][1], "   · PLAYABLE" if live else ""]
			grid.add_child(_label(txt, font_hud, 21, SUN if live else Color(INK, 0.75), 4))
	return grid


func toggle_pause() -> void:
	if not _overlay.visible:
		if get_tree().paused:
			return
		get_tree().paused = true
		_clear_overlay()
		var t := _label("Paused", font_display, 90, SUN, 12)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_overlay_box.add_child(t)
		var r := _button("Resume", true)
		r.pressed.connect(toggle_pause)
		_overlay_box.add_child(_center(r))
		var again := _button("Restart mission", false)
		again.pressed.connect(func():
			get_tree().paused = false
			_overlay.visible = false
			replay_pressed.emit())
		_overlay_box.add_child(_center(again))
		var q := _button("Quit game", false)
		q.pressed.connect(func(): get_tree().quit())
		_overlay_box.add_child(_center(q))
		_overlay.visible = true
		r.call_deferred("grab_focus")
	elif get_tree().paused:
		get_tree().paused = false
		_overlay.visible = false


func show_mission_passed(lines: Array, next_text: String) -> void:
	_clear_overlay()
	var k := _label("ACT I  ·  TRACK 2", font_hud_bold, 22, DIM, 4)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(k)
	var t := _label("Mission passed!", font_display, 104, SUN, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color("8e2f55"))
	_overlay_box.add_child(t)
	for line in lines:
		var l := _label(line, font_hud_bold, 30, INK, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_overlay_box.add_child(l)
	var n := _label(next_text, font_hud, 22, SUN, 4)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(n)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var keep := _button("Keep driving", true)
	keep.pressed.connect(func():
		_overlay.visible = false
		_set_gameplay_hud(true)
		keep_driving_pressed.emit())
	var again := _button("Replay mission", false)
	again.pressed.connect(func():
		_overlay.visible = false
		_set_gameplay_hud(true)
		replay_pressed.emit())
	row.add_child(keep)
	row.add_child(again)
	_overlay_box.add_child(row)
	_overlay.visible = true
	_set_gameplay_hud(false)
	keep.call_deferred("grab_focus")


func hide_overlay() -> void:
	_overlay.visible = false
	_set_gameplay_hud(true)


func _set_gameplay_hud(on: bool) -> void:
	if not on:
		_objective_time = 0.0
		_district_time = 0.0
		_objective_big.modulate.a = 0.0
		_district.modulate.a = 0.0
		clear_subs()
	radar.visible = on
	_clock.get_parent().visible = on
	_mission_box.visible = on and _mission_obj.text != ""
	_help.visible = false
