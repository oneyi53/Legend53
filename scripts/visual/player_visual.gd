extends Node2D

## Original hand-drawn adventurer with layered cloth, armor, face and class weapon.
var _idle_clock := 0.0
var _art_sprite: Sprite2D
var _last_class := ""

func _ready() -> void:
    _art_sprite = Sprite2D.new()
    _art_sprite.centered = true
    _art_sprite.position = Vector2(0, -8)
    _art_sprite.scale = Vector2(0.34, 0.34)
    _art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(_art_sprite)
    _refresh_class_art()

func _refresh_class_art() -> void:
    var parent := get_parent()
    var class_id := str(parent.get("class_id")) if is_instance_valid(parent) else "warrior"
    if class_id == _last_class:
        return
    _last_class = class_id
    var art_path := "res://assets/characters/warrior.svg"
    if class_id == "mage":
        art_path = "res://assets/characters/mage.svg"
    elif class_id == "taoist":
        art_path = "res://assets/characters/taoist.svg"
    _art_sprite.texture = load(art_path)

func _process(delta: float) -> void:
    _idle_clock += delta
    _refresh_class_art()
    var parent := get_parent()
    var moving: bool = is_instance_valid(parent) and parent is CharacterBody2D and (parent as CharacterBody2D).velocity.length() > 8.0
    _art_sprite.position.y = -8.0 + sin(_idle_clock * (8.5 if moving else 2.8)) * (2.0 if moving else 0.8)
    _art_sprite.rotation = sin(_idle_clock * 8.5) * 0.025 if moving else sin(_idle_clock * 1.4) * 0.008
    queue_redraw()

func _draw() -> void:
    _draw_ellipse(Vector2(0, 15), Vector2(16, 5), Color(0.02, 0.04, 0.03, 0.42))
    if is_instance_valid(_art_sprite) and _art_sprite.texture != null:
        return
    var parent := get_parent()
    var class_id := str(parent.get("class_id")) if is_instance_valid(parent) else "warrior"
    var moving := is_instance_valid(parent) and parent is CharacterBody2D and parent.velocity.length() > 8.0
    var bob := sin(_idle_clock * (8.5 if moving else 2.8)) * (2.0 if moving else 0.8)
    var step := sin(_idle_clock * 8.5) * 2.0 if moving else 0.0
    var cape := Color("#8d2936")
    var cloth := Color("#315d77")
    var trim := Color("#d8b66c")
    var skin := Color("#d8a47c")
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

    # Contact shadow and trailing mantle.
    _draw_ellipse(Vector2(0, 15), Vector2(15, 5), Color(0.02, 0.04, 0.03, 0.42))
    draw_colored_polygon(PackedVector2Array([Vector2(-8,-8+bob),Vector2(-16,1+bob),Vector2(-13,16+bob),Vector2(-4,12+bob),Vector2(0,17+bob),Vector2(11,14+bob),Vector2(15,1+bob),Vector2(7,-9+bob)]), cape.darkened(0.18))
    draw_colored_polygon(PackedVector2Array([Vector2(-8,-4+bob),Vector2(-13,3+bob),Vector2(-8,12+bob),Vector2(-2,9+bob)]), cape.lightened(0.12))
    draw_line(Vector2(0,-7+bob),Vector2(0,12+bob),cape.lightened(0.24),1.2,true)

    # Boots and articulated legs.
    draw_colored_polygon(PackedVector2Array([Vector2(-8,5+bob),Vector2(-6,14+step),Vector2(-1,15+step),Vector2(-2,5+bob)]),Color("#292d31"))
    draw_colored_polygon(PackedVector2Array([Vector2(2,5+bob),Vector2(3,15-step),Vector2(9,14-step),Vector2(7,5+bob)]),Color("#343238"))
    draw_line(Vector2(-6,12+step),Vector2(-1,12+step),trim,1.4,true)
    draw_line(Vector2(4,12-step),Vector2(9,12-step),trim,1.4,true)

    # Torso, shoulder guards and chest plate.
    draw_colored_polygon(PackedVector2Array([Vector2(-10,-10+bob),Vector2(-7,-15+bob),Vector2(7,-15+bob),Vector2(11,-9+bob),Vector2(8,7+bob),Vector2(-8,7+bob)]),cloth)
    draw_colored_polygon(PackedVector2Array([Vector2(-9,-10+bob),Vector2(-6,-14+bob),Vector2(-2,-10+bob),Vector2(-6,-5+bob)]),trim.darkened(0.08))
    draw_colored_polygon(PackedVector2Array([Vector2(9,-10+bob),Vector2(6,-14+bob),Vector2(2,-10+bob),Vector2(6,-5+bob)]),trim)
    draw_colored_polygon(PackedVector2Array([Vector2(-5,-11+bob),Vector2(0,-13+bob),Vector2(5,-10+bob),Vector2(4,3+bob),Vector2(-4,3+bob)]),cloth.lightened(0.18))
    draw_line(Vector2(0,-10+bob),Vector2(0,3+bob),trim,1.2,true)
    draw_line(Vector2(-7,4+bob),Vector2(7,4+bob),trim,2.0,true)
    draw_circle(Vector2(0,4+bob),1.7,Color("#f5d98e"))

    # Arms and bracers.
    draw_line(Vector2(-9,-8+bob),Vector2(-13,2+bob),skin.darkened(0.08),4.0,true)
    draw_line(Vector2(9,-8+bob),Vector2(12,1+bob),skin,4.0,true)
    draw_line(Vector2(-12,0+bob),Vector2(-14,4+bob),trim,3.0,true)
    draw_line(Vector2(11,-1+bob),Vector2(14,2+bob),trim,3.0,true)

    # Head, hairline, face and hood rim.
    draw_circle(Vector2(0,-19+bob),6.5,skin)
    draw_arc(Vector2(0,-20+bob),6.8,PI,TAU,20,Color("#2b2424"),3.6,true)
    draw_colored_polygon(PackedVector2Array([Vector2(-6,-20+bob),Vector2(-7,-25+bob),Vector2(-2,-27+bob),Vector2(5,-25+bob),Vector2(7,-20+bob),Vector2(2,-22+bob),Vector2(-3,-22+bob)]),cape.darkened(0.12))
    draw_circle(Vector2(-2.3,-18+bob),0.75,Color("#fff0d0"))
    draw_circle(Vector2(2.3,-18+bob),0.75,Color("#fff0d0"))
    draw_line(Vector2(-2,-14+bob),Vector2(2,-14+bob),Color("#925d4b"),0.9,true)

    # Weapon silhouettes and distinct magical identity.
    if class_id == "mage":
        draw_line(Vector2(11,-7+bob),Vector2(16,-27+bob),Color("#6d4b32"),3.2,true)
        draw_circle(Vector2(16,-29+bob),5.0,weapon.darkened(0.12))
        draw_circle(Vector2(16,-29+bob),3.0,Color("#e9ffff"))
        draw_arc(Vector2(16,-29+bob),7.0,_idle_clock, _idle_clock + PI * 1.35,18,Color("#80dcff",0.8),1.2,true)
    elif class_id == "taoist":
        draw_line(Vector2(11,-6+bob),Vector2(18,13+bob),Color("#745437"),2.8,true)
        draw_colored_polygon(PackedVector2Array([Vector2(12,-5+bob),Vector2(18,-3+bob),Vector2(16,4+bob),Vector2(10,2+bob)]),weapon)
        draw_circle(Vector2(15,-1+bob),2.0,Color("#f6e6b4"))
    else:
        draw_line(Vector2(10,-5+bob),Vector2(23,12+bob),Color("#73533a"),3.0,true)
        draw_colored_polygon(PackedVector2Array([Vector2(19,5+bob),Vector2(26,13+bob),Vector2(21,-2+bob)]),weapon)
        draw_line(Vector2(16,2+bob),Vector2(21,-2+bob),trim,2.2,true)
        draw_line(Vector2(12,-2+bob),Vector2(18,5+bob),Color("#f4e7cb"),1.0,true)

    # Small highlights keep the sprite readable against forest ground.
    draw_arc(Vector2(0,4+bob),13.0,0.12,PI-0.12,20,Color(1.0,0.86,0.58,0.62),1.2,true)

func _draw_ellipse(center: Vector2, radii: Vector2, fill: Color) -> void:
    var points := PackedVector2Array()
    for index in range(28):
        var angle := TAU * float(index) / 28.0
        points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
    draw_colored_polygon(points, fill)
