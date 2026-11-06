extends CharacterBody2D

## Portrait movement, auto-approach, combat health and offline character progression.

signal health_changed(current: float, maximum: float)
signal experience_changed(current: int, required: int, current_level: int)
signal level_up(new_level: int)
signal died
signal respawned

@export var move_speed: float = 220.0
@export var max_health: float = 120.0
@export var respawn_delay: float = 2.0

var health: float
var level: int = 1
var experience: int = 0
var _experience_required: int = 100
var _spawn_position: Vector2
var _is_dead: bool = false
var _auto_target: Node2D

func _ready() -> void:
    health = max_health
    _spawn_position = global_position
    add_to_group("player")
    health_changed.emit(health, max_health)
    experience_changed.emit(experience, _experience_required, level)

func _physics_process(_delta: float) -> void:
    if _is_dead:
        velocity = Vector2.ZERO
        return

    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var screen_direction := Vector2.ZERO
    if input_vector.length_squared() > 0.01:
        _auto_target = null
        screen_direction = Vector2(
            (input_vector.x - input_vector.y) * 0.5,
            input_vector.x + input_vector.y
        )
    elif is_instance_valid(_auto_target):
        var distance := global_position.distance_to(_auto_target.global_position)
        if distance > 54.0:
            screen_direction = global_position.direction_to(_auto_target.global_position)
        else:
            _auto_target = null

    if screen_direction.length_squared() > 1.0:
        screen_direction = screen_direction.normalized()
    velocity = screen_direction * move_speed
    move_and_slide()

func set_auto_move_target(target: Node2D) -> void:
    if not _is_dead:
        _auto_target = target

func clear_auto_move_target() -> void:
    _auto_target = null

func take_damage(amount: float) -> void:
    if _is_dead or amount <= 0.0:
        return
    health = maxf(0.0, health - amount)
    health_changed.emit(health, max_health)
    if health <= 0.0:
        _begin_respawn()

func add_experience(amount: int) -> void:
    if amount <= 0 or _is_dead:
        return
    experience += amount
    while experience >= _experience_required:
        experience -= _experience_required
        _level_up()
    experience_changed.emit(experience, _experience_required, level)

func _level_up() -> void:
    level += 1
    _experience_required = 100 + (level - 1) * 45
    max_health += 12.0
    health = max_health
    health_changed.emit(health, max_health)
    level_up.emit(level)

func _begin_respawn() -> void:
    _is_dead = true
    _auto_target = null
    velocity = Vector2.ZERO
    died.emit()
    var body_visual := get_node_or_null("BodyVisual") as Polygon2D
    if body_visual:
        body_visual.color = Color("#713c48")
    var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collision:
        collision.set_deferred("disabled", true)
    _finish_respawn()

func _finish_respawn() -> void:
    await get_tree().create_timer(respawn_delay).timeout
    if not is_inside_tree():
        return
    global_position = _spawn_position
    health = max_health
    _is_dead = false
    var body_visual := get_node_or_null("BodyVisual") as Polygon2D
    if body_visual:
        body_visual.color = Color(0.25, 0.72, 0.95, 1.0)
    var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collision:
        collision.set_deferred("disabled", false)
    health_changed.emit(health, max_health)
    respawned.emit()
