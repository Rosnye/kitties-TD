extends Node2D

const Data = preload("res://data.gd")
const Enemy = preload("res://enemy.gd")
const Tower = preload("res://tower.gd")

const CELL := 64
const COLS := 16
const ROWS := 9
const ORIGIN := Vector2(0, 64)
const MAX_WAVES := 10
const WAYPOINT_CELLS := [
	Vector2i(-1, 2), Vector2i(3, 2), Vector2i(3, 6), Vector2i(8, 6),
	Vector2i(8, 1), Vector2i(12, 1), Vector2i(12, 5), Vector2i(16, 5),
]

enum State { BUILD, WAVE, CHOOSING, OVER }

var state := State.BUILD
var lives := 20
var coins := 200
var wave := 0
var hp_scale := 1.0
var mods := {
	"dmg": 1.0, "range": 1.0, "rate": 1.0, "splash": 1.0,
	"slow": 0.0, "bounty": 1.0, "income": 0, "discount": 0.0,
}
var path_points: Array = []
var path_cells := {}
var towers := {}  # Vector2i -> Tower
var selected := "basic"
var spawn_queue: Array = []
var spawn_timer := 0.0
var spawn_interval := 0.8
var hover_cell := Vector2i(-99, -99)
var autotest := false

var info_label: Label
var start_button: Button
var tower_buttons := {}
var ui: CanvasLayer


func _ready() -> void:
	_build_path()
	_build_ui()
	_update_ui()
	if "--autotest" in OS.get_cmdline_user_args():
		_setup_autotest()


# ---------------------------------------------------------------- camino

func cell_center(c: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _build_path() -> void:
	for c in WAYPOINT_CELLS:
		path_points.append(cell_center(c))
	for i in range(WAYPOINT_CELLS.size() - 1):
		var a: Vector2i = WAYPOINT_CELLS[i]
		var b: Vector2i = WAYPOINT_CELLS[i + 1]
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var c := a
		path_cells[c] = true
		while c != b:
			c += step
			path_cells[c] = true


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 10)
	bar.add_theme_constant_override("separation", 10)
	ui.add_child(bar)

	info_label = Label.new()
	info_label.custom_minimum_size = Vector2(330, 0)
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(info_label)

	var group := ButtonGroup.new()
	var keys := Data.TOWERS.keys()
	for i in keys.size():
		var k: String = keys[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = (k == selected)
		b.pressed.connect(_select_tower.bind(k))
		bar.add_child(b)
		tower_buttons[k] = b

	start_button = Button.new()
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(_start_wave)
	bar.add_child(start_button)

	var hint := Label.new()
	hint.text = "Clic: construir  |  Clic derecho: vender (70%)  |  1-3: elegir gato  |  Espacio: iniciar oleada"
	hint.position = Vector2(8, 40)
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	ui.add_child(hint)


func tower_cost(t: String) -> int:
	return int(round(Data.TOWERS[t].cost * (1.0 - mods.discount)))


func _update_ui() -> void:
	info_label.text = "Vidas: %d    Monedas: %d    Oleada: %d/%d" % [lives, coins, wave, MAX_WAVES]
	var i := 1
	for k in tower_buttons:
		tower_buttons[k].text = "%d. %s (%d)" % [i, Data.TOWERS[k].name, tower_cost(k)]
		i += 1
	start_button.disabled = state != State.BUILD
	start_button.text = "Iniciar oleada %d" % (wave + 1)


func _select_tower(k: String) -> void:
	selected = k
	tower_buttons[k].button_pressed = true


# ---------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	if state == State.OVER:
		return
	if event is InputEventMouseButton and event.pressed:
		var cell := _pos_to_cell(get_global_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_sell(cell)
	elif event is InputEventKey and event.pressed and not event.echo:
		var keys := Data.TOWERS.keys()
		match event.keycode:
			KEY_1: _select_tower(keys[0])
			KEY_2: _select_tower(keys[1])
			KEY_3: _select_tower(keys[2])
			KEY_SPACE:
				if state == State.BUILD:
					_start_wave()


func _pos_to_cell(p: Vector2) -> Vector2i:
	var v := (p - ORIGIN) / CELL
	return Vector2i(floori(v.x), floori(v.y))


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < COLS and c.y >= 0 and c.y < ROWS


func _can_build(c: Vector2i) -> bool:
	return _in_grid(c) and not path_cells.has(c) and not towers.has(c)


func _try_place(c: Vector2i) -> void:
	if state == State.CHOOSING or not _can_build(c):
		return
	var cost := tower_cost(selected)
	if coins < cost:
		return
	coins -= cost
	var t := Tower.new()
	t.setup(selected, self, c, cost)
	t.position = cell_center(c)
	add_child(t)
	towers[c] = t
	_update_ui()


func _try_sell(c: Vector2i) -> void:
	if not towers.has(c):
		return
	var t = towers[c]
	coins += int(t.paid * 0.7)
	t.queue_free()
	towers.erase(c)
	_update_ui()


# ---------------------------------------------------------------- oleadas

func _start_wave() -> void:
	if state != State.BUILD:
		return
	wave += 1
	state = State.WAVE
	hp_scale = 1.0 + 0.09 * (wave - 1)
	spawn_queue = []
	for i in 5 + wave * 2:
		spawn_queue.append("mouse")
	if wave >= 3:
		for i in wave:
			spawn_queue.append("fast")
	if wave >= 5:
		for i in wave - 4:
			spawn_queue.append("rat")
	spawn_queue.shuffle()
	spawn_interval = maxf(0.35, 0.9 - 0.05 * wave)
	spawn_timer = 0.0
	_update_ui()


func _spawn(t: String) -> void:
	var e := Enemy.new()
	e.setup(t, hp_scale, path_points)
	e.add_to_group("enemies")
	e.died.connect(_on_enemy_died)
	e.escaped.connect(_on_enemy_escaped)
	add_child(e)


func _on_enemy_died(e) -> void:
	coins += int(round(e.def.reward * mods.bounty))
	_update_ui()


func _on_enemy_escaped(e) -> void:
	lives -= e.def.damage
	_update_ui()
	if lives <= 0:
		_end_game(false)


func _wave_complete() -> void:
	coins += 40 + wave * 8 + int(mods.income)
	if wave >= MAX_WAVES:
		_end_game(true)
		return
	state = State.CHOOSING
	_update_ui()
	_show_upgrades()


# ---------------------------------------------------------------- mejoras

func _show_upgrades() -> void:
	var pool := Data.UPGRADES.duplicate()
	pool.shuffle()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Oleada %d superada. Elige una mejora:" % wave
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for i in 3:
		var u: Dictionary = pool[i]
		var b := Button.new()
		b.text = "%s\n%s" % [u.name, u.desc]
		b.custom_minimum_size = Vector2(380, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_choose_upgrade.bind(u.id, panel))
		box.add_child(b)


func _choose_upgrade(id: String, panel: Control) -> void:
	_apply_upgrade(id)
	panel.queue_free()
	state = State.BUILD
	_update_ui()


func _apply_upgrade(id: String) -> void:
	match id:
		"dmg": mods.dmg += 0.2
		"range": mods.range += 0.15
		"rate": mods.rate += 0.2
		"splash": mods.splash += 0.4
		"slow": mods.slow += 0.1
		"bounty": mods.bounty += 0.25
		"income": mods.income += 30
		"heal": lives += 5
		"cash": coins += 120
		"discount": mods.discount = minf(0.45, mods.discount + 0.15)


# ---------------------------------------------------------------- fin

func _end_game(won: bool) -> void:
	state = State.OVER
	if autotest:
		print("RESULT won=%s wave=%d lives=%d" % [won, wave, lives])
		get_tree().quit()
		return
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var l := Label.new()
	l.text = "¡Los gatitos ganaron!" if won else "Los ratones se comieron la comida..."
	l.add_theme_font_size_override("font_size", 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var b := Button.new()
	b.text = "Jugar de nuevo"
	b.custom_minimum_size = Vector2(240, 48)
	b.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(b)


# ---------------------------------------------------------------- bucle y dibujo

func _process(delta: float) -> void:
	hover_cell = _pos_to_cell(get_global_mouse_position())
	if state == State.WAVE:
		if spawn_queue.size() > 0:
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawn(spawn_queue.pop_front())
				spawn_timer = spawn_interval
		elif get_tree().get_nodes_in_group("enemies").size() == 0:
			_wave_complete()
	if autotest:
		_bot_build()
		if state == State.BUILD:
			_start_wave()
		elif state == State.CHOOSING:
			_choose_upgrade(Data.UPGRADES[randi() % Data.UPGRADES.size()].id, ui.get_child(ui.get_child_count() - 1))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL, ROWS * CELL + ORIGIN.y)), Color(0.12, 0.14, 0.12))
	for x in COLS:
		for y in ROWS:
			var c := Vector2i(x, y)
			var col: Color
			if path_cells.has(c):
				col = Color(0.76, 0.66, 0.48)
			elif (x + y) % 2 == 0:
				col = Color(0.36, 0.62, 0.36)
			else:
				col = Color(0.33, 0.58, 0.33)
			draw_rect(Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL)), col)
	# cuenco de comida al final del camino
	var bowl := cell_center(Vector2i(COLS - 1, 5))
	draw_circle(bowl, 22.0, Color(0.75, 0.2, 0.25))
	draw_circle(bowl, 15.0, Color(0.5, 0.3, 0.15))
	# vista previa de construcción / alcance
	if state != State.OVER and _in_grid(hover_cell):
		if towers.has(hover_cell):
			var t = towers[hover_cell]
			draw_arc(t.position, t.get_range(), 0, TAU, 64, Color(1, 1, 1, 0.7), 2.0)
		elif _can_build(hover_cell):
			var center := cell_center(hover_cell)
			var ok := coins >= tower_cost(selected)
			var tint := Color(1, 1, 1, 0.25) if ok else Color(1, 0.2, 0.2, 0.3)
			draw_rect(Rect2(center - Vector2(CELL, CELL) / 2, Vector2(CELL, CELL)), tint)
			draw_arc(center, Data.TOWERS[selected].range * mods.range, 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0)


# ---------------------------------------------------------------- autotest (depuración)

func _setup_autotest() -> void:
	autotest = true
	Engine.time_scale = 10.0


## Bot de prueba: con la economía real, construye en orden cuando le alcanza.
var _bot_spots := [Vector2i(2, 3), Vector2i(4, 3), Vector2i(5, 5), Vector2i(7, 4), Vector2i(9, 3),
	Vector2i(6, 5), Vector2i(10, 2), Vector2i(11, 4), Vector2i(13, 4), Vector2i(11, 2),
	Vector2i(2, 1), Vector2i(4, 5), Vector2i(7, 7), Vector2i(9, 5), Vector2i(10, 0)]
var _bot_kinds := ["basic", "basic", "yarn", "siamese", "basic", "yarn", "basic", "siamese", "yarn", "basic",
	"basic", "yarn", "basic", "siamese", "yarn"]
var _bot_i := 0


func _bot_build() -> void:
	while _bot_i < _bot_spots.size():
		selected = _bot_kinds[_bot_i]
		if coins < tower_cost(selected):
			return
		_try_place(_bot_spots[_bot_i])
		_bot_i += 1
