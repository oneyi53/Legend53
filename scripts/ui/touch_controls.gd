extends Control

## Portrait virtual joystick plus combat buttons. Mouse emulation supports desktop review.

const JOYSTICK_RADIUS: float = 72.0
const DEAD_ZONE: float = 0.16
const JOYSTICK_MARGIN := Vector2(118.0, 150.0)
const BUTTON_RADIUS: float = 39.0

var _touch_index: int = -1
var _mouse_active: bool = false
var _stick := Vector2.ZERO
var _combat_director: Node

func _ready() -> void:
    mouse_filter = 2
    _combat_director = get_tree().get_first_node_in_group("combat_director")
    queue_redraw()

func _joystick_center() -> Vector2:
    var viewport_size := get_viewport_rect().size
    return Vector2(JOYSTICK_MARGIN.x, viewport_size.y - JOYSTICK_MARGIN.y)

func _button_centers() -> Dictionary:
    var size := get_viewport_rect().size
    return {
        "attack": Vector2(size.x - 92.0, size.y - 112.0),
        "auto": Vector2(size.x - 190.0, size.y - 112.0)
    }

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _handle_press(event.index, event.position)
        elif event.index == _touch_index:
            _touch_index = -1
            _clear_stick()
    elif event is InputEventScreenDrag and event.index == _touch_index:
        _update_stick(event.position - _joystick_center())
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _handle_mouse_press(event.position)
        elif _mouse_active:
            _mouse_active = false
            _clear_stick()
    elif event is InputEventMouseMotion and _mouse_active:
        _update_stick(event.position - _joystick_center())

func _handle_press(index: int, position: Vector2) -> void:
    var centers := _button_centers()
    if position.distance_to(centers.auto) <= BUTTON_RADIUS * 1.35:
        _toggle_auto()
    elif position.distance_to(centers.attack) <= BUTTON_RADIUS * 1.35:
        _manual_attack()
    elif position.distance_to(_joystick_center()) <= JOYSTICK_RADIUS * 1.8 and _touch_index == -1:
        _touch_index = index
        _update_stick(position - _joystick_center())

func _handle_mouse_press(position: Vector2) -> void:
    var centers := _button_centers()
    if position.distance_to(centers.auto) <= BUTTON_RADIUS * 1.35:
        _toggle_auto()
    elif position.distance_to(centers.attack) <= BUTTON_RADIUS * 1.35:
        _manual_attack()
    elif position.distance_to(_joystick_center()) <= JOYSTICK_RADIUS * 1.8:
        _mouse_active = true
        _update_stick(position - _joystick_center())

func _toggle_auto() -> void:
    if is_instance_valid(_combat_director):
        _combat_director.toggle_auto_combat()
    queue_redraw()

func _manual_attack() -> void:
    if is_instance_valid(_combat_director):
        _combat_director.manual_attack()

func _update_stick(offset: Vector2) -> void:
    var screen_stick := offset.limit_length(JOYSTICK_RADIUS) / JOYSTICK_RADIUS
    _stick = Vector2(
        screen_stick.x + screen_stick.y * 0.5,
        -screen_stick.x + screen_stick.y * 0.5
    )
    _set_action("move_left", _stick.x < -DEAD_ZONE)
    _set_action("move_right", _stick.x > DEAD_ZONE)
    _set_action("move_up", _stick.y < -DEAD_ZONE)
    _set_action("move_down", _stick.y > DEAD_ZONE)
    queue_redraw()

func _set_action(action_name: String, pressed: bool) -> void:
    if pressed:
        Input.action_press(action_name)
    else:
        Input.action_release(action_name)

func _clear_stick() -> void:
    _stick = Vector2.ZERO
    for action_name in ["move_left", "move_right", "move_up", "move_down"]:
        Input.action_release(action_name)
    queue_redraw()

func _draw() -> void:
    var center := _joystick_center()
    draw_circle(center, JOYSTICK_RADIUS, Color(0.05, 0.09, 0.08, 0.48))
    draw_arc(center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.75, 0.86, 0.76, 0.62), 3.0, true)
    var stick_offset := Vector2((_stick.x - _stick.y) * 0.5, _stick.x + _stick.y)
    if stick_offset.length_squared() > 0.0:
        stick_offset = stick_offset.normalized() * JOYSTICK_RADIUS * 0.58
    draw_circle(center + stick_offset, 28.0, Color(0.72, 0.84, 0.72, 0.82))

    var centers := _button_centers()
    draw_circle(centers.attack, BUTTON_RADIUS, Color("#9a493b"))
    draw_arc(centers.attack, BUTTON_RADIUS, 0.0, TAU, 36, Color("#e8b18a"), 3.0, true)
    draw_string(ThemeDB.fallback_font, centers.attack + Vector2(-19.0, 6.0), "ATK", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

    var auto_on := false
    if is_instance_valid(_combat_director):
        auto_on = _combat_director.auto_combat_enabled
    draw_circle(centers.auto, BUTTON_RADIUS * 0.82, Color("#547c56") if auto_on else Color("#46534b"))
    draw_arc(centers.auto, BUTTON_RADIUS * 0.82, 0.0, TAU, 36, Color("#b9d0aa"), 2.0, true)
    draw_string(ThemeDB.fallback_font, centers.auto + Vector2(-19.0, 6.0), "AUTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _exit_tree() -> void:
    _clear_stick()
