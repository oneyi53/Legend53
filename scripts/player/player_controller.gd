extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal experience_changed(current: int, required: int, current_level: int)
signal level_up(new_level: int)
signal inventory_changed
signal equipment_changed
signal died
signal respawned
signal save_status(message: String)
const SAVE_PATH := "user://hero_world_save.json"
var _autosave_timer: float = 0.0
const AUTOSAVE_INTERVAL: float = 8.0

@export var move_speed: float = 220.0
@export var base_max_health: float = 120.0
@export var respawn_delay: float = 2.0

var health: float
var level: int = 1
var experience: int = 0
var inventory: Array[Dictionary] = []
var equipment: Dictionary = {"weapon": {}, "armor": {}}
var _experience_required: int = 100
var _spawn_position: Vector2
var _is_dead: bool = false
var _auto_target: Node2D
var _path_points := PackedVector2Array()
var _path_index: int = 0
var _path_recalc_timer: float = 0.0

var max_health: float:
    get:
        var armor: Dictionary = equipment.get("armor", {})
        return base_max_health + float(armor.get("health", 0)) + (level - 1) * 12.0

var attack_power: float:
    get:
        var weapon: Dictionary = equipment.get("weapon", {})
        return 18.0 + float(weapon.get("attack", 0)) + (level - 1) * 2.0

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
    velocity = direction * move_speed
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
    health = maxf(0.0, health - amount)
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

func add_inventory_item(item: Dictionary) -> void:
    if item.is_empty():
        return
    inventory.append(item.duplicate(true))
    inventory_changed.emit()
    save_game()

func equip_best(slot: String) -> bool:
    if slot != "weapon" and slot != "armor":
        return false
    var best_index := -1
    var best_value := -1.0
    var current: Dictionary = equipment.get(slot, {})
    var current_value := float(current.get("attack", 0)) if slot == "weapon" else float(current.get("health", 0))
    for index in range(inventory.size()):
        var item: Dictionary = inventory[index]
        if str(item.get("slot", "")) != slot:
            continue
        var value := float(item.get("attack", 0)) if slot == "weapon" else float(item.get("health", 0))
        if value > current_value and value > best_value:
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

func get_equipment_summary() -> String:
    var weapon: Dictionary = equipment.get("weapon", {})
    var armor: Dictionary = equipment.get("armor", {})
    return "武器：%s (+%d攻击)\n护甲：%s (+%d生命)\n总攻击：%d  生命上限：%d" % [
        str(weapon.get("name", "未装备")), int(weapon.get("attack", 0)),
        str(armor.get("name", "未装备")), int(armor.get("health", 0)),
        roundi(attack_power), roundi(max_health)
    ]

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
        "position_x": global_position.x,
        "position_y": global_position.y,
        "inventory": inventory_data,
        "equipment": equipment.duplicate(true)
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
        equipment = {
            "weapon": saved_equipment.get("weapon", {}),
            "armor": saved_equipment.get("armor", {})
        }
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

func _exit_tree() -> void:
    if is_inside_tree():
        save_game()
