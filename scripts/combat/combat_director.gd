extends Node

signal mode_changed(is_auto: bool)
signal target_changed(target: Node2D)

@export var auto_notice_range: float = 520.0
@export var auto_attack_range: float = 58.0
@export var manual_target_range: float = 280.0
@export var attack_damage: float = 18.0
@export var attack_interval: float = 0.72

var auto_combat_enabled: bool = false
var current_target: Node2D
var _attack_timer: float = 0.0

func _ready() -> void:
    add_to_group("combat_director")

func _process(delta: float) -> void:
    _attack_timer = maxf(0.0, _attack_timer - delta)
    if Input.is_action_just_pressed("toggle_auto"):
        toggle_auto_combat()
    if Input.is_action_just_pressed("attack"):
        manual_attack()

    if not auto_combat_enabled:
        return
    var player := get_tree().get_first_node_in_group("player") as Node2D
    if not is_instance_valid(player):
        return
    if not is_instance_valid(current_target):
        current_target = _find_nearest_target(auto_notice_range)
        target_changed.emit(current_target)
    if not is_instance_valid(current_target):
        if player.has_method("clear_auto_move_target"):
            player.clear_auto_move_target()
        return

    var distance := player.global_position.distance_to(current_target.global_position)
    if distance > auto_attack_range:
        if player.has_method("set_auto_move_target"):
            player.set_auto_move_target(current_target)
    else:
        if player.has_method("clear_auto_move_target"):
            player.clear_auto_move_target()
        _attack_current_target()

func toggle_auto_combat() -> void:
    auto_combat_enabled = not auto_combat_enabled
    if not auto_combat_enabled:
        current_target = null
        var player := get_tree().get_first_node_in_group("player") as Node2D
        if is_instance_valid(player) and player.has_method("clear_auto_move_target"):
            player.clear_auto_move_target()
        target_changed.emit(null)
    mode_changed.emit(auto_combat_enabled)

func manual_attack() -> void:
    if auto_combat_enabled:
        return
    if not is_instance_valid(current_target):
        current_target = _find_nearest_target(manual_target_range)
        target_changed.emit(current_target)
    if not is_instance_valid(current_target):
        return
    var player := get_tree().get_first_node_in_group("player") as Node2D
    if is_instance_valid(player) and player.global_position.distance_to(current_target.global_position) <= auto_attack_range:
        _attack_current_target()

func _attack_current_target() -> void:
    if _attack_timer > 0.0 or not is_instance_valid(current_target):
        return
    if current_target.has_method("take_damage"):
        current_target.take_damage(attack_damage)
    _attack_timer = attack_interval
    if not is_instance_valid(current_target):
        target_changed.emit(null)

func _find_nearest_target(search_range: float) -> Node2D:
    var player := get_tree().get_first_node_in_group("player") as Node2D
    if not is_instance_valid(player):
        return null
    var nearest: Node2D
    var nearest_distance := search_range
    for candidate in get_tree().get_nodes_in_group("enemies"):
        if not candidate is Node2D:
            continue
        var distance := player.global_position.distance_to(candidate.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = candidate
    return nearest
