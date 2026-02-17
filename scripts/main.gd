extends Node2D

const UnitScene := preload("res://scenes/Unit.tscn")
const BaseScene := preload("res://scenes/Base.tscn")

const LANE_Y := [220.0, 360.0, 500.0]
const PLAYER_SPAWN_X := 180.0
const ENEMY_SPAWN_X := 1100.0
const MATCH_TIME := 300.0
const UNIT_CAP := 10

var player_civ: String = "Egyptians"
var player_resource: float = 80.0
var enemy_resource: float = 80.0
var elapsed: float = 0.0
var game_over := false

var player_base: BaseBuilding
var enemy_base: BaseBuilding

var player_generation: float = 1.0
var enemy_generation: float = 1.0
var player_upgrade_level := 1
var enemy_upgrade_level := 1
var player_upgrade_in_progress := false
var enemy_upgrade_in_progress := false

var player_global_armor_bonus: float = 0.0
var enemy_global_armor_bonus: float = 0.0
var player_road_speed_bonus: float = 0.0
var enemy_road_speed_bonus: float = 0.0

var civ_data := {
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
@onready var lane_picker: OptionButton = $CanvasLayer/Panel/Lane
@onready var class_picker: OptionButton = $CanvasLayer/Panel/Class
@onready var ai_timer: Timer = $AITimer
@onready var resource_timer: Timer = $ResourceTimer

func _ready() -> void:
	for key in civ_data.keys():
		class_picker.add_item(key)
	for i in 3:
		lane_picker.add_item("Lane %d" % [i + 1])
	class_picker.item_selected.connect(_on_class_selected)
	cheap_btn.pressed.connect(_spawn_player_cheap)
	exp_btn.pressed.connect(_spawn_player_exp)
	upg_btn.pressed.connect(_upgrade_player)
	ai_timer.timeout.connect(_enemy_wave)
	resource_timer.timeout.connect(_resource_tick)
	_setup_bases()
	ai_timer.start(30.0)
	resource_timer.start(1.0)

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
	player_base.set_civ_data(player_civ, civ_data[player_civ]["start_hp"])
	enemy_base.set_civ_data("Norse", civ_data["Norse"]["start_hp"])
	add_child(player_base)
	add_child(enemy_base)
	player_generation = civ_data[player_civ]["generation"][0]
	enemy_generation = civ_data["Norse"]["generation"][0]
	player_upgrade_level = 1
	enemy_upgrade_level = 1
	player_global_armor_bonus = 0
	enemy_global_armor_bonus = 0
	player_road_speed_bonus = 0
	enemy_road_speed_bonus = 0
	result_label.text = ""
	elapsed = 0.0
	game_over = false

func _process(delta: float) -> void:
	if game_over:
		return
	elapsed += delta
	if elapsed >= MATCH_TIME:
		_end_game("Time up! Draw")
		return
	_update_units(delta)
	_update_hud()
	if Input.is_action_just_pressed("spawn_cheap"):
		_spawn_player_cheap()
	if Input.is_action_just_pressed("spawn_expensive"):
		_spawn_player_exp()
	if Input.is_action_just_pressed("upgrade_base"):
		_upgrade_player()

func _resource_tick() -> void:
	if game_over:
		return
	player_resource += player_generation
	enemy_resource += enemy_generation

func _get_units(side: String) -> Array:
	var out: Array = []
	for c in get_children():
		if c is Unit and c.owner_side == side:
			out.append(c)
	return out

func _spawn_player_cheap() -> void:
	_spawn_unit("player", false, lane_picker.selected)

func _spawn_player_exp() -> void:
	_spawn_unit("player", true, lane_picker.selected)

func _spawn_unit(side: String, expensive: bool, lane: int) -> void:
	if game_over:
		return
	if _get_units(side).size() >= UNIT_CAP:
		return
	var civ := player_civ if side == "player" else "Norse"
	var data: Dictionary = civ_data[civ]["unit_exp"] if expensive else civ_data[civ]["unit_cheap"]
	var cost: int = data["cost"]
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
	u.unit_name = data["name"]
	u.hp = data["hp"]
	u.damage = data["dmg"]
	u.attack_range = data["range"]
	u.move_speed = data["speed"]
	u.attack_cooldown = data["cd"]
	u.is_expensive = expensive
	u.armor += player_global_armor_bonus if side == "player" else enemy_global_armor_bonus
	if expensive and data.has("aura"):
		u.support_damage_bonus = data["aura"]
	u.position = Vector2(PLAYER_SPAWN_X if side == "player" else ENEMY_SPAWN_X, LANE_Y[lane])
	add_child(u)

func _update_units(delta: float) -> void:
	for c in get_children():
		if c is not Unit:
			continue
		var u: Unit = c
		var target := _find_target_for(u)
		if target != null:
			if u.position.distance_to(target.position) <= u.attack_range and u.can_attack():
				var dealt := u.damage + _ally_damage_bonus(u)
				if target is Unit:
					target.take_damage(dealt)
					if u.class_id == "Norse" and u.owner_side == "player":
						player_resource += 2
				elif target is BaseBuilding:
					target.take_damage(dealt)
					if u.class_id == "Norse" and u.owner_side == "player":
						player_resource += 4
				u.trigger_attack()
		else:
			var dir := 1.0 if u.owner_side == "player" else -1.0
			var speed_bonus := player_road_speed_bonus if u.owner_side == "player" and u.class_id == "Romans" else 0.0
			speed_bonus = enemy_road_speed_bonus if u.owner_side == "enemy" and u.class_id == "Romans" else speed_bonus
			u.position.x += dir * (u.move_speed + speed_bonus) * delta
		if player_base.hp <= 0:
			_end_game("Defeat")
		if enemy_base.hp <= 0:
			_end_game("Victory")

func _find_target_for(u: Unit) -> Node2D:
	var enemies: Array = _get_units("enemy" if u.owner_side == "player" else "player")
	var best: Unit = null
	var best_dist := INF
	for e in enemies:
		if e.lane != u.lane:
			continue
		var d: float = abs(e.position.x - u.position.x)
		if d < best_dist:
			best_dist = d
			best = e
	if best != null and best_dist <= u.attack_range:
		return best
	var base_target := enemy_base if u.owner_side == "player" else player_base
	if abs(base_target.position.x - u.position.x) <= u.attack_range + 25:
		return base_target
	return null

func _ally_damage_bonus(u: Unit) -> float:
	var bonus := 0.0
	if u.class_id == "Romans":
		var count := 0
		for ally in _get_units(u.owner_side):
			if ally.lane == u.lane and ally != u and ally.class_id == "Romans":
				count += 1
		bonus += float(count)
	if u.class_id == "Norse" and u.owner_side == "player":
		for ally in _get_units("player"):
			if ally.lane == u.lane and ally.support_damage_bonus > 0.0 and ally.position.distance_to(u.position) <= ally.support_buff_radius:
				bonus += ally.support_damage_bonus
	return bonus

func _upgrade_player() -> void:
	if player_upgrade_in_progress:
		return
	if player_upgrade_level >= 4:
		return
	var civ: Dictionary = civ_data[player_civ]
	var idx := player_upgrade_level - 1
	var cost: int = civ["upgrade_costs"][idx]
	if player_resource < cost:
		return
	player_resource -= cost
	player_upgrade_in_progress = true
	await get_tree().create_timer(civ["upgrade_time"][idx]).timeout
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
	var idx := enemy_upgrade_level - 1
	var cost: int = civ["upgrade_costs"][idx]
	if enemy_resource < cost:
		return
	enemy_resource -= cost
	enemy_upgrade_in_progress = true
	await get_tree().create_timer(civ["upgrade_time"][idx]).timeout
	if game_over:
		return
	enemy_upgrade_level += 1
	enemy_base.level = enemy_upgrade_level
	_apply_upgrade_effect("enemy", "Norse")
	enemy_upgrade_in_progress = false

func _apply_upgrade_effect(side: String, civ_name: String) -> void:
	var data: Dictionary = civ_data[civ_name]
	var lvl := (player_upgrade_level if side == "player" else enemy_upgrade_level)
	if lvl == 2:
		if side == "player":
			player_generation = data["generation"][1]
		else:
			enemy_generation = data["generation"][1]
	elif lvl == 3:
		if side == "player":
			player_base.apply_upgrade(data["base_hp_upgrade"])
		else:
			enemy_base.apply_upgrade(data["base_hp_upgrade"])
	elif lvl == 4:
		for u in _get_units(side):
			u.armor += data["unit_upgrade"]["armor"]
			u.damage *= data["unit_upgrade"]["damage_mult"]
		if side == "player":
			player_global_armor_bonus += data["unit_upgrade"]["armor"]
			if civ_name == "Romans":
				player_road_speed_bonus += 30.0
		else:
			enemy_global_armor_bonus += data["unit_upgrade"]["armor"]
			if civ_name == "Romans":
				enemy_road_speed_bonus += 30.0

func _enemy_wave() -> void:
	if game_over:
		return
	if enemy_resource > 70 and randi() % 3 == 0:
		await _enemy_upgrade()
	for i in 3:
		if randi() % 100 < 45:
			_spawn_unit("enemy", false, i)
		if randi() % 100 < 25:
			_spawn_unit("enemy", true, i)

func _on_class_selected(idx: int) -> void:
	player_civ = class_picker.get_item_text(idx)
	_setup_bases()
	player_resource = 80
	enemy_resource = 80

func _update_hud() -> void:
	var resource_name := civ_data[player_civ]["resource"]
	hud.text = "%s: %d | Base HP: %d/%d | Level: %d | Time: %ds" % [
		resource_name,
		int(player_resource),
		int(player_base.hp),
		int(player_base.max_hp),
		player_upgrade_level,
		int(MATCH_TIME - elapsed)
	]

func _end_game(message: String) -> void:
	game_over = true
	result_label.text = message
