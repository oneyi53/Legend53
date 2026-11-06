extends Node2D

const INTERACT_DISTANCE := 118.0

func _ready() -> void:
    add_to_group("quest_npc")
    queue_redraw()

func _draw() -> void:
    draw_ellipse(Vector2(0, 22), Vector2(24, 9), Color("#1d2b25"))
    draw_colored_polygon(PackedVector2Array([Vector2(-15, 2),Vector2(15,2),Vector2(19,30),Vector2(-19,30)]), Color("#8b6548"))
    draw_colored_polygon(PackedVector2Array([Vector2(-13,-2),Vector2(13,-2),Vector2(10,14),Vector2(-10,14)]), Color("#d4b17a"))
    draw_circle(Vector2(0,-14), 12, Color("#d9ad83"))
    draw_arc(Vector2(0,-15), 13, PI, TAU, 24, Color("#e0d1ad"), 5.0, true)
    draw_line(Vector2(19,0), Vector2(24,29), Color("#8d7048"), 4.0)
    draw_circle(Vector2(24,30), 4, Color("#c6a46a"))
    var font := ThemeDB.fallback_font
    if font:
        draw_string(font, Vector2(-60,-38), "守林村长", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color("#ffe4a8"))
        draw_string(font, Vector2(-15,-55), "!", HORIZONTAL_ALIGNMENT_CENTER, 30, 22, Color("#f4d16d"))

func is_player_near(player: Node2D) -> bool:
    return is_instance_valid(player) and global_position.distance_to(player.global_position) <= INTERACT_DISTANCE
