extends Node2D

var target: Node2D
var game
var def: Dictionary
var damage := 0.0
var speed := 420.0
var hit_time := -1.0  # >= 0 mientras se muestra la explosión


func _process(delta: float) -> void:
	if hit_time >= 0.0:
		hit_time += delta
		queue_redraw()
		if hit_time > 0.18:
			queue_free()
		return
	if not is_instance_valid(target) or not target.alive:
		queue_free()
		return
	var to := target.position - position
	var step := speed * delta
	if to.length() <= step + 4.0:
		position = target.position
		_hit()
	else:
		position += to.normalized() * step
		queue_redraw()


func _hit() -> void:
	if def.has("splash"):
		var radius: float = def.splash * game.mods.splash
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive and e.position.distance_to(position) <= radius:
				e.take_damage(damage)
		hit_time = 0.0
		return
	target.take_damage(damage)
	if def.has("slow") and target.alive:
		target.apply_slow(maxf(0.15, def.slow - game.mods.slow), def.slow_time)
	queue_free()


func _draw() -> void:
	if hit_time >= 0.0:
		var radius: float = def.splash * game.mods.splash
		var a := 1.0 - hit_time / 0.18
		draw_circle(Vector2.ZERO, radius, Color(1, 0.4, 0.5, 0.35 * a))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1, 0.5, 0.6, a), 2.0)
	else:
		draw_circle(Vector2.ZERO, 5.0, def.color.darkened(0.2))
