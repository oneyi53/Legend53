extends Node2D

## Original, code-drawn portrait ARPG character. Kept asset-free for reliable scaling.
var _idle_clock := 0.0

func _process(delta: float) -> void:
    _idle_clock += delta
    queue_redraw()

func _draw() -> void:
    var parent := get_parent()
    var class_id := str(parent.get("class_id")) if is_instance_valid(parent) else "warrior"
    var bob := sin(_idle_clock * 2.8) * 1.1
    var cape := Color("#8d2936")
    var cloth := Color("#315d77")
    var trim := Color("#d8b66c")
    var weapon := Color("#dce4e7")
    if class_id == "mage":
        cape = Color("#334b83")
        cloth = Color("#594d91")
        trim = Color("#8bd7ed")
        weapon = Color("#8be6ff")
    elif class_id == "taoist":
        cape = Color("#3e7255")
        cloth = Color("#d2c8a0")
        trim = Color("#e5d38a")
        weapon = Color("#d6e7bc")

    # Ground shadow and back-facing cape.
    draw_colored_polygon(PackedVector2Array([Vector2(-13, 13), Vector2(0, 18), Vector2(14, 13), Vector2(0, 9)]), Color(0.04, 0.07, 0.06, 0.38))
    draw_colored_polygon(PackedVector2Array([Vector2(-7, -7 + bob), Vector2(-15, 1 + bob), Vector2(-12, 13 + bob), Vector2(0, 9 + bob), Vector2(10, 14 + bob), Vector2(13, 1 + bob), Vector2(6, -8 + bob)]), cape)
    draw_colored_polygon(PackedVector2Array([Vector2(-8, 5 + bob), Vector2(-5, 15 + bob), Vector2(-1, 15 + bob), Vector2(-2, 5 + bob)]), Color("#292e35"))
    draw_colored_polygon(PackedVector2Array([Vector2(2, 5 + bob), Vector2(3, 15 + bob), Vector2(8, 15 + bob), Vector2(7, 5 + bob)]), Color("#292e35"))

    # Shoulder plates, torso and belt.
    draw_colored_polygon(PackedVector2Array([Vector2(-10, -9 + bob), Vector2(-7, -14 + bob), Vector2(7, -14 + bob), Vector2(11, -8 + bob), Vector2(8, 6 + bob), Vector2(-7, 6 + bob)]), cloth)
    draw_colored_polygon(PackedVector2Array([Vector2(-10, -10 + bob), Vector2(-6, -14 + bob), Vector2(-3, -10 + bob), Vector2(-6, -5 + bob)]), trim)
    draw_colored_polygon(PackedVector2Array([Vector2(10, -10 + bob), Vector2(6, -14 + bob), Vector2(3, -10 + bob), Vector2(6, -5 + bob)]), trim)
    draw_line(Vector2(-7, 3 + bob), Vector2(7, 3 + bob), trim, 2.0, true)

    # Head, hair/hood and face highlight.
    draw_circle(Vector2(0, -18 + bob), 6.2, Color("#d8a47c"))
    draw_arc(Vector2(0, -19 + bob), 6.4, PI, TAU, 18, Color("#2b2424"), 3.2, true)
    draw_circle(Vector2(-2.2, -18 + bob), 0.7, Color("#fff0d0"))
    draw_line(Vector2(-3, -12 + bob), Vector2(3, -12 + bob), Color("#8d5848"), 1.0)

    # Weapon silhouette changes by class.
    if class_id == "mage":
        draw_line(Vector2(10, -7 + bob), Vector2(15, -27 + bob), Color("#6d4b32"), 3.0, true)
        draw_circle(Vector2(15, -29 + bob), 4.0, weapon)
        draw_circle(Vector2(15, -29 + bob), 2.0, Color("#d9ffff"))
    elif class_id == "taoist":
        draw_line(Vector2(11, -6 + bob), Vector2(17, 12 + bob), Color("#745437"), 2.5, true)
        draw_colored_polygon(PackedVector2Array([Vector2(13, -3 + bob), Vector2(18, -1 + bob), Vector2(16, 4 + bob), Vector2(11, 2 + bob)]), weapon)
    else:
        draw_line(Vector2(10, -5 + bob), Vector2(22, 10 + bob), Color("#73533a"), 2.6, true)
        draw_colored_polygon(PackedVector2Array([Vector2(19, 5 + bob), Vector2(25, 12 + bob), Vector2(21, -1 + bob)]), weapon)
        draw_line(Vector2(16, 2 + bob), Vector2(21, -1 + bob), trim, 2.0, true)

    # Small ground-facing highlight gives the sprite a readable edge.
    draw_arc(Vector2(0, 4 + bob), 13.0, 0.12, PI - 0.12, 20, Color(1.0, 0.86, 0.58, 0.55), 1.2, true)
