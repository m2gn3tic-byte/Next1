class_name CourierProfile
extends RefCounted
## Local, offline records. Exported web builds use Godot's IndexedDB storage.

const MAX_RATING := 3
const LEVELS := preload("res://scripts/levels.gd")

var best_score := 0
var best_deliveries := 0
var sound_enabled := true
var unlocked_level := 1
var selected_level := 1
var level_stars: Dictionary = {}
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
		best_deliveries = clampi(saved_deliveries, 0, CourierRun.DELIVERY_GOAL)
	if saved_sound is bool:
		sound_enabled = saved_sound
	_load_progress(file)


func _load_progress(file: ConfigFile) -> void:
	if not file.has_section("progress"):
		# An older full five-parcel victory is a genuine completed first region.
		# Its shield rating was not saved, so award the conservative one star.
		if best_deliveries == CourierRun.DELIVERY_GOAL:
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
	best_deliveries = maxi(best_deliveries, clampi(deliveries, 0, CourierRun.DELIVERY_GOAL))
	return save()


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value("records", "score", best_score)
	file.set_value("records", "deliveries", best_deliveries)
	file.set_value("settings", "sound", sound_enabled)
	file.set_value("progress", "unlocked_level", unlocked_level)
	file.set_value("progress", "selected_level", selected_level)
	file.set_value("progress", "stars", level_stars)
	return file.save(storage_path)
