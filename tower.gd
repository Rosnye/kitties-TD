extends Node2D

const Data = preload("res://data.gd")
const Projectile = preload("res://projectile.gd")

var type: String
var def: Dictionary
var game
var cell: Vector2i
var paid := 0
var cooldown := 0.0
var facing := Vector2.DOWN


func setup(t: String, g, c: Vector2i, cost: int) -> void:
	type = t
	def = Data.TOWERS[t]
	game = g
	cell = c
	paid = cost


func get_range() -> float:
	return def.range * game.mods.range


func _process(delta: float) -> void:
	cooldown -= delta
	var target = _find_target()
	if target == null:
		return
	facing = (target.position - position).normalized()
	queue_redraw()
	if cooldown <= 0.0:
		_shoot(target)
		cooldown = 1.0 / (def.rate * game.mods.rate)


func _find_target():
	var best = null
	var best_dist := -1.0
	var r := get_range()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.alive and e.position.distance_to(position) <= r and e.dist > best_dist:
			best = e
			best_dist = e.dist
	return best


func _shoot(target) -> void:
	var p := Projectile.new()
	p.position = position
	p.target = target
	p.game = game
	p.def = def
	p.damage = def.damage * game.mods.dmg
	game.add_child(p)


func _draw() -> void:
	var col: Color = def.color
	# orejas
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -8), Vector2(-17, -30), Vector2(-3, -19)]), col.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(20, -8), Vector2(17, -30), Vector2(3, -19)]), col.darkened(0.15))
	# cara
	draw_circle(Vector2.ZERO, 23.0, col)
	match type:
		"basic":
			for x in [-8.0, 0.0, 8.0]:
				draw_line(Vector2(x, -22), Vector2(x, -13), col.darkened(0.35), 3.0)
		"siamese":
			draw_circle(Vector2(0, 5), 13.0, Color(0.35, 0.25, 0.2))
		"yarn":
			draw_circle(Vector2(15, 17), 8.0, Color(0.85, 0.2, 0.3))
			draw_arc(Vector2(15, 17), 8.0, 0.5, 3.5, 8, Color(1, 0.6, 0.65), 1.5)
	# ojos que siguen al objetivo
	for x in [-9.0, 9.0]:
		draw_circle(Vector2(x, -3), 6.0, Color.WHITE)
		draw_circle(Vector2(x, -3) + facing * 2.5, 3.0, Color.BLACK)
	draw_circle(Vector2(0, 7), 2.5, Color(0.95, 0.55, 0.6))
	draw_line(Vector2(-4, 10), Vector2(-16, 8), Color(0.15, 0.15, 0.15), 1.0)
	draw_line(Vector2(4, 10), Vector2(16, 8), Color(0.15, 0.15, 0.15), 1.0)
