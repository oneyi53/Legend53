extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal experience_changed(current: int, required: int, current_level: int)
signal level_up(new_level: int)
signal inventory_changed
signal equipment_changed
signal died
signal respawned
signal save_status(message: String)
signal gold_changed(amount: int)
const SAVE_PATH := "user://hero_world_save.json"
var _autosave_timer: float = 0.0
const AUTOSAVE_INTERVAL: float = 8.0

@export var move_speed: float = 220.0
@export var base_max_health: float = 120.0
@export var respawn_delay: float = 2.0

var health: float
var level: int = 1
var experience: int = 0
var gold: int = 100
var potions: int = 0
var materials: Dictionary = {"rune_fragment": 0}
var class_id: String = "warrior"
var discovered_regions: Array[String] = ["village"]
var inventory: Array[Dictionary] = []
var collected_gear: Dictionary = {}
const EQUIPMENT_SLOTS := ["weapon", "helmet", "necklace", "bracelet", "ring", "armor", "belt", "boots"]
var equipment: Dictionary = {"weapon": {}, "helmet": {}, "necklace": {}, "bracelet": {}, "ring": {}, "armor": {}, "belt": {}, "boots": {}}
var _experience_required: int = 100
var _spawn_position: Vector2
var _is_dead: bool = false
var _auto_target: Node2D
var _path_points := PackedVector2Array()
var _path_index: int = 0
var _path_recalc_timer: float = 0.0

var max_health: float:
    get:
        var class_health := 135.0 if class_id == "warrior" else (88.0 if class_id == "mage" else 108.0)
        return class_health + _equipment_stat("health") + (level - 1) * 12.0

var attack_power: float:
    get:
        var weapon: Dictionary = equipment.get("weapon", {})
        var class_attack := 18.0 if class_id == "warrior" else (15.0 if class_id == "mage" else 16.0)
        return class_attack + _equipment_stat("attack") + (level - 1) * 2.0

var attack_range: float:
    get:
        return 58.0 if class_id == "warrior" else (235.0 if class_id == "mage" else 165.0)

var defense_multiplier: float:
    get:
        var class_factor := 0.72 if class_id == "warrior" else (1.12 if class_id == "mage" else 0.90)
        return maxf(0.35, class_factor - _equipment_stat("defense") * 0.006)

var critical_chance: float:
    get:
        return clampf(0.12 + _equipment_stat("critical_chance") / 100.0, 0.0, 0.60)

var attack_speed_multiplier: float:
    get:
        return clampf(1.0 + _equipment_stat("attack_speed") / 100.0, 0.65, 1.8)

func _equipment_stat(stat_name: String) -> float:
    var total := 0.0
    for slot in EQUIPMENT_SLOTS:
        var item: Dictionary = equipment.get(slot, {})
        total += float(item.get(stat_name, 0.0))
    return total + _set_bonus_stat(stat_name)

func get_equipment_score(item: Dictionary) -> float:
    return float(item.get("attack", 0)) * 4.0 + float(item.get("health", 0)) * 0.45 + float(item.get("defense", 0)) * 8.0 + float(item.get("critical_chance", 0)) * 12.0 + float(item.get("attack_speed", 0)) * 10.0 + float(item.get("quality_rank", 0)) * 2.0 + float(item.get("upgrade_level", 0)) * 1.5

func get_combat_power() -> int:
    var score := float(level) * 12.0 + attack_power * 4.0 + max_health * 0.35 + _equipment_stat("defense") * 8.0 + _equipment_stat("critical_chance") * 12.0 + _equipment_stat("attack_speed") * 10.0
    return roundi(score)

func _active_set_counts() -> Dictionary:
    var counts: Dictionary = {}
    for slot in EQUIPMENT_SLOTS:
        var item: Dictionary = equipment.get(slot, {})
        var set_id := str(item.get("set_id", ""))
        if not set_id.is_empty(): counts[set_id] = int(counts.get(set_id, 0)) + 1
    return counts

func _set_bonus_stat(stat_name: String) -> float:
    var total := 0.0
    var counts := _active_set_counts()
    for set_id in counts:
        var pieces := int(counts[set_id])
        if pieces >= 2 and stat_name == "defense": total += 1.0
        if pieces >= 4:
            if stat_name == "attack": total += 4.0
            if stat_name == "defense": total += 2.0
        if pieces >= 6:
            if stat_name == "health": total += 30.0
            if stat_name == "critical_chance": total += 3.0
        if pieces >= 8:
            if stat_name == "attack": total += 8.0
            if stat_name == "attack_speed": total += 5.0
    return total

func get_set_bonus_summary() -> String:
    var lines := PackedStringArray()
    var counts := _active_set_counts()
    for set_id in ["forest", "ruins"]:
        var pieces := int(counts.get(set_id, 0))
        var label := "林地守望" if set_id == "forest" else "遗迹征服者"
        lines.append("%s套装：%d/8 · 2件防御+1 · 4件攻击+4/防御+2 · 6件生命+30/暴击+3%% · 8件攻击+8/攻速+5%%" % [label, pieces])
    return "\n".join(lines)

func get_collection_summary() -> String:
    # 4 exploration regions × 2 themed sets × 8 slots, plus 3 boss relics.
    # Count unique discovered IDs so old saves and legacy set IDs remain valid.
    return "装备图鉴：%d / 35 件已发现" % mini(collected_gear.size(), 35)
func get_class_name() -> String:
    match class_id:
        "mage": return "法师"
        "taoist": return "道士"
        _: return "战士"

func get_skill_name() -> String:
    match class_id:
        "mage": return "烈焰火球"
        "taoist": return "灵符治疗"
        _: return "旋风斩"

func switch_class(next_class: String) -> bool:
    if next_class not in ["warrior", "mage", "taoist"] or next_class == class_id:
        return false
    var old_max := max_health
    var health_ratio := health / maxf(old_max, 1.0)
    class_id = next_class
    health = clampf(health_ratio * max_health, 1.0, max_health)
    health_changed.emit(health, max_health)
    equipment_changed.emit()
    save_game()
    return true

func restore_health(amount: float) -> float:
    if amount <= 0.0 or _is_dead:
        return 0.0
    var before := health
    health = minf(max_health, health + amount)
    var restored := health - before
    if restored > 0.0:
        health_changed.emit(health, max_health)
        save_game()
    return restored

func _ready() -> void:
    _spawn_position = global_position
    _load_game()
    health = clampf(health, 0.0, max_health)
    if health <= 0.0:
        health = max_health
    add_to_group("player")
    health_changed.emit(health, max_health)
    experience_changed.emit(experience, _experience_required, level)
    inventory_changed.emit()
    equipment_changed.emit()
    save_status.emit("本地存档已读取" if FileAccess.file_exists(SAVE_PATH) else "新旅程已开始")

func _physics_process(delta: float) -> void:
    _autosave_timer += delta
    if _autosave_timer >= AUTOSAVE_INTERVAL:
        _autosave_timer = 0.0
        save_game()
    if _is_dead:
        velocity = Vector2.ZERO
        return
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var direction := Vector2.ZERO
    if input_vector.length_squared() > 0.01:
        _auto_target = null
        direction = Vector2((input_vector.x - input_vector.y) * 0.5, input_vector.x + input_vector.y)
    elif is_instance_valid(_auto_target):
        _path_recalc_timer -= delta
        if _path_recalc_timer <= 0.0:
            _rebuild_auto_path()
        while _path_index < _path_points.size() and global_position.distance_to(_path_points[_path_index]) < 18.0:
            _path_index += 1
        if _path_index < _path_points.size():
            direction = global_position.direction_to(_path_points[_path_index])
        elif global_position.distance_to(_auto_target.global_position) > 58.0:
            direction = global_position.direction_to(_auto_target.global_position)
        else:
            _auto_target = null
            _path_points.clear()
    if direction.length_squared() > 1.0:
        direction = direction.normalized()
    var class_speed := move_speed * (1.0 if class_id == "warrior" else (1.06 if class_id == "mage" else 1.02))
    velocity = direction * class_speed
    move_and_slide()

func set_auto_move_target(target: Node2D) -> void:
    if not _is_dead:
        if _auto_target != target:
            _auto_target = target
            _rebuild_auto_path()

func clear_auto_move_target() -> void:
    _auto_target = null
    _path_points.clear()
    _path_index = 0

func _rebuild_auto_path() -> void:
    _path_recalc_timer = 0.45
    _path_points.clear()
    _path_index = 0
    var navigation := get_tree().get_first_node_in_group("world_navigation")
    if is_instance_valid(navigation) and is_instance_valid(_auto_target) and navigation.has_method("find_world_path"):
        _path_points = navigation.call("find_world_path", global_position, _auto_target.global_position)

func take_damage(amount: float) -> void:
    if _is_dead or amount <= 0.0:
        return
    health = maxf(0.0, health - amount * defense_multiplier)
    health_changed.emit(health, max_health)
    if health <= 0.0:
        _begin_respawn()
    else:
        save_game()

func add_experience(amount: int) -> void:
    if amount <= 0 or _is_dead:
        return
    experience += amount
    while experience >= _experience_required:
        experience -= _experience_required
        level += 1
        _experience_required = 100 + (level - 1) * 45
        health = max_health
        level_up.emit(level)
    health_changed.emit(health, max_health)
    experience_changed.emit(experience, _experience_required, level)
    save_game()

func add_gold(amount: int) -> void:
    if amount <= 0:
        return
    gold += amount
    gold_changed.emit(gold)
    save_game()

func unlock_region(region_id: String) -> bool:
    if region_id.is_empty() or discovered_regions.has(region_id):
        return false
    discovered_regions.append(region_id)
    save_game()
    return true

func is_region_unlocked(region_id: String) -> bool:
    return discovered_regions.has(region_id)

func upgrade_equipment(slot: String) -> bool:
    if not EQUIPMENT_SLOTS.has(slot) or gold < 50:
        return false
    var item: Dictionary = equipment.get(slot, {}).duplicate(true)
    if item.is_empty() or int(item.get("upgrade_level", 0)) >= 5:
        return false
    gold -= 50
    var upgrade_level := int(item.get("upgrade_level", 0)) + 1
    item["upgrade_level"] = upgrade_level
    var stat := _primary_stat_for_slot(slot)
    item[stat] = float(item.get(stat, 0)) + (2.0 if stat == "attack" else (12.0 if stat == "health" else 1.0))
    equipment[slot] = item
    health = minf(health, max_health)
    gold_changed.emit(gold)
    equipment_changed.emit()
    health_changed.emit(health, max_health)
    save_game()
    return true

func add_material(material_id: String, amount: int) -> void:
    if material_id.is_empty() or amount <= 0:
        return
    materials[material_id] = int(materials.get(material_id, 0)) + amount
    inventory_changed.emit()
    save_game()

func forge_equipment(slot: String) -> bool:
    if not EQUIPMENT_SLOTS.has(slot) or gold < 100 or int(materials.get("rune_fragment", 0)) < 2:
        return false
    var item: Dictionary = equipment.get(slot, {}).duplicate(true)
    if item.is_empty() or int(item.get("forge_level", 0)) >= 3:
        return false
    gold -= 100
    materials["rune_fragment"] = int(materials.get("rune_fragment", 0)) - 2
    var forge_level := int(item.get("forge_level", 0)) + 1
    item["forge_level"] = forge_level
    var stat := _primary_stat_for_slot(slot)
    var increase := 4.0 if stat == "attack" else (18.0 if stat == "health" else (2.0 if stat == "defense" else 2.0))
    item[stat] = float(item.get(stat, 0.0)) + increase
    equipment[slot] = item
    health = minf(health, max_health)
    gold_changed.emit(gold)
    equipment_changed.emit()
    health_changed.emit(health, max_health)
    inventory_changed.emit()
    save_game()
    return true

func buy_health_potion() -> bool:
    if gold < 30:
        return false
    gold -= 30
    potions += 1
    save_game()
    return true

func use_health_potion() -> bool:
    if potions <= 0 or health >= max_health or _is_dead:
        return false
    potions -= 1
    health = minf(max_health, health + 60.0)
    health_changed.emit(health, max_health)
    save_game()
    return true

func teleport_to(destination: Vector2) -> void:
    if _is_dead:
        return
    clear_auto_move_target()
    global_position = destination
    velocity = Vector2.ZERO
    save_game()

func add_inventory_item(item: Dictionary) -> void:
    if item.is_empty():
        return
    var item_id := str(item.get("item_id", ""))
    if not item_id.is_empty(): collected_gear[item_id] = 1
    inventory.append(item.duplicate(true))
    inventory_changed.emit()
    save_game()

func equip_best(slot: String) -> bool:
    if not EQUIPMENT_SLOTS.has(slot):
        return false
    var best_index := -1
    var best_value := get_equipment_score(equipment.get(slot, {}))
    for index in range(inventory.size()):
        var item: Dictionary = inventory[index]
        if str(item.get("slot", "")) != slot:
            continue
        var value := get_equipment_score(item)
        if value > best_value:
            best_value = value
            best_index = index
    if best_index < 0:
        return false
    var old_item: Dictionary = equipment.get(slot, {})
    var new_item: Dictionary = inventory[best_index]
    inventory.remove_at(best_index)
    if not old_item.is_empty():
        inventory.append(old_item)
    equipment[slot] = new_item
    health = minf(health, max_health)
    health_changed.emit(health, max_health)
    equipment_changed.emit()
    inventory_changed.emit()
    save_game()
    return true

func equip_best_all() -> int:
    var equipped_count := 0
    for slot in EQUIPMENT_SLOTS:
        if equip_best(slot):
            equipped_count += 1
    return equipped_count

func _primary_stat_for_slot(slot: String) -> String:
    match slot:
        "weapon": return "attack"
        "armor": return "health"
        "helmet", "belt", "boots": return "defense"
        "necklace": return "critical_chance"
        "bracelet", "ring": return "attack_speed"
    return "attack"

func get_equipment_summary() -> String:
    var lines := PackedStringArray()
    var labels := {"weapon":"武器", "helmet":"头盔", "necklace":"项链", "bracelet":"手镯", "ring":"戒指", "armor":"衣服", "belt":"腰带", "boots":"鞋子"}
    for slot in EQUIPMENT_SLOTS:
        var item: Dictionary = equipment.get(slot, {})
        lines.append("%s：%s" % [labels[slot], str(item.get("name", "未装备"))])
    lines.append("攻击 %d · 生命 %d · 防御 %d · 暴击 %.1f%% · 攻速 +%.1f%%" % [roundi(attack_power), roundi(max_health), roundi(_equipment_stat("defense")), critical_chance * 100.0, _equipment_stat("attack_speed")])
    lines.append("角色战力：%d" % get_combat_power())
    lines.append(get_set_bonus_summary())
    lines.append(get_collection_summary())
    return "\n".join(lines)

func _begin_respawn() -> void:
    _is_dead = true
    _auto_target = null
    velocity = Vector2.ZERO
    died.emit()
    var visual := get_node_or_null("BodyVisual") as Polygon2D
    if visual:
        visual.color = Color("#713c48")
    var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collision:
        collision.set_deferred("disabled", true)
    _finish_respawn()

func _finish_respawn() -> void:
    await get_tree().create_timer(respawn_delay).timeout
    if not is_inside_tree():
        return
    global_position = _spawn_position
    health = max_health
    _is_dead = false
    var visual := get_node_or_null("BodyVisual") as Polygon2D
    if visual:
        visual.color = Color(0.25, 0.72, 0.95, 1.0)
    var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collision:
        collision.set_deferred("disabled", false)
    health_changed.emit(health, max_health)
    respawned.emit()
    save_game()


func save_game() -> void:
    var inventory_data: Array = []
    for item in inventory:
        inventory_data.append(item.duplicate(true))
    var data := {
        "version": 1,
        "level": level,
        "experience": experience,
        "experience_required": _experience_required,
        "health": health,
        "gold": gold,
        "potions": potions,
        "materials": materials.duplicate(true),
        "class_id": class_id,
        "discovered_regions": discovered_regions,
        "position_x": global_position.x,
        "position_y": global_position.y,
        "inventory": inventory_data,
        "equipment": equipment.duplicate(true),
        "collected_gear": collected_gear.duplicate(true)
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        save_status.emit("存档失败：无法写入本地文件")
        return
    file.store_string(JSON.stringify(data))
    file.close()
    save_status.emit("已保存")

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        health = max_health
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        health = max_health
        save_status.emit("存档读取失败，使用新角色")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
        health = max_health
        save_status.emit("存档格式不兼容，使用新角色")
        return
    level = maxi(1, int(parsed.get("level", 1)))
    _experience_required = maxi(100, int(parsed.get("experience_required", 100 + (level - 1) * 45)))
    experience = clampi(int(parsed.get("experience", 0)), 0, _experience_required - 1)
    var saved_equipment: Variant = parsed.get("equipment", {})
    if saved_equipment is Dictionary:
        equipment = {"weapon": {}, "helmet": {}, "necklace": {}, "bracelet": {}, "ring": {}, "armor": {}, "belt": {}, "boots": {}}
        for slot in EQUIPMENT_SLOTS:
            var saved_item: Variant = saved_equipment.get(slot, {})
            if saved_item is Dictionary:
                equipment[slot] = saved_item.duplicate(true)
    var saved_collection: Variant = parsed.get("collected_gear", {})
    collected_gear = saved_collection.duplicate(true) if saved_collection is Dictionary else {}
    inventory.clear()
    var saved_inventory: Variant = parsed.get("inventory", [])
    if saved_inventory is Array:
        for item in saved_inventory:
            if item is Dictionary:
                inventory.append(item.duplicate(true))
    var saved_x := float(parsed.get("position_x", global_position.x))
    var saved_y := float(parsed.get("position_y", global_position.y))
    global_position = Vector2(saved_x, saved_y)
    health = float(parsed.get("health", max_health))
    health = clampf(health, 0.0, max_health)
    gold = maxi(0, int(parsed.get("gold", 100)))
    potions = maxi(0, int(parsed.get("potions", 0)))
    var saved_materials: Variant = parsed.get("materials", {})
    materials = saved_materials.duplicate(true) if saved_materials is Dictionary else {}
    materials["rune_fragment"] = maxi(0, int(materials.get("rune_fragment", 0)))
    class_id = str(parsed.get("class_id", "warrior"))
    if class_id not in ["warrior", "mage", "taoist"]:
        class_id = "warrior"
    discovered_regions.clear()
    discovered_regions.append("village")
    var saved_regions: Variant = parsed.get("discovered_regions", ["village"])
    if saved_regions is Array:
        for region_id in saved_regions:
            var region_key := str(region_id)
            if region_key in ["village", "entrance", "deepwood", "ruins", "clearing"] and not discovered_regions.has(region_key):
                discovered_regions.append(region_key)
    gold_changed.emit(gold)

func _exit_tree() -> void:
    if is_inside_tree():
        save_game()
