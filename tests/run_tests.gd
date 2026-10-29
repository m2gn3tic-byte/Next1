extends SceneTree
## Run using: ./tools/godot.sh --headless --script res://tests/run_tests.gd

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
	_test_steering_and_pause()
	_test_pickups()
	_test_collisions()
	_test_deliveries()
	_test_deterministic_spawning()
	_test_complete_flight()
	_test_profile()
	await _test_scene()
	print("\nRESULT: %s passed, %s failed" % [passed, failed])
	call_deferred("quit", 1 if failed > 0 else 0)


func _test_steering_and_pause() -> void:
	var state := CourierRun.new()
	state.begin(42)
	state.steer(Vector2(-2000, 9999))
	check(state.target == Vector2(90, 1620), "steering stays inside the playable safe area")
	var before := state.ship
	state.step(1.0 / 60.0)
	check(state.ship.distance_to(before) > 0.0 and state.ship.distance_to(before) < 22.0, "ship moves smoothly instead of teleporting")
	state.pause()
	before = state.ship
	var time_before := state.elapsed
	for i in range(120):
		state.step(1.0 / 60.0)
	state.steer(Vector2(900, 900))
	check(state.ship == before and state.elapsed == time_before and state.target == before, "pause freezes movement, simulation and steering")
	state.resume()
	state.step(1.0 / 60.0)
	check(state.mode == CourierRun.Mode.FLYING and state.elapsed > time_before, "resuming continues the same flight")
	before = state.ship
	state.steer(Vector2(990, 350))
	state.step(100.0)
	check(state.ship.distance_to(before) < 41.0, "a stalled frame cannot teleport the ship through hazards")
	state.begin(42)
	check(state.ship == Vector2(540, 1380) and state.elapsed == 0.0 and state.shields == 3 and state.coins.is_empty(), "restart resets all run state")


func _test_pickups() -> void:
	var state := CourierRun.new()
	state.begin(0)
	state.coins.append({"position": state.ship, "speed": 0.0})
	state.step(1.0 / 60.0)
	state.step(1.0 / 60.0)
	check(state.collected_coins == 1 and state.score == 20 and state.coins.is_empty(), "a collected coin awards points exactly once")
	state.coins.append({"position": Vector2(100, 2100), "speed": 0.0})
	state.step(1.0 / 60.0)
	check(state.coins.is_empty(), "offscreen coins are removed")


func _rock(at: Vector2) -> Dictionary:
	return {"position": at, "speed": 0.0, "radius": 100.0, "angle": 0.0, "spin": 0.0, "variant": 0}


func _test_collisions() -> void:
	var state := CourierRun.new()
	state.begin(1)
	state.invincible_for = 0.0
	state.asteroids.append(_rock(state.ship))
	state.step(1.0 / 60.0)
	check(state.shields == 2 and state.invincible_for > 1.5, "collision consumes one shield and starts protection")
	state.asteroids.append(_rock(state.ship))
	state.step(1.0 / 60.0)
	check(state.shields == 2, "temporary protection prevents stacked collision damage")
	state.invincible_for = 0.0
	state.step(1.0 / 60.0)
	state.invincible_for = 0.0
	state.asteroids.append(_rock(state.ship))
	state.step(1.0 / 60.0)
	check(state.mode == CourierRun.Mode.LOST and state.shields == 0, "losing the final shield ends the flight")
	var time_before := state.elapsed
	state.step(1.0 / 60.0)
	check(state.elapsed == time_before, "finished flights stop simulating")


func _test_deliveries() -> void:
	var state := CourierRun.new()
	state.begin(2)
	state.destination_active = true
	state.destination = Vector2(540, 540)
	state.ship = state.dock_position()
	state.target = state.ship
	state.step(1.0 / 60.0)
	check(state.delivered == 0 and state.dock_progress > 0.0, "entering a landing ring starts a delivery, not an instant reward")
	state.ship = Vector2(900, 1000)
	state.target = state.ship
	state.step(1.0 / 60.0)
	check(state.dock_progress == 0.0 and state.delivered == 0, "leaving the landing ring resets the delivery hold")
	state.ship = state.dock_position()
	state.target = state.ship
	for i in range(33):
		state.step(1.0 / 60.0)
	check(state.delivered == 1 and state.score == 150 and state.collected_coins == 2 and not state.destination_active, "holding in the ring delivers a parcel and awards its reward once")
	check(state.next_destination > state.elapsed and state.invincible_for > 0.0, "delivery leaves a safe interval before the next destination")
	state.destination_active = true
	state.destination = Vector2(540, 540)
	state.asteroids.append(_rock(state.dock_position()))
	state.step(1.0 / 60.0)
	check(state.asteroids.is_empty(), "landing zones are kept clear of asteroid collisions")


func _test_deterministic_spawning() -> void:
	var a := CourierRun.new()
	var b := CourierRun.new()
	a.begin(2026)
	b.begin(2026)
	for i in range(240):
		a.step(1.0 / 60.0)
		b.step(1.0 / 60.0)
	check(a.asteroids.size() >= 2 and a.coins.size() >= 1, "flight spawns real obstacles and collectibles")
	check(a.asteroids == b.asteroids and a.coins == b.coins, "a fixed seed produces reproducible flights")


func _test_complete_flight() -> void:
	var state := CourierRun.new()
	state.begin(99)
	# A pilot uses the same steer/step API as real input, including real spawning.
	for frame in range(60 * 140):
		if state.mode != CourierRun.Mode.FLYING:
			break
		if state.destination_active:
			state.steer(state.dock_position())
		else:
			var desired := Vector2(state.ship.x, 1380)
			for rock in state.asteroids:
				if rock.position.y > 850.0 and rock.position.y < 1510.0 and absf(rock.position.x - desired.x) < rock.radius + 100.0:
					desired.x = 170.0 if rock.position.x > 540.0 else 910.0
			state.steer(desired)
		state.step(1.0 / 60.0)
	check(state.mode == CourierRun.Mode.WON and state.delivered == state.delivery_goal, "pilot completes the actual variable-length mission with generated hazards")
	check(state.score >= 700 and state.collected_coins >= 4, "completed mission includes delivery and completion rewards")
	check(state.elapsed > 15.0 and state.elapsed < 140.0, "complete mission has a bounded, playable duration")


func _test_profile() -> void:
	var path := "user://test-profile-%s.cfg" % Time.get_ticks_usec()
	var stored := CourierProfile.new(path)
	check(stored.best_score == 0 and stored.sound_enabled, "new profile has usable defaults")
	stored.sound_enabled = false
	check(stored.record(1200, 5) == OK, "records and sound preferences can be saved")
	stored.record(100, 1)
	var restored := CourierProfile.new(path)
	check(restored.best_score == 1200 and restored.best_deliveries == 5 and not restored.sound_enabled, "records survive reload and cannot decrease")
	DirAccess.remove_absolute(path)


func _test_scene() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(game.home.visible and not game.hud.visible, "main scene starts on its playable start screen")
	game.get_node("Home/StartButton").pressed.emit()
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.FLYING and game.hud.visible and not game.home.visible, "start button enters the game and updates HUD")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(540, 1400)
	touch.pressed = true
	game._unhandled_input(touch)
	var motion := InputEventScreenDrag.new()
	motion.index = 0
	motion.position = Vector2(740, 1100)
	game._unhandled_input(motion)
	for i in range(25):
		game._process(1.0 / 60.0)
	check(game.run.ship.x > 700 and game.run.ship.y < 1150, "touch dragging moves the actual ship in both directions")
	var intruder := InputEventScreenDrag.new()
	intruder.index = 1
	intruder.position = Vector2(100, 500)
	var target_before: Vector2 = game.run.target
	game._unhandled_input(intruder)
	check(game.run.target == target_before, "a second finger cannot take over steering")
	game.get_node("Header/PauseButton").pressed.emit()
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.PAUSED and game.overlay.visible, "pause button displays a working pause screen")
	game.get_node("Overlay/PrimaryButton").pressed.emit()
	game._process(1.0 / 60.0)
	check(game.run.mode == CourierRun.Mode.FLYING and not game.overlay.visible, "resume button returns to the same flight")
	game._pause_for_background()
	check(game.run.mode == CourierRun.Mode.PAUSED and game.drag_id == -1, "backgrounding pauses the game and releases the active pointer")
	game._go_home()
	game._process(1.0 / 60.0)
	check(game.home.visible and not game.overlay.visible, "home action restores the start screen")
	game.queue_free()
	await process_frame
	# Let the asynchronous audio mixer release a stopped playback before teardown.
	await create_timer(0.2).timeout
