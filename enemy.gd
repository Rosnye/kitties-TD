extends Node2D

const Data = preload("res://data.gd")

signal died(enemy)
signal escaped(enemy)

var type: String
var def: Dictionary
var hp: float
var max_hp: float
var path: Array = []
var idx := 1
var dist := 0.0  # distancia recorrida, para elegir el objetivo más avanzado
var slow_mult := 1.0
var slow_left := 0.0
var alive := true


func setup(t: String, hp_scale: float, pts: Array) -> void:
	type = t
	def = Data.ENEMIES[t]
	max_hp = def.hp * hp_scale
	hp = max_hp
	path = pts
	position = pts[0]


func _process(delta: float) -> void:
	if slow_left > 0.0:
		slow_left -= delta
		if slow_left <= 0.0:
			slow_mult = 1.0
	var step: float = def.speed * slow_mult * delta
	dist += step
	while step > 0.0:
		var target: Vector2 = path[idx]
		var d := position.distance_to(target)
		if d <= step:
			position = target
			step -= d
			idx += 1
			if idx >= path.size():
				alive = false
				escaped.emit(self)
				queue_free()
				return
		else:
			position += (target - position) / d * step
			step = 0.0
	queue_redraw()


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		alive = false
		died.emit(self)
		queue_free()


func apply_slow(factor: float, time: float) -> void:
	slow_mult = minf(slow_mult, factor)
	slow_left = maxf(slow_left, time)


func _draw() -> void:
	var r: float = def.radius
	var col: Color = def.color
	if slow_left > 0.0:
		col = col.lerp(Color(0.5, 0.7, 1.0), 0.5)
	draw_circle(Vector2(-r * 0.5, -r * 0.7), r * 0.4, col.lightened(0.25))
	draw_circle(Vector2(r * 0.5, -r * 0.7), r * 0.4, col.lightened(0.25))
	draw_circle(Vector2.ZERO, r, col)
	draw_circle(Vector2(-r * 0.35, -r * 0.1), r * 0.14, Color.BLACK)
	draw_circle(Vector2(r * 0.35, -r * 0.1), r * 0.14, Color.BLACK)
	draw_circle(Vector2(0, r * 0.25), r * 0.12, Color(0.9, 0.5, 0.55))
	if hp < max_hp:
		var w := r * 2.0
		draw_rect(Rect2(-r, -r - 12, w, 4), Color(0.4, 0.05, 0.05))
		draw_rect(Rect2(-r, -r - 12, w * hp / max_hp, 4), Color(0.2, 0.85, 0.3))
