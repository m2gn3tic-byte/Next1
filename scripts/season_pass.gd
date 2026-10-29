class_name CourierSeasonPass
extends RefCounted
## One free Halloween track. The premium track is an unavailable preview.

const ID := "halloween-2026"
const TIER_COUNT := 10
const XP_PER_TIER := 200
const MAX_XP := TIER_COUNT * XP_PER_TIER
const COIN_REWARDS := [10, 15, 20, 25, 30, 35, 40, 45, 50, 0]


static func reward(tier: int) -> Dictionary:
	if tier < 1 or tier > TIER_COUNT:
		return {}
	return {"coins": COIN_REWARDS[tier - 1], "item": "moon_trail" if tier == 10 else "", "xp": tier * XP_PER_TIER}
