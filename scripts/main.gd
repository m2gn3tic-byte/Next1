extends Control
## All artwork and hit areas use a 1080 × 1920 logical portrait canvas.

const SPACE := preload("res://assets/space.svg")
const SHIP := preload("res://assets/ship.svg")
const PLANET := preload("res://assets/planet.svg")
const ASTEROID := preload("res://assets/asteroid.svg")
const FONT := preload("res://assets/fonts/DejaVuSans.ttf")
const BOLD := preload("res://assets/fonts/DejaVuSans-Bold.ttf")
const MINT := Color("9af5d3")
const CREAM := Color("fff4d9")
const MUTED := Color("97aac6")
const GOLD := Color("ffcf6d")

var run := CourierRun.new()
var profile: CourierProfile
var stars: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var trail: Array[Vector2] = []
var intro_remaining := 0.0
var visual_rng := RandomNumberGenerator.new()
var clock := 0.0
var drag_id := -1
var drag_origin := Vector2.ZERO
var ship_origin := Vector2.ZERO
var bank_angle := 0.0
var hit_flash := 0.0
var toast_remaining := 0.0
var notification_text := ""
var last_mode := CourierRun.Mode.READY
var sound_player: AudioStreamPlayer
var sounds: Dictionary = {}

var home: Control
var hud: Control
var overlay: Control
var coin_label: Label
var package_label: Label
var score_label: Label
var hint_label: Label
var subhint_label: Label
var toast_label: Label
var record_label: Label
var sound_button: Button
var overlay_title: Label
var overlay_subtitle: Label
var overlay_stats: Label
var primary_button: Button
var secondary_button: Button
var level_buttons: Array[Button] = []
var region_label: Label
var home_region_label: Label
var home_description: Label


func _ready() -> void:
	profile = CourierProfile.new()
	visual_rng.seed = 774
	for i in range(145):
		stars.append({"position": Vector2(visual_rng.randf_range(20.0, 1060.0), visual_rng.randf_range(0.0, 1920.0)),
			"depth": visual_rng.randf_range(0.2, 1.0), "phase": visual_rng.randf_range(0.0, TAU)})
	run.event.connect(_on_run_event)
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -13.0
	add_child(sound_player)
	_make_sounds()
	_build_interface()
	_sync_interface()
	get_window().focus_exited.connect(_pause_for_background)


func _exit_tree() -> void:
	if is_instance_valid(sound_player):
		sound_player.stop()
		sound_player.stream = null


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	if run.mode != CourierRun.Mode.PAUSED:
		clock += dt
	if run.mode == CourierRun.Mode.FLYING:
		var direction := Vector2(
			float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)))
		if direction.length_squared() > 0.0:
			run.steer(run.ship + direction.normalized() * CourierRun.SHIP_SPEED * dt)
		var horizontal := run.target.x - run.ship.x
		bank_angle = lerpf(bank_angle, clampf(horizontal / 650.0, -0.22, 0.22), 9.0 * dt)
		run.step(dt)
		trail.append(run.ship + Vector2(0, 86))
		if trail.size() > 22:
			trail.pop_front()
		for star in stars:
			star.position.y = fposmod(star.position.y + dt * 72.0 * star.depth, 1920.0)
	if run.mode != CourierRun.Mode.PAUSED:
		hit_flash = maxf(0.0, hit_flash - dt * 2.0)
		toast_remaining = maxf(0.0, toast_remaining - dt)
		intro_remaining = maxf(0.0, intro_remaining - dt)
		for collection in [rings, floaters]:
			for i in range(collection.size() - 1, -1, -1):
				collection[i].life -= dt
				if collection[i].life <= 0.0:
					collection.remove_at(i)
		for i in range(particles.size() - 1, -1, -1):
			particles[i].life -= dt
			particles[i].position += particles[i].velocity * dt
			particles[i].velocity *= 1.0 - dt * 1.5
			if particles[i].life <= 0.0:
				particles.remove_at(i)
	if run.mode != last_mode:
		drag_id = -1
		if run.mode == CourierRun.Mode.WON or run.mode == CourierRun.Mode.LOST:
			if profile.record(run.score, run.delivered) != OK:
				push_warning("Record could not be saved on this device.")
			if run.mode == CourierRun.Mode.WON and profile.complete_level(run.level, run.shields) != OK:
				push_warning("Level progress could not be saved on this device.")
		last_mode = run.mode
	_sync_interface()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if run.mode == CourierRun.Mode.READY:
				_start_run()
			elif run.mode == CourierRun.Mode.WON or run.mode == CourierRun.Mode.LOST:
				_primary_action()
			elif run.mode == CourierRun.Mode.PAUSED:
				run.resume()
	if run.mode != CourierRun.Mode.FLYING:
		return
	if event is InputEventScreenTouch:
		if event.pressed and drag_id == -1 and event.position.y > 300.0:
			drag_id = event.index
			drag_origin = event.position
			ship_origin = run.ship
		elif not event.pressed and event.index == drag_id:
			drag_id = -1
			run.target = run.ship
	elif event is InputEventScreenDrag and event.index == drag_id:
		run.steer(ship_origin + (event.position - drag_origin) * 1.15)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y > 300.0 and drag_id == -1:
			drag_id = -2
			drag_origin = event.position
			ship_origin = run.ship
		elif not event.pressed and drag_id == -2:
			drag_id = -1
			run.target = run.ship
	elif event is InputEventMouseMotion and drag_id == -2:
		run.steer(ship_origin + (event.position - drag_origin) * 1.15)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_for_background()


func _pause_for_background() -> void:
	run.pause()
	drag_id = -1


func _start_run() -> void:
	run.begin(-1, clampi(profile.selected_level, 1, profile.unlocked_level))
	last_mode = run.mode
	drag_id = -1
	particles.clear()
	rings.clear()
	floaters.clear()
	trail.clear()
	intro_remaining = 2.4
	toast_remaining = 0.0
	hit_flash = 0.0
	bank_angle = 0.0
	_play_sound("start")
	_sync_interface()


func _go_home() -> void:
	run.mode = CourierRun.Mode.READY
	drag_id = -1
	particles.clear()
	rings.clear()
	floaters.clear()
	trail.clear()
	_sync_interface()


func _toggle_pause() -> void:
	if run.mode == CourierRun.Mode.FLYING:
		run.pause()
	elif run.mode == CourierRun.Mode.PAUSED:
		run.resume()
	drag_id = -1
	_sync_interface()


func _on_run_event(kind: String, at: Vector2, amount: int) -> void:
	match kind:
		"coin":
			_burst(at, GOLD, 10)
			floaters.append({"position": at, "text": "+20", "color": GOLD, "life": 0.8})
			_play_sound("coin")
		"delivery":
			var accent: Color = _level_data().accent
			_burst(at, accent, 58)
			rings.append({"position": at, "color": accent, "life": 1.0})
			floaters.append({"position": at - Vector2(0, 130), "text": "+150  ·  PAKK KOHAL", "color": GOLD, "life": 1.3})
			notification_text = "Pakk kohal!  +150"
			toast_remaining = 2.3
			_play_sound("delivery")
		"destination":
			notification_text = "Järgmine peatus läheneb"
			toast_remaining = 2.4
		"hit":
			_burst(at, Color("ffa78e"), 24)
			hit_flash = 0.5
			notification_text = "Kilp kaitses sind!"
			toast_remaining = 1.5
			_play_sound("hit")
		"repair":
			rings.append({"position": at, "color": MINT, "life": 0.8})
			_burst(at, MINT, 20)
			floaters.append({"position": at - Vector2(0, 75), "text": "+1 KILP", "color": MINT, "life": 1.6})
		"won":
			_burst(Vector2(540.0, 485.0), GOLD, 90)
			_play_sound("delivery")
		"lost":
			_play_sound("hit")


func _burst(at: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"position": at, "velocity": Vector2.from_angle(visual_rng.randf() * TAU) * visual_rng.randf_range(80.0, 350.0),
			"color": color, "life": visual_rng.randf_range(0.35, 1.0), "size": visual_rng.randf_range(3.0, 9.0)})


func _build_interface() -> void:
	var header := _layer("Header")
	_label(header, "KOSMOSEKULLER", Rect2(64, 72, 780, 80), 59, CREAM, true)
	region_label = _label(header, "VÄIKE LAEV. SUUR GALAKTIKA.", Rect2(68, 152, 760, 40), 23, MUTED)
	sound_button = _button(header, "♪", Rect2(824, 76, 78, 78), _toggle_sound, false)
	sound_button.tooltip_text = "Heli sisse / välja"
	sound_button.accessibility_name = "Heli sisse või välja"
	var pause_button := _button(header, "Ⅱ", Rect2(922, 76, 90, 78), _toggle_pause, false)
	pause_button.name = "PauseButton"
	pause_button.tooltip_text = "Paus (P / Esc)"
	pause_button.accessibility_name = "Peata lend"

	home = _layer("Home")
	_label(home, "VALI OMA JÄRGMINE SIHTKOHT", Rect2(130, 496, 820, 48), 23, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(home, "Galaktika ootab.", Rect2(120, 568, 840, 104), 68, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(home, "Kolm piirkonda. Viis pakki igas lennus.\nAva järgmine rada ja kogu tähti.", Rect2(150, 702, 780, 100), 28, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	home_region_label = _label(home, "", Rect2(180, 844, 720, 48), 27, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)
	home_description = _label(home, "", Rect2(140, 1132, 800, 40), 23, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(CourierLevels.COUNT):
		var level_number := i + 1
		var button := _button(home, "", Rect2(150 + i * 268, 1190, 244, 115), _select_level.bind(level_number), false)
		button.name = "Level%sButton" % level_number
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_stylebox_override("disabled", _style(Color("101c32"), Color("26374e"), 26))
		button.add_theme_color_override("font_disabled_color", Color("60718b"))
		level_buttons.append(button)
	var start := _button(home, "ALUSTA LENDU  →", Rect2(150, 1364, 780, 116), _start_run, true)
	start.name = "StartButton"
	_label(home, "Libista laeva. Väldi asteroide.\nPeatu planeedi maandumisringis.", Rect2(150, 1576, 780, 110), 27, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	record_label = _label(home, "", Rect2(150, 1770, 780, 48), 24, GOLD, false, HORIZONTAL_ALIGNMENT_CENTER)

	hud = _layer("FlightHUD")
	coin_label = _label(hud, "0", Rect2(134, 238, 170, 60), 36, GOLD, true)
	package_label = _label(hud, "PAKID 0/5", Rect2(360, 223, 360, 48), 27, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	score_label = _label(hud, "0 P", Rect2(797, 238, 200, 50), 28, MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT)
	hint_label = _label(hud, "LIBISTA JA JUHI", Rect2(90, 1670, 900, 64), 31, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	subhint_label = _label(hud, "Hiir või nooleklahvid töötavad ka", Rect2(70, 1740, 940, 45), 23, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label = _label(hud, "", Rect2(100, 1550, 880, 60), 30, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)

	overlay = _layer("Overlay")
	_label(overlay, "KOSMOSEPOST // LENNUPÄEVIK", Rect2(150, 621, 780, 46), 23, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)
	overlay_title = _label(overlay, "", Rect2(130, 726, 820, 100), 64, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	overlay_subtitle = _label(overlay, "", Rect2(180, 864, 720, 130), 30, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	overlay_stats = _label(overlay, "", Rect2(150, 1035, 780, 160), 39, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	primary_button = _button(overlay, "", Rect2(150, 1260, 780, 110), _primary_action, true)
	primary_button.name = "PrimaryButton"
	secondary_button = _button(overlay, "AVALEHELE", Rect2(150, 1400, 780, 100), _go_home, false)
	secondary_button.name = "HomeButton"


func _primary_action() -> void:
	if run.mode == CourierRun.Mode.PAUSED:
		run.resume()
	else:
		if run.mode == CourierRun.Mode.WON and run.level < CourierLevels.COUNT:
			_select_level(run.level + 1)
		_start_run()


func _select_level(level_number: int) -> void:
	if level_number < 1 or level_number > profile.unlocked_level:
		return
	if profile.select_level(level_number) != OK:
		push_warning("Level selection could not be saved on this device.")
	_sync_interface()


func _level_data() -> Dictionary:
	return CourierLevels.get_level(profile.selected_level if run.mode == CourierRun.Mode.READY else run.level)


func _sync_interface() -> void:
	if home == null:
		return
	var is_home := run.mode == CourierRun.Mode.READY
	var is_paused := run.mode == CourierRun.Mode.PAUSED
	var is_over := run.mode == CourierRun.Mode.WON or run.mode == CourierRun.Mode.LOST
	home.visible = is_home
	hud.visible = not is_home
	hud.modulate.a = 0.2 if is_paused or is_over else 1.0
	overlay.visible = is_paused or is_over
	var level_data := _level_data()
	region_label.text = "AVATUD PIIRKONDI %s/3  ·  VALI OMA RADA" % profile.unlocked_level if is_home else "TASE %02d  ·  %s" % [run.level, level_data.name.to_upper()]
	home_region_label.text = "%02d  //  %s" % [profile.selected_level, level_data.name.to_upper()]
	if home_region_label.get_theme_color("font_color") != level_data.accent:
		home_region_label.add_theme_color_override("font_color", level_data.accent)
	home_description.text = level_data.description
	for i in range(level_buttons.size()):
		var number := i + 1
		var unlocked := number <= profile.unlocked_level
		var stars_text := "★".repeat(profile.stars_for_level(number))
		level_buttons[i].disabled = not unlocked
		level_buttons[i].set_pressed_no_signal(number == profile.selected_level)
		level_buttons[i].text = "%02d  %s\n%s" % [number, stars_text, CourierLevels.get_level(number).name if unlocked else "LUKUS"]
		level_buttons[i].tooltip_text = "Läbi eelmine tase, et see piirkond avada" if not unlocked else CourierLevels.get_level(number).description
	sound_button.text = "♪" if profile.sound_enabled else "×"
	get_node("Header/PauseButton").visible = not is_home and not is_over and not is_paused
	record_label.text = "SINU REKORD  ·  %s P" % profile.best_score if profile.best_score > 0 else "LÕÕGASTAV LEND  ·  MÄNGI OMAS TEMPOS"
	coin_label.text = str(run.collected_coins)
	package_label.text = "PAKID %s/5" % run.delivered
	score_label.text = "%s P" % run.score
	toast_label.text = notification_text
	toast_label.modulate.a = minf(1.0, toast_remaining * 2.0)
	if run.destination_active:
		var can_land := run.destination.y >= 400.0
		hint_label.text = "LENDA MÄRGITUD RINGI" if can_land else "SIHTKOHT LÄHENEB"
		subhint_label.text = "Hoia laeva ringis, kuni pakk on üle antud" if can_land else "Hoia kurssi. Maandumisring avaneb kohe."
	else:
		hint_label.text = "LIBISTA JA JUHI"
		subhint_label.text = "Korja münte ja väldi asteroide"
	if is_paused:
		overlay_title.text = "Väike hingetõmme."
		overlay_subtitle.text = "Sinu pakid ootavad turvaliselt.\nJätka, kui oled valmis."
		overlay_stats.text = "%s / 5 PAKKI    ·    %s P" % [run.delivered, run.score]
		primary_button.text = "JÄTKA LENDU  →"
	elif is_over:
		var won := run.mode == CourierRun.Mode.WON
		overlay_title.text = "Kõik pakid kohal!" if won else "Uus lend ootab."
		overlay_subtitle.text = "Galaktika tänab sind.\nOled tõeline kosmosekuller!" if won else "Iga lend teeb sind osavamaks.\nProovime veel ühe korra?"
		overlay_stats.text = "%s P\n%s/5 pakki   ·   %s münti" % [run.score, run.delivered, run.collected_coins]
		if won:
			overlay_title.text = "Tase %02d läbitud!" % run.level
			overlay_subtitle.text = "%s on nüüd avatud!\nJärgmine seiklus ootab sind." % CourierLevels.get_level(run.level + 1).name if run.level < CourierLevels.COUNT else "Kõik kolm piirkonda on läbitud!\nPüüa igal rajal kolm tähte."
		primary_button.text = "JÄRGMINE TASE  →" if won and run.level < CourierLevels.COUNT else "LENDAME VEEL  →"


func _layer(layer_name: String) -> Control:
	var node := Control.new()
	node.name = layer_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(node)
	return node


func _label(parent: Control, text: String, rect: Rect2, size_px: int, color: Color, bold: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", BOLD if bold else FONT)
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node


func _button(parent: Control, text: String, rect: Rect2, action: Callable, primary: bool) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", BOLD)
	node.add_theme_font_size_override("font_size", 31)
	node.add_theme_color_override("font_color", Color("122e37") if primary else CREAM)
	node.add_theme_color_override("font_hover_color", Color("122e37") if primary else CREAM)
	node.add_theme_color_override("font_pressed_color", Color("122e37") if primary else CREAM)
	node.add_theme_stylebox_override("normal", _style(MINT if primary else Color("172640"), Color("b7ffe4") if primary else Color("38506d"), 26))
	node.add_theme_stylebox_override("hover", _style(Color("bfffe8") if primary else Color("263c58"), MINT, 26))
	node.add_theme_stylebox_override("pressed", _style(Color("7bdbb7") if primary else Color("304966"), MINT, 26))
	var focus := _style(Color.TRANSPARENT, GOLD, 26)
	focus.set_border_width_all(4)
	node.add_theme_stylebox_override("focus", focus)
	node.pressed.connect(action)
	parent.add_child(node)
	return node


func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


func _draw() -> void:
	var theme := _level_data()
	draw_texture_rect(SPACE, Rect2(Vector2.ZERO, CourierRun.WORLD), false, theme.sky_tint)
	for star in stars:
		var alpha: float = (0.3 + star.depth * 0.5) * (0.8 + sin(clock * 0.9 + star.phase) * 0.2)
		var color := Color(0.7, 0.85, 1.0, alpha)
		draw_circle(star.position, 1.0 + star.depth * 1.8, color, true, -1.0, true)
		if star.depth > 0.95:
			_cross(star.position, 7.0, Color(0.85, 0.95, 1.0, alpha))
	if run.mode == CourierRun.Mode.READY:
		_draw_home()
	else:
		_draw_flight()
		# Keep moving obstacles behind a quiet header so its text stays readable.
		_panel(Rect2(40, 50, 1000, 145), Color(0.04, 0.07, 0.145, 0.96), Color.TRANSPARENT, 24)
	for ring in rings:
		var tint: Color = ring.color
		tint.a = maxf(0.0, ring.life * 0.7)
		draw_arc(ring.position, 35.0 + (1.0 - ring.life) * 240.0, 0, TAU, 72, tint, 4.0 * ring.life, true)
	for particle in particles:
		var color: Color = particle.color
		color.a = clampf(particle.life * 1.8, 0.0, 1.0)
		draw_circle(particle.position, particle.size * minf(1.0, particle.life * 3.0), color, true, -1.0, true)
	if run.mode == CourierRun.Mode.PAUSED or run.mode == CourierRun.Mode.WON or run.mode == CourierRun.Mode.LOST:
		draw_rect(Rect2(Vector2.ZERO, CourierRun.WORLD), Color(0.02, 0.04, 0.11, 0.76))
		_panel(Rect2(90, 560, 900, 1010), Color("111e36"), Color("344e68"), 48)
		var icon_color := GOLD if run.mode == CourierRun.Mode.WON else MINT
		if run.mode == CourierRun.Mode.WON:
			for i in range(3):
				_draw_star(Vector2(410 + i * 130, 494 - (28 if i == 1 else 0)), 42.0, GOLD if i < run.shields else Color("35475e"))
		else:
			_cross(Vector2(540, 518), 28.0, icon_color)
	if run.mode == CourierRun.Mode.FLYING:
		for floater in floaters:
			var tint: Color = floater.color
			tint.a = minf(1.0, floater.life * 2.0)
			_center_text(floater.text, floater.position - Vector2(0, (1.6 - floater.life) * 58.0), 30, tint)
		if intro_remaining > 0.0:
			var opacity := minf(1.0, intro_remaining * 2.0)
			_panel(Rect2(200, 437, 680, 145), Color(0.045, 0.09, 0.16, opacity * 0.95), Color(theme.accent, opacity * 0.5), 30)
			_center_text("TASE %02d" % run.level, Vector2(540, 486), 23, Color(theme.accent, opacity))
			_center_text(theme.name, Vector2(540, 544), 39, Color(CREAM, opacity))
	if hit_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, CourierRun.WORLD), Color(1.0, 0.37, 0.38, hit_flash * 0.24))


func _draw_home() -> void:
	draw_arc(Vector2(540, 1010), 638.0, -2.8, 0.8, 120, Color(0.4, 0.7, 0.8, 0.13), 2.0, true)
	draw_arc(Vector2(540, 1010), 700.0, -1.0, 2.4, 120, Color(0.4, 0.7, 0.8, 0.08), 2.0, true)
	_draw_planet(Vector2(1005, 445), 185.0, 0.18, _level_data().planet_tint)
	_draw_planet(Vector2(0, 1570), 155.0, -0.24, Color("f5b1a6"))
	_panel(Rect2(90, 455, 900, 1080), Color(0.06, 0.105, 0.19, 0.94), Color("2b405c"), 48)
	draw_arc(Vector2(540, 1013), 111.0, 0.0, TAU, 80, Color(0.6, 0.96, 0.82, 0.15), 2.0, true)
	_draw_ship(Vector2(540, 998 + sin(clock * 1.8) * 7.0), 0.62, sin(clock * 1.3) * 0.035, false)
	_cross(Vector2(330, 990), 13.0, GOLD)
	_cross(Vector2(745, 1060), 9.0, MINT)
	_draw_parcel(Vector2(841, 393), 0.75, clock * 0.1)


func _draw_flight() -> void:
	# Faraway planets are decoration, deliberately dimmer than active targets.
	_draw_planet(Vector2(-70, 1340 + sin(clock * 0.15) * 35.0), 205.0, 0.3, Color(0.65, 0.49, 0.66, 0.6))
	if run.destination_active:
		_draw_destination()
	else:
		draw_arc(Vector2(1005, 695), 73.0, 0.0, TAU, 50, Color(0.6, 0.8, 0.95, 0.12), 2.0, true)
		draw_circle(Vector2(1005, 695), 43.0, Color("1b2c4c"), true, -1.0, true)
	for coin in run.coins:
		_draw_coin(coin.position)
	for rock in run.asteroids:
		draw_set_transform(rock.position, rock.angle, Vector2.ONE * rock.radius / 150.0)
		draw_texture_rect(ASTEROID, Rect2(-150, -150, 300, 300), false, Color("e0c7e8") if rock.variant == 1 else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	# Keep the ship visible while protected; the shield arc conveys invulnerability.
	for i in range(1, trail.size()):
		var tint: Color = _level_data().accent
		tint.a = float(i) / trail.size() * 0.17
		draw_line(trail[i - 1], trail[i], tint, 3.0 + float(i) / trail.size() * 9.0, true)
	var shake := Vector2(sin(clock * 71.0), cos(clock * 59.0)) * hit_flash * 10.0
	_draw_ship(run.ship + shake, 0.66, bank_angle, run.invincible_for > 0.0)
	_draw_hud()


func _draw_destination() -> void:
	var pad := run.dock_position()
	if run.destination.y >= 400.0:
		# Small navigation dots lead to the actual interactive delivery pad.
		var from := run.ship - Vector2(0, 80)
		var distance := from.distance_to(pad)
		if distance > 140.0:
			var count := mini(12, int(distance / 55.0))
			for i in range(1, count):
				var t := float(i) / count
				var p := from.lerp(pad, t)
				p.x += sin(t * PI) * 35.0
				draw_circle(p, 3.5, Color(0.6, 0.96, 0.83, 0.18 + t * 0.35), true, -1.0, true)
	_draw_planet(run.destination, 177.0, 0.0, _level_data().planet_tint)
	var pulse := 1.0 + sin(clock * 3.3) * 0.04
	draw_circle(pad, CourierRun.DOCK_RADIUS * pulse + 20.0, Color(0.45, 1.0, 0.77, 0.035), true, -1.0, true)
	draw_circle(pad, CourierRun.DOCK_RADIUS * pulse, Color(0.45, 1.0, 0.77, 0.07), true, -1.0, true)
	draw_arc(pad, CourierRun.DOCK_RADIUS, 0.0, TAU, 80, Color(0.6, 0.96, 0.83, 0.6), 3.0, true)
	for i in range(4):
		var angle := i * PI / 2.0 + clock * 0.12
		draw_arc(pad, CourierRun.DOCK_RADIUS + 12.0, angle, angle + 0.23, 12, MINT, 6.0, true)
	if run.dock_progress > 0.0:
		draw_arc(pad, CourierRun.DOCK_RADIUS + 23.0, -PI / 2.0, -PI / 2.0 + TAU * minf(run.dock_progress, 1.0), 80, GOLD, 9.0, true)
	_draw_parcel(pad, 0.55, 0.0)
	if run.dock_progress > 0.0:
		_center_text("ANNAN PAKKI ÜLE…", pad + Vector2(0, 161), 23, GOLD)
	var label_position := Vector2(run.destination.x, maxf(370.0, run.destination.y - 211.0))
	_panel(Rect2(label_position - Vector2(110, 30), Vector2(220, 60)), MINT, MINT, 24)
	_center_text("SIHTKOHT", label_position + Vector2(0, 9), 23, Color("183b42"))


func _draw_hud() -> void:
	_panel(Rect2(60, 211, 960, 112), Color(0.055, 0.1, 0.18, 0.94), Color("2b405c"), 30)
	draw_line(Vector2(90, 332), Vector2(990, 332), Color("263c56"), 5.0, true)
	var progress := (float(run.delivered) + run.dock_progress) / CourierRun.DELIVERY_GOAL
	if progress > 0.0:
		draw_line(Vector2(90, 332), Vector2(90 + 900 * progress, 332), _level_data().accent, 5.0, true)
	draw_line(Vector2(304, 235), Vector2(304, 298), Color("2c405b"), 2.0, true)
	draw_line(Vector2(774, 235), Vector2(774, 298), Color("2c405b"), 2.0, true)
	_draw_coin(Vector2(102, 265), 0.68)
	for i in range(CourierRun.DELIVERY_GOAL):
		var color := MINT if i < run.delivered else Color("334762")
		var at := Vector2(436 + i * 52, 292)
		_panel(Rect2(at - Vector2(14, 12), Vector2(28, 24)), color, color, 5)
		draw_line(at + Vector2(0, -12), at + Vector2(0, 12), Color("152e3d"), 4.0, true)
	_panel(Rect2(170, 1645, 740, 157), Color(0.05, 0.09, 0.17, 0.9), Color("283d59"), 34)
	for i in range(CourierRun.MAX_SHIELDS):
		var at := Vector2(450 + i * 90, 1854)
		var color := MINT if i < run.shields else Color("34455f")
		var shape := PackedVector2Array([at + Vector2(0, -24), at + Vector2(20, -15), at + Vector2(17, 11), at + Vector2(0, 25), at + Vector2(-17, 11), at + Vector2(-20, -15), at + Vector2(0, -24)])
		draw_polyline(shape, color, 4.0, true)
		if i < run.shields:
			var inside := PackedVector2Array([at + Vector2(0, -14), at + Vector2(11, -9), at + Vector2(9, 6), at + Vector2(0, 14), at + Vector2(-9, 6), at + Vector2(-11, -9)])
			draw_colored_polygon(inside, Color(0.6, 0.96, 0.83, 0.24))


func _draw_ship(at: Vector2, ship_scale: float, angle: float, shielded: bool) -> void:
	draw_set_transform(at, angle, Vector2.ONE * ship_scale)
	var flame := 1.0 + sin(clock * 38.0) * 0.12
	var outer := PackedVector2Array([Vector2(-18, 112), Vector2(-14, 165), Vector2(0, 222 * flame), Vector2(14, 165), Vector2(18, 112)])
	draw_colored_polygon(outer, Color(1.0, 0.54, 0.4, 0.48))
	var inner := PackedVector2Array([Vector2(-10, 113), Vector2(-7, 161), Vector2(0, 191 * flame), Vector2(7, 161), Vector2(10, 113)])
	draw_colored_polygon(inner, Color("fff1b4"))
	for x in [-78.0, 78.0]:
		draw_line(Vector2(x, 100), Vector2(x, 128.0 + 20.0 * flame), Color("9debe3"), 8.0, true)
	draw_texture_rect(SHIP, Rect2(-120, -160, 240, 320), false)
	if shielded:
		draw_arc(Vector2.ZERO, 153.0, -2.8, 0.15, 60, Color(0.6, 0.96, 0.83, 0.32), 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_planet(at: Vector2, radius: float, angle: float, color: Color) -> void:
	draw_set_transform(at, angle, Vector2.ONE)
	draw_texture_rect(PLANET, Rect2(-radius * 1.2, -radius * 1.2, radius * 2.4, radius * 2.4), false, color)
	draw_set_transform(Vector2.ZERO)


func _draw_coin(at: Vector2, coin_scale: float = 1.0) -> void:
	draw_circle(at, 35.0 * coin_scale, Color(1.0, 0.79, 0.4, 0.045), true, -1.0, true)
	draw_circle(at, 26.0 * coin_scale, Color("cc873f"), true, -1.0, true)
	draw_circle(at - Vector2(0, 2) * coin_scale, 23.0 * coin_scale, GOLD, true, -1.0, true)
	draw_arc(at - Vector2(0, 2) * coin_scale, 20.0 * coin_scale, 0.0, TAU, 32, Color("fff0ae"), 2.5 * coin_scale, true)
	var points := PackedVector2Array()
	for i in range(10):
		var radius := (13.0 if i % 2 == 0 else 6.0) * coin_scale
		points.append(at + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * radius - Vector2(0, 2) * coin_scale)
	draw_colored_polygon(points, CREAM)


func _draw_parcel(at: Vector2, parcel_scale: float, angle: float) -> void:
	draw_set_transform(at, angle, Vector2.ONE * parcel_scale)
	var box := PackedVector2Array([Vector2(0, -35), Vector2(42, -17), Vector2(42, 25), Vector2(0, 45), Vector2(-42, 25), Vector2(-42, -17)])
	draw_colored_polygon(box, GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 3), Vector2(42, -17), Vector2(42, 25), Vector2(0, 45)]), Color("e5ac55"))
	draw_polyline(PackedVector2Array([Vector2(-42, -17), Vector2(0, 3), Vector2(42, -17)]), CREAM, 3.0, true)
	draw_line(Vector2(0, 3), Vector2(0, 44), Color("fff0ac"), 4.0, true)
	draw_line(Vector2(-20, -27), Vector2(21, -8), Color("fff0ac"), 9.0, true)
	draw_line(Vector2(21, -8), Vector2(21, 34), Color("fff0ac"), 9.0, true)
	draw_set_transform(Vector2.ZERO)


func _panel(rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	draw_style_box(_style(fill, border, radius), rect)


func _cross(at: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius * 0.22, -radius * 0.22), at + Vector2(radius, 0), at + Vector2(radius * 0.22, radius * 0.22), at + Vector2(0, radius), at + Vector2(-radius * 0.22, radius * 0.22), at + Vector2(-radius, 0), at + Vector2(-radius * 0.22, -radius * 0.22)]), color)


func _draw_star(at: Vector2, radius: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		points.append(at + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * radius * (1.0 if i % 2 == 0 else 0.46))
	draw_colored_polygon(points, tint)


func _center_text(text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var width := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(BOLD, baseline - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _toggle_sound() -> void:
	profile.sound_enabled = not profile.sound_enabled
	if not profile.sound_enabled:
		sound_player.stop()
	if profile.save() != OK:
		push_warning("Sound preference could not be saved on this device.")
	_sync_interface()


func _play_sound(sound_name: String) -> void:
	if profile.sound_enabled and sounds.has(sound_name):
		sound_player.stream = sounds[sound_name]
		sound_player.play()


func _make_sounds() -> void:
	# Short synthesized chimes: no downloads, audio permissions or licensed clips.
	for sound_name in ["coin", "delivery", "hit", "start"]:
		var notes: Array
		match sound_name:
			"coin": notes = [880.0, 1174.66]
			"delivery": notes = [523.25, 659.25, 783.99, 1046.5]
			"hit": notes = [196.0, 146.83]
			_: notes = [392.0, 523.25, 659.25]
		var samples_per_note := 3000
		var data := PackedByteArray()
		data.resize(notes.size() * samples_per_note * 2)
		for n in range(notes.size()):
			for i in range(samples_per_note):
				var t := float(i) / 22050.0
				var envelope := minf(1.0, float(i) / 100.0) * pow(1.0 - float(i) / samples_per_note, 2.0)
				var value := int(sin(t * TAU * notes[n]) * envelope * 15000.0)
				data.encode_s16((n * samples_per_note + i) * 2, value)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		sounds[sound_name] = stream
