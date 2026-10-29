class_name CourierText
extends RefCounted
## Bundled offline translations. Stable keys keep game rules independent of language.

const LANGUAGES := {
	"et": "Eesti", "en": "English", "es": "Español", "pt_BR": "Português (BR)",
	"fr": "Français", "de": "Deutsch", "it": "Italiano", "nl": "Nederlands",
	"pl": "Polski", "ro": "Română", "fi": "Suomi", "sv": "Svenska",
	"tr": "Türkçe", "ru": "Русский", "uk": "Українська", "el": "Ελληνικά",
	"id": "Bahasa Indonesia", "vi": "Tiếng Việt", "th": "ไทย", "ar": "العربية",
	"hi": "हिन्दी", "zh_CN": "简体中文", "ja": "日本語", "ko": "한국어",
}
static var language := "et"
static var _packs: Dictionary = {}
static var _number_runs: RegEx


static func supports(code: String) -> bool:
	return LANGUAGES.has(code)


static func device_language(locale: String) -> String:
	var normalized := locale.replace("-", "_").to_lower()
	for code in LANGUAGES:
		if str(code).to_lower() == normalized:
			return code
	var base := normalized.split("_")[0]
	if base == "pt":
		return "pt_BR"
	if base == "zh":
		return "zh_CN"
	return base if supports(base) else "en"


static func set_language(code: String) -> void:
	language = code if supports(code) else "en"


static func packs() -> Dictionary:
	if _packs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/i18n/strings.json"))
		if parsed is Dictionary:
			_packs = parsed
	return _packs


static func has(key: String) -> bool:
	return packs().get("en", {}).has(key)


static func t(key: String, arguments: Array = []) -> String:
	var data := packs()
	var value: String = data.get(language, {}).get(key, data.get("en", {}).get(key, key))
	return directional(value if arguments.is_empty() else value % arguments)


static func directional(value: String) -> String:
	if language != "ar":
		return value
	# Keep ratios, ranges and XP in logical order within right-to-left sentences.
	# Strip our own previous isolates so composing translated strings is idempotent.
	value = value.replace("\u2066", "").replace("\u2069", "")
	if _number_runs == null:
		_number_runs = RegEx.new()
		_number_runs.compile("[0-9]+(?:[ /–—:.-]+[0-9]+)*(?: ?(?:XP|P))?")
	var result := ""
	var cursor := 0
	for found in _number_runs.search_all(value):
		result += value.substr(cursor, found.get_start() - cursor) + "\u2066" + found.get_string() + "\u2069"
		cursor = found.get_end()
	return result + value.substr(cursor)
