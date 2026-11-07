extends Node

signal mode_changed(is_auto: bool)
signal target_changed(target: Node2D)
signal loot_message(text: String)
signal enemy_defeated(enemy: Node2D)
signal skill_used(skill_name: String, affected_count: int)

const EXP_LOOT_SCRIPT = preload("res://scripts/combat/experience_drop.gd")
const GEAR_LOOT_SCRIPT = preload("res://scripts/combat/equipment_drop.gd")
const COMBAT_EFFECT_SCRIPT = preload("res://scripts/combat/combat_effect.gd")

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
        player.add_experience(45 if enemy.is_elite else 20)
    if enemy.is_elite or randf() <= experience_drop_chance:
        _spawn_experience_drop(enemy.global_position)
    if is_instance_valid(player) and player.has_method("add_gold"):
        var gold_reward := 150 if enemy.is_boss else (randi_range(20, 30) if enemy.is_elite else randi_range(5, 12))
        player.add_gold(gold_reward)
        loot_message.emit("获得金币 +%d" % gold_reward)
    if enemy.is_boss:
        if is_instance_valid(player):
            player.add_experience(250)
            player.add_inventory_item({"item_id":"boss_corrupted_tree_blade","name":"传说·古树守护者之刃","slot":"weapon","attack":22,"health":0,"quality":"legendary","quality_rank":5,"drop_source":"腐化古树首领"})
            player.add_inventory_item({"item_id":"boss_ancient_bark_armor","name":"传说·远古树皮甲","slot":"armor","attack":0,"health":110,"defense":2,"quality":"legendary","quality_rank":5,"drop_source":"腐化古树首领"})
            player.add_inventory_item({"item_id":"boss_corruption_core","name":"传说·腐化核心坠饰","slot":"necklace","attack":0,"health":35,"critical_chance":5,"quality":"legendary","quality_rank":5,"drop_source":"腐化古树首领"})
        loot_message.emit("腐化古树已击败！获得专属传说装备与首领图鉴")
    elif enemy.is_elite or randf() <= equipment_drop_chance:
        _spawn_equipment_drop(enemy.global_position, enemy)
    if enemy.is_elite:
        loot_message.emit("精英怪击败！额外经验与金币已获得")
    if current_target == enemy:
        current_target = null
        target_changed.emit(null)

func _spawn_experience_drop(pos: Vector2) -> void:
    var drop := Area2D.new()
    drop.set_script(EXP_LOOT_SCRIPT)
    drop.global_position = pos + Vector2(-18, 0)
    get_tree().current_scene.add_child(drop)
    drop.connect("collected", Callable(self, "_on_experience_collected"))

func _spawn_equipment_drop(pos: Vector2, enemy: Node2D) -> void:
    var zone_id := str(enemy.get("zone_name"))
    if zone_id == "遗忘祭坛":
        zone_id = "clearing"
    if zone_id not in ["entrance", "deepwood", "ruins", "clearing"]:
        zone_id = "entrance"
    var set_id := "forest" if zone_id in ["entrance", "deepwood"] else "ruins"
    var set_names := {"forest":"林地守望", "ruins":"遗迹征服者"}
    var region_names := {"entrance":"林间入口", "deepwood":"幽暗密林", "ruins":"古代遗迹", "clearing":"遗忘祭坛"}
    var region_prefixes := {"entrance":"林间", "deepwood":"幽暗", "ruins":"遗迹", "clearing":"祭坛"}
    var roll := randf()
    # Progressively better areas and elite enemies improve the quality roll.
    roll = minf(0.999, roll + (0.08 if zone_id == "deepwood" else (0.14 if zone_id == "ruins" else (0.20 if zone_id == "clearing" else 0.0))) + (0.12 if enemy.is_elite else 0.0))
    var quality := "common"
    var rank := 1
    if roll >= 0.995:
        quality = "legendary"
        rank = 5
    elif roll >= 0.96:
        quality = "epic"
        rank = 4
    elif roll >= 0.84:
        quality = "rare"
        rank = 3
    elif roll >= 0.58:
        quality = "fine"
        rank = 2
    var multiplier := [1.0, 1.0, 1.18, 1.42, 1.78, 2.35][rank]
    var region_multiplier := 1.0 + (0.12 if zone_id == "deepwood" else (0.22 if zone_id == "ruins" else (0.35 if zone_id == "clearing" else 0.0)))
    multiplier *= region_multiplier
    var slot_pool := ["weapon", "helmet", "necklace", "bracelet", "ring", "armor", "belt", "boots"]
    var slot := str(slot_pool[randi_range(0, slot_pool.size() - 1)])
    var primary_stats := {"weapon":"attack", "helmet":"defense", "necklace":"critical_chance", "bracelet":"attack_speed", "ring":"attack_speed", "armor":"health", "belt":"defense", "boots":"defense"}
    var stat_ranges := {"attack":[2,5], "health":[12,28], "defense":[1,3], "critical_chance":[1,3], "attack_speed":[1,3]}
    var set_piece_names := {
        "forest":{"weapon":"守望者短刃","helmet":"守望者头盔","necklace":"守望者坠饰","bracelet":"守望者护腕","ring":"守望者指环","armor":"守望者轻甲","belt":"守望者腰带","boots":"守望者长靴"},
        "ruins":{"weapon":"遗迹裁决者","helmet":"遗迹石盔","necklace":"古文明项链","bracelet":"符文护腕","ring":"符文戒指","armor":"遗迹胸甲","belt":"遗迹束带","boots":"遗迹行靴"}
    }
    var stat := str(primary_stats[slot])
    var limits: Array = stat_ranges[stat]
    var item_id := "%s_%s_%s" % [set_id, zone_id, slot]
    var item: Dictionary = {"name":"%s·%s" % [str(region_prefixes[zone_id]), str(set_piece_names[set_id][slot])], "slot":slot, "set_id":set_id, "set_name":str(set_names[set_id]), "item_id":item_id, "drop_source":str(region_names[zone_id]), "attack":0, "health":0, "defense":0, "critical_chance":0, "attack_speed":0}
    item[stat] = roundi(randi_range(int(limits[0]), int(limits[1])) * multiplier)
    if rank >= 3 or zone_id in ["ruins", "clearing"]:
        var affix_stats := ["attack", "health", "defense", "critical_chance", "attack_speed"]
        affix_stats.erase(stat)
        var affix := str(affix_stats[randi_range(0, affix_stats.size() - 1)])
        var affix_limits: Array = stat_ranges[affix]
        item[affix] = roundi(randi_range(int(affix_limits[0]), int(affix_limits[1])) * multiplier * 0.55)
    var quality_names := {"common":"普通", "fine":"优秀", "rare":"稀有", "epic":"史诗", "legendary":"传说"}
    item["quality"] = quality
    item["quality_rank"] = rank
    item["name"] = str(quality_names[quality]) + "·" + str(item["name"])
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
    var effect_kind := "slash"
    if class_key == "mage":
        effect_kind = "fire"
    elif class_key == "taoist":
        effect_kind = "seal"
    _spawn_combat_effect(player.global_position, effect_kind, skill_name, false)
    var hit_count := 0
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy) or not enemy is Node2D:
            continue
        if player.global_position.distance_to(enemy.global_position) <= radius:
            if enemy.has_method("take_damage"):
                var skill_damage := float(player.get("attack_power")) * multiplier
                enemy.take_damage(skill_damage)
                _spawn_combat_effect(enemy.global_position, effect_kind, str(roundi(skill_damage)), false)
                hit_count += 1
    if class_key == "taoist":
        var missing_health := float(player.get("max_health")) - float(player.get("health"))
        var restored := minf(float(player.get("max_health")) * 0.28, missing_health)
        if restored > 0.0:
            player.call("restore_health", restored)
            _spawn_combat_effect(player.global_position, "heal", "+%d" % roundi(restored), false)
    _skill_cooldown = get_skill_cooldown_duration()
    skill_used.emit(skill_name, hit_count)
    loot_message.emit("%s发动！命中%d个目标%s" % [skill_name, hit_count, "，治疗效果已生效" if class_key == "taoist" else ""])
    return true

func _attack_current_target() -> void:
    if _attack_timer > 0.0 or not is_instance_valid(current_target):
        return
    var player := get_tree().get_first_node_in_group("player")
    var damage := 18.0
    var critical_chance := 0.12
    var speed_multiplier := 1.0
    if is_instance_valid(player):
        damage = float(player.get("attack_power"))
        critical_chance = float(player.get("critical_chance"))
        speed_multiplier = float(player.get("attack_speed_multiplier"))
    var critical := randf() < critical_chance
    if critical:
        damage *= 1.8
    if current_target.has_method("take_damage"):
        current_target.take_damage(damage)
        _spawn_combat_effect(current_target.global_position, "slash", str(roundi(damage)), critical)
    _attack_timer = attack_interval / maxf(speed_multiplier, 0.1)
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

func _spawn_combat_effect(world_position: Vector2, effect_kind: String, label_text: String, critical: bool) -> void:
    var effect := Node2D.new()
    effect.set_script(COMBAT_EFFECT_SCRIPT)
    effect.set("effect_kind", effect_kind)
    effect.set("label_text", label_text)
    effect.set("is_critical", critical)
    effect.global_position = world_position
    get_tree().current_scene.add_child(effect)
