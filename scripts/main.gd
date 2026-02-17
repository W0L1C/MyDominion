extends Node2D

const UnitScene := preload("res://scenes/Unit.tscn")
const BaseScene := preload("res://scenes/Base.tscn")

const LANE_Y: Array[float] = [220.0, 360.0, 500.0]
const LANE_START_X: float = 170.0
const LANE_END_X: float = 1110.0
const PLAYER_SPAWN_X: float = 190.0
const ENEMY_SPAWN_X: float = 1090.0
const MATCH_TIME: float = 300.0
const UNIT_CAP: int = 10

var player_civ: String = "Egyptians"
var player_resource: float = 80.0
var enemy_resource: float = 80.0
var elapsed: float = 0.0
var game_over: bool = false
var selected_lane: int = 1

var player_base: BaseBuilding
var enemy_base: BaseBuilding

var player_generation: float = 1.0
var enemy_generation: float = 1.0
var player_upgrade_level: int = 1
var enemy_upgrade_level: int = 1
var player_upgrade_in_progress: bool = false
var enemy_upgrade_in_progress: bool = false

var player_global_armor_bonus: float = 0.0
var enemy_global_armor_bonus: float = 0.0
var player_road_speed_bonus: float = 0.0
var enemy_road_speed_bonus: float = 0.0

var civ_data: Dictionary = {
	"Egyptians": {
		"resource": "Limestone Blocks",
		"start_hp": 1800.0,
		"generation": [1.2, 2.0, 3.0],
		"upgrade_costs": [70, 120, 180],
		"upgrade_time": [12.0, 16.0, 20.0],
		"unit_cheap": {"name":"Laborer", "cost":18, "hp":45, "dmg":5, "range":32, "speed":100, "cd":1.0},
		"unit_exp": {"name":"Anubis Guard", "cost":55, "hp":120, "dmg":18, "range":34, "speed":80, "cd":1.2},
		"base_hp_upgrade": 250.0,
		"unit_upgrade": {"armor": 2.0, "damage_mult": 1.2}
	},
	"Norse": {
		"resource": "Plunder",
		"start_hp": 1100.0,
		"generation": [0.5, 0.8, 1.1],
		"upgrade_costs": [60, 90, 120],
		"upgrade_time": [8.0, 10.0, 12.0],
		"unit_cheap": {"name":"Berserker", "cost":15, "hp":35, "dmg":12, "range":28, "speed":155, "cd":0.7},
		"unit_exp": {"name":"Shield Maiden", "cost":48, "hp":90, "dmg":15, "range":35, "speed":125, "cd":0.85, "aura":4.0},
		"base_hp_upgrade": 180.0,
		"unit_upgrade": {"armor": 1.0, "damage_mult": 1.15}
	},
	"Romans": {
		"resource": "Logistics",
		"start_hp": 1300.0,
		"generation": [1.0, 1.6, 2.2],
		"upgrade_costs": [65, 100, 145],
		"upgrade_time": [9.0, 12.0, 14.0],
		"unit_cheap": {"name":"Velites", "cost":20, "hp":55, "dmg":9, "range":58, "speed":115, "cd":1.0},
		"unit_exp": {"name":"Praetorian", "cost":58, "hp":115, "dmg":17, "range":36, "speed":95, "cd":1.0},
		"base_hp_upgrade": 220.0,
		"unit_upgrade": {"armor": 2.0, "damage_mult": 1.1}
	}
}

@onready var hud: Label = $CanvasLayer/HUD
@onready var result_label: Label = $CanvasLayer/Result
@onready var cheap_btn: Button = $CanvasLayer/Panel/Cheap
@onready var exp_btn: Button = $CanvasLayer/Panel/Expensive
@onready var upg_btn: Button = $CanvasLayer/Panel/Upgrade
@onready var class_picker: OptionButton = $CanvasLayer/Panel/Class
@onready var ai_timer: Timer = $AITimer
@onready var resource_timer: Timer = $ResourceTimer

func _ready() -> void:
	for key: Variant in civ_data.keys():
		class_picker.add_item(str(key))
	class_picker.item_selected.connect(_on_class_selected)
	cheap_btn.pressed.connect(_spawn_player_cheap)
	exp_btn.pressed.connect(_spawn_player_exp)
	upg_btn.pressed.connect(_upgrade_player)
	ai_timer.timeout.connect(_enemy_wave)
	resource_timer.timeout.connect(_resource_tick)
	_setup_bases()
	ai_timer.start(30.0)
	resource_timer.start(1.0)
	queue_redraw()

func _draw() -> void:
	for i: int in range(LANE_Y.size()):
		var y: float = LANE_Y[i]
		var lane_color: Color = Color(0.26, 0.26, 0.31, 0.7)
		if i == selected_lane:
			lane_color = Color(0.9, 0.82, 0.25, 0.95)
		draw_line(Vector2(LANE_START_X, y), Vector2(LANE_END_X, y), lane_color, 14.0)
		draw_string(ThemeDB.fallback_font, Vector2(LANE_START_X - 60.0, y + 4.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 30.0, 16, Color.WHITE)

func _setup_bases() -> void:
	if player_base:
		player_base.queue_free()
	if enemy_base:
		enemy_base.queue_free()
	player_base = BaseScene.instantiate()
	enemy_base = BaseScene.instantiate()
	player_base.position = Vector2(90, 360)
	enemy_base.position = Vector2(1190, 360)
	player_base.side = "player"
	enemy_base.side = "enemy"
	player_base.set_civ_data(player_civ, float(civ_data[player_civ]["start_hp"]))
	enemy_base.set_civ_data("Norse", float(civ_data["Norse"]["start_hp"]))
	if player_civ == "Egyptians":
		player_base.set_visual(_resolve_egyptian_base_texture())
	else:
		player_base.set_visual(null)
	add_child(player_base)
	add_child(enemy_base)
	player_generation = float(civ_data[player_civ]["generation"][0])
	enemy_generation = float(civ_data["Norse"]["generation"][0])
	player_upgrade_level = 1
	enemy_upgrade_level = 1
	player_global_armor_bonus = 0.0
	enemy_global_armor_bonus = 0.0
	player_road_speed_bonus = 0.0
	enemy_road_speed_bonus = 0.0
	result_label.text = ""
	elapsed = 0.0
	game_over = false

func _resolve_egyptian_base_texture() -> Texture2D:
	var candidates: Array[String] = [
		"res://assets/egyptian_base.png",
		"res://assets/EgyptianBase.png",
		"res://assets/egypt/base.png",
		"res://egyptian_base.png"
	]
	for path: String in candidates:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

func _process(delta: float) -> void:
	if game_over:
		return
	elapsed += delta
	if elapsed >= MATCH_TIME:
		_end_game("Time up! Draw")
		return
	_update_units(delta)
	_update_hud()
	queue_redraw()
	if Input.is_action_just_pressed("spawn_cheap"):
		_spawn_player_cheap()
	if Input.is_action_just_pressed("spawn_expensive"):
		_spawn_player_exp()
	if Input.is_action_just_pressed("upgrade_base"):
		_upgrade_player()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_select_lane_from_position(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_lane_from_position(event.position)

func _select_lane_from_position(pos: Vector2) -> void:
	for i: int in range(LANE_Y.size()):
		if absf(pos.y - LANE_Y[i]) <= 45.0 and pos.x >= LANE_START_X and pos.x <= LANE_END_X:
			selected_lane = i
			queue_redraw()
			return

func _resource_tick() -> void:
	if game_over:
		return
	player_resource += player_generation
	enemy_resource += enemy_generation

func _get_units(side: String) -> Array[Unit]:
	var out: Array[Unit] = []
	for c: Node in get_children():
		if c is Unit and c.owner_side == side:
			out.append(c as Unit)
	return out

func _spawn_player_cheap() -> void:
	_spawn_unit("player", false, selected_lane)

func _spawn_player_exp() -> void:
	_spawn_unit("player", true, selected_lane)

func _spawn_unit(side: String, expensive: bool, lane: int) -> void:
	if game_over:
		return
	if _get_units(side).size() >= UNIT_CAP:
		return
	var civ: String = player_civ if side == "player" else "Norse"
	var data: Dictionary = civ_data[civ]["unit_exp"] if expensive else civ_data[civ]["unit_cheap"]
	var cost: int = int(data["cost"])
	if side == "player" and player_resource < cost:
		return
	if side == "enemy" and enemy_resource < cost:
		return
	if side == "player":
		player_resource -= cost
	else:
		enemy_resource -= cost
	var u: Unit = UnitScene.instantiate()
	u.owner_side = side
	u.class_id = civ
	u.lane = lane
	u.unit_name = str(data["name"])
	u.hp = float(data["hp"])
	u.damage = float(data["dmg"])
	u.attack_range = float(data["range"])
	u.move_speed = float(data["speed"])
	u.attack_cooldown = float(data["cd"])
	u.is_expensive = expensive
	u.armor += player_global_armor_bonus if side == "player" else enemy_global_armor_bonus
	if expensive and data.has("aura"):
		u.support_damage_bonus = float(data["aura"])
	u.position = Vector2(PLAYER_SPAWN_X if side == "player" else ENEMY_SPAWN_X, LANE_Y[lane])
	add_child(u)

func _update_units(delta: float) -> void:
	for c: Node in get_children():
		if c is not Unit:
			continue
		var u: Unit = c
		var target: Node2D = _find_target_for(u)
		if target != null:
			if u.position.distance_to(target.position) <= u.attack_range + 8.0 and u.can_attack():
				var dealt: float = u.damage + _ally_damage_bonus(u)
				if target is Unit:
					target.take_damage(dealt)
					if u.class_id == "Norse" and u.owner_side == "player":
						player_resource += 2.0
				elif target is BaseBuilding:
					target.take_damage(dealt)
					if u.class_id == "Norse" and u.owner_side == "player":
						player_resource += 4.0
				u.trigger_attack()
		else:
			var dir: float = 1.0 if u.owner_side == "player" else -1.0
			var speed_bonus: float = 0.0
			if u.class_id == "Romans":
				speed_bonus = player_road_speed_bonus if u.owner_side == "player" else enemy_road_speed_bonus
			u.position.x += dir * (u.move_speed + speed_bonus) * delta
			u.position.x = clampf(u.position.x, LANE_START_X, LANE_END_X)
		if player_base.hp <= 0.0:
			_end_game("Defeat")
		if enemy_base.hp <= 0.0:
			_end_game("Victory")

func _find_target_for(u: Unit) -> Node2D:
	var enemy_side: String = "enemy" if u.owner_side == "player" else "player"
	var enemies: Array[Unit] = _get_units(enemy_side)
	var best: Unit = null
	var best_dist: float = INF
	for e: Unit in enemies:
		if e.lane != u.lane:
			continue
		var d: float = absf(e.position.x - u.position.x)
		if d < best_dist:
			best_dist = d
			best = e
	if best != null and best_dist <= u.attack_range + 8.0:
		return best
	var base_target: BaseBuilding = enemy_base if u.owner_side == "player" else player_base
	var base_edge_x: float = base_target.position.x - 50.0 if u.owner_side == "player" else base_target.position.x + 50.0
	if absf(base_edge_x - u.position.x) <= u.attack_range + 8.0:
		return base_target
	return null

func _ally_damage_bonus(u: Unit) -> float:
	var bonus: float = 0.0
	if u.class_id == "Romans":
		var count: int = 0
		for ally: Unit in _get_units(u.owner_side):
			if ally.lane == u.lane and ally != u and ally.class_id == "Romans":
				count += 1
		bonus += float(count)
	if u.class_id == "Norse" and u.owner_side == "player":
		for ally: Unit in _get_units("player"):
			if ally.lane == u.lane and ally.support_damage_bonus > 0.0 and ally.position.distance_to(u.position) <= ally.support_buff_radius:
				bonus += ally.support_damage_bonus
	return bonus

func _upgrade_player() -> void:
	if player_upgrade_in_progress:
		return
	if player_upgrade_level >= 4:
		return
	var civ: Dictionary = civ_data[player_civ]
	var idx: int = player_upgrade_level - 1
	var cost: int = int(civ["upgrade_costs"][idx])
	if player_resource < cost:
		return
	player_resource -= cost
	player_upgrade_in_progress = true
	await get_tree().create_timer(float(civ["upgrade_time"][idx])).timeout
	if game_over:
		return
	player_upgrade_level += 1
	player_base.level = player_upgrade_level
	_apply_upgrade_effect("player", player_civ)
	player_upgrade_in_progress = false

func _enemy_upgrade() -> void:
	if enemy_upgrade_in_progress or enemy_upgrade_level >= 4:
		return
	var civ: Dictionary = civ_data["Norse"]
	var idx: int = enemy_upgrade_level - 1
	var cost: int = int(civ["upgrade_costs"][idx])
	if enemy_resource < cost:
		return
	enemy_resource -= cost
	enemy_upgrade_in_progress = true
	await get_tree().create_timer(float(civ["upgrade_time"][idx])).timeout
	if game_over:
		return
	enemy_upgrade_level += 1
	enemy_base.level = enemy_upgrade_level
	_apply_upgrade_effect("enemy", "Norse")
	enemy_upgrade_in_progress = false

func _apply_upgrade_effect(side: String, civ_name: String) -> void:
	var data: Dictionary = civ_data[civ_name]
	var lvl: int = player_upgrade_level if side == "player" else enemy_upgrade_level
	if lvl == 2:
		if side == "player":
			player_generation = float(data["generation"][1])
		else:
			enemy_generation = float(data["generation"][1])
	elif lvl == 3:
		if side == "player":
			player_base.apply_upgrade(float(data["base_hp_upgrade"]))
		else:
			enemy_base.apply_upgrade(float(data["base_hp_upgrade"]))
	elif lvl == 4:
		for u: Unit in _get_units(side):
			u.armor += float(data["unit_upgrade"]["armor"])
			u.damage *= float(data["unit_upgrade"]["damage_mult"])
		if side == "player":
			player_global_armor_bonus += float(data["unit_upgrade"]["armor"])
			if civ_name == "Romans":
				player_road_speed_bonus += 30.0
		else:
			enemy_global_armor_bonus += float(data["unit_upgrade"]["armor"])
			if civ_name == "Romans":
				enemy_road_speed_bonus += 30.0

func _enemy_wave() -> void:
	if game_over:
		return
	if enemy_resource > 70.0 and randi() % 3 == 0:
		await _enemy_upgrade()
	for i: int in range(3):
		if randi() % 100 < 45:
			_spawn_unit("enemy", false, i)
		if randi() % 100 < 25:
			_spawn_unit("enemy", true, i)

func _on_class_selected(idx: int) -> void:
	player_civ = class_picker.get_item_text(idx)
	_setup_bases()
	player_resource = 80.0
	enemy_resource = 80.0

func _update_hud() -> void:
	var resource_name: String = str(civ_data[player_civ]["resource"])
	hud.text = "%s: %d | Base HP: %d/%d | Level: %d | Lane: %d | Time: %ds" % [
		resource_name,
		int(player_resource),
		int(player_base.hp),
		int(player_base.max_hp),
		player_upgrade_level,
		selected_lane + 1,
		int(MATCH_TIME - elapsed)
	]

func _end_game(message: String) -> void:
	game_over = true
	result_label.text = message
