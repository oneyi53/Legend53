extends CharacterBody2D

## P1: eight-way input mapped onto a 2:1 isometric ground plane.

@export var move_speed: float = 220.0

func _physics_process(_delta: float) -> void:
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var isometric_direction := Vector2(
        input_vector.x - input_vector.y,
        (input_vector.x + input_vector.y) * 0.5
    )

    if isometric_direction.length_squared() > 1.0:
        isometric_direction = isometric_direction.normalized()

    velocity = isometric_direction * move_speed
    move_and_slide()
