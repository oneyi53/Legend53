extends Node

## Maintains a small roaming population; spawned enemies use the same combat/loot loop.
const ENEMY_SCENE = preload("res://scenes/actors/enemy.tscn")

@export var maximum_alive: int = 5
@export var respawn_interval: float = 9.0
@export var minimum_player_distance: float = 220.0

var _timer: float = 4.0
# Coordinates are centers of walkable cells on the current isometric field.
var _spawn_points := PackedVector2Array([
    Vector2(432, 208),
    Vector2(528, 496),
    Vector2(264, 544),
    Vector2(360, 832),
    Vector2(168, 832),
    Vector2(456, 736)
])

func _process(delta: float) -> void:
    _timer -= delta
    if _timer > 0.0:
        return
    _timer = respawn_interval
    var alive := get_tree().get_nodes_in_group("enemies").size()
    if alive >= maximum_alive:
        return
    var player := get_tree().get_first_node_in_group("player") as Node2D
    var candidates: Array[Vector2] = []
    for point in _spawn_points:
        if is_instance_valid(player) and player.global_position.distance_to(point) < minimum_player_distance:
            continue
        candidates.append(point)
    if candidates.is_empty():
        return
    var parent := get_parent().get_node_or_null("Enemies")
    if not is_instance_valid(parent):
        return
    var enemy := ENEMY_SCENE.instantiate()
    enemy.name = "ForestRaider_%d" % Time.get_ticks_msec()
    parent.add_child(enemy)
    enemy.global_position = candidates[randi_range(0, candidates.size() - 1)]
