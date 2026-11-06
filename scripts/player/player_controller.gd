extends CharacterBody2D

## P0 movement placeholder. P1 will replace this with isometric navigation,
## touch controls, obstacle avoidance and squad-follow behavior.

@export var move_speed: float = 220.0

func _physics_process(_delta: float) -> void:
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = input_vector * move_speed
    move_and_slide()
