class_name CourierProfile
extends RefCounted
## Local, offline records. Exported web builds use Godot's IndexedDB storage.

var best_score := 0
var best_deliveries := 0
var sound_enabled := true
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


func record(score: int, deliveries: int) -> Error:
	best_score = maxi(best_score, score)
	best_deliveries = maxi(best_deliveries, clampi(deliveries, 0, CourierRun.DELIVERY_GOAL))
	return save()


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value("records", "score", best_score)
	file.set_value("records", "deliveries", best_deliveries)
	file.set_value("settings", "sound", sound_enabled)
	return file.save(storage_path)
