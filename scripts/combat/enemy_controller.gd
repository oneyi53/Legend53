extends CharacterBody2D

## Lightweight melee enemy used to validate the first combat loop.

@export var max_health: float = 45.0
@export var move_speed: float = 72.0
@export var notice_range: float = 260.0
@export var attack_range: float = 42.0
@export var attack_damage: float = 6.0
@export var attack_interval: float = 1.25

var health: float
var _attack_timer: float = 0.0
var _player: Node2D

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    _player = get_tree().get_first_node_in_group("player") as Node2D
    queue_redraw()

func _physics_process(delta: float) -> void:
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

func take_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    queue_redraw()
    if health <= 0.0:
        queue_free()

func _draw() -> void:
    draw_circle(Vector2(0.0, 8.0), 17.0, Color("#26362f"))
    draw_colored_polygon(
        PackedVector2Array([Vector2(0, -17), Vector2(15, -2), Vector2(11, 15), Vector2(-11, 15), Vector2(-15, -2)]),
        Color("#b65b43")
    )
    draw_rect(Rect2(-18.0, -29.0, 36.0, 5.0), Color("#382d2a"))
    draw_rect(Rect2(-18.0, -29.0, 36.0 * (health / max_health), 5.0), Color("#d85b4d"))
