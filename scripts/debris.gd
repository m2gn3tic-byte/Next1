class_name CourierDebris
extends RefCounted
## Visual shards only: they never collide, spawn asteroids or award coins.

const MAX_SHARDS := 240
var shards: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 7742) -> void:
	rng.seed = seed_value


func burst(at: Vector2, radius: float, variant: int) -> void:
	var count := clampi(int(radius / 5.0), 10, 26)
	var offset := rng.randf_range(0.0, TAU)
	for i in range(count):
		# Stratified angles guarantee debris across the entire circle.
		var angle := offset + (i + rng.randf_range(0.15, 0.85)) * TAU / count
		var direction := Vector2.from_angle(angle)
		var size_px := rng.randf_range(8.0, 23.0) * sqrt(radius / 85.0)
		var points := PackedVector2Array()
		for corner in range(5):
			points.append(Vector2.from_angle(corner * TAU / 5.0) * size_px * rng.randf_range(0.55, 1.0))
		var duration := rng.randf_range(0.65, 1.25)
		shards.append({"position": at + direction * radius * 0.2,
			"velocity": direction * rng.randf_range(190.0, 450.0),
			"angle": rng.randf_range(0, TAU), "spin": rng.randf_range(2.0, 6.0) * (-1 if i % 2 == 0 else 1),
			"life": duration, "duration": duration, "points": points,
			"color": Color("aa91bf") if variant == 1 else Color("8c93ae")})
	while shards.size() > MAX_SHARDS:
		shards.pop_front()


func step(delta: float) -> void:
	var dt := clampf(delta, 0.0, 1.0 / 30.0)
	for i in range(shards.size() - 1, -1, -1):
		var shard := shards[i]
		shard.life -= dt
		if shard.life <= 0:
			shards.remove_at(i)
			continue
		shard.position += shard.velocity * dt
		shard.velocity *= exp(-1.7 * dt)
		shard.angle += shard.spin * dt


func clear() -> void:
	shards.clear()
