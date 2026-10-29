class_name CourierLevels
extends RefCounted
## A finite, deterministic 100-stop campaign. Saved level IDs remain one-based.

const COUNT := 100
const MAX_DELIVERIES := 7
const GOALS := [2, 3, 5, 2, 4, 3, 6, 4, 5, 7]
const REGIONS := [
	["Mündiorbiit", "9af5d3", Color.WHITE, Color.WHITE],
	["Udumets", "d3b8ff", Color(1.65, 0.78, 1.4), Color(0.96, 0.90, 1.12)],
	["Kristallivöö", "ffcf6d", Color(1.95, 0.84, 0.6), Color(1.12, 0.95, 0.90)],
	["Komeedisadam", "8cdaff", Color(0.9, 1.1, 1.5), Color(0.86, 1.02, 1.12)],
	["Roosakas udu", "ffb5d1", Color(1.65, 0.75, 1.15), Color(1.12, 0.90, 1.03)],
	["Jääpeegel", "c2f3ff", Color(0.9, 1.25, 1.5), Color(0.83, 1.03, 1.15)],
	["Päikesetuul", "ffb777", Color(1.9, 0.74, 0.5), Color(1.18, 0.91, 0.86)],
	["Smaragdkaar", "9fffad", Color(0.9, 1.4, 0.9), Color(0.9, 1.1, 0.94)],
	["Öölaternad", "c5b3ff", Color(1.45, 0.7, 1.7), Color(0.96, 0.85, 1.18)],
	["Tähevärav", "ffe5a1", Color(1.9, 1.15, 0.7), Color(1.13, 1.02, 0.92)],
]


static func get_level(number: int) -> Dictionary:
	var index := clampi(number, 1, COUNT) - 1
	var tier := int(index / 10)
	var stop := index % 10
	var region: Array = REGIONS[tier]
	var goal: int = GOALS[(stop + tier * 3) % GOALS.size()]
	if index == COUNT - 1:
		goal = MAX_DELIVERIES
	return {
		"name": CourierText.t("region_%s" % tier), "tier": tier, "goal": goal,
		"description": CourierText.t("level_description", [goal, tier + 1]),
		"accent": Color(region[1]), "planet_tint": region[2], "sky_tint": region[3],
		"speed": 260.0 + tier * 18.0 + stop * 1.5,
		"spawn_interval": maxf(0.80, 1.12 - tier * 0.030 - stop * 0.004),
		"drift": 0.0 if tier == 0 else 9.0 + tier * 8.0,
	}
