extends Node2D
class_name Unit

var owner_side: String = "player"
var lane: int = 1
var unit_name: String = "Unit"
var hp: float = 40.0
var damage: float = 6.0
var attack_range: float = 55.0
var move_speed: float = 120.0
var attack_cooldown: float = 0.8
var gold_cost: int = 10
var is_expensive: bool = false
var support_buff_radius: float = 70.0
var support_damage_bonus: float = 0.0
var armor: float = 0.0
var class_id: String = ""

var _cooldown: float = 0.0

func _ready() -> void:
	z_index = 3

func _process(delta: float) -> void:
	_cooldown = max(0.0, _cooldown - delta)
	queue_redraw()

func can_attack() -> bool:
	return _cooldown <= 0.0

func trigger_attack() -> void:
	_cooldown = attack_cooldown

func take_damage(amount: float) -> void:
	hp -= max(1.0, amount - armor)
	if hp <= 0.0:
		queue_free()

func _draw() -> void:
	var color := Color(0.2, 0.8, 0.3) if owner_side == "player" else Color(0.9, 0.25, 0.25)
	draw_circle(Vector2.ZERO, 12.0 if not is_expensive else 16.0, color)
	draw_string(ThemeDB.fallback_font, Vector2(-22, -16), unit_name.substr(0, 3), HORIZONTAL_ALIGNMENT_LEFT, 60, 12, Color.WHITE)
	var hp_ratio: float = clampf(hp / 120.0, 0.0, 1.0)
	draw_rect(Rect2(-16, 16, 32, 4), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-16, 16, 32 * hp_ratio, 4), Color(0.1, 1.0, 0.2))
