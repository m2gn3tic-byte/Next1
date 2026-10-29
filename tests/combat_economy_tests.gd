extends SceneTree
## Actual bullet collisions, reward distribution and durable cosmetic transactions.

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
	var value := "user://economy-%s-%s.cfg" % [Time.get_ticks_usec(), paths.size()]
	paths.append(value)
	return value


func _run_tests() -> void:
	_test_campaign()
	_test_weapon()
	_test_rewards()
	_test_inventory()
	_test_season()
	_test_migration_and_failures()
	await _test_scene()
	for path in paths:
		DirAccess.remove_absolute(path)
	print("\nCOMBAT/ECONOMY RESULT: %s passed, %s failed" % [passed, failed])
	call_deferred("quit", 1 if failed > 0 else 0)


func _test_campaign() -> void:
	var goals: Dictionary = {}
	var bounded := true
	for number in range(1, 101):
		var level := CourierLevels.get_level(number)
		goals[level.goal] = true
		bounded = bounded and level.goal >= 2 and level.goal <= 7 and level.speed < 440 and level.spawn_interval >= 0.8
	check(bounded and goals.size() == 6, "all 100 finite definitions vary across 2–7 parcels with bounded difficulty")
	check(CourierLevels.get_level(11).speed > CourierLevels.get_level(10).speed
		and CourierLevels.get_level(11).drift > CourierLevels.get_level(10).drift,
		"the ten-level boundary increases actual speed and introduces drift")
	check(CourierLevels.get_level(100).goal == 7 and CourierLevels.get_level(101) == CourierLevels.get_level(100),
		"campaign has a final seven-parcel stop and no level 101")


func _quiet_run(seed_value: int = 42) -> CourierRun:
	var state := CourierRun.new()
	state.begin(seed_value)
	state.next_destination = 999.0
	state.asteroid_timer = 999.0
	state.coin_timer = 999.0
	return state


func _rock(size_class: int, at: Vector2 = Vector2(540, 900)) -> Dictionary:
	return {"position": at, "radius": CourierRun.ROCK_RADII[size_class], "hp": CourierRun.ROCK_HP[size_class],
		"max_hp": CourierRun.ROCK_HP[size_class], "size_class": size_class,
		"speed": 0.0, "drift": 0.0, "angle": 0.0, "spin": 0.0, "variant": 0}


func _test_weapon() -> void:
	var state := _quiet_run()
	state.auto_fire = false
	for frame in range(60):
		state.step(1.0 / 60.0)
	check(state.bullets.is_empty(), "autofire can be switched off without spawning invisible shots")
	state.auto_fire = true
	state.step(1.0 / 60.0)
	check(state.bullets.size() == 1, "autofire creates a real projectile from the ship")
	var snapshot := state.bullets.duplicate(true)
	state.pause()
	for frame in range(60):
		state.step(1.0 / 60.0)
	check(state.bullets == snapshot, "pause freezes projectiles and the fire timer")
	state.resume()
	state.step(1.0 / 60.0)
	check(state.bullets != snapshot, "resume continues existing projectiles")
	state.begin(42)
	check(state.bullets.is_empty() and state.destroyed == 0, "restart clears previous projectiles and kill counts")
	state = _quiet_run()
	state.auto_fire = false
	state.asteroids.append(_rock(1))
	state.bullets.append({"position": Vector2(540, 935)})
	state.step(1.0 / 30.0)
	check(state.asteroids.size() == 1 and state.asteroids[0].hp == 2 and state.bullets.is_empty(),
		"a swept projectile removes exactly one of a medium asteroid's three hit points")
	state = _quiet_run()
	state.auto_fire = false
	state.asteroids.append(_rock(0, Vector2(540, 250)))
	state.bullets.append({"position": Vector2(540, 350)})
	for frame in range(10):
		state.step(1.0 / 60.0)
	check(state.destroyed == 0 and state.collected_coins == 0, "hidden hazards behind the top HUD cannot generate offscreen rewards")
	state = _quiet_run()
	for frame in range(60 * 20):
		state.step(1.0 / 60.0)
	check(state.bullets.size() < 8, "offscreen projectiles are removed and cannot grow without bound")


func _test_rewards() -> void:
	var observed: Dictionary = {}
	var all_valid := true
	for size_class in range(3):
		for seed_value in range(40):
			var state := _quiet_run(seed_value)
			state.asteroids.append(_rock(size_class))
			for frame in range(60 * 3):
				state.step(1.0 / 60.0)
			var reward := state.collected_coins
			all_valid = all_valid and state.destroyed == 1 and state.asteroids.is_empty()
			if size_class == 0:
				all_valid = all_valid and reward == 0
			elif size_class == 1:
				all_valid = all_valid and reward >= 1 and reward <= 3
				observed[reward] = true
			else:
				all_valid = all_valid and reward >= 4 and reward <= 7
	check(all_valid, "actual shots destroy all three sizes with exactly their 0 / 1–3 / 4–7 coin rewards")
	check(observed.size() == 3, "medium asteroid rewards actually vary: deterministic trials produce 1, 2 and 3")
	var state := _quiet_run()
	state.auto_fire = false
	state.invincible_for = 0.0
	state.asteroids.append(_rock(2, state.ship))
	state.step(1.0 / 60.0)
	check(state.shields == 2 and state.collected_coins == 0 and state.destroyed == 0,
		"ramming an asteroid costs a shield without granting destruction rewards")
	state = _quiet_run()
	state._spawn_coins(260)
	check(state.coins.size() == 1, "a flight coin wave contains one coin instead of three")
	var a := _quiet_run(8)
	var b := _quiet_run(8)
	for current in [a, b]:
		current.asteroids.append(_rock(1))
		for frame in range(180):
			current.step(1.0 / 60.0)
	check(a.collected_coins == b.collected_coins and a.destroyed == b.destroyed, "seeded combat and reward randomization remain reproducible")


func _test_inventory() -> void:
	var path := _path()
	var profile := CourierProfile.new(path)
	check(profile.wallet == 0 and profile.equipped_ship == "courier" and profile.owned_items.size() == 2,
		"a fresh profile owns the standard ship and trail with an empty wallet")
	check(profile.acquire_item("aurora") == ERR_UNAUTHORIZED and profile.wallet == 0 and not profile.owned_items.has("aurora"),
		"insufficient coins cannot grant an item or overdraw the wallet")
	check(profile.credit_coins(250) == OK and CourierProfile.new(path).wallet == 250,
		"earned coins are durable immediately without needing a victory")
	check(profile.credit_coins(0) == ERR_INVALID_PARAMETER and profile.credit_coins(-5) == ERR_INVALID_PARAMETER
		and profile.credit_coins(CourierProfile.MAX_BALANCE) == ERR_INVALID_PARAMETER and profile.wallet == 250,
		"invalid or overflowing credits cannot corrupt the wallet")
	check(profile.acquire_item("aurora") == OK and profile.wallet == 160 and profile.equipped_ship == "aurora",
		"a valid coin purchase charges once, grants ownership and equips the ship")
	check(profile.acquire_item("aurora") == ERR_ALREADY_EXISTS and profile.wallet == 160,
		"buying an owned item again cannot charge a second time")
	check(profile.acquire_item("violet_trail") == OK and profile.wallet == 100 and profile.equipped_trail == "violet_trail",
		"trails can be bought and equipped separately from ships")
	check(profile.equip_item("comet") == ERR_UNAUTHORIZED and profile.equipped_ship == "aurora",
		"an unowned cosmetic cannot be equipped")
	check(profile.equip_item("courier") == OK and profile.equipped_ship == "courier" and profile.wallet == 100,
		"the original ship remains available to equip without another charge")
	profile.auto_fire = false
	profile.save()
	var restored := CourierProfile.new(path)
	check(restored.wallet == 100 and restored.owned_items.has("aurora") and restored.equipped_ship == "courier"
		and restored.equipped_trail == "violet_trail" and not restored.auto_fire,
		"wallet, ownership, ship, trail and firing preference survive a reload")
	check(profile.acquire_item("unknown") == ERR_INVALID_PARAMETER and profile.wallet == 100,
		"unknown catalogue IDs cannot alter the economy")


func _test_season() -> void:
	var during := {"year": 2026, "month": 10, "day": 29}
	check(CourierCatalogue.halloween_active({"year": 2026, "month": 10, "day": 15})
		and CourierCatalogue.halloween_active({"year": 2026, "month": 11, "day": 7})
		and not CourierCatalogue.halloween_active({"year": 2026, "month": 11, "day": 8}),
		"Halloween availability includes both dates and expires after 7 November")
	var path := _path()
	var profile := CourierProfile.new(path)
	check(profile.acquire_item("pumpkin", {"year": 2026, "month": 10, "day": 14}) == ERR_UNAVAILABLE,
		"the free seasonal gift cannot be claimed before the event")
	check(profile.acquire_item("pumpkin", during) == OK and profile.wallet == 0 and profile.equipped_ship == "pumpkin",
		"the Halloween ship is a genuinely free claim and equips immediately")
	check(profile.acquire_item("pumpkin", during) == ERR_ALREADY_EXISTS and profile.owned_items.count("pumpkin") == 1,
		"the seasonal gift cannot be claimed repeatedly")
	var restored := CourierProfile.new(path)
	check(restored.equip_item("pumpkin") == OK and restored.equipped_ship == "pumpkin",
		"a claimed seasonal ship stays owned and usable regardless of event expiration")
	profile.credit_coins(10000)
	check(profile.acquire_item("nightwing", during) == ERR_UNAVAILABLE and profile.wallet == 10000
		and not profile.owned_items.has("nightwing") and profile.equip_item("nightwing") == ERR_UNAUTHORIZED,
		"premium preview never grants ownership, takes money or sells the paid ship for coins")


func _test_migration_and_failures() -> void:
	var path := _path()
	var file := ConfigFile.new()
	file.set_value("records", "score", 2900)
	file.set_value("records", "deliveries", 5)
	file.set_value("settings", "sound", false)
	file.set_value("progress", "unlocked_level", 3)
	file.set_value("progress", "selected_level", 3)
	file.set_value("progress", "stars", {1: 3, 2: 2, 3: 1})
	file.save(path)
	var migrated := CourierProfile.new(path)
	check(migrated.unlocked_level == 4 and migrated.selected_level == 3 and migrated.stars_for_level(2) == 2
		and migrated.best_score == 2900 and not migrated.sound_enabled and migrated.wallet == 0,
		"old three-region saves retain stars and preferences, unlock four and invent no old coins")
	file.set_value("inventory", "wallet", -800)
	file.set_value("inventory", "owned", ["nightwing", "unknown", 99])
	file.set_value("inventory", "ship", "nightwing")
	file.set_value("inventory", "trail", "comet")
	file.save(path)
	var bad := CourierProfile.new(path)
	check(bad.wallet == 0 and bad.equipped_ship == "courier" and bad.equipped_trail == "mint_trail"
		and not bad.owned_items.has("nightwing"), "malformed inventory cannot equip invalid or offline premium items")
	var broken := CourierProfile.new("user://missing-dir-%s/courier.cfg" % Time.get_ticks_usec())
	check(broken.credit_coins(4) != OK and broken.wallet == 0, "failed coin saves roll back the in-memory wallet")
	broken.wallet = 100
	check(broken.acquire_item("aurora") != OK and broken.wallet == 100 and not broken.owned_items.has("aurora")
		and broken.equipped_ship == "courier", "failed purchase saves restore coins, ownership and equipped appearance")


func _test_scene() -> void:
	var path := _path()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var original_profile = game.profile
	game.profile = CourierProfile.new(path)
	game.profile.sound_enabled = false
	game._sync_interface()
	game.get_node("Home/ShopButton").pressed.emit()
	check(game.shop.visible and not game.home.visible and not game.hud.visible, "the main menu opens a separate working shop")
	game.get_node("Shop/Item_aurora").pressed.emit()
	check(game.profile.wallet == 0 and not game.profile.owned_items.has("aurora") and game.menu_feedback.text.contains("90"),
		"shop gives a useful missing-coins message without granting a free purchase")
	game._show_menu("home")
	game._start_run()
	game.run.coins.append({"position": game.run.ship, "speed": 0.0})
	game._process(1.0 / 60.0)
	game._process(1.0 / 60.0)
	check(game.profile.wallet == 1 and CourierProfile.new(path).wallet == 1,
		"an actual flight pickup credits the persistent wallet exactly once")
	game.run.asteroids.append(_rock(1, game.run.ship - Vector2(0, 220)))
	game.run.asteroids[0].hp = 1
	game.run.bullets.append({"position": game.run.asteroids[0].position + Vector2(0, 30)})
	game._process(1.0 / 60.0)
	check(game.profile.wallet >= 2 and game.profile.wallet <= 4 and game.run.destroyed == 1,
		"an actual destroyed medium asteroid credits its randomized persistent reward")
	var earned: int = game.profile.wallet
	game._go_home()
	check(CourierProfile.new(path).wallet == earned, "returning to the menu retains coins from the unfinished flight")
	game.profile.credit_coins(250)
	game._show_menu("shop")
	var before: int = game.profile.wallet
	game.get_node("Shop/Item_aurora").pressed.emit()
	check(game.profile.equipped_ship == "aurora" and game.profile.wallet == before - 90,
		"the real shop button purchases and equips a coin ship")
	game._shop_action("aurora")
	check(game.profile.wallet == before - 90, "equipping an owned ship through the shop does not charge again")
	game.get_node("Shop/OriginalShipButton").pressed.emit()
	check(game.profile.equipped_ship == "courier" and game.profile.wallet == before - 90,
		"the shop provides a working button to re-equip the original ship for free")
	game.get_node("Shop/Item_aurora").pressed.emit()
	game.get_node("Shop/Item_nightwing").pressed.emit()
	check(game.preview.visible and not game.shop.visible and not game.profile.owned_items.has("nightwing")
		and game.profile.equipped_ship == "aurora", "premium button opens a non-purchasing preview without replacing the real equipped ship")
	game._show_menu("map")
	game._change_map_page(9)
	check(game.map_page == 9 and game.map_next.disabled and game.level_buttons[9].disabled
		and game.profile.selected_level == 1, "locked later map pages can be viewed without skipping progression")
	game._go_home()
	game._start_run()
	game.get_node("FlightHUD/FireButton").pressed.emit()
	check(not game.run.auto_fire and not CourierProfile.new(path).auto_fire,
		"the flight autofire toggle updates the actual weapon and saves the preference")
	game.profile = original_profile
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
