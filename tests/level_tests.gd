extends SceneTree
## Deterministic level/progression checks; no browser or network dependency.

const LEVELS := preload("res://scripts/levels.gd")
const RUN := preload("res://scripts/run_state.gd")
const PROFILE := preload("res://scripts/profile.gd")
var passed := 0
var failed := 0
var paths: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", description)
	else:
		failed += 1
		push_error("FAIL  " + description)


func _path() -> String:
	var value := "user://levels-test-%s-%s.cfg" % [Time.get_ticks_usec(), paths.size()]
	paths.append(value)
	return value


func _run_tests() -> void:
	_test_catalogue_and_motion()
	_test_progression()
	_test_migration_and_bad_saves()
	_test_shield_repairs()
	_test_full_missions()
	for path in paths:
		DirAccess.remove_absolute(path)
	print("\nLEVEL RESULT: %s passed, %s failed" % [passed, failed])
	call_deferred("quit", 1 if failed > 0 else 0)


func _test_catalogue_and_motion() -> void:
	check(LEVELS.COUNT == 3 and LEVELS.get_level(2).name == "Udumets", "three named regions are available")
	var definition := LEVELS.get_level(1)
	definition["speed"] = 9999.0
	check(LEVELS.get_level(1).speed == 260.0, "catalogue reads cannot mutate shared balance settings")
	var first := RUN.new()
	var later := RUN.new()
	first.begin(22, 1)
	later.begin(22, 3)
	for i in range(61):
		first.step(1.0 / 60.0)
		later.step(1.0 / 60.0)
	check(not first.asteroids.is_empty() and not later.asteroids.is_empty(), "both early and late regions spawn real hazards")
	check(later.asteroids[0].speed > first.asteroids[0].speed, "later regions increase actual asteroid speed")
	check(first.asteroids[0].drift == 0.0 and absf(later.asteroids[0].drift) > 0.0, "later regions introduce lateral asteroid movement")
	var x_before: float = later.asteroids[0].position.x
	later.step(1.0 / 60.0)
	check(not is_equal_approx(later.asteroids[0].position.x, x_before), "the later-region hazard really moves sideways")
	later.asteroids[0].position.x = 20.0
	later.asteroids[0].drift = -38.0
	later.step(1.0 / 60.0)
	check(later.asteroids[0].position.x >= later.asteroids[0].radius + 15.0 and later.asteroids[0].drift > 0.0, "drifting asteroids bounce inside the playfield")
	later.begin(22, 99)
	check(later.level == LEVELS.COUNT, "out-of-range run levels are clamped")
	later.begin(22)
	check(later.level == 1, "legacy begin(seed) starts the first region")


func _test_progression() -> void:
	var path := _path()
	var profile := PROFILE.new(path)
	check(profile.unlocked_level == 1 and profile.selected_level == 1, "new players begin with only the first region")
	check(profile.select_level(2) == ERR_UNAUTHORIZED and profile.selected_level == 1, "locked regions cannot be selected")
	check(profile.complete_level(2, 3) == ERR_UNAUTHORIZED and profile.unlocked_level == 1, "finishing a locked region cannot skip progression")
	check(profile.complete_level(1, 0) == ERR_INVALID_PARAMETER and profile.stars_for_level(1) == 0, "a loss cannot award completion stars or unlock a region")
	check(profile.complete_level(1, 2) == OK and profile.unlocked_level == 2 and profile.stars_for_level(1) == 2, "winning unlocks exactly the next region and awards shield stars")
	check(profile.select_level(2) == OK and profile.selected_level == 2, "newly unlocked region becomes selectable")
	profile.complete_level(1, 1)
	check(profile.stars_for_level(1) == 2 and profile.selected_level == 2, "replays cannot reduce stars or overwrite the chosen region")
	profile.complete_level(1, 3)
	profile.complete_level(2, 1)
	check(profile.unlocked_level == 3 and profile.stars_for_level(1) == 3, "better replays improve stars while progression reaches the final region")
	profile.select_level(3)
	profile.complete_level(3, 3)
	check(profile.unlocked_level == LEVELS.COUNT and profile.select_level(4) == ERR_INVALID_PARAMETER, "finishing the campaign does not create a nonexistent next region")
	profile.record(1800, 5)
	profile.sound_enabled = false
	profile.save()
	var restored := PROFILE.new(path)
	check(restored.unlocked_level == 3 and restored.selected_level == 3 and restored.stars_for_level(3) == 3, "unlocks, selected region and stars survive reload")
	check(restored.best_score == 1800 and restored.best_deliveries == 5 and not restored.sound_enabled, "progress saving preserves existing records and sound settings")


func _test_migration_and_bad_saves() -> void:
	var old_path := _path()
	var file := ConfigFile.new()
	file.set_value("records", "score", 1500)
	file.set_value("records", "deliveries", 5)
	file.set_value("settings", "sound", false)
	file.save(old_path)
	var old := PROFILE.new(old_path)
	check(old.unlocked_level == 2 and old.stars_for_level(1) == 1 and old.best_score == 1500 and not old.sound_enabled, "legacy victory migrates conservatively without losing records or preferences")
	var bad_path := _path()
	file = ConfigFile.new()
	file.set_value("progress", "unlocked_level", 3)
	file.set_value("progress", "selected_level", 3)
	file.set_value("progress", "stars", {1: "three", 2: 3, 3: 99})
	file.save(bad_path)
	var bad := PROFILE.new(bad_path)
	check(bad.unlocked_level == 1 and bad.selected_level == 1 and bad.level_stars.is_empty(), "malformed and noncontiguous stars cannot unlock later regions")
	file.set_value("progress", "unlocked_level", -100)
	file.set_value("progress", "selected_level", "2")
	file.set_value("progress", "stars", [3, 3, 3])
	file.save(bad_path)
	bad = PROFILE.new(bad_path)
	check(bad.unlocked_level == 1 and bad.selected_level == 1 and bad.level_stars.is_empty(), "invalid types and out-of-range progress load safe defaults")


func _test_shield_repairs() -> void:
	var state := RUN.new()
	state.begin(4)
	state.delivered = 1
	state.shields = 1
	state.destination_active = true
	state.destination = Vector2(540, 540)
	state.ship = state.dock_position()
	state.target = state.ship
	for i in range(33):
		state.step(1.0 / 60.0)
	check(state.delivered == 2 and state.shields == 2, "the second successful delivery restores one lost shield")
	state.delivered = 3
	state.shields = RUN.MAX_SHIELDS
	state.destination_active = true
	state.destination = Vector2(540, 540)
	state.ship = state.dock_position()
	state.target = state.ship
	for i in range(33):
		state.step(1.0 / 60.0)
	check(state.delivered == 4 and state.shields == RUN.MAX_SHIELDS, "delivery repairs never exceed the maximum shield count")


func _test_full_missions() -> void:
	for number in range(1, LEVELS.COUNT + 1):
		var state := RUN.new()
		state.begin(99, number)
		# The pilot uses normal steering and real generated hazards throughout.
		for frame in range(60 * 140):
			if state.mode != RUN.Mode.FLYING:
				break
			if state.destination_active and state.destination.y >= 400.0:
				state.steer(state.dock_position())
			else:
				var desired := Vector2(state.ship.x, 1380)
				for rock in state.asteroids:
					if rock.position.y > 850.0 and rock.position.y < 1510.0 and absf(rock.position.x - desired.x) < rock.radius + 100.0:
						desired.x = 170.0 if rock.position.x > 540.0 else 910.0
				state.steer(desired)
			state.step(1.0 / 60.0)
		check(state.mode == RUN.Mode.WON and state.delivered == 5, "region %s full five-parcel mission is playable with generated hazards" % number)
		check(state.elapsed > 25.0 and state.elapsed < 140.0 and state.score >= 1150, "region %s completes within a bounded duration with real rewards" % number)
