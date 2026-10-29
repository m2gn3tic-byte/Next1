class_name CourierRun
extends RefCounted
## Deterministic game rules, independent of drawing, audio and platform input.

signal event(kind: String, at: Vector2, amount: int)

enum Mode { READY, FLYING, PAUSED, WON, LOST }

const WORLD := Vector2(1080.0, 1920.0)
const SHIP_RADIUS := 36.0
const SHIP_SPEED := 1180.0
const DELIVERY_GOAL := 5
const DOCK_RADIUS := 110.0
const DOCK_TIME := 0.5
const MAX_SHIELDS := 3
const LEVELS := preload("res://scripts/levels.gd")

var mode: Mode = Mode.READY
var level := 1
var ship := Vector2(540.0, 1380.0)
var target := ship
var asteroids: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var shields := MAX_SHIELDS
var delivered := 0
var collected_coins := 0
var score := 0
var elapsed := 0.0
var invincible_for := 0.0
var destination_active := false
var destination := Vector2.ZERO
var dock_progress := 0.0
var asteroid_timer := 0.8
var coin_timer := 0.5
var next_destination := 5.0
var rng := RandomNumberGenerator.new()


func begin(seed_value: int = -1, level_number: int = 1) -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	mode = Mode.FLYING
	level = clampi(level_number, 1, LEVELS.COUNT)
	ship = Vector2(540.0, 1380.0)
	target = ship
	asteroids.clear()
	coins.clear()
	shields = MAX_SHIELDS
	delivered = 0
	collected_coins = 0
	score = 0
	elapsed = 0.0
	invincible_for = 1.5
	destination_active = false
	destination = Vector2.ZERO
	dock_progress = 0.0
	asteroid_timer = 0.8
	coin_timer = 0.5
	next_destination = 5.0


func steer(position: Vector2) -> void:
	if mode == Mode.FLYING:
		target = position.clamp(Vector2(90.0, 350.0), Vector2(990.0, 1620.0))


func pause() -> void:
	if mode == Mode.FLYING:
		mode = Mode.PAUSED
		target = ship


func resume() -> void:
	if mode == Mode.PAUSED:
		mode = Mode.FLYING
		target = ship


func dock_position() -> Vector2:
	return destination + Vector2(0.0, 220.0)


func step(delta: float) -> void:
	if mode != Mode.FLYING or delta <= 0.0:
		return
	# Cap catch-up after a stalled/backgrounded frame; don't tunnel through hazards.
	var dt := minf(delta, 1.0 / 30.0)
	elapsed += dt
	invincible_for = maxf(0.0, invincible_for - dt)
	ship = ship.move_toward(target, SHIP_SPEED * dt)
	var settings := LEVELS.get_level(level)
	var speed: float = settings.speed + delivered * 28.0

	if not destination_active and elapsed >= next_destination:
		destination_active = true
		destination = Vector2(rng.randf_range(270.0, 810.0), -240.0)
		dock_progress = 0.0
		event.emit("destination", destination, delivered + 1)

	if destination_active:
		destination.y = minf(540.0, destination.y + speed * dt)
		# Reserve a real clear approach around the landing pad, not just its center.
		for i in range(asteroids.size() - 1, -1, -1):
			if asteroids[i].position.distance_to(dock_position()) < asteroids[i].radius + 240.0:
				asteroids.remove_at(i)
		if destination.y >= 400.0 and ship.distance_to(dock_position()) < DOCK_RADIUS:
			dock_progress += dt / DOCK_TIME
			if dock_progress >= 1.0:
				_deliver()
		else:
			dock_progress = 0.0

	if mode != Mode.FLYING:
		return
	if not destination_active:
		asteroid_timer -= dt
		if asteroid_timer <= 0.0:
			_spawn_asteroid(speed)
			asteroid_timer = maxf(0.64, float(settings.spawn_interval) - delivered * 0.08)
		coin_timer -= dt
		if coin_timer <= 0.0:
			_spawn_coins(speed)
			coin_timer = 2.1

	for i in range(coins.size() - 1, -1, -1):
		var coin: Dictionary = coins[i]
		coin.position.y += coin.speed * dt
		if coin.position.distance_to(ship) < SHIP_RADIUS + 28.0:
			collected_coins += 1
			score += 20
			coins.remove_at(i)
			event.emit("coin", coin.position, 1)
		elif coin.position.y > WORLD.y + 80.0:
			coins.remove_at(i)

	for i in range(asteroids.size() - 1, -1, -1):
		var rock: Dictionary = asteroids[i]
		rock.position.y += rock.speed * dt
		var drift := float(rock.get("drift", 0.0))
		rock.position.x += drift * dt
		var left_edge: float = rock.radius + 15.0
		var right_edge: float = WORLD.x - rock.radius - 15.0
		if rock.position.x < left_edge or rock.position.x > right_edge:
			rock.position.x = clampf(rock.position.x, left_edge, right_edge)
			rock["drift"] = -drift
		rock.angle += rock.spin * dt
		if rock.position.y > WORLD.y + rock.radius:
			asteroids.remove_at(i)
		elif invincible_for <= 0.0 and rock.position.distance_to(ship) < SHIP_RADIUS + rock.radius * 0.82:
			asteroids.remove_at(i)
			shields -= 1
			invincible_for = 1.6
			event.emit("hit", ship, shields)
			if shields == 0:
				mode = Mode.LOST
				event.emit("lost", ship, score)
				break


func _deliver() -> void:
	delivered += 1
	collected_coins += 5
	score += 150
	destination_active = false
	dock_progress = 0.0
	next_destination = elapsed + 7.0
	invincible_for = maxf(invincible_for, 2.0)
	asteroid_timer = 1.5
	# Give the player time to leave the previous landing spot.
	asteroids = asteroids.filter(func(rock: Dictionary) -> bool:
		return rock.position.distance_to(ship) > rock.radius + 260.0)
	event.emit("delivery", dock_position(), delivered)
	if delivered % 2 == 0 and shields < MAX_SHIELDS:
		shields += 1
		event.emit("repair", ship, shields)
	if delivered == DELIVERY_GOAL:
		score += 300 + shields * 100
		mode = Mode.WON
		event.emit("won", ship, score)


func _spawn_asteroid(speed: float) -> void:
	var radius := rng.randf_range(68.0, 126.0)
	var position := Vector2(rng.randf_range(radius + 15.0, WORLD.x - radius - 15.0), -160.0)
	for rock in asteroids:
		if rock.position.distance_to(position) < rock.radius + radius + 90.0:
			return
	asteroids.append({
		"position": position, "radius": radius, "speed": speed,
		"angle": rng.randf_range(-PI, PI), "spin": rng.randf_range(-0.32, 0.32),
		"variant": rng.randi_range(0, 1),
		"drift": float(LEVELS.get_level(level).drift) * (-1.0 if rng.randf() < 0.5 else 1.0),
	})


func _spawn_coins(speed: float) -> void:
	var x := rng.randf_range(190.0, 890.0)
	for i in range(3):
		var position := Vector2(x + sin(float(i)) * 45.0, -160.0 - i * 100.0)
		var clear := true
		for rock in asteroids:
			if rock.position.distance_to(position) < rock.radius + 85.0:
				clear = false
				break
		if clear:
			coins.append({"position": position, "speed": speed})
