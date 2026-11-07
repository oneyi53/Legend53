extends CharacterBody2D

signal defeated(enemy: Node2D)

@export var max_health: float = 45.0
@export var move_speed: float = 72.0
@export var notice_range: float = 260.0
@export var attack_range: float = 42.0
@export var attack_damage: float = 6.0
@export var attack_interval: float = 1.25

const SAFE_ZONE_END_Y := 390.0
const SAFE_ZONE_BUFFER := 16.0
var health: float
var _attack_timer := 0.0
var _player: Node2D
var _is_defeated := false
var zone_name := "林间入口"
var enemy_level := 1
var is_boss := false
var is_elite := false
var elite_type := ""
var elite_title := ""
var boss_title := ""
var boss_phase := 0
var _boss_base_speed := 48.0
var _boss_base_damage := 18.0
var _boss_base_interval := 1.45
var _boss_windup := 0.0
var _boss_telegraph_radius := 158.0
var _boss_attack_pending := false
var _visual_clock := 0.0
var _was_targeted := false

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    _player = get_tree().get_first_node_in_group("player") as Node2D
    scale = Vector2(1.16, 1.16)
    queue_redraw()

func _process(delta: float) -> void:
    _visual_clock += delta
    var director := get_tree().get_first_node_in_group("combat_director")
    var targeted := is_instance_valid(director) and director.get("current_target") == self
    if targeted != _was_targeted or is_boss:
        _was_targeted = targeted
        queue_redraw()

func _physics_process(delta: float) -> void:
    if _is_defeated:
        return
    if not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node2D
        velocity = Vector2.ZERO
        move_and_slide()
        return
    _attack_timer = maxf(0.0, _attack_timer - delta)
    # The village is a protected sanctuary. Enemies disengage immediately
    # when the player enters it and cannot cross its southern boundary.
    if _player.global_position.y < SAFE_ZONE_END_Y:
        velocity = Vector2.ZERO
        move_and_slide()
        return
    if is_boss and _boss_attack_pending:
        _boss_windup = maxf(0.0, _boss_windup - delta)
        queue_redraw()
        if _boss_windup <= 0.0:
            _boss_attack_pending = false
            if global_position.distance_to(_player.global_position) <= _boss_telegraph_radius and _player.has_method("take_damage"):
                _player.take_damage(attack_damage)
            queue_redraw()
        velocity = Vector2.ZERO
        move_and_slide()
        return
    var distance := global_position.distance_to(_player.global_position)
    velocity = global_position.direction_to(_player.global_position) * move_speed if distance <= notice_range and distance > attack_range else Vector2.ZERO
    if global_position.y + velocity.y * delta < SAFE_ZONE_END_Y + SAFE_ZONE_BUFFER:
        velocity = Vector2.ZERO
    move_and_slide()
    if is_boss and distance <= 205.0 and _attack_timer <= 0.0:
        _boss_attack_pending = true
        _boss_windup = 0.82
        _attack_timer = attack_interval
        queue_redraw()
    elif distance <= attack_range and _attack_timer <= 0.0:
        if _player.has_method("take_damage"):
            _player.take_damage(attack_damage)
        _attack_timer = attack_interval

func configure_for_zone(zone_id: String, level_value: int) -> void:
    zone_name = zone_id
    enemy_level = maxi(1, level_value)
    var factor := 1.0 + float(enemy_level - 1) * 0.22
    max_health = 45.0 * factor
    move_speed = 72.0 + float(enemy_level - 1) * 2.5
    attack_damage = 6.0 + float(enemy_level - 1) * 1.2
    health = max_health
    queue_redraw()

func configure_elite(variant: String) -> void:
    if is_boss:
        return
    is_elite = true
    elite_type = variant
    match variant:
        "swift":
            elite_title = "迅捷"
            move_speed *= 1.38
            attack_interval *= 0.78
        "guardian":
            elite_title = "坚甲"
            max_health *= 2.25
            health = max_health
            attack_damage *= 0.82
        _:
            elite_type = "brute"
            elite_title = "狂暴"
            max_health *= 1.45
            health = max_health
            attack_damage *= 1.65
            move_speed *= 0.92
    queue_redraw()

func configure_boss() -> void:
    is_boss = true
    boss_title = "腐化古树"
    enemy_level = 8
    zone_name = "遗忘祭坛"
    max_health = 900.0
    health = max_health
    move_speed = 48.0
    notice_range = 420.0
    attack_range = 76.0
    attack_damage = 18.0
    attack_interval = 1.45
    _boss_base_speed = move_speed
    _boss_base_damage = attack_damage
    _boss_base_interval = attack_interval
    scale = Vector2(1.65, 1.65)
    queue_redraw()

func take_damage(amount: float) -> void:
    if _is_defeated or amount <= 0.0:
        return
    health = maxf(0.0, health - amount)
    if is_boss:
        var next_phase := 2 if health <= max_health * 0.35 else (1 if health <= max_health * 0.70 else 0)
        if next_phase > boss_phase:
            boss_phase = next_phase
            if boss_phase == 1:
                move_speed = _boss_base_speed * 1.18
                attack_damage = _boss_base_damage * 1.20
                attack_interval = _boss_base_interval * 0.88
                boss_title = "腐化古树 · 苏醒"
            else:
                move_speed = _boss_base_speed * 1.42
                attack_damage = _boss_base_damage * 1.55
                attack_interval = _boss_base_interval * 0.72
                _boss_telegraph_radius = 188.0
                boss_title = "腐化古树 · 暴走"
            _attack_timer = minf(_attack_timer, attack_interval)
    queue_redraw()
    modulate = Color("#ffd0b8")
    var flash := create_tween()
    flash.tween_property(self, "modulate", Color.WHITE, 0.12)
    if health <= 0.0:
        _is_defeated = true
        defeated.emit(self)
        queue_free()

func _draw() -> void:
    if _was_targeted:
        var pulse := 0.62 + 0.22 * sin(_visual_clock * 5.0)
        draw_arc(Vector2(0, 3), 29.0, 0.0, TAU, 40, Color(1.0, 0.78, 0.32, pulse), 2.6, true)
        draw_colored_polygon(PackedVector2Array([Vector2(-5,-52),Vector2(0,-61),Vector2(5,-52)]),Color("#f4d27a",pulse))
    if is_elite:
        var elite_color := Color("#75d9e8") if elite_type == "swift" else (Color("#d5c7a0") if elite_type == "guardian" else Color("#e78a58"))
        draw_arc(Vector2(0, 1), 27.0, 0.0, TAU, 36, elite_color, 2.2, true)
        draw_circle(Vector2(0, -28), 3.5, elite_color)

    if is_boss:
        # Corrupted ancient tree: roots, trunk, antler-like branches and glowing core.
        draw_colored_polygon(PackedVector2Array([Vector2(-25, 13), Vector2(-43, 22), Vector2(-18, 19), Vector2(-5, 12), Vector2(8, 20), Vector2(39, 22), Vector2(21, 10)]), Color("#302d25"))
        draw_colored_polygon(PackedVector2Array([Vector2(-18, 13), Vector2(-15, -21), Vector2(-7, -35), Vector2(8, -35), Vector2(17, -18), Vector2(18, 13)]), Color("#654b35"))
        draw_colored_polygon(PackedVector2Array([Vector2(-13, -17), Vector2(-30, -37), Vector2(-27, -51), Vector2(-20, -39), Vector2(-8, -28)]), Color("#79573a"))
        draw_colored_polygon(PackedVector2Array([Vector2(12, -19), Vector2(29, -43), Vector2(27, -54), Vector2(19, -42), Vector2(6, -28)]), Color("#79573a"))
        draw_colored_polygon(PackedVector2Array([Vector2(-5, -28), Vector2(-2, -45), Vector2(4, -51), Vector2(7, -34)]), Color("#98704a"))
        draw_circle(Vector2(-7, -10), 5.0, Color("#a9d46c",0.16 + 0.10 * sin(_visual_clock * 3.0)))
        draw_circle(Vector2(8, -10), 5.0, Color("#a9d46c",0.16 + 0.10 * sin(_visual_clock * 3.0)))
        draw_circle(Vector2(-7, -10), 2.8, Color("#e4a64c"))
        draw_circle(Vector2(8, -10), 2.8, Color("#e4a64c"))
        draw_line(Vector2(-12,-28),Vector2(-23,-39),Color("#a17b4c"),3.0,true)
        draw_line(Vector2(13,-28),Vector2(24,-40),Color("#a17b4c"),3.0,true)
        draw_arc(Vector2(0,4),24.0,0.15,PI-0.15,24,Color("#a7bd62",0.72),2.0,true)
        draw_line(Vector2(-7, 0), Vector2(8, 0), Color("#30231f"), 2.0, true)
        draw_arc(Vector2(0, -2), 18.0, PI, TAU, 24, Color("#a7bd62"), 2.0, true)
    else:
        var body_color := Color("#b65b43") if enemy_level < 5 else Color("#8c5b9e")
        if is_elite:
            body_color = Color("#3d9eaa") if elite_type == "swift" else (Color("#9c8960") if elite_type == "guardian" else Color("#b34d37"))
        if enemy_level >= 8:
            body_color = Color("#b77a36")

        # Original forest beast silhouette with four paws, muzzle, ears and tail.
        draw_line(Vector2(-12, 3), Vector2(-21, 12), Color("#49352f"), 4.0, true)
        draw_line(Vector2(-21, 12), Vector2(-25, 8), Color("#49352f"), 3.0, true)
        draw_colored_polygon(PackedVector2Array([Vector2(-17, -6), Vector2(-11, -14), Vector2(7, -15), Vector2(17, -7), Vector2(15, 7), Vector2(5, 13), Vector2(-12, 10)]), body_color)
        draw_line(Vector2(-8,-9),Vector2(5,-12),body_color.lightened(0.30),2.0,true)
        draw_arc(Vector2(2,-3),11.0,PI*1.05,PI*1.85,18,body_color.darkened(0.28),1.5,true)
        draw_circle(Vector2(14,-8),2.5,Color("#fff0b0"))
        draw_circle(Vector2(14,-8),1.0,Color("#3b2925"))
        draw_line(Vector2(-10,8),Vector2(-13,16),Color("#49352f"),4.0,true)
        draw_line(Vector2(8,8),Vector2(12,16),Color("#49352f"),4.0,true)
        draw_line(Vector2(-10, 5), Vector2(-13, 16), Color("#49352f"), 3.5, true)
        draw_line(Vector2(8, 6), Vector2(12, 16), Color("#49352f"), 3.5, true)
        draw_line(Vector2(14, 0), Vector2(20, 10), Color("#49352f"), 3.5, true)
        draw_colored_polygon(PackedVector2Array([Vector2(7, -10), Vector2(12, -20), Vector2(17, -11), Vector2(19, -2), Vector2(12, 4), Vector2(5, 0)]), body_color.lightened(0.12))
        draw_colored_polygon(PackedVector2Array([Vector2(8, -17), Vector2(9, -25), Vector2(14, -18)]), Color("#49352f"))
        draw_circle(Vector2(15, -8), 1.5, Color("#f4d27a"))
        draw_colored_polygon(PackedVector2Array([Vector2(19, -1), Vector2(27, 2), Vector2(18, 5)]), Color("#d8b69b"))
        if enemy_level >= 5 or elite_type == "brute":
            draw_colored_polygon(PackedVector2Array([Vector2(-8, -11), Vector2(-15, -20), Vector2(-13, -8)]), Color("#d8c7a0"))
        if elite_type == "guardian":
            draw_arc(Vector2(0, -3), 17.0, PI, TAU, 24, Color("#d9c99e"), 3.0, true)
        elif elite_type == "swift":
            draw_line(Vector2(-5, -17), Vector2(11, -17), Color("#b5eff0"), 1.5, true)

    var bar_width := 58.0 if is_boss else 36.0
    var bar_y := -67.0 if is_boss else -34.0
    draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 5), Color("#382d2a"))
    draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * clampf(health / maxf(max_health, 1), 0, 1), 5), Color("#d85b4d"))
    if is_boss:
        var aura_alpha := 0.18 + 0.10 * absf(sin(_visual_clock * 2.2))
        draw_arc(Vector2.ZERO, 42.0 + sin(_visual_clock * 2.0) * 2.0, 0.0, TAU, 48, Color("#a6c36c",aura_alpha), 3.0, true)
    if is_boss and _boss_attack_pending:
        var warning_alpha := 0.42 + 0.30 * absf(sin(Time.get_ticks_msec() * 0.018))
        draw_arc(Vector2.ZERO, _boss_telegraph_radius / scale.x, 0.0, TAU, 48, Color(1.0, 0.20, 0.14, warning_alpha), 3.5, true)
        draw_arc(Vector2.ZERO, (_boss_telegraph_radius / scale.x) * clampf(1.0 - _boss_windup / 0.82, 0.08, 1.0), 0.0, TAU, 48, Color(1.0, 0.62, 0.28, 0.9), 2.0, true)
    if is_boss and ThemeDB.fallback_font:
        draw_string(ThemeDB.fallback_font, Vector2(-56, -75), boss_title, HORIZONTAL_ALIGNMENT_CENTER, 112, 10, Color("#ffd59a"))
    elif is_elite and ThemeDB.fallback_font:
        draw_string(ThemeDB.fallback_font, Vector2(-35, -43), elite_title, HORIZONTAL_ALIGNMENT_CENTER, 70, 9, Color("#f5d99a"))
