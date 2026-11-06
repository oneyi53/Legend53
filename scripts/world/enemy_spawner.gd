extends Node
const ENEMY_SCENE = preload("res://scenes/actors/enemy.tscn")
@export var maximum_alive: int = 6
@export var respawn_interval: float = 9.0
@export var minimum_player_distance: float = 220.0
var _timer := 4.0
var _boss_spawned := false
var _spawn_points: Array[Dictionary] = [
 {"position":Vector2(432,208),"zone":"entrance","level":1},
 {"position":Vector2(528,496),"zone":"deepwood","level":3},
 {"position":Vector2(264,544),"zone":"deepwood","level":3},
 {"position":Vector2(360,832),"zone":"ruins","level":5},
 {"position":Vector2(168,832),"zone":"ruins","level":5}
]
func _process(delta: float) -> void:
 _timer -= delta
 if _timer > 0.0: return
 _timer = respawn_interval
 var player := get_tree().get_first_node_in_group("player") as Node2D
 if is_instance_valid(player) and player.global_position.y >= 900.0 and not _boss_spawned:
  _spawn_boss()
 if get_tree().get_nodes_in_group("enemies").size() >= maximum_alive: return
 var candidates: Array[Dictionary] = []
 for point in _spawn_points:
  var pos: Vector2 = point.position
  if is_instance_valid(player) and player.global_position.distance_to(pos) < minimum_player_distance: continue
  candidates.append(point)
 if candidates.is_empty(): return
 var parent := get_parent().get_node_or_null("Enemies")
 if not is_instance_valid(parent): return
 var spawn: Dictionary = candidates[randi_range(0,candidates.size()-1)]
 var enemy := ENEMY_SCENE.instantiate()
 enemy.name = "ForestRaider_%d" % Time.get_ticks_msec()
 parent.add_child(enemy)
 enemy.global_position = spawn.position
 enemy.configure_for_zone(str(spawn.zone),int(spawn.level))
func _spawn_boss() -> void:
 var parent := get_parent().get_node_or_null("Enemies")
 if not is_instance_valid(parent): return
 var boss := ENEMY_SCENE.instantiate()
 boss.name = "CorruptedAncientTree"
 parent.add_child(boss)
 boss.global_position = Vector2(456,1000)
 boss.configure_boss()
 _boss_spawned = true
