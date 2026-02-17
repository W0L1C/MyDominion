extends Node2D
class_name BaseBuilding

var side: String = "player"
var civ: String = "Egyptians"
var level: int = 1
var hp: float = 1000.0
var max_hp: float = 1000.0
var base_texture: Texture2D = null

func set_civ_data(civ_name: String, starting_hp: float) -> void:
	civ = civ_name
	max_hp = starting_hp
	hp = starting_hp
	queue_redraw()

func set_visual(texture: Texture2D) -> void:
	base_texture = texture
	queue_redraw()

func apply_upgrade(level_hp_bonus: float) -> void:
	max_hp += level_hp_bonus
	hp += level_hp_bonus
	queue_redraw()

func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()

func _draw() -> void:
	var col: Color = Color(0.3, 0.55, 1.0) if side == "player" else Color(1.0, 0.35, 0.35)
	if base_texture != null:
		draw_texture_rect(base_texture, Rect2(-56, -56, 112, 112), false)
	else:
		draw_rect(Rect2(-50, -40, 100, 80), col)
	draw_string(ThemeDB.fallback_font, Vector2(-56, -64), civ + " L" + str(level), HORIZONTAL_ALIGNMENT_LEFT, 170, 14, Color.WHITE)
	draw_rect(Rect2(-50, 46, 100, 8), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(-50, 46, 100 * clampf(hp / max_hp, 0.0, 1.0), 8), Color(0.1, 1.0, 0.2))
