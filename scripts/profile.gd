class_name CourierProfile
extends RefCounted
## Local, offline records. Exported web builds use Godot's IndexedDB storage.

const MAX_RATING := 3
const LEVELS := preload("res://scripts/levels.gd")
const CATALOGUE := preload("res://scripts/catalogue.gd")
const MAX_BALANCE := 999999999

var best_score := 0
var best_deliveries := 0
var sound_enabled := true
var unlocked_level := 1
var selected_level := 1
var level_stars: Dictionary = {}
var wallet := 0
var owned_items: Array[String] = ["courier", "mint_trail"]
var equipped_ship := "courier"
var equipped_trail := "mint_trail"
var auto_fire := true
var storage_path: String


func _init(path: String = "user://courier.cfg") -> void:
	storage_path = path
	var file := ConfigFile.new()
	if file.load(storage_path) != OK:
		return
	var saved_score: Variant = file.get_value("records", "score", 0)
	var saved_deliveries: Variant = file.get_value("records", "deliveries", 0)
	var saved_sound: Variant = file.get_value("settings", "sound", true)
	if saved_score is int:
		best_score = maxi(0, saved_score)
	if saved_deliveries is int:
		best_deliveries = clampi(saved_deliveries, 0, LEVELS.MAX_DELIVERIES)
	if saved_sound is bool:
		sound_enabled = saved_sound
	_load_progress(file)
	_load_inventory(file)


func _load_progress(file: ConfigFile) -> void:
	if not file.has_section("progress"):
		# An older full five-parcel victory is a genuine completed first region.
		# Its shield rating was not saved, so award the conservative one star.
		if best_deliveries >= 5:
			level_stars[1] = 1
			unlocked_level = mini(2, LEVELS.COUNT)
		return
	var saved_stars: Variant = file.get_value("progress", "stars", {})
	if saved_stars is Dictionary:
		# Valid progression is contiguous: a later completion cannot skip a region.
		for number in range(1, LEVELS.COUNT + 1):
			var rating: Variant = saved_stars.get(number, 0)
			if not rating is int or rating < 1 or rating > MAX_RATING:
				break
			level_stars[number] = rating
	var available := 1
	while available < LEVELS.COUNT and level_stars.has(available):
		available += 1
	var saved_unlocked: Variant = file.get_value("progress", "unlocked_level", 1)
	if saved_unlocked is int and saved_unlocked >= 1 and saved_unlocked <= LEVELS.COUNT:
		unlocked_level = mini(saved_unlocked, available)
	# Old saves capped at three regions even after the third victory.
	if not file.has_section("inventory") and level_stars.has(3):
		unlocked_level = maxi(unlocked_level, 4)
	var saved_selected: Variant = file.get_value("progress", "selected_level", 1)
	if saved_selected is int and saved_selected >= 1 and saved_selected <= unlocked_level:
		selected_level = saved_selected
	for number in level_stars.keys():
		if number > unlocked_level:
			level_stars.erase(number)


func stars_for_level(number: int) -> int:
	return int(level_stars.get(number, 0))


func select_level(number: int) -> Error:
	if number < 1 or number > LEVELS.COUNT:
		return ERR_INVALID_PARAMETER
	if number > unlocked_level:
		return ERR_UNAUTHORIZED
	selected_level = number
	return save()


func complete_level(number: int, shields: int) -> Error:
	if number < 1 or number > LEVELS.COUNT or shields < 1 or shields > MAX_RATING:
		return ERR_INVALID_PARAMETER
	if number > unlocked_level:
		return ERR_UNAUTHORIZED
	level_stars[number] = maxi(stars_for_level(number), shields)
	unlocked_level = maxi(unlocked_level, mini(number + 1, LEVELS.COUNT))
	return save()


func record(score: int, deliveries: int) -> Error:
	best_score = maxi(best_score, score)
	best_deliveries = maxi(best_deliveries, clampi(deliveries, 0, LEVELS.MAX_DELIVERIES))
	return save()


func _load_inventory(file: ConfigFile) -> void:
	var saved_wallet: Variant = file.get_value("inventory", "wallet", 0)
	if saved_wallet is int and saved_wallet >= 0 and saved_wallet <= MAX_BALANCE:
		wallet = saved_wallet
	var saved_owned: Variant = file.get_value("inventory", "owned", [])
	if saved_owned is Array:
		for id in saved_owned:
			if id is String and not owned_items.has(id):
				var data := CATALOGUE.item(id)
				if not data.is_empty() and data.access in ["coins", "season_gift"]:
					owned_items.append(id)
	var ship: Variant = file.get_value("inventory", "ship", "courier")
	var tail: Variant = file.get_value("inventory", "trail", "mint_trail")
	if ship is String and owned_items.has(ship) and CATALOGUE.item(ship).kind == "ship":
		equipped_ship = ship
	if tail is String and owned_items.has(tail) and CATALOGUE.item(tail).kind == "trail":
		equipped_trail = tail
	var saved_fire: Variant = file.get_value("settings", "auto_fire", true)
	if saved_fire is bool:
		auto_fire = saved_fire


func credit_coins(amount: int) -> Error:
	if amount < 1 or amount > MAX_BALANCE - wallet:
		return ERR_INVALID_PARAMETER
	wallet += amount
	var result := save()
	if result != OK:
		wallet -= amount
	return result


func acquire_item(id: String, date: Dictionary = {}) -> Error:
	var data := CATALOGUE.item(id)
	if data.is_empty():
		return ERR_INVALID_PARAMETER
	if data.access == "premium":
		return ERR_UNAVAILABLE
	if owned_items.has(id):
		return ERR_ALREADY_EXISTS
	if data.access == "season_gift" and not CATALOGUE.halloween_active(date):
		return ERR_UNAVAILABLE
	if wallet < int(data.price):
		return ERR_UNAUTHORIZED
	var previous_ship := equipped_ship
	var previous_trail := equipped_trail
	wallet -= int(data.price)
	owned_items.append(id)
	if data.kind == "ship":
		equipped_ship = id
	else:
		equipped_trail = id
	var result := save()
	if result != OK:
		wallet += int(data.price)
		owned_items.erase(id)
		equipped_ship = previous_ship
		equipped_trail = previous_trail
	return result


func equip_item(id: String) -> Error:
	if not owned_items.has(id):
		return ERR_UNAUTHORIZED
	var previous_ship := equipped_ship
	var previous_trail := equipped_trail
	if CATALOGUE.item(id).kind == "ship":
		equipped_ship = id
	else:
		equipped_trail = id
	var result := save()
	if result != OK:
		equipped_ship = previous_ship
		equipped_trail = previous_trail
	return result


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value("records", "score", best_score)
	file.set_value("records", "deliveries", best_deliveries)
	file.set_value("settings", "sound", sound_enabled)
	file.set_value("settings", "auto_fire", auto_fire)
	file.set_value("progress", "unlocked_level", unlocked_level)
	file.set_value("progress", "selected_level", selected_level)
	file.set_value("progress", "stars", level_stars)
	file.set_value("inventory", "wallet", wallet)
	file.set_value("inventory", "owned", owned_items)
	file.set_value("inventory", "ship", equipped_ship)
	file.set_value("inventory", "trail", equipped_trail)
	# Keep the previous complete save if writing the replacement fails.
	var temporary := storage_path + ".tmp"
	var result := file.save(temporary)
	if result != OK:
		return result
	return DirAccess.rename_absolute(temporary, storage_path)
