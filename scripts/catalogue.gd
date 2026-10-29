class_name CourierCatalogue
extends RefCounted
## Cosmetic items only. Premium ownership is never granted by the offline client.

const HALLOWEEN_START := 20261015
const HALLOWEEN_END := 20261107
const SHOP_IDS := ["aurora", "comet", "violet_trail", "gold_trail", "pumpkin", "nightwing"]
const ITEMS := {
	"courier": {"name": "Postilind", "kind": "ship", "price": 0, "access": "starter", "art": "res://assets/ship.svg", "color": Color("9af5d3")},
	"aurora": {"name": "Virmaline", "kind": "ship", "price": 90, "access": "coins", "art": "res://assets/aurora.svg", "color": Color("9af5d3")},
	"comet": {"name": "Komeet", "kind": "ship", "price": 180, "access": "coins", "art": "res://assets/comet.svg", "color": Color("8cdaff")},
	"mint_trail": {"name": "Tähetolm", "kind": "trail", "price": 0, "access": "starter", "color": Color("9af5d3")},
	"violet_trail": {"name": "Udujälg", "kind": "trail", "price": 60, "access": "coins", "color": Color("d3b8ff")},
	"gold_trail": {"name": "Kuldjälg", "kind": "trail", "price": 100, "access": "coins", "color": Color("ffcf6d")},
	"pumpkin": {"name": "Kõrvitsakuller", "kind": "ship", "price": 0, "access": "season_gift", "art": "res://assets/pumpkin.svg", "color": Color("ffac66")},
	"nightwing": {"name": "Öötiib", "kind": "ship", "price": 0, "access": "premium", "art": "res://assets/nightwing.svg", "color": Color("d3b8ff")},
}


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {}).duplicate(true)


static func date_number(date: Dictionary) -> int:
	return int(date.get("year", 0)) * 10000 + int(date.get("month", 0)) * 100 + int(date.get("day", 0))


static func halloween_active(date: Dictionary = {}) -> bool:
	var today := date_number(Time.get_datetime_dict_from_system(true) if date.is_empty() else date)
	return today >= HALLOWEEN_START and today <= HALLOWEEN_END
