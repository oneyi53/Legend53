extends CanvasLayer

var _player: Node
var _combat: Node
var _health_bar: ProgressBar
var _health_text: Label
var _experience_bar: ProgressBar
var _experience_text: Label
var _mode_text: Label
var _target_text: Label
var _notice_text: Label
var _inventory_panel: PanelContainer
var _inventory_text: Label
var _weapon_button: Button
var _armor_button: Button
var _save_text: Label
var _region_text: Label

func _ready() -> void:
    _player = get_tree().get_first_node_in_group("player")
    _combat = get_tree().get_first_node_in_group("combat_director")
    _build_hud()
    if is_instance_valid(_player):
        _player.connect("health_changed", Callable(self, "_on_health_changed"))
        _player.connect("experience_changed", Callable(self, "_on_experience_changed"))
        _player.connect("level_up", Callable(self, "_on_level_up"))
        _player.connect("inventory_changed", Callable(self, "_refresh_inventory"))
        _player.connect("equipment_changed", Callable(self, "_refresh_inventory"))
        _player.connect("died", Callable(self, "_on_player_died"))
        _player.connect("respawned", Callable(self, "_on_player_respawned"))
        _player.connect("save_status", Callable(self, "_on_save_status"))
        _on_health_changed(float(_player.get("health")), float(_player.get("max_health")))
        _on_experience_changed(int(_player.get("experience")), int(_player.get("_experience_required")), int(_player.get("level")))
        _refresh_inventory()
    var world := get_tree().get_first_node_in_group("world_navigation")
    if is_instance_valid(world) and world.has_signal("region_changed"):
        world.connect("region_changed", Callable(self, "_on_region_changed"))
        var region: Dictionary = world.call("get_current_region")
        _on_region_changed(str(region.name), int(region.level))
    if is_instance_valid(_combat):
        _combat.connect("mode_changed", Callable(self, "_on_mode_changed"))
        _combat.connect("target_changed", Callable(self, "_on_target_changed"))
        _combat.connect("loot_message", Callable(self, "_on_loot_message"))
        _on_mode_changed(bool(_combat.get("auto_combat_enabled")))

func _build_hud() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _health_text = _make_label(root, Vector2(24, 94), Vector2(280, 24), 16, Color("#f4e9d2"))
    _health_bar = ProgressBar.new()
    _health_bar.position = Vector2(24, 120)
    _health_bar.size = Vector2(260, 14)
    _health_bar.show_percentage = false
    root.add_child(_health_bar)
    _experience_text = _make_label(root, Vector2(24, 139), Vector2(300, 20), 13, Color("#d8e3c8"))
    _experience_bar = ProgressBar.new()
    _experience_bar.position = Vector2(24, 161)
    _experience_bar.size = Vector2(260, 9)
    _experience_bar.show_percentage = false
    root.add_child(_experience_bar)
    _mode_text = _make_label(root, Vector2(24, 180), Vector2(240, 22), 14, Color("#d8e3c8"))
    _target_text = _make_label(root, Vector2(24, 205), Vector2(300, 22), 13, Color("#e4b69a"))
    _target_text.text = "目标：未锁定"
    _notice_text = _make_label(root, Vector2(24, 232), Vector2(420, 22), 13, Color("#8fe6b1"))
    _region_text = _make_label(root, Vector2(24, 74), Vector2(320, 20), 13, Color("#e2d2a9"))
    _region_text.text = "区域：林间入口 · 推荐等级 1"
    _save_text = _make_label(root, Vector2(24, 708), Vector2(300, 20), 12, Color("#b7c7b9"))
    var save_button := Button.new()
    save_button.text = "立即存档"
    save_button.position = Vector2(570, 24)
    save_button.size = Vector2(126, 38)
    save_button.mouse_filter = Control.MOUSE_FILTER_STOP
    save_button.pressed.connect(_save_now)
    root.add_child(save_button)

    var open_button := Button.new()
    open_button.text = "背包 / 装备"
    open_button.position = Vector2(24, 266)
    open_button.size = Vector2(132, 38)
    open_button.mouse_filter = Control.MOUSE_FILTER_STOP
    open_button.pressed.connect(_toggle_inventory)
    root.add_child(open_button)

    _inventory_panel = PanelContainer.new()
    _inventory_panel.position = Vector2(24, 312)
    _inventory_panel.size = Vector2(420, 330)
    _inventory_panel.visible = false
    _inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(_inventory_panel)
    var content := VBoxContainer.new()
    _inventory_panel.add_child(content)
    var title := Label.new()
    title.text = "角色装备与背包"
    title.add_theme_font_size_override("font_size", 20)
    content.add_child(title)
    _inventory_text = Label.new()
    _inventory_text.custom_minimum_size = Vector2(380, 160)
    _inventory_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(_inventory_text)
    _weapon_button = Button.new()
    _weapon_button.text = "装备更强武器"
    _weapon_button.pressed.connect(_equip_weapon)
    content.add_child(_weapon_button)
    _armor_button = Button.new()
    _armor_button.text = "装备更强护甲"
    _armor_button.pressed.connect(_equip_armor)
    content.add_child(_armor_button)
    var close_button := Button.new()
    close_button.text = "关闭"
    close_button.pressed.connect(_toggle_inventory)
    content.add_child(close_button)

func _make_label(parent: Control, pos: Vector2, dimensions: Vector2, size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = pos
    label.size = dimensions
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _toggle_inventory() -> void:
    _inventory_panel.visible = not _inventory_panel.visible
    _refresh_inventory()

func _refresh_inventory() -> void:
    if not is_instance_valid(_inventory_text) or not is_instance_valid(_player):
        return
    var items: Array = _player.get("inventory")
    var lines := PackedStringArray([str(_player.call("get_equipment_summary")), "", "背包物品："])
    if items.is_empty():
        lines.append("（空）击败森林劫掠者寻找装备")
    else:
        for item in items:
            var slot_name := "武器" if str(item.get("slot", "")) == "weapon" else "护甲"
            var bonus := "+%d攻击" % int(item.get("attack", 0)) if slot_name == "武器" else "+%d生命" % int(item.get("health", 0))
            lines.append("%s [%s] %s" % [str(item.get("name", "装备")), slot_name, bonus])
    _inventory_text.text = "\n".join(lines)
    _weapon_button.disabled = not _has_upgrade("weapon")
    _armor_button.disabled = not _has_upgrade("armor")

func _has_upgrade(slot: String) -> bool:
    var items: Array = _player.get("inventory")
    var gear: Dictionary = _player.get("equipment")
    var equipped: Dictionary = gear.get(slot, {})
    var current := float(equipped.get("attack", 0)) if slot == "weapon" else float(equipped.get("health", 0))
    for item in items:
        var value := float(item.get("attack", 0)) if slot == "weapon" else float(item.get("health", 0))
        if str(item.get("slot", "")) == slot and value > current:
            return true
    return false

func _equip_weapon() -> void:
    _player.call("equip_best", "weapon")
    _refresh_inventory()

func _equip_armor() -> void:
    _player.call("equip_best", "armor")
    _refresh_inventory()

func _on_health_changed(current: float, maximum: float) -> void:
    _health_bar.max_value = maximum
    _health_bar.value = current
    _health_text.text = "生命 %d / %d" % [roundi(current), roundi(maximum)]

func _on_experience_changed(current: int, required: int, current_level: int) -> void:
    _experience_bar.max_value = required
    _experience_bar.value = current
    _experience_text.text = "等级 %d  经验 %d / %d" % [current_level, current, required]

func _on_level_up(new_level: int) -> void:
    _notice_text.text = "升级！当前等级 %d，属性提升" % new_level

func _on_mode_changed(is_auto: bool) -> void:
    _mode_text.text = "战斗模式：自动" if is_auto else "战斗模式：手动"

func _on_target_changed(target: Node2D) -> void:
    _target_text.text = "目标：森林劫掠者" if is_instance_valid(target) else "目标：未锁定"

func _on_loot_message(message: String) -> void:
    _notice_text.text = message
    _refresh_inventory()

func _on_player_died() -> void:
    _notice_text.text = "生命耗尽 · 2秒后重返战场"

func _on_player_respawned() -> void:
    _on_health_changed(float(_player.get("health")), float(_player.get("max_health")))
    _notice_text.text = "已返回战场"


func _save_now() -> void:
    if is_instance_valid(_player):
        _player.call("save_game")

func _on_region_changed(region_name: String, recommended_level: int) -> void:
    if is_instance_valid(_region_text):
        _region_text.text = "区域：%s · 推荐等级 %d" % [region_name, recommended_level]

func _on_save_status(message: String) -> void:
    if is_instance_valid(_save_text):
        _save_text.text = "存档：" + message
