extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal experience_changed(current: int, required: int, current_level: int)
signal level_up(new_level: int)
signal inventory_changed
signal equipment_changed
signal died
signal respawned

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

var max_health: float:
    get:
        var armor: Dictionary = equipment.get("armor", {})
        return base_max_health + float(armor.get("health", 0)) + (level - 1) * 12.0

var attack_power: float:
    get:
        var weapon: Dictionary = equipment.get("weapon", {})
        return 18.0 + float(weapon.get("attack", 0)) + (level - 1) * 2.0

func _ready() -> void:
    health = max_health
    _spawn_position = global_position
    add_to_group("player")
    health_changed.emit(health, max_health)
    experience_changed.emit(experience, _experience_required, level)

func _physics_process(_delta: float) -> void:
    if _is_dead:
        velocity = Vector2.ZERO
        return
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var direction := Vector2.ZERO
    if input_vector.length_squared() > 0.01:
        _auto_target = null
        direction = Vector2((input_vector.x - input_vector.y) * 0.5, input_vector.x + input_vector.y)
    elif is_instance_valid(_auto_target):
        if global_position.distance_to(_auto_target.global_position) > 54.0:
            direction = global_position.direction_to(_auto_target.global_position)
        else:
            _auto_target = null
    if direction.length_squared() > 1.0:
        direction = direction.normalized()
    velocity = direction * move_speed
    move_and_slide()

func set_auto_move_target(target: Node2D) -> void:
    if not _is_dead:
        _auto_target = target

func clear_auto_move_target() -> void:
    _auto_target = null

func take_damage(amount: float) -> void:
    if _is_dead or amount <= 0.0:
        return
    health = maxf(0.0, health - amount)
    health_changed.emit(health, max_health)
    if health <= 0.0:
        _begin_respawn()

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

func add_inventory_item(item: Dictionary) -> void:
    if item.is_empty():
        return
    inventory.append(item.duplicate(true))
    inventory_changed.emit()

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
