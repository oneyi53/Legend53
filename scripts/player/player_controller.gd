extends CharacterBody2D

## Portrait movement and player health for the first combat slice.

signal health_changed(current: float, maximum: float)

@export var move_speed: float = 220.0
@export var max_health: float = 120.0

var health: float

func _ready() -> void:
    health = max_health
    add_to_group("player")

func _physics_process(_delta: float) -> void:
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var screen_direction := Vector2(
        (input_vector.x - input_vector.y) * 0.5,
        input_vector.x + input_vector.y
    )
    if screen_direction.length_squared() > 1.0:
        screen_direction = screen_direction.normalized()
    velocity = screen_direction * move_speed
    move_and_slide()

func take_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    health_changed.emit(health, max_health)
