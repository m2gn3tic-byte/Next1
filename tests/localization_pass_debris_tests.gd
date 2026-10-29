extends SceneTree
## Offline UI coverage, visible rock shards and durable free-season rewards.

var passed := 0
var failed := 0
var paths: Array[String] = []
const DURING := {"year": 2026, "month": 10, "day": 29}
const AFTER := {"year": 2026, "month": 11, "day": 8}


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
	var value := "user://season-locale-%s-%s.cfg" % [Time.get_ticks_usec(), paths.size()]
	paths.append(value)
	return value


func _run_tests() -> void:
	_test_pass()
	_test_pass_bad_saves()
	_test_debris()
	await _test_scene_and_languages()
	CourierText.set_language("et")
	for path in paths:
		DirAccess.remove_absolute(path)
	print("\nLANGUAGE/PASS/DEBRIS RESULT: %s passed, %s failed" % [passed, failed])
	call_deferred("quit", 1 if failed > 0 else 0)


func _test_pass() -> void:
	var path := _path()
	var profile := CourierProfile.new(path)
	check(profile.pass_xp == 0 and profile.pass_claimed.is_empty() and profile.language == "et", "existing players start the new free track without losing their default language")
	check(profile.claim_pass_reward(1) == ERR_UNAUTHORIZED and profile.wallet == 0, "unearned pass rewards cannot be claimed")
	check(profile.claim_pass_reward(0) == ERR_INVALID_PARAMETER and profile.claim_pass_reward(11) == ERR_INVALID_PARAMETER, "the pass has exactly ten valid reward tiers")
	check(profile.award_flight(5, 5, DURING) == OK and profile.wallet == 5 and profile.pass_xp == 5, "a flight award saves the five-coin maximum and earned XP together")
	check(profile.award_flight(6, 5, DURING) == ERR_INVALID_PARAMETER and profile.wallet == 5 and profile.pass_xp == 5, "the persistent flight reward API also enforces the five-coin ceiling")
	check(profile.award_flight(-1, 5, DURING) == ERR_INVALID_PARAMETER and profile.award_flight(0, -1, DURING) == ERR_INVALID_PARAMETER, "invalid flight awards cannot subtract or corrupt balances")
	profile.award_flight(1, 25, AFTER)
	check(profile.wallet == 6 and profile.pass_xp == 5, "after the event, flight coins remain earnable but seasonal XP stops")
	for i in range(2):
		profile.award_flight(0, 100, DURING)
	check(profile.claim_pass_reward(1) == OK and profile.wallet == 16 and profile.pass_claimed == [1], "reaching 200 XP unlocks a real one-time ten-coin reward")
	check(profile.claim_pass_reward(1) == ERR_ALREADY_EXISTS and profile.wallet == 16, "a claimed reward cannot be collected twice")
	check(profile.claim_pass_reward(2) == ERR_UNAUTHORIZED, "future tiers stay locked until their XP threshold is earned")
	var restored := CourierProfile.new(path)
	check(restored.pass_xp == 205 and restored.pass_claimed == [1] and restored.wallet == 16, "XP, claimed tiers and wallet survive a profile reload")
	for i in range(25):
		profile.award_flight(0, 100, DURING)
	check(profile.pass_xp == CourierSeasonPass.MAX_XP and profile.pass_xp == 2000, "the finite seasonal track caps at 2000 XP")
	check(profile.acquire_item("moon_trail", DURING) == ERR_UNAVAILABLE and profile.equip_item("moon_trail") == ERR_UNAUTHORIZED, "the final season cosmetic cannot be bought for zero coins or equipped early")
	check(profile.claim_pass_reward(10) == OK and profile.owned_items.has("moon_trail") and profile.equipped_trail == "moon_trail", "tier ten grants and equips the exclusive Moonbeam trail")
	profile.equip_item("mint_trail")
	check(profile.equip_item("moon_trail") == OK and profile.wallet == 16, "the earned season cosmetic remains re-equippable without paying again")
	check(profile.claim_pass_reward(10) == ERR_ALREADY_EXISTS and profile.owned_items.count("moon_trail") == 1, "the exclusive item is never duplicated by repeated reward claims")
	check(profile.claim_pass_reward(2) == OK and profile.wallet == 31, "earned rewards remain claimable without requiring the event to be active")
	restored = CourierProfile.new(path)
	check(restored.pass_claimed.has(10) and restored.equipped_trail == "moon_trail" and restored.wallet == 31, "exclusive ownership, equipment and out-of-order claims persist")
	check(profile.set_language("ja") == OK and CourierProfile.new(path).language == "ja", "language selection is saved with the existing profile")
	check(profile.set_language("unknown") == ERR_INVALID_PARAMETER and profile.language == "ja", "invalid language codes cannot replace the selected language")


func _test_pass_bad_saves() -> void:
	var path := _path()
	var file := ConfigFile.new()
	file.set_value("inventory", "wallet", 123)
	file.set_value("inventory", "owned", ["courier", "moon_trail"])
	file.set_value("inventory", "trail", "moon_trail")
	file.set_value("season_pass", "id", "unknown-season")
	file.set_value("season_pass", "xp", 2000)
	file.set_value("season_pass", "claimed", [10])
	file.save(path)
	var profile := CourierProfile.new(path)
	check(profile.wallet == 123 and profile.pass_xp == 0 and not profile.owned_items.has("moon_trail"), "an unrelated season cannot grant this season's XP or exclusive cosmetic")
	file.set_value("season_pass", "id", CourierSeasonPass.ID)
	file.set_value("season_pass", "xp", "2000")
	file.set_value("season_pass", "claimed", [10, 99, "1"])
	file.set_value("settings", "language", ["ja"])
	file.save(path)
	profile = CourierProfile.new(path)
	check(profile.pass_xp == 0 and profile.pass_claimed.is_empty() and profile.language == "et", "malformed XP, claim types and language load safe defaults")
	file.set_value("season_pass", "xp", 400)
	file.set_value("season_pass", "claimed", [1, 1, 2, 10, -1, "2"])
	file.save(path)
	profile = CourierProfile.new(path)
	check(profile.pass_claimed == [1, 2] and not profile.owned_items.has("moon_trail"), "only distinct genuinely earned tier IDs load from a saved track")
	var broken := CourierProfile.new("user://missing-locale-season-%s/profile.cfg" % Time.get_ticks_usec())
	broken.wallet = 100
	broken.pass_xp = 1999
	check(broken.award_flight(5, 5, DURING) != OK and broken.wallet == 100 and broken.pass_xp == 1999, "failed flight saving rolls back both wallet and XP atomically")
	broken.pass_xp = 2000
	check(broken.claim_pass_reward(10) != OK and broken.pass_claimed.is_empty() and not broken.owned_items.has("moon_trail") and broken.equipped_trail == "mint_trail", "failed reward saving rolls back claim, cosmetic ownership and equipment")
	check(broken.claim_pass_reward(1) != OK and broken.wallet == 100 and broken.pass_claimed.is_empty(), "failed coin-reward saving does not consume the claim or grant unsaved money")


func _test_debris() -> void:
	var effect := CourierDebris.new(14)
	var at := Vector2(540, 900)
	effect.burst(at, 126, 1)
	var quadrants: Dictionary = {}
	for shard in effect.shards:
		quadrants[Vector2(signf(shard.velocity.x), signf(shard.velocity.y))] = true
	check(quadrants.size() == 4 and effect.shards.size() >= 20, "large rock fragments radiate into all four quadrants across 360 degrees")
	check(effect.shards[0].points.size() == 5 and absf(effect.shards[0].spin) >= 2, "fragments are solid irregular rotating rock polygons")
	var first := effect.shards[0].duplicate(true)
	effect.step(1.0 / 60.0)
	check(effect.shards[0].position != first.position and effect.shards[0].angle != first.angle and effect.shards[0].life < first.life, "rock shards move outward, rotate and lose opacity over their lifetime")
	for i in range(120):
		effect.step(1.0 / 60.0)
	check(effect.shards.is_empty(), "faded fragments are removed after their finite lifetime")
	for i in range(100):
		effect.burst(at, 126, 0)
	check(effect.shards.size() == CourierDebris.MAX_SHARDS, "repeated explosions stay within a fixed mobile-friendly debris budget")
	effect.clear()
	check(effect.shards.is_empty(), "a new flight clears previous explosion debris")
	var state := CourierRun.new()
	state.begin(7)
	state.next_destination = 999
	state.asteroid_timer = 999
	state.coin_timer = 999
	state.asteroid_shattered.connect(effect.burst)
	state.asteroids.append({"position": Vector2(540, 900), "radius": 126.0, "hp": 6, "max_hp": 6,
		"size_class": 2, "variant": 1, "speed": 0.0, "drift": 0.0, "angle": 0.0, "spin": 0.0})
	for i in range(180):
		state.step(1.0 / 60.0)
	check(state.destroyed == 1 and not effect.shards.is_empty() and state.collected_coins >= 3 and state.collected_coins <= 5,
		"real bullet destruction creates solid debris and at most five coins exactly once")
	var earned := state.collected_coins
	for i in range(120):
		effect.step(1.0 / 60.0)
		state.step(1.0 / 60.0)
	check(state.collected_coins == earned and state.destroyed == 1 and state.asteroids.is_empty(), "visual fragments do not become hazards or additional coin sources")


func _all_text_nodes(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Label or node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_all_text_nodes(child))
	return result


func _test_scene_and_languages() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var original_profile = game.profile
	game.profile = CourierProfile.new(_path())
	game.profile.sound_enabled = false
	check(CourierText.device_language("pt-PT") == "pt_BR" and CourierText.device_language("zh-TW") == "zh_CN", "first-launch locale detection maps regional Portuguese and Chinese to available translations")
	check(CourierText.device_language("ar-SA") == "ar" and CourierText.device_language("ja_JP") == "ja", "first-launch detection handles hyphenated and underscored device locales")
	check(CourierText.device_language("unknown") == "en", "unsupported device languages use a readable English fallback")
	var data := CourierText.packs()
	check(CourierText.LANGUAGES.size() == 24 and data.size() == 24, "all 24 selectable languages have bundled offline translation packs")
	var english_keys: Array = data.en.keys()
	for code in CourierText.LANGUAGES:
		var complete := true
		for key in english_keys:
			complete = complete and data[code].has(key) and not str(data[code][key]).is_empty()
		check(complete and data[code].size() == english_keys.size(), "%s supplies every menu, HUD, store and season translation" % code)
		var missing := ""
		var content := str(CourierText.LANGUAGES[code])
		for value in data[code].values():
			content += value
		for index in range(content.length()):
			var point := content.unicode_at(index)
			if point < 33:
				continue
			var supported := false
			for font in [game.FONT, game.CJK_FONT, game.DEVANAGARI_FONT, game.THAI_FONT]:
				if font.has_char(point):
					supported = true
					break
			if not supported:
				missing += content[index]
		check(missing.is_empty(), "%s has font coverage for all translated characters: %s" % [code, missing])
		game._choose_language(code)
		var fits := true
		var overflow := ""
		for screen in ["home", "shop", "map", "pass", "languages", "preview"]:
			game._show_menu(screen)
			for node in _all_text_nodes(game):
				if not node.is_visible_in_tree():
					continue
				var font: Font = node.get_theme_font("font")
				var font_size := node.get_theme_font_size("font_size")
				for line in node.text.split("\n"):
					if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > node.size.x - 12:
						fits = false
						overflow += "%s: %s; " % [screen, line]
		check(fits, "%s UI text fits portrait controls: %s" % [code, overflow])
		check(game.region_label.text == CourierText.t("subtitle") and game.get_node("Home/StartButton").text == CourierText.t("start"), "%s changes static and dynamic labels immediately" % code)
	CourierText.set_language("ar")
	var rtl := CourierText.t("home_progress", [1])
	check(rtl.contains("\u20661 / 100\u2069"), "Arabic keeps progress ratios in readable left-to-right numeric order")
	check(CourierText.directional(rtl) == rtl, "composed RTL text does not accumulate nested direction markers")
	game._choose_language("et")
	game.profile.pass_xp = 2000
	game.profile.save()
	game._show_menu("pass")
	game.pass_buttons[0].pressed.emit()
	check(game.profile.wallet == 10 and game.pass_buttons[0].disabled, "the real pass claim button grants the first reward and prevents repeats")
	game._change_pass_page(1)
	game.pass_buttons[4].pressed.emit()
	check(game.profile.equipped_trail == "moon_trail" and game.profile.pass_claimed.has(10), "the final page grants the exclusive trail through a working claim button")
	game.profile.equip_item("mint_trail")
	game._sync_interface()
	game.pass_buttons[4].pressed.emit()
	check(game.profile.equipped_trail == "moon_trail" and game.profile.wallet == 10, "claimed seasonal cosmetics can be re-equipped from the pass without another payout")
	game._go_home()
	game._start_run()
	game._on_asteroid_shattered(Vector2(540, 900), 85, 0)
	game.run.pause()
	var frozen: Array = game.debris.shards.duplicate(true)
	for i in range(60):
		game._process(1.0 / 60.0)
	check(game.debris.shards == frozen, "pausing the real scene freezes every shard and its fade lifetime")
	game.run.resume()
	game._process(1.0 / 60.0)
	check(game.debris.shards != frozen, "resuming the scene continues the existing explosion")
	game._go_home()
	check(game.debris.shards.is_empty(), "leaving a flight removes old rock debris")
	game.profile = original_profile
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
