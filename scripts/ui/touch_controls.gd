extends Control

## Minimal virtual joystick for portrait mobile play.
## Mouse emulation is included so the same control can be tested on desktop.

const JOYSTICK_RADIUS: float = 72.0
const DEAD_ZONE: float = 0.16
const JOYSTICK_MARGIN := Vector2(118.0, 150.0)

var _touch_index: int = -1
var _mouse_active: bool = false
var _stick := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _joystick_center() -> Vector2:
    var viewport_size := get_viewport_rect().size
    return Vector2(JOYSTICK_MARGIN.x, viewport_size.y - JOYSTICK_MARGIN.y)

func _input(event: InputEvent) -> void:
    var center := _joystick_center()

    if event is InputEventScreenTouch:
        if event.pressed and event.position.distance_to(center) <= JOYSTICK_RADIUS * 1.8 and _touch_index == -1:
            _touch_index = event.index
            _update_stick(event.position - center)
        elif not event.pressed and event.index == _touch_index:
            _touch_index = -1
            _clear_stick()
    elif event is InputEventScreenDrag and event.index == _touch_index:
        _update_stick(event.position - center)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and event.position.distance_to(center) <= JOYSTICK_RADIUS * 1.8:
            _mouse_active = true
            _update_stick(event.position - center)
        elif not event.pressed and _mouse_active:
            _mouse_active = false
            _clear_stick()
    elif event is InputEventMouseMotion and _mouse_active:
        _update_stick(event.position - center)

func _update_stick(offset: Vector2) -> void:
    var screen_stick := offset.limit_length(JOYSTICK_RADIUS) / JOYSTICK_RADIUS
    # Convert screen-space joystick direction back to the map's isometric axes.
    _stick = Vector2(
        screen_stick.x + screen_stick.y * 0.5,
        -screen_stick.x + screen_stick.y * 0.5
    )
    _apply_actions()
    queue_redraw()

func _apply_actions() -> void:
    _set_action("move_left", _stick.x < -DEAD_ZONE)
    _set_action("move_right", _stick.x > DEAD_ZONE)
    _set_action("move_up", _stick.y < -DEAD_ZONE)
    _set_action("move_down", _stick.y > DEAD_ZONE)

func _set_action(action_name: String, pressed: bool) -> void:
    if pressed:
        Input.action_press(action_name)
    else:
        Input.action_release(action_name)

func _clear_stick() -> void:
    _stick = Vector2.ZERO
    Input.action_release("move_left")
    Input.action_release("move_right")
    Input.action_release("move_up")
    Input.action_release("move_down")
    queue_redraw()

func _draw() -> void:
    var center := _joystick_center()
    draw_circle(center, JOYSTICK_RADIUS, Color(0.05, 0.09, 0.08, 0.48))
    draw_arc(center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.75, 0.86, 0.76, 0.62), 3.0, true)

    var screen_stick := Vector2.ZERO
    if _stick.length_squared() > 0.0:
        screen_stick = Vector2(
            (_stick.x - _stick.y) * 0.5,
            _stick.x + _stick.y
        ).normalized() * JOYSTICK_RADIUS * 0.58

    draw_circle(center + screen_stick, 28.0, Color(0.72, 0.84, 0.72, 0.82))
    draw_arc(center + screen_stick, 28.0, 0.0, TAU, 32, Color(0.95, 0.98, 0.9, 0.9), 2.0, true)

func _exit_tree() -> void:
    _clear_stick()
