extends Control
## All artwork and hit areas use a 1080 × 1920 logical portrait canvas.

const SPACE := preload("res://assets/space.svg")
const SHIP := preload("res://assets/ship.svg")
const PLANET := preload("res://assets/planet.svg")
const ASTEROID := preload("res://assets/asteroid.svg")
const FONT := preload("res://assets/fonts/DejaVuSans.ttf")
const BOLD := preload("res://assets/fonts/DejaVuSans-Bold.ttf")
const CJK_FONT := preload("res://assets/fonts/CourierCJKUI.otf")
const DEVANAGARI_FONT := preload("res://assets/fonts/NotoDevanagari.ttf")
const THAI_FONT := preload("res://assets/fonts/NotoThai.ttf")
const MINT := Color("9af5d3")
const CREAM := Color("fff4d9")
const MUTED := Color("97aac6")
const GOLD := Color("ffcf6d")
const SHIPS := {
	"courier": SHIP,
	"aurora": preload("res://assets/aurora.svg"),
	"comet": preload("res://assets/comet.svg"),
	"pumpkin": preload("res://assets/pumpkin.svg"),
	"nightwing": preload("res://assets/nightwing.svg"),
}

var run := CourierRun.new()
var profile: CourierProfile
var debris := CourierDebris.new()
var localized_nodes: Array[Control] = []
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
var menu_screen := "home"
var map_page := 0
var level_map: Control
var shop: Control
var preview: Control
var wallet_label: Label
var map_title: Label
var map_summary: Label
var map_previous: Button
var map_next: Button
var shop_buttons: Dictionary = {}
var menu_feedback: Label
var fire_button: Button
var preview_id := "nightwing"
var home_progress: Label
var halloween_label: Button
var language_menu: Control
var language_buttons: Dictionary = {}
var season_pass: Control
var pass_page := 0
var pass_progress_label: Label
var pass_rows: Array[Label] = []
var pass_requirements: Array[Label] = []
var pass_buttons: Array[Button] = []
var pass_previous: Button
var pass_next: Button


func _ready() -> void:
	profile = CourierProfile.new()
	if not FileAccess.file_exists(profile.storage_path):
		profile.language = CourierText.device_language(OS.get_locale())
	for font: Font in [FONT, BOLD]:
		font.fallbacks = [CJK_FONT, DEVANAGARI_FONT, THAI_FONT]
	CourierText.set_language(profile.language)
	visual_rng.seed = 774
	for i in range(145):
		stars.append({"position": Vector2(visual_rng.randf_range(20.0, 1060.0), visual_rng.randf_range(0.0, 1920.0)),
			"depth": visual_rng.randf_range(0.2, 1.0), "phase": visual_rng.randf_range(0.0, TAU)})
	run.event.connect(_on_run_event)
	run.asteroid_shattered.connect(_on_asteroid_shattered)
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -13.0
	add_child(sound_player)
	_make_sounds()
	_build_interface()
	for node in localized_nodes:
		_text(node, _t(node.get_meta("loc_key")), true)
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
		debris.step(dt)
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
		elif event.keycode == KEY_SPACE and run.mode == CourierRun.Mode.FLYING:
			_toggle_fire()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if run.mode == CourierRun.Mode.READY and menu_screen in ["home", "map"]:
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
	menu_screen = "home"
	run.begin(-1, clampi(profile.selected_level, 1, profile.unlocked_level))
	run.auto_fire = profile.auto_fire
	last_mode = run.mode
	drag_id = -1
	debris.clear()
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
	menu_screen = "home"
	run.mode = CourierRun.Mode.READY
	last_mode = run.mode
	drag_id = -1
	debris.clear()
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
			_reward_flight(amount, 2)
			_burst(at, GOLD, 10)
			floaters.append({"position": at, "text": _t("coin_popup"), "color": GOLD, "life": 0.8})
			_play_sound("coin")
		"delivery":
			var accent: Color = _level_data().accent
			_burst(at, accent, 58)
			rings.append({"position": at, "color": accent, "life": 1.0})
			floaters.append({"position": at - Vector2(0, 130), "text": _t("delivery_popup"), "color": GOLD, "life": 1.3})
			notification_text = _t("delivery_toast")
			toast_remaining = 2.3
			_reward_flight(2, 25)
			_play_sound("delivery")
		"destination":
			notification_text = _t("destination_toast")
			toast_remaining = 2.4
		"hit":
			_burst(at, Color("ffa78e"), 24)
			hit_flash = 0.5
			notification_text = _t("hit_toast")
			toast_remaining = 1.5
			_play_sound("hit")
		"repair":
			rings.append({"position": at, "color": MINT, "life": 0.8})
			_burst(at, MINT, 20)
			floaters.append({"position": at - Vector2(0, 75), "text": _t("shield_popup"), "color": MINT, "life": 1.6})
		"asteroid_hit":
			_burst(at, Color("b5d8ef"), 5)
		"asteroid_destroyed":
			_burst(at, GOLD if amount > 0 else MUTED, 12)
			rings.append({"position": at, "color": GOLD if amount > 0 else MINT, "life": 0.5})
			floaters.append({"position": at, "text": _t("rock_popup", [amount]) if amount > 0 else "+10 P", "color": GOLD, "life": 1.0})
			_reward_flight(amount, 5)
			_play_sound("rock")
		"won":
			_reward_flight(0, 50)
			_burst(Vector2(540.0, 485.0), GOLD, 90)
			_play_sound("delivery")
		"lost":
			_play_sound("hit")


func _on_asteroid_shattered(at: Vector2, radius: float, variant: int) -> void:
	debris.burst(at, radius, variant)


func _burst(at: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"position": at, "velocity": Vector2.from_angle(visual_rng.randf() * TAU) * visual_rng.randf_range(80.0, 350.0),
			"color": color, "life": visual_rng.randf_range(0.35, 1.0), "size": visual_rng.randf_range(3.0, 9.0)})


func _build_interface() -> void:
	var header := _layer("Header")
	_label(header, "game_title", Rect2(64, 72, 630, 80), 59, CREAM, true)
	region_label = _label(header, "subtitle", Rect2(68, 152, 760, 40), 23, MUTED)
	sound_button = _button(header, "♪", Rect2(824, 76, 78, 78), _toggle_sound, false)
	var language_button := _button(header, "文A", Rect2(716, 76, 88, 78), _show_menu.bind("languages"), false)
	language_button.name = "LanguageButton"
	_font_size(language_button, 26)
	sound_button.tooltip_text = _t("sound_tip")
	sound_button.accessibility_name = _t("sound_tip")
	var pause_button := _button(header, "Ⅱ", Rect2(922, 76, 90, 78), _toggle_pause, false)
	pause_button.name = "PauseButton"
	pause_button.tooltip_text = _t("pause_tip")
	pause_button.accessibility_name = _t("pause_tip")

	home = _layer("Home")
	_label(home, "home_tag", Rect2(130, 496, 820, 48), 23, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(home, "home_title", Rect2(120, 568, 840, 104), 68, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	home_progress = _label(home, "", Rect2(150, 702, 780, 100), 28, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	home_region_label = _label(home, "", Rect2(180, 844, 720, 48), 27, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)
	home_description = _label(home, "", Rect2(140, 1132, 800, 45), 26, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	var map_button := _button(home, "levels", Rect2(150, 1190, 376, 110), _show_menu.bind("map"), false)
	map_button.name = "MapButton"
	var shop_button := _button(home, "shop", Rect2(554, 1190, 376, 110), _show_menu.bind("shop"), false)
	shop_button.name = "ShopButton"
	var start := _button(home, "start", Rect2(150, 1364, 780, 116), _start_run, true)
	start.name = "StartButton"
	halloween_label = _button(home, "", Rect2(120, 1580, 840, 130), _show_menu.bind("pass"), false)
	halloween_label.name = "SeasonButton"
	_font_size(halloween_label, 27)
	halloween_label.add_theme_color_override("font_color", GOLD)
	record_label = _label(home, "", Rect2(150, 1770, 780, 48), 24, GOLD, false, HORIZONTAL_ALIGNMENT_CENTER)

	level_map = _layer("LevelMap")
	_button(level_map, "back_menu", Rect2(80, 260, 260, 84), _show_menu.bind("home"), false)
	map_title = _label(level_map, "", Rect2(100, 360, 880, 70), 37, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(10):
		var button := _button(level_map, "", Rect2(100 + (i % 2) * 460, 470 + int(i / 2) * 155, 420, 132), _choose_map_slot.bind(i), false)
		button.name = "Level%sButton" % (i + 1)
		button.toggle_mode = true
		_font_size(button, 28)
		button.add_theme_stylebox_override("disabled", _style(Color("101c32"), Color("26374e"), 26))
		button.add_theme_color_override("font_disabled_color", Color("60718b"))
		level_buttons.append(button)
	map_summary = _label(level_map, "", Rect2(100, 1320, 880, 110), 29, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)
	var map_start := _button(level_map, "map_start", Rect2(100, 1490, 880, 110), _start_run, true)
	map_start.name = "StartButton"
	map_previous = _button(level_map, "previous", Rect2(100, 1690, 420, 90), _change_map_page.bind(-1), false)
	map_previous.name = "PreviousButton"
	map_next = _button(level_map, "next", Rect2(560, 1690, 420, 90), _change_map_page.bind(1), false)
	map_next.name = "NextButton"

	shop = _layer("Shop")
	_button(shop, "back_menu", Rect2(80, 260, 260, 84), _show_menu.bind("home"), false)
	_label(shop, "shop_title", Rect2(80, 360, 920, 70), 39, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(shop, "shop_subtitle", Rect2(80, 432, 920, 42), 23, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	for index in range(CourierCatalogue.SHOP_IDS.size()):
		var id: String = CourierCatalogue.SHOP_IDS[index]
		var data := CourierCatalogue.item(id)
		var at := Vector2(100 + (index % 2) * 460, 510 + int(index / 2) * 395)
		_label(shop, "item_" + id, Rect2(at.x + 12, at.y + 167, 396, 42), 29, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
		var detail := "ship_skin" if data.kind == "ship" else "trail"
		if data.access == "season_gift":
			detail = "gift_detail"
		elif data.access == "premium":
			detail = "paid_detail"
		_label(shop, detail, Rect2(at.x + 10, at.y + 215, 400, 40), 18, data.color, true, HORIZONTAL_ALIGNMENT_CENTER)
		var button := _button(shop, "", Rect2(at.x + 25, at.y + 277, 370, 72), _shop_action.bind(id), false)
		button.name = "Item_" + id
		_font_size(button, 25)
		shop_buttons[id] = button
	_label(shop, "season_dates", Rect2(80, 1705, 920, 42), 21, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	var original_ship := _button(shop, "original_ship", Rect2(100, 1765, 420, 64), _shop_action.bind("courier"), false)
	original_ship.name = "OriginalShipButton"
	_font_size(original_ship, 23)
	var original_trail := _button(shop, "original_trail", Rect2(560, 1765, 420, 64), _shop_action.bind("mint_trail"), false)
	original_trail.name = "OriginalTrailButton"
	_font_size(original_trail, 23)

	preview = _layer("Preview")
	_button(preview, "back_shop", Rect2(80, 260, 260, 84), _show_menu.bind("shop"), false)
	_label(preview, "preview_tag", Rect2(100, 470, 880, 50), 25, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(preview, "item_nightwing", Rect2(100, 550, 880, 110), 70, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(preview, "preview_desc", Rect2(100, 686, 880, 60), 29, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_label(preview, "preview_title", Rect2(100, 1200, 880, 70), 29, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(preview, "preview_note", Rect2(100, 1290, 880, 120), 28, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_button(preview, "return_shop", Rect2(150, 1500, 780, 110), _show_menu.bind("shop"), true)

	language_menu = _layer("Languages")
	_button(language_menu, "back_menu", Rect2(80, 260, 260, 84), _show_menu.bind("home"), false)
	_label(language_menu, "language_title", Rect2(80, 360, 920, 70), 39, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(language_menu, "language_note", Rect2(80, 442, 920, 58), 25, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	var language_index := 0
	for code in CourierText.LANGUAGES:
		var button := _button(language_menu, CourierText.LANGUAGES[code], Rect2(80 + (language_index % 3) * 312, 560 + int(language_index / 3) * 146, 296, 116), _choose_language.bind(code), false)
		button.name = "Language_" + code
		button.toggle_mode = true
		_font_size(button, 27)
		language_buttons[code] = button
		language_index += 1

	season_pass = _layer("BattlePass")
	_button(season_pass, "back_menu", Rect2(80, 260, 260, 84), _show_menu.bind("home"), false)
	_label(season_pass, "pass_title", Rect2(80, 360, 920, 70), 42, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(season_pass, "pass_guide", Rect2(80, 444, 920, 50), 26, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	pass_progress_label = _label(season_pass, "", Rect2(80, 515, 920, 55), 29, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(season_pass, "season_dates", Rect2(100, 601, 880, 34), 18, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	for slot in range(5):
		var y := 640 + slot * 174
		pass_rows.append(_label(season_pass, "", Rect2(190, y + 18, 520, 58), 32, CREAM, true))
		pass_requirements.append(_label(season_pass, "", Rect2(190, y + 82, 510, 40), 23, MUTED))
		var button := _button(season_pass, "", Rect2(735, y + 42, 230, 76), _claim_pass_slot.bind(slot), false)
		button.name = "Tier%sButton" % (slot + 1)
		_font_size(button, 23)
		pass_buttons.append(button)
	pass_previous = _button(season_pass, "previous", Rect2(100, 1530, 420, 86), _change_pass_page.bind(-1), false)
	pass_previous.name = "PreviousButton"
	pass_next = _button(season_pass, "next", Rect2(560, 1530, 420, 86), _change_pass_page.bind(1), false)
	pass_next.name = "NextButton"
	_label(season_pass, "pass_premium", Rect2(100, 1655, 880, 60), 31, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(season_pass, "pass_premium_note", Rect2(100, 1725, 880, 90), 24, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)

	var menu_chrome := _layer("MenuChrome")
	wallet_label = _label(menu_chrome, "", Rect2(380, 260, 610, 84), 31, GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
	menu_feedback = _label(menu_chrome, "", Rect2(70, 1835, 940, 60), 24, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)

	hud = _layer("FlightHUD")
	coin_label = _label(hud, "0", Rect2(134, 238, 170, 60), 36, GOLD, true)
	package_label = _label(hud, "PAKID 0/5", Rect2(360, 223, 360, 48), 27, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	score_label = _label(hud, "0 P", Rect2(797, 238, 200, 50), 28, MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT)
	hint_label = _label(hud, "steer", Rect2(70, 1660, 675, 64), 27, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	subhint_label = _label(hud, "Hiir või nooleklahvid töötavad ka", Rect2(65, 1727, 680, 58), 21, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	fire_button = _button(hud, "", Rect2(770, 1663, 240, 122), _toggle_fire, false)
	fire_button.name = "FireButton"
	_font_size(fire_button, 24)
	toast_label = _label(hud, "", Rect2(100, 1550, 880, 60), 30, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)

	overlay = _layer("Overlay")
	_label(overlay, "log_tag", Rect2(150, 621, 780, 46), 23, MINT, true, HORIZONTAL_ALIGNMENT_CENTER)
	overlay_title = _label(overlay, "", Rect2(130, 726, 820, 100), 64, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	overlay_subtitle = _label(overlay, "", Rect2(180, 864, 720, 130), 30, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	overlay_stats = _label(overlay, "", Rect2(150, 1035, 780, 160), 39, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	primary_button = _button(overlay, "", Rect2(150, 1260, 780, 110), _primary_action, true)
	primary_button.name = "PrimaryButton"
	secondary_button = _button(overlay, "home", Rect2(150, 1400, 780, 100), _go_home, false)
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


func _show_menu(screen: String) -> void:
	if run.mode != CourierRun.Mode.READY:
		return
	menu_screen = screen
	menu_feedback.text = ""
	if screen == "map":
		map_page = int((profile.selected_level - 1) / 10)
	_sync_interface()


func _change_map_page(direction: int) -> void:
	map_page = clampi(map_page + direction, 0, 9)
	_sync_interface()


func _choose_map_slot(slot: int) -> void:
	_select_level(map_page * 10 + slot + 1)


func _shop_action(id: String) -> void:
	var data := CourierCatalogue.item(id)
	if data.access == "premium":
		preview_id = id
		_show_menu("preview")
		return
	var already_owned := profile.owned_items.has(id)
	var result := profile.equip_item(id) if already_owned else profile.acquire_item(id)
	if result == OK:
		_text(menu_feedback, _t("using_item", [data.name]))
		_play_sound("coin")
	elif result == ERR_UNAUTHORIZED:
		_text(menu_feedback, _t("need_coins", [maxi(0, int(data.price) - profile.wallet)]))
	elif result == ERR_UNAVAILABLE:
		_text(menu_feedback, _t("gift_dates"))
	else:
		_text(menu_feedback, _t("save_error"))
	_sync_interface()


func _toggle_fire() -> void:
	profile.auto_fire = not profile.auto_fire
	run.auto_fire = profile.auto_fire
	if profile.save() != OK:
		push_warning("Fire preference could not be saved on this device.")
	_sync_interface()


func _reward_flight(coins: int, xp: int) -> void:
	if profile.award_flight(coins, xp) != OK:
		notification_text = _t("coin_save_error")
		toast_remaining = 3.0
		push_warning("Earned flight rewards could not be saved on this device.")


func _choose_language(code: String) -> void:
	if profile.set_language(code) != OK:
		_text(menu_feedback, _t("save_error"))
		return
	CourierText.set_language(profile.language)
	for node in localized_nodes:
		_text(node, _t(node.get_meta("loc_key")))
	_show_menu("home")


func _change_pass_page(direction: int) -> void:
	pass_page = clampi(pass_page + direction, 0, 1)
	_sync_interface()


func _claim_pass_slot(slot: int) -> void:
	var tier := pass_page * 5 + slot + 1
	var reward := CourierSeasonPass.reward(tier)
	var re_equip := profile.pass_claimed.has(tier) and not str(reward.item).is_empty()
	var result := profile.equip_item(reward.item) if re_equip else profile.claim_pass_reward(tier)
	_text(menu_feedback, _t("reward_claimed") if result == OK else _t("save_error"))
	if result == OK:
		_play_sound("delivery")
	_sync_interface()


func _sync_interface() -> void:
	if home == null:
		return
	var is_home := run.mode == CourierRun.Mode.READY
	var is_paused := run.mode == CourierRun.Mode.PAUSED
	var is_over := run.mode == CourierRun.Mode.WON or run.mode == CourierRun.Mode.LOST
	home.visible = is_home and menu_screen == "home"
	level_map.visible = is_home and menu_screen == "map"
	shop.visible = is_home and menu_screen == "shop"
	preview.visible = is_home and menu_screen == "preview"
	language_menu.visible = is_home and menu_screen == "languages"
	season_pass.visible = is_home and menu_screen == "pass"
	get_node("MenuChrome").visible = is_home
	get_node("Header/LanguageButton").visible = is_home
	get_node("Header/LanguageButton").tooltip_text = _t("language_tip")
	sound_button.tooltip_text = _t("sound_tip")
	sound_button.accessibility_name = _t("sound_tip")
	get_node("Header/PauseButton").tooltip_text = _t("pause_tip")
	get_node("Header/PauseButton").accessibility_name = _t("pause_tip")
	hud.visible = not is_home
	hud.modulate.a = 0.2 if is_paused or is_over else 1.0
	overlay.visible = is_paused or is_over
	var level_data := _level_data()
	_text(region_label, _t("subtitle") if is_home else _t("level_region", [run.level, level_data.name]))
	_text(wallet_label, _t("wallet", [profile.wallet]))
	_text(home_progress, _t("home_progress", [profile.unlocked_level]))
	_text(home_region_label, "%02d // %s" % [profile.selected_level, level_data.name])
	if home_region_label.get_theme_color("font_color") != level_data.accent:
		home_region_label.add_theme_color_override("font_color", level_data.accent)
	_text(home_description, level_data.description)
	_text(halloween_label, _t("pass_cta", [profile.pass_xp]))
	if language_menu.visible:
		for code in language_buttons:
			language_buttons[code].set_pressed_no_signal(code == profile.language)
	if season_pass.visible:
		_text(pass_progress_label, _t("pass_progress", [profile.pass_xp]) if CourierCatalogue.halloween_active() else _t("pass_ended"))
		pass_previous.disabled = pass_page == 0
		pass_next.disabled = pass_page == 1
		for slot in range(5):
			var tier := pass_page * 5 + slot + 1
			var reward := CourierSeasonPass.reward(tier)
			var claimed := profile.pass_claimed.has(tier)
			var eligible := profile.pass_xp >= int(reward.xp)
			var is_item := not str(reward.item).is_empty()
			_text(pass_rows[slot], _t("coins", [reward.coins]) if not is_item else _t("item_" + str(reward.item)))
			_text(pass_requirements[slot], _t("tier", [tier]) + " · %s XP" % reward.xp)
			var button := pass_buttons[slot]
			button.disabled = not eligible or (claimed and (not is_item or profile.equipped_trail == reward.item))
			_text(button, _t("claimed") if claimed else (_t("claim") if eligible else _t("need_xp", [int(reward.xp) - profile.pass_xp])))
			if claimed and is_item:
				_text(button, _t("equipped") if profile.equipped_trail == reward.item else _t("equip"))
	if level_map.visible:
		_text(map_title, "%02d–%02d // %s" % [map_page * 10 + 1, map_page * 10 + 10, CourierLevels.get_level(map_page * 10 + 1).name])
		_text(map_summary, _t("selected_level", [profile.selected_level, level_data.name, level_data.description]))
		map_previous.disabled = map_page == 0
		map_next.disabled = map_page == 9
		for i in range(level_buttons.size()):
			var number := map_page * 10 + i + 1
			var unlocked := number <= profile.unlocked_level
			var rating := profile.stars_for_level(number)
			level_buttons[i].disabled = not unlocked
			level_buttons[i].set_pressed_no_signal(number == profile.selected_level)
			_text(level_buttons[i], "%02d   %s\n%s" % [number, "★".repeat(rating) if rating > 0 else _t("ready" if unlocked else "locked"), _t("parcels", [CourierLevels.get_level(number).goal])])
	if shop.visible:
		for id in shop_buttons:
			var data := CourierCatalogue.item(id)
			var owned := profile.owned_items.has(id)
			var equipped: bool = id == profile.equipped_ship or id == profile.equipped_trail
			var button: Button = shop_buttons[id]
			_text(button, _t("equipped") if equipped else (_t("equip") if owned else _t("coins", [data.price])))
			button.disabled = equipped
			if data.access == "season_gift" and not owned:
				_text(button, _t("claim_free") if CourierCatalogue.halloween_active() else _t("season_over"))
				button.disabled = not CourierCatalogue.halloween_active()
			elif data.access == "premium":
				_text(button, _t("preview"))
	sound_button.text = "♪" if profile.sound_enabled else "×"
	get_node("Header/PauseButton").visible = not is_home and not is_over and not is_paused
	_text(record_label, _t("record", [profile.best_score]) if profile.best_score > 0 else _t("tagline"))
	_text(coin_label, str(run.collected_coins))
	_text(package_label, _t("packages", [run.delivered, run.delivery_goal]))
	_text(score_label, _t("score", [run.score]))
	_text(toast_label, notification_text)
	toast_label.modulate.a = minf(1.0, toast_remaining * 2.0)
	_text(fire_button, _t("auto_on" if run.auto_fire else "auto_off"))
	fire_button.disabled = is_paused or is_over
	if run.destination_active:
		var can_land := run.destination.y >= 400.0
		_text(hint_label, _t("land_hint" if can_land else "approach_hint"))
		_text(subhint_label, _t("land_help" if can_land else "approach_help"))
	else:
		_text(hint_label, _t("steer"))
		_text(subhint_label, _t("rewards_help"))
	if is_paused:
		_text(overlay_title, _t("pause_title"))
		_text(overlay_subtitle, _t("pause_note"))
		_text(overlay_stats, _t("pause_stats", [run.delivered, run.delivery_goal, run.score]))
		_text(primary_button, _t("resume"))
	elif is_over:
		var won := run.mode == CourierRun.Mode.WON
		_text(overlay_title, _t("won_title", [run.level]) if won else _t("lost_title"))
		_text(overlay_subtitle, _t("won_note" if won else "lost_note"))
		if won and run.level == CourierLevels.COUNT:
			_text(overlay_subtitle, _t("campaign_note"))
		_text(overlay_stats, _t("result_stats", [run.score, run.delivered, run.delivery_goal, run.collected_coins]))
		_text(primary_button, _t("next_level" if won and run.level < CourierLevels.COUNT else "retry"))


func _layer(layer_name: String) -> Control:
	var node := Control.new()
	node.name = layer_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(node)
	return node


func _label(parent: Control, text: String, rect: Rect2, size_px: int, color: Color, bold: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = _t(text) if CourierText.has(text) else text
	if CourierText.has(text):
		node.set_meta("loc_key", text)
		localized_nodes.append(node)
	node.position = rect.position
	node.size = rect.size
	node.clip_text = true
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", BOLD if bold else FONT)
	_font_size(node, size_px)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node


func _button(parent: Control, text: String, rect: Rect2, action: Callable, primary: bool) -> Button:
	var node := Button.new()
	node.text = _t(text) if CourierText.has(text) else text
	if CourierText.has(text):
		node.set_meta("loc_key", text)
		localized_nodes.append(node)
	node.position = rect.position
	node.size = rect.size
	node.clip_text = true
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", BOLD)
	_font_size(node, 31)
	node.add_theme_color_override("font_color", Color("122e37") if primary else CREAM)
	node.add_theme_color_override("font_hover_color", Color("122e37") if primary else CREAM)
	node.add_theme_color_override("font_pressed_color", Color("122e37") if primary else CREAM)
	node.add_theme_stylebox_override("normal", _style(MINT if primary else Color("172640"), Color("b7ffe4") if primary else Color("38506d"), 26))
	node.add_theme_stylebox_override("hover", _style(Color("bfffe8") if primary else Color("263c58"), MINT, 26))
	node.add_theme_stylebox_override("pressed", _style(Color("7bdbb7") if primary else Color("304966"), MINT, 26))
	node.add_theme_stylebox_override("disabled", _style(Color("101c32"), Color("26374e"), 26))
	node.add_theme_color_override("font_disabled_color", MUTED)
	var focus := _style(Color.TRANSPARENT, GOLD, 26)
	focus.set_border_width_all(4)
	node.add_theme_stylebox_override("focus", focus)
	node.pressed.connect(action)
	parent.add_child(node)
	return node


func _t(key: String, arguments: Array = []) -> String:
	return CourierText.t(key, arguments)


func _font_size(node: Control, value: int) -> void:
	node.set_meta("base_font", value)
	node.add_theme_font_size_override("font_size", value)


func _text(node: Control, value: String, force: bool = false) -> void:
	value = CourierText.directional(value)
	if not force and node.text == value and node.get_meta("fitted_width", -1.0) == node.size.x:
		return
	node.text = value
	var font: Font = node.get_theme_font("font")
	var size_px := int(node.get_meta("base_font", node.get_theme_font_size("font_size")))
	var limit := maxf(1.0, node.size.x - 24.0)
	var lines := value.split("\n")
	while size_px > 14:
		var fits := true
		for line in lines:
			if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > limit:
				fits = false
				break
		if fits:
			break
		size_px -= 1
	node.add_theme_font_size_override("font_size", size_px)
	node.set_meta("fitted_width", node.size.x)


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
		_panel(Rect2(620, 260, 395, 84), Color(0.055, 0.1, 0.18, 0.96), Color("34475e"), 26)
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
			_center_text(_t("level", [run.level]), Vector2(540, 486), 23, Color(theme.accent, opacity))
			_center_text(theme.name, Vector2(540, 544), 39, Color(CREAM, opacity))
	if hit_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, CourierRun.WORLD), Color(1.0, 0.37, 0.38, hit_flash * 0.24))


func _draw_home() -> void:
	if menu_screen == "languages":
		return
	if menu_screen == "pass":
		_draw_pass()
		return
	if menu_screen == "map":
		_panel(Rect2(65, 440, 950, 820), Color(0.06, 0.105, 0.19, 0.9), Color("2b405c"), 40)
		return
	if menu_screen == "shop":
		_draw_shop()
		return
	if menu_screen == "preview":
		_panel(Rect2(90, 430, 900, 1210), Color("111e36"), Color("69558c"), 48)
		_draw_ship(Vector2(540, 930 + sin(clock * 1.8) * 10), 0.96, 0.0, false, preview_id)
		return
	draw_arc(Vector2(540, 1010), 638.0, -2.8, 0.8, 120, Color(0.4, 0.7, 0.8, 0.13), 2.0, true)
	draw_arc(Vector2(540, 1010), 700.0, -1.0, 2.4, 120, Color(0.4, 0.7, 0.8, 0.08), 2.0, true)
	_draw_planet(Vector2(1005, 445), 185.0, 0.18, _level_data().planet_tint)
	_draw_planet(Vector2(0, 1570), 155.0, -0.24, Color("f5b1a6"))
	_panel(Rect2(90, 455, 900, 1080), Color(0.06, 0.105, 0.19, 0.94), Color("2b405c"), 48)
	draw_arc(Vector2(540, 1003), 111.0, 0.0, TAU, 80, Color(0.6, 0.96, 0.82, 0.15), 2.0, true)
	_draw_ship(Vector2(540, 988 + sin(clock * 1.8) * 7.0), 0.55, sin(clock * 1.3) * 0.035, false)
	_cross(Vector2(330, 990), 13.0, GOLD)
	_cross(Vector2(745, 1060), 9.0, MINT)
	_draw_parcel(Vector2(841, 393), 0.75, clock * 0.1)


func _draw_pass() -> void:
	var progress := float(profile.pass_xp) / CourierSeasonPass.MAX_XP
	draw_line(Vector2(120, 585), Vector2(960, 585), Color("34475e"), 13.0, true)
	if progress > 0:
		draw_line(Vector2(120, 585), Vector2(120 + 840 * progress, 585), GOLD, 13.0, true)
	for slot in range(5):
		var tier := pass_page * 5 + slot + 1
		var earned := profile.pass_xp >= tier * CourierSeasonPass.XP_PER_TIER
		var y := 640 + slot * 174
		_panel(Rect2(100, y, 880, 150), Color("111f36"), GOLD if earned else Color("34475e"), 28)
		_draw_star(Vector2(145, y + 74), 22, GOLD if earned else Color("52627c"))


func _draw_shop() -> void:
	for index in range(CourierCatalogue.SHOP_IDS.size()):
		var id: String = CourierCatalogue.SHOP_IDS[index]
		var data := CourierCatalogue.item(id)
		var at := Vector2(100 + (index % 2) * 460, 510 + int(index / 2) * 395)
		var owned := profile.owned_items.has(id)
		_panel(Rect2(at, Vector2(420, 370)), Color("111f36"), data.color if owned else Color("34475e"), 32)
		if data.kind == "ship":
			_draw_ship(at + Vector2(210, 84), 0.34, sin(clock * 0.7) * 0.025, false, id)
		else:
			for i in range(18):
				var tint: Color = data.color
				tint.a = 0.1 + i / 24.0
				var point := at + Vector2(80 + i * 15, 105 + sin(i * 0.32 + clock) * 22)
				draw_circle(point, 2 + i * 0.5, tint, true, -1.0, true)
			_draw_star(at + Vector2(350, 105 + sin(18 * 0.32 + clock) * 22), 22, data.color)


func _draw_flight() -> void:
	# Faraway planets are decoration, deliberately dimmer than active targets.
	_draw_planet(Vector2(-70, 1340 + sin(clock * 0.15) * 35.0), 205.0, 0.3, Color(0.65, 0.49, 0.66, 0.6))
	if run.destination_active:
		_draw_destination()
	else:
		draw_arc(Vector2(1005, 695), 73.0, 0.0, TAU, 50, Color(0.6, 0.8, 0.95, 0.12), 2.0, true)
		draw_circle(Vector2(1005, 695), 43.0, Color("1b2c4c"), true, -1.0, true)
	for bullet in run.bullets:
		var at: Vector2 = bullet.position
		draw_line(at + Vector2(0, 19), at - Vector2(0, 25), Color(0.5, 1.0, 0.9, 0.18), 20.0, true)
		draw_line(at + Vector2(0, 15), at - Vector2(0, 23), MINT, 7.0, true)
		draw_line(at + Vector2(0, 10), at - Vector2(0, 21), CREAM, 2.0, true)
	for coin in run.coins:
		_draw_coin(coin.position)
	for rock in run.asteroids:
		draw_set_transform(rock.position, rock.angle, Vector2.ONE * rock.radius / 150.0)
		draw_texture_rect(ASTEROID, Rect2(-150, -150, 300, 300), false, Color("e0c7e8") if rock.variant == 1 else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		var hp := int(rock.get("hp", 3))
		var max_hp := int(rock.get("max_hp", 3))
		if hp < max_hp:
			var at: Vector2 = rock.position - Vector2(0, rock.radius + 18)
			draw_line(at - Vector2(40, 0), at + Vector2(40, 0), Color("2b405c"), 6.0, true)
			draw_line(at - Vector2(40, 0), at - Vector2(40, 0) + Vector2(80.0 * hp / max_hp, 0), GOLD, 6.0, true)
	for shard in debris.shards:
		var fraction: float = shard.life / shard.duration
		var tint: Color = shard.color
		tint.a = fraction * fraction
		draw_set_transform(shard.position, shard.angle, Vector2.ONE * (0.35 + fraction * 0.65))
		draw_colored_polygon(shard.points, tint)
		var edge: Color = tint.lightened(0.32)
		edge.a = tint.a
		draw_line(shard.points[0], shard.points[1], edge, 2.0, true)
		draw_set_transform(Vector2.ZERO)
	# Keep the ship visible while protected; the shield arc conveys invulnerability.
	for i in range(1, trail.size()):
		var tint: Color = CourierCatalogue.item(profile.equipped_trail).color
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
		_center_text(_t("docking"), pad + Vector2(0, 161), 23, GOLD)
	var label_position := Vector2(run.destination.x, maxf(370.0, run.destination.y - 211.0))
	_panel(Rect2(label_position - Vector2(110, 30), Vector2(220, 60)), MINT, MINT, 24)
	_center_text(_t("destination"), label_position + Vector2(0, 9), 23, Color("183b42"), 195.0)


func _draw_hud() -> void:
	_panel(Rect2(60, 211, 960, 112), Color(0.055, 0.1, 0.18, 0.94), Color("2b405c"), 30)
	draw_line(Vector2(90, 332), Vector2(990, 332), Color("263c56"), 5.0, true)
	var progress := (float(run.delivered) + run.dock_progress) / run.delivery_goal
	if progress > 0.0:
		draw_line(Vector2(90, 332), Vector2(90 + 900 * progress, 332), _level_data().accent, 5.0, true)
	draw_line(Vector2(304, 235), Vector2(304, 298), Color("2c405b"), 2.0, true)
	draw_line(Vector2(774, 235), Vector2(774, 298), Color("2c405b"), 2.0, true)
	_draw_coin(Vector2(102, 265), 0.68)
	for i in range(run.delivery_goal):
		var color := MINT if i < run.delivered else Color("334762")
		var at := Vector2(540 - (run.delivery_goal - 1) * 23 + i * 46, 292)
		_panel(Rect2(at - Vector2(14, 12), Vector2(28, 24)), color, color, 5)
		draw_line(at + Vector2(0, -12), at + Vector2(0, 12), Color("152e3d"), 4.0, true)
	_panel(Rect2(55, 1645, 970, 157), Color(0.05, 0.09, 0.17, 0.9), Color("283d59"), 34)
	for i in range(CourierRun.MAX_SHIELDS):
		var at := Vector2(450 + i * 90, 1854)
		var color := MINT if i < run.shields else Color("34455f")
		var shape := PackedVector2Array([at + Vector2(0, -24), at + Vector2(20, -15), at + Vector2(17, 11), at + Vector2(0, 25), at + Vector2(-17, 11), at + Vector2(-20, -15), at + Vector2(0, -24)])
		draw_polyline(shape, color, 4.0, true)
		if i < run.shields:
			var inside := PackedVector2Array([at + Vector2(0, -14), at + Vector2(11, -9), at + Vector2(9, 6), at + Vector2(0, 14), at + Vector2(-9, 6), at + Vector2(-11, -9)])
			draw_colored_polygon(inside, Color(0.6, 0.96, 0.83, 0.24))


func _draw_ship(at: Vector2, ship_scale: float, angle: float, shielded: bool, skin: String = "") -> void:
	draw_set_transform(at, angle, Vector2.ONE * ship_scale)
	var flame := 1.0 + sin(clock * 38.0) * 0.12
	var outer := PackedVector2Array([Vector2(-18, 112), Vector2(-14, 165), Vector2(0, 222 * flame), Vector2(14, 165), Vector2(18, 112)])
	draw_colored_polygon(outer, Color(1.0, 0.54, 0.4, 0.48))
	var inner := PackedVector2Array([Vector2(-10, 113), Vector2(-7, 161), Vector2(0, 191 * flame), Vector2(7, 161), Vector2(10, 113)])
	draw_colored_polygon(inner, Color("fff1b4"))
	for x in [-78.0, 78.0]:
		draw_line(Vector2(x, 100), Vector2(x, 128.0 + 20.0 * flame), Color("9debe3"), 8.0, true)
	draw_texture_rect(SHIPS.get(profile.equipped_ship if skin.is_empty() else skin, SHIP), Rect2(-120, -160, 240, 320), false)
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


func _center_text(text: String, baseline: Vector2, font_size: int, color: Color, maximum_width: float = 900.0) -> void:
	text = CourierText.directional(text)
	while font_size > 14 and BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > maximum_width:
		font_size -= 1
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
	for sound_name in ["coin", "delivery", "hit", "start", "rock"]:
		var notes: Array
		match sound_name:
			"coin": notes = [880.0, 1174.66]
			"delivery": notes = [523.25, 659.25, 783.99, 1046.5]
			"hit": notes = [196.0, 146.83]
			"rock": notes = [164.81, 110.0]
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
