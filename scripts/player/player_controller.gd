extends CharacterBody2D

## P1 portrait movement. Keyboard and virtual joystick both feed the same actions.

@export var move_speed: float = 220.0

func _physics_process(_delta: float) -> void:
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    # The map's isometric axes are rotated for a portrait field.
    var screen_direction := Vector2(
        (input_vector.x - input_vector.y) * 0.5,
        input_vector.x + input_vector.y
    )

    if screen_direction.length_squared() > 1.0:
        screen_direction = screen_direction.normalized()

    velocity = screen_direction * move_speed
    move_and_slide()
