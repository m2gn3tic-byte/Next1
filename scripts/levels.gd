class_name CourierLevels
extends RefCounted
## Small, hand-tuned regions; level numbers in saves and UI are one-based.

const COUNT := 3
const DEFINITIONS := [
	{
		"name": "Mündiorbiit", "description": "Rahulik algus. Leia oma lennurütm.",
		"accent": Color("9af5d3"), "planet_tint": Color.WHITE,
		"sky_tint": Color.WHITE, "speed": 260.0, "spawn_interval": 1.12, "drift": 0.0,
	},
	{
		"name": "Udumets", "description": "Lillakas udu ja vaikselt triivivad asteroidid.",
		"accent": Color("d3b8ff"), "planet_tint": Color(1.65, 0.78, 1.4),
		"sky_tint": Color(0.96, 0.90, 1.12), "speed": 286.0, "spawn_interval": 1.02, "drift": 22.0,
	},
	{
		"name": "Kristallivöö", "description": "Kiirem lend läbi kuldse asteroidivöö.",
		"accent": Color("ffcf6d"), "planet_tint": Color(1.95, 0.84, 0.6),
		"sky_tint": Color(1.12, 0.95, 0.90), "speed": 312.0, "spawn_interval": 0.94, "drift": 38.0,
	},
]


static func get_level(number: int) -> Dictionary:
	# Return a copy so UI animation or tests cannot mutate the shared definitions.
	return DEFINITIONS[clampi(number, 1, COUNT) - 1].duplicate(true)
