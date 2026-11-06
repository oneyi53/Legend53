extends Node

signal mode_changed(is_auto: bool)
signal target_changed(target: Node2D)
signal loot_message(text: String)
signal enemy_defeated(enemy: Node2D)
signal skill_used(skill_name: String, affected_count: int)

const EXP_LOOT_SCRIPT = preload("res://scripts/combat/experience_drop.gd")
const GEAR_LOOT_SCRIPT = preload("res://scripts/combat/equipment_drop.gd")

@export var auto_notice_range: float = 520.0
@export var auto_attack_range: float = 58.0
@export var manual_target_range: float = 280.0
@export var attack_interval: float = 0.72
@export_range(0.0, 1.0) var experience_drop_chance: float = 0.65
@export_range(0.0, 1.0) var equipment_drop_chance: float = 0.30

var auto_combat_enabled: bool = false
var current_target: Node2D
var _attack_timer: float = 0.0
var _skill_cooldown: float = 0.0
var _bound_enemies: Array[Node] = []

func _ready() -> void:
    add_to_group("combat_director")
    call_deferred("_bind_existing_enemies")

func _process(delta: float) -> void:
    _bind_existing_enemies()
    _attack_timer = maxf(0.0, _attack_timer - delta)
    _skill_cooldown = maxf(0.0, _skill_cooldown - delta)
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
    var effective_range := float(player.get("attack_range"))
    if distance > effective_range:
        if player.has_method("set_auto_move_target"):
            player.set_auto_move_target(current_target)
    else:
        if player.has_method("clear_auto_move_target"):
            player.clear_auto_move_target()
        _attack_current_target()

func _bind_existing_enemies() -> void:
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy) or _bound_enemies.has(enemy):
            continue
        if enemy.has_signal("defeated"):
            enemy.connect("defeated", Callable(self, "_on_enemy_defeated"))
            _bound_enemies.append(enemy)

func _on_enemy_defeated(enemy: Node2D) -> void:
    enemy_defeated.emit(enemy)
    var player := get_tree().get_first_node_in_group("player")
    if is_instance_valid(player) and player.has_method("add_experience"):
        player.add_experience(20)
    if randf() <= experience_drop_chance:
        _spawn_experience_drop(enemy.global_position)
    if is_instance_valid(player) and player.has_method("add_gold"):
        var gold_reward := 150 if enemy.is_boss else randi_range(5, 12)
        player.add_gold(gold_reward)
        loot_message.emit("获得金币 +%d" % gold_reward)
    if enemy.is_boss:
        if is_instance_valid(player):
            player.add_experience(250)
            player.add_inventory_item({"name":"古树守护者之刃","slot":"weapon","attack":12,"health":0})
            player.add_inventory_item({"name":"远古树皮甲","slot":"armor","attack":0,"health":65})
        loot_message.emit("腐化古树已击败！获得首领奖励")
    elif randf() <= equipment_drop_chance:
        _spawn_equipment_drop(enemy.global_position)
    if current_target == enemy:
        current_target = null
        target_changed.emit(null)

func _spawn_experience_drop(pos: Vector2) -> void:
    var drop := Area2D.new()
    drop.set_script(EXP_LOOT_SCRIPT)
    drop.global_position = pos + Vector2(-18, 0)
    get_tree().current_scene.add_child(drop)
    drop.connect("collected", Callable(self, "_on_experience_collected"))

func _spawn_equipment_drop(pos: Vector2) -> void:
    var item: Dictionary
    if randf() < 0.58:
        item = {"name": "林地短刃", "slot": "weapon", "attack": randi_range(2, 5), "health": 0}
    else:
        item = {"name": "巡林皮甲", "slot": "armor", "attack": 0, "health": randi_range(12, 28)}
    var drop := Area2D.new()
    drop.set_script(GEAR_LOOT_SCRIPT)
    drop.item_data = item
    drop.global_position = pos + Vector2(18, 0)
    get_tree().current_scene.add_child(drop)
    drop.connect("collected", Callable(self, "_on_equipment_collected"))

func _on_experience_collected(amount: int) -> void:
    var player := get_tree().get_first_node_in_group("player")
    if is_instance_valid(player) and player.has_method("add_experience"):
        player.add_experience(amount)
    loot_message.emit("拾取经验结晶 +%d EXP" % amount)

func _on_equipment_collected(item: Dictionary) -> void:
    loot_message.emit("获得装备：%s（已放入背包）" % str(item.get("name", "装备")))

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
    var effective_range := float(player.get("attack_range")) if is_instance_valid(player) else auto_attack_range
    if is_instance_valid(player) and player.global_position.distance_to(current_target.global_position) <= effective_range:
        _attack_current_target()

func get_skill_cooldown_remaining() -> float:
    return _skill_cooldown

func get_skill_cooldown_duration() -> float:
    var player := get_tree().get_first_node_in_group("player")
    if not is_instance_valid(player):
        return 8.0
    match str(player.get("class_id")):
        "mage": return 7.0
        "taoist": return 9.0
        _: return 8.0

func cast_class_skill() -> bool:
    if _skill_cooldown > 0.0:
        return false
    var player := get_tree().get_first_node_in_group("player") as Node2D
    if not is_instance_valid(player) or bool(player.get("_is_dead")):
        return false
    var class_key := str(player.get("class_id"))
    var radius := 132.0
    var multiplier := 2.35
    var skill_name := "旋风斩"
    if class_key == "mage":
        radius = 245.0
        multiplier = 2.8
        skill_name = "烈焰火球"
    elif class_key == "taoist":
        radius = 178.0
        multiplier = 1.9
        skill_name = "灵符治疗"
    var hit_count := 0
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy) or not enemy is Node2D:
            continue
        if player.global_position.distance_to(enemy.global_position) <= radius:
            if enemy.has_method("take_damage"):
                enemy.take_damage(float(player.get("attack_power")) * multiplier)
                hit_count += 1
    if class_key == "taoist":
        var missing_health := float(player.get("max_health")) - float(player.get("health"))
        var restored := minf(float(player.get("max_health")) * 0.28, missing_health)
        if restored > 0.0:
            player.call("restore_health", restored)
    _skill_cooldown = get_skill_cooldown_duration()
    skill_used.emit(skill_name, hit_count)
    loot_message.emit("%s发动！命中%d个目标%s" % [skill_name, hit_count, "，治疗效果已生效" if class_key == "taoist" else ""])
    return true

func _attack_current_target() -> void:
    if _attack_timer > 0.0 or not is_instance_valid(current_target):
        return
    var player := get_tree().get_first_node_in_group("player")
    var damage := 18.0
    if is_instance_valid(player):
        damage = float(player.get("attack_power"))
    if current_target.has_method("take_damage"):
        current_target.take_damage(damage)
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
