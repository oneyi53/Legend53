extends Node2D

const INTERACT_DISTANCE := 104.0
@export_enum("blacksmith", "merchant", "guide") var service_type := "blacksmith"

var display_name: String:
    get:
        match service_type:
            "blacksmith": return "铁匠·格林"
            "merchant": return "行商·米娅"
            "guide": return "传送向导·艾文"
        return "村民"

func _ready() -> void:
    add_to_group("service_npcs")
    queue_redraw()

func is_player_near(player: Node2D) -> bool:
    return is_instance_valid(player) and global_position.distance_to(player.global_position) <= INTERACT_DISTANCE

func _draw() -> void:
    draw_circle(Vector2(0, 20), 22, Color("#1d2b25"))
    match service_type:
        "blacksmith":
            draw_colored_polygon(PackedVector2Array([Vector2(-17,0),Vector2(17,0),Vector2(20,30),Vector2(-20,30)]), Color("#596b78"))
            draw_circle(Vector2(0,-14), 12, Color("#d3a17d"))
            draw_line(Vector2(16,-5), Vector2(27,12), Color("#b8b9bd"), 6.0)
            draw_rect(Rect2(20,8,16,8), Color("#9a7858"))
        "merchant":
            draw_colored_polygon(PackedVector2Array([Vector2(-17,0),Vector2(17,0),Vector2(20,30),Vector2(-20,30)]), Color("#8b7550"))
            draw_circle(Vector2(0,-14), 12, Color("#e0b58b"))
            draw_colored_polygon(PackedVector2Array([Vector2(-19,-24),Vector2(19,-24),Vector2(12,-17),Vector2(-12,-17)]), Color("#d3a65d"))
            draw_circle(Vector2(22,20), 10, Color("#9c754c"))
        "guide":
            draw_colored_polygon(PackedVector2Array([Vector2(-16,0),Vector2(16,0),Vector2(20,30),Vector2(-20,30)]), Color("#536c8d"))
            draw_circle(Vector2(0,-14), 12, Color("#d9ad83"))
            draw_circle(Vector2(0,-29), 5, Color("#8bd8dc"))
            draw_line(Vector2(0,-29), Vector2(0,-44), Color("#8bd8dc"), 3.0)
    var font := ThemeDB.fallback_font
    if font:
        draw_string(font, Vector2(-66,-43), display_name, HORIZONTAL_ALIGNMENT_CENTER, 132, 14, Color("#ffe4a8"))
