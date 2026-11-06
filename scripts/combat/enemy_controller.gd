extends CharacterBody2D

## Lightweight melee enemy used to validate the first combat loop.

signal defeated(enemy: Node2D)

@export var max_health: float = 45.0
@export var move_speed: float = 72.0
@export var notice_range: float = 260.0
@export var attack_range: float = 42.0
@export var attack_damage: float = 6.0
@export var attack_interval: float = 1.25

var health: float
var _attack_timer: float = 0.0
var _player: Node2D
var _is_defeated: bool = false
var zone_name := "林间入口"
var enemy_level: int = 1
var _base_stats_applied := false

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    if not _base_stats_applied:
        _base_stats_applied = true
    _player = get_tree().get_first_node_in_group("player") as Node2D
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
    var distance := global_position.distance_to(_player.global_position)
    if distance <= notice_range and distance > attack_range:
        velocity = global_position.direction_to(_player.global_position) * move_speed
    else:
        velocity = Vector2.ZERO
    move_and_slide()

    if distance <= attack_range and _attack_timer <= 0.0:
        if _player.has_method("take_damage"):
            _player.take_damage(attack_damage)
        _attack_timer = attack_interval

func configure_for_zone(zone_id: String, level_value: int) -> void:
    zone_name = zone_id
    enemy_level = maxi(1, level_value)
    var scale := 1.0 + float(enemy_level - 1) * 0.22
    max_health = 45.0 * scale
    move_speed = 72.0 + float(enemy_level - 1) * 2.5
    attack_damage = 6.0 + float(enemy_level - 1) * 1.2
    if is_inside_tree():
        health = max_health
        queue_redraw()

func take_damage(amount: float) -> void:
    if _is_defeated or amount <= 0.0:
        return
    health = maxf(0.0, health - amount)
    queue_redraw()
    modulate = Color("#ffd0b8")
    var flash := create_tween()
    flash.tween_property(self, "modulate", Color.WHITE, 0.12)
    if health <= 0.0:
        _is_defeated = true
        defeated.emit(self)
        queue_free()

func _draw() -> void:
    draw_circle(Vector2(0.0, 8.0), 17.0, Color("#26362f"))
    var body_color := Color("#b65b43") if enemy_level < 5 else Color("#8c5b9e")
    if enemy_level >= 8:
        body_color = Color("#b77a36")
    draw_colored_polygon(
        PackedVector2Array([Vector2(0, -17), Vector2(15, -2), Vector2(11, 15), Vector2(-11, 15), Vector2(-15, -2)]),
        body_color
    )
    draw_rect(Rect2(-18.0, -29.0, 36.0, 5.0), Color("#382d2a"))
    var health_ratio := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
    draw_rect(Rect2(-18.0, -29.0, 36.0 * health_ratio, 5.0), Color("#d85b4d"))
