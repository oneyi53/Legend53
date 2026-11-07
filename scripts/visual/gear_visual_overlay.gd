extends Node2D
var _player: Node
var _gear: Dictionary = {}
var _class_id := "warrior"
const QUALITY_COLORS := {"common":Color("#aeb6b8"),"uncommon":Color("#62c878"),"rare":Color("#55a9ed"),"epic":Color("#b17be8"),"legendary":Color("#f2b84b")}
func _ready() -> void:
    _player = get_parent().get_parent()
    if is_instance_valid(_player) and _player.has_signal("equipment_changed"):
        _player.equipment_changed.connect(_refresh_gear)
    if is_instance_valid(_player):
        _refresh_gear()
func _refresh_gear() -> void:
    if not is_instance_valid(_player):
        return
    var current: Variant = _player.get("equipment")
    _gear = current.duplicate(true) if current is Dictionary else {}
    _class_id = str(_player.get("class_id"))
    queue_redraw()
func _item(slot: String) -> Dictionary:
    var value: Variant = _gear.get(slot, {})
    return value if value is Dictionary else {}
func _color_for(slot: String) -> Color:
    var item := _item(slot)
    var color: Color = QUALITY_COLORS.get(str(item.get("quality","common")), Color("#b7c2c4"))
    if int(item.get("upgrade_level",0)) >= 3 or int(item.get("forge_level",0)) >= 2 or int(item.get("awaken_level",0)) > 0:
        color = color.lightened(0.24)
    return color
func _draw() -> void:
    if _gear.is_empty():
        return
    _draw_helmet()
    _draw_armor()
    _draw_necklace()
    _draw_bracers()
    _draw_ring()
    _draw_belt()
    _draw_boots()
    _draw_weapon()
func _draw_helmet() -> void:
    if _item("helmet").is_empty(): return
    var color := _color_for("helmet")
    draw_colored_polygon(PackedVector2Array([Vector2(43,27),Vector2(45,12),Vector2(57,4),Vector2(73,4),Vector2(85,13),Vector2(86,28),Vector2(76,24),Vector2(64,19),Vector2(52,25)]), color.darkened(0.22))
    draw_arc(Vector2(64,22),23.0,PI,TAU,24,color.lightened(0.35),4.0,true)
    draw_circle(Vector2(64,9),3.0,color.lightened(0.5))
func _draw_armor() -> void:
    if _item("armor").is_empty(): return
    var color := _color_for("armor")
    draw_colored_polygon(PackedVector2Array([Vector2(43,62),Vector2(51,56),Vector2(64,66),Vector2(77,56),Vector2(86,63),Vector2(81,105),Vector2(64,114),Vector2(47,105)]),color.darkened(0.18))
    draw_colored_polygon(PackedVector2Array([Vector2(53,65),Vector2(64,73),Vector2(75,65),Vector2(72,99),Vector2(64,105),Vector2(56,99)]),color)
    draw_line(Vector2(64,70),Vector2(64,104),color.lightened(0.5),2.0,true)
    draw_circle(Vector2(64,86),4.0,color.lightened(0.55))
func _draw_necklace() -> void:
    if _item("necklace").is_empty(): return
    var color := _color_for("necklace")
    draw_arc(Vector2(64,51),15.0,0.15,PI-0.15,20,color,3.0,true)
    draw_colored_polygon(PackedVector2Array([Vector2(64,62),Vector2(69,69),Vector2(64,76),Vector2(59,69)]),color.lightened(0.25))
    draw_circle(Vector2(64,69),2.0,Color("#fff0c2"))
func _draw_bracers() -> void:
    if _item("bracelet").is_empty(): return
    var color := _color_for("bracelet")
    draw_line(Vector2(27,88),Vector2(39,96),color,5.0,true)
    draw_line(Vector2(89,96),Vector2(102,86),color,5.0,true)
    draw_line(Vector2(28,84),Vector2(38,91),color.lightened(0.4),1.5,true)
    draw_line(Vector2(91,91),Vector2(101,82),color.lightened(0.4),1.5,true)
func _draw_ring() -> void:
    if _item("ring").is_empty(): return
    var color := _color_for("ring")
    draw_circle(Vector2(105,91),4.5,color)
    draw_circle(Vector2(105,91),2.0,Color("#fff1bd"))
    draw_circle(Vector2(27,94),3.5,color)
func _draw_belt() -> void:
    if _item("belt").is_empty(): return
    var color := _color_for("belt")
    draw_line(Vector2(43,107),Vector2(85,107),color.darkened(0.12),6.0,true)
    draw_rect(Rect2(59,101,10,12),color.lightened(0.28))
    draw_rect(Rect2(62,104,4,6),Color("#3b3027"))
func _draw_boots() -> void:
    if _item("boots").is_empty(): return
    var color := _color_for("boots")
    draw_colored_polygon(PackedVector2Array([Vector2(43,130),Vector2(61,131),Vector2(62,150),Vector2(39,153),Vector2(37,146)]),color)
    draw_colored_polygon(PackedVector2Array([Vector2(68,131),Vector2(86,130),Vector2(91,146),Vector2(89,153),Vector2(66,150)]),color)
    draw_line(Vector2(40,146),Vector2(60,146),color.lightened(0.45),2.0,true)
    draw_line(Vector2(69,146),Vector2(89,146),color.lightened(0.45),2.0,true)
func _draw_weapon() -> void:
    var item := _item("weapon")
    if item.is_empty(): return
    var color := _color_for("weapon")
    if _class_id == "mage":
        draw_line(Vector2(96,68),Vector2(113,25),Color("#76563b"),5.0,true)
        draw_circle(Vector2(114,22),10.0,color.darkened(0.22))
        draw_circle(Vector2(114,22),5.5,color)
        draw_arc(Vector2(114,22),14.0,0.0,TAU,24,color.lightened(0.4),2.0,true)
    elif _class_id == "taoist":
        draw_line(Vector2(99,72),Vector2(112,137),Color("#795739"),5.0,true)
        draw_rect(Rect2(103,66,18,14),color)
        draw_rect(Rect2(108,69,8,8),Color("#a9473e"))
    else:
        draw_line(Vector2(99,75),Vector2(120,126),Color("#795739"),6.0,true)
        draw_colored_polygon(PackedVector2Array([Vector2(112,112),Vector2(126,142),Vector2(108,133)]),color)
        draw_line(Vector2(105,95),Vector2(117,91),color.lightened(0.5),3.0,true)
    if int(item.get("awaken_level",0)) > 0:
        draw_arc(Vector2(110,103),18.0,-0.8,1.4,18,Color("#f4d27a",0.8),2.0,true)
