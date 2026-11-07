extends Node2D

var effect_kind := "slash"
var label_text := ""
var is_critical := false
var _life := 0.48
var _age := 0.0

func _ready() -> void:
    z_index = 30
    if effect_kind == "fire":
        _life = 0.62
    elif effect_kind == "heal" or effect_kind == "seal":
        _life = 0.72
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    _age += delta
    if _age >= _life:
        queue_free()
        return
    queue_redraw()

func _draw() -> void:
    var progress := clampf(_age / _life, 0.0, 1.0)
    var fade := 1.0 - progress
    var radius := 18.0 + progress * 46.0
    match effect_kind:
        "fire":
            draw_circle(Vector2.ZERO, 13.0 + progress * 30.0, Color(1.0, 0.34, 0.08, 0.28 * fade))
            draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(1.0, 0.68, 0.24, fade), 4.0, true)
        "seal":
            draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(0.42, 0.82, 1.0, fade), 3.0, true)
            draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 6, Color(0.72, 0.92, 1.0, fade), 2.0, true)
        "heal":
            draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(0.38, 1.0, 0.66, fade), 3.0, true)
            draw_line(Vector2(-10, 0), Vector2(10, 0), Color(0.72, 1.0, 0.78, fade), 4.0)
            draw_line(Vector2(0, -10), Vector2(0, 10), Color(0.72, 1.0, 0.78, fade), 4.0)
        _:
            draw_line(Vector2(-30, 12), Vector2(26, -18), Color(1.0, 0.88, 0.62, fade), 5.0)
            draw_arc(Vector2.ZERO, radius * 0.72, -0.7, 1.7, 20, Color(1.0, 0.72, 0.35, fade), 3.0, true)
    if not label_text.is_empty() and ThemeDB.fallback_font:
        var text_color := Color("#ffdf82") if is_critical else Color("#fff3dc")
        var prefix := "暴击 " if is_critical else ""
        var rise := 34.0 + progress * 42.0
        draw_string(ThemeDB.fallback_font, Vector2(-44, -rise), prefix + label_text, HORIZONTAL_ALIGNMENT_CENTER, 88, 17 if is_critical else 14, Color(text_color.r, text_color.g, text_color.b, fade))
