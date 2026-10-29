extends SceneTree
## Integration checks for level selection, real delivery results and saved progress.
## Run: ./tools/godot.sh --headless --script res://tests/progression_scene_tests.gd

var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run_tests")


func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", description)
	else:
		failed += 1
		push_error("FAIL  " + description)


func _run_tests() -> void:
	var path := "user://scene-progress-%s.cfg" % Time.get_ticks_usec()
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	# _ready only reads the real profile. All subsequent actions use this isolated file.
	var original_profile = game.profile
	var temporary_profile = CourierProfile.new(path)
	temporary_profile.sound_enabled = false
	temporary_profile.best_score = 2600
	game.profile = temporary_profile
	game._sync_interface()
	var has_buttons := true
	for number in range(1, 4):
		var button = game.get_node_or_null("Home/Level%sButton" % number)
		if button == null:
			has_buttons = false
	check(has_buttons, "home exposes all three level choices")
	if has_buttons:
		_test_selection_and_first_victory(game, path)
		_test_failure_and_reselection(game, path)
		_test_campaign_finish(game, path)
		_test_keyboard_next_level(game)
	game.profile = original_profile
	game.queue_free()
	await process_frame
	# Allow the asynchronous audio mixer to release stopped playback before teardown.
	await create_timer(0.2).timeout
	DirAccess.remove_absolute(path)
	print("\nPROGRESSION SCENE RESULT: %s passed, %s failed" % [passed, failed])
	call_deferred("quit", 1 if failed > 0 else 0)


func _test_selection_and_first_victory(game, path: String) -> void:
	check(not game.get_node("Home/Level1Button").disabled, "first level is available on a fresh profile")
	check(game.get_node("Home/Level2Button").disabled and game.get_node("Home/Level3Button").disabled,
		"later levels are disabled before earlier deliveries are completed")
	game.get_node("Home/StartButton").pressed.emit()
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.FLYING and game.run.level == 1,
		"start button launches the selected first level")
	_finish_level(game, 1)
	check(game.run.mode == CourierRun.Mode.WON and game.run.delivered == 5 and game.overlay.visible,
		"fifth actual delivery opens the level-complete screen")
	check(game.profile.unlocked_level == 2 and game.profile.stars_for_level(1) == 1,
		"victory unlocks the next level and records earned stars")
	var reloaded = CourierProfile.new(path)
	check(reloaded.unlocked_level == 2 and reloaded.stars_for_level(1) == 1,
		"earned unlock and stars survive a profile reload")
	game.get_node("Overlay/PrimaryButton").pressed.emit()
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.FLYING and game.run.level == 2 and game.profile.selected_level == 2,
		"level-complete primary action selects and starts the next level")
	check(game.run.delivered == 0 and game.run.shields == CourierRun.MAX_SHIELDS,
		"next level starts with fresh delivery and shield state")


func _test_failure_and_reselection(game, path: String) -> void:
	# Lose through the real collision path rather than directly setting LOST.
	game.run.shields = 1
	game.run.invincible_for = 0.0
	game.run.asteroids.clear()
	game.run.asteroids.append({
		"position": game.run.ship, "speed": 0.0, "radius": 100.0,
		"angle": 0.0, "spin": 0.0, "variant": 0,
	})
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.LOST and game.overlay.visible,
		"losing the final shield opens the retry screen")
	check(game.profile.selected_level == 2 and game.profile.unlocked_level == 2 and game.profile.stars_for_level(2) == 0,
		"failed level does not unlock later content or award completion stars")
	game.get_node("Overlay/PrimaryButton").pressed.emit()
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.FLYING and game.run.level == 2 and game.run.delivered == 0,
		"retry restarts the failed level instead of skipping or returning to level one")
	game._go_home()
	game._process(1.0 / 60.0)
	check(game.home.visible and not game.get_node("Home/Level2Button").disabled and game.get_node("Home/Level3Button").disabled,
		"returning home refreshes which levels have been unlocked")
	game.get_node("Home/Level1Button").pressed.emit()
	check(game.profile.selected_level == 1, "an earlier unlocked level can be selected for replay")
	var selected = CourierProfile.new(path)
	check(selected.selected_level == 1 and selected.stars_for_level(1) == 1,
		"choosing a replay level persists without losing its stars")
	game.get_node("Home/Level2Button").pressed.emit()
	game.get_node("Home/StartButton").pressed.emit()
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.FLYING and game.run.level == 2,
		"home start respects an unlocked level chosen by its button")


func _test_campaign_finish(game, path: String) -> void:
	_finish_level(game, 2)
	check(game.profile.unlocked_level == 3 and game.profile.stars_for_level(2) == 2,
		"completing the second level unlocks the final region with its own star rating")
	game.get_node("Overlay/PrimaryButton").pressed.emit()
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.FLYING and game.run.level == 3,
		"next-level action reaches the final region")
	_finish_level(game, 3)
	check(game.run.mode == CourierRun.Mode.WON and game.profile.unlocked_level == 3 and game.profile.stars_for_level(3) == 3,
		"final victory records three stars without creating a nonexistent fourth level")
	game.get_node("Overlay/PrimaryButton").pressed.emit()
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.FLYING and game.run.level == 3 and game.profile.selected_level == 3,
		"final victory primary action safely replays the final level")
	game._go_home()
	game._process(1.0 / 60.0)
	var all_available := true
	for number in range(1, 4):
		all_available = all_available and not game.get_node("Home/Level%sButton" % number).disabled
	check(all_available, "completed campaign keeps all earlier levels available for replay")
	var reloaded = CourierProfile.new(path)
	check(reloaded.unlocked_level == 3 and reloaded.selected_level == 3
		and reloaded.stars_for_level(1) == 1 and reloaded.stars_for_level(2) == 2 and reloaded.stars_for_level(3) == 3,
		"campaign progress and separate star ratings persist across reloads")
	check(reloaded.best_score >= 2600 and not reloaded.sound_enabled,
		"progression preserves an existing higher score and sound preference")


func _finish_level(game, remaining_shields: int) -> void:
	# Inject only docking encounters; production hold/progress/reward/terminal paths run.
	for delivery in range(5):
		game.run.destination_active = true
		game.run.destination = Vector2(540.0, 540.0)
		game.run.dock_progress = 0.0
		game.run.asteroids.clear()
		game.run.coins.clear()
		game.run.asteroid_timer = 999.0
		game.run.coin_timer = 999.0
		game.run.ship = game.run.dock_position()
		game.run.target = game.run.ship
		if delivery == 4:
			game.run.shields = remaining_shields
		for frame in range(33):
			game._process(1.0 / 60.0)


func _test_keyboard_next_level(game) -> void:
	game.get_node("Home/Level1Button").pressed.emit()
	game.get_node("Home/StartButton").pressed.emit()
	game._process(1.0 / 60.0)
	_finish_level(game, 3)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	game._unhandled_input(enter)
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.FLYING and game.run.level == 2,
		"Enter after victory matches the primary button and advances to the next level")
