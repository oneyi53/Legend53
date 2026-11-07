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
var _equip_all_button: Button
var _save_text: Label
var _region_text: Label
var _quest_text: Label
var _npc_button: Button
var _dialogue_panel: PanelContainer
var _dialogue_text: Label
var _dialogue_action: Button
var _quest_node: Node
var _npc: Node2D
var _nearby_npc: Node2D
var _service_npcs: Array[Node2D] = []
var _dialogue_title: Label
var _dialogue_secondary: Button
var _dialogue_forge_button: Button
var _dialogue_awaken_button: Button
var _currency_text: Label
var _potion_button: Button
var _skill_button: Button
var _class_button: Button
var _teleport_index := 0
const TELEPORTS := [{"id":"village","name":"守林新手村","position":Vector2(360,320)},{"id":"entrance","name":"林间入口","position":Vector2(360,450)},{"id":"deepwood","name":"幽暗密林","position":Vector2(360,620)},{"id":"ruins","name":"古代遗迹","position":Vector2(360,800)},{"id":"clearing","name":"遗忘祭坛","position":Vector2(456,1000)}]

func _ready() -> void:
    _player = get_tree().get_first_node_in_group("player")
    _combat = get_tree().get_first_node_in_group("combat_director")
    _quest_node = get_tree().get_first_node_in_group("quest_director")
    _npc = get_tree().get_first_node_in_group("quest_npc") as Node2D
    for candidate in get_tree().get_nodes_in_group("service_npcs"):
        if candidate is Node2D:
            _service_npcs.append(candidate)
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
        _player.connect("gold_changed", Callable(self, "_on_gold_changed"))
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
    if is_instance_valid(_quest_node):
        _quest_node.quest_updated.connect(_on_quest_updated)
        _quest_node.quest_notice.connect(_on_loot_message)
        _quest_node.call_deferred("_publish")

func _process(_delta: float) -> void:
    _nearby_npc = null
    if not is_instance_valid(_player):
        _npc_button.visible = false
        return
    var nearest_distance := INF
    var candidates: Array[Node2D] = []
    if is_instance_valid(_npc):
        candidates.append(_npc)
    candidates.append_array(_service_npcs)
    for candidate in candidates:
        if not is_instance_valid(candidate) or not candidate.call("is_player_near", _player):
            continue
        var distance := candidate.global_position.distance_to(_player.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            _nearby_npc = candidate
    if is_instance_valid(_skill_button):
        var remaining := float(_combat.call("get_skill_cooldown_remaining")) if is_instance_valid(_combat) else 0.0
        _skill_button.disabled = remaining > 0.0
        _skill_button.text = "技能冷却 %.1f秒" % remaining if remaining > 0.0 else str(_player.call("get_skill_name"))
    _npc_button.visible = is_instance_valid(_nearby_npc)
    if is_instance_valid(_nearby_npc):
        _npc_button.text = "交谈 · 村长" if _nearby_npc == _npc else "交谈 · " + str(_nearby_npc.get("display_name"))

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
    _notice_text = _make_label(root, Vector2(24, 232), Vector2(520, 22), 13, Color("#8fe6b1"))
    _skill_button = Button.new()
    _skill_button.position = Vector2(536, 650)
    _skill_button.size = Vector2(160, 58)
    _skill_button.text = "旋风斩"
    _skill_button.mouse_filter = Control.MOUSE_FILTER_STOP
    _skill_button.pressed.connect(_cast_skill)
    root.add_child(_skill_button)
    _region_text = _make_label(root, Vector2(24, 74), Vector2(320, 20), 13, Color("#e2d2a9"))
    _region_text.text = "区域：林间入口 · 推荐等级 1"
    _currency_text = _make_label(root, Vector2(24, 54), Vector2(250, 20), 13, Color("#f2d58d"))
    _currency_text.text = "金币 100  ·  药剂 0"
    _quest_text = _make_label(root, Vector2(24, 748), Vector2(500, 48), 13, Color("#f1d7a6"))
    _quest_text.text = "主线：清理林间 · 与守林村长交谈"
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
    _npc_button = Button.new()
    _npc_button.text = "交谈"
    _npc_button.position = Vector2(550, 748)
    _npc_button.size = Vector2(126, 44)
    _npc_button.visible = false
    _npc_button.mouse_filter = Control.MOUSE_FILTER_STOP
    _npc_button.pressed.connect(_open_npc_dialogue)
    root.add_child(_npc_button)
    _inventory_panel = PanelContainer.new()
    _inventory_panel.position = Vector2(24, 312)
    _inventory_panel.size = Vector2(420, 860)
    _inventory_panel.visible = false
    _inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(_inventory_panel)
    var content := VBoxContainer.new()
    _inventory_panel.add_child(content)
    var title := Label.new()
    title.text = "角色装备与背包"
    title.add_theme_font_size_override("font_size", 20)
    content.add_child(title)
    _class_button = Button.new()
    _class_button.text = "切换职业"
    _class_button.pressed.connect(_cycle_class)
    content.add_child(_class_button)
    _inventory_text = Label.new()
    _inventory_text.custom_minimum_size = Vector2(380, 360)
    _inventory_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(_inventory_text)
    _potion_button = Button.new()
    _potion_button.text = "使用生命药剂（恢复60）"
    _potion_button.pressed.connect(_use_potion)
    content.add_child(_potion_button)
    _weapon_button = Button.new()
    _weapon_button.text = "装备更强武器"
    _weapon_button.pressed.connect(_equip_weapon)
    content.add_child(_weapon_button)
    _armor_button = Button.new()
    _armor_button.text = "装备更强护甲"
    _armor_button.pressed.connect(_equip_armor)
    content.add_child(_armor_button)
    _equip_all_button = Button.new()
    _equip_all_button.text = "自动穿戴全部部位最佳装备"
    _equip_all_button.pressed.connect(_equip_all)
    content.add_child(_equip_all_button)
    var close_button := Button.new()
    close_button.text = "关闭"
    close_button.pressed.connect(_toggle_inventory)
    content.add_child(close_button)
    _dialogue_panel = PanelContainer.new()
    _dialogue_panel.position = Vector2(70, 430)
    _dialogue_panel.size = Vector2(580, 250)
    _dialogue_panel.visible = false
    _dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(_dialogue_panel)
    var dialogue_box := VBoxContainer.new()
    _dialogue_panel.add_child(dialogue_box)
    _dialogue_title = Label.new()
    _dialogue_title.text = "守林村长"
    _dialogue_title.add_theme_font_size_override("font_size", 21)
    dialogue_box.add_child(_dialogue_title)
    _dialogue_text = Label.new()
    _dialogue_text.custom_minimum_size = Vector2(530, 120)
    _dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_box.add_child(_dialogue_text)
    _dialogue_action = Button.new()
    _dialogue_action.pressed.connect(_on_dialogue_action)
    dialogue_box.add_child(_dialogue_action)
    _dialogue_secondary = Button.new()
    _dialogue_secondary.text = "切换目的地"
    _dialogue_secondary.visible = false
    _dialogue_secondary.pressed.connect(_cycle_teleport)
    dialogue_box.add_child(_dialogue_secondary)
    _dialogue_forge_button = Button.new()
    _dialogue_forge_button.text = "锻造装备"
    _dialogue_forge_button.visible = false
    _dialogue_forge_button.pressed.connect(_forge_equipment)
    dialogue_box.add_child(_dialogue_forge_button)
    var dialogue_close := Button.new()
    dialogue_close.text = "离开"
    dialogue_close.pressed.connect(func(): _dialogue_panel.visible = false)
    dialogue_box.add_child(dialogue_close)

func _make_label(parent: Control, pos: Vector2, dimensions: Vector2, size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = pos
    label.size = dimensions
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _open_npc_dialogue() -> void:
    if not is_instance_valid(_nearby_npc):
        return
    _dialogue_panel.visible = true
    _dialogue_secondary.visible = false
    _dialogue_forge_button.visible = false
    if _nearby_npc == _npc:
        _dialogue_title.text = "守林村长"
        _dialogue_text.text = _quest_node.call("get_npc_dialogue")
        _dialogue_action.text = _quest_node.call("get_npc_action_text")
        return
    var service := str(_nearby_npc.get("service_type"))
    _dialogue_title.text = str(_nearby_npc.get("display_name"))
    match service:
        "blacksmith":
            _dialogue_text.text = "装备整理与强化：每次强化消耗 50 金币。武器 +2 攻击，护甲 +12 生命；每件装备最多强化 5 次。"
            _dialogue_action.text = "装备背包中更好的武器与护甲"
            _dialogue_secondary.visible = true
            _dialogue_secondary.text = "金币强化当前武器与护甲（各50金币）"
            _dialogue_forge_button.visible = true
            _dialogue_forge_button.text = "符文锻造武器与护甲（每件100金币+2碎片）"
            _dialogue_awaken_button.visible = true
            _dialogue_awaken_button.text = "觉醒已装备武器/衣服/项链（区域材料+金币）"
        "merchant":
            _dialogue_text.text = "生命药剂售价 30 金币，使用后恢复 60 点生命。当前金币：%d，药剂：%d。" % [int(_player.get("gold")), int(_player.get("potions"))]
            _dialogue_action.text = "购买生命药剂 · 30金币"
        "guide":
            _dialogue_text.text = "只有亲自探索抵达过的区域才会开放传送。传送免费；深入区域存在更强敌人。"
            _dialogue_secondary.visible = true
            _teleport_index = _first_unlocked_teleport_index()
            _dialogue_text.text += "\n当前目的地：" + str(TELEPORTS[_teleport_index].name)
            _dialogue_action.text = "传送至此处"

func _on_dialogue_action() -> void:
    if not is_instance_valid(_nearby_npc):
        return
    if _nearby_npc == _npc:
        if _quest_node.call("can_turn_in"):
            _quest_node.call("turn_in_current_quest")
        elif not bool(_quest_node.get("accepted")):
            _quest_node.call("accept_current_quest")
        _open_npc_dialogue()
        return
    match str(_nearby_npc.get("service_type")):
        "blacksmith":
            var weapon_ok: bool = _player.call("equip_best", "weapon")
            var armor_ok: bool = _player.call("equip_best", "armor")
            _notice_text.text = "装备整理完成" if weapon_ok or armor_ok else "背包中暂无可替换装备"
            _refresh_inventory()
        "merchant":
            if _player.call("buy_health_potion"):
                _notice_text.text = "购买成功：生命药剂 ×1"
            else:
                _notice_text.text = "金币不足：生命药剂需要 30 金币"
        "guide":
            var destination: Dictionary = TELEPORTS[_teleport_index]
            if not _player.call("is_region_unlocked", str(destination.id)):
                _notice_text.text = "该区域尚未探索，暂不可传送"
                return
            _player.call("teleport_to", destination.position)
            _notice_text.text = "已传送至：" + str(destination.name)
            _dialogue_panel.visible = false
    if is_instance_valid(_currency_text):
        _currency_text.text = "金币 %d  ·  药剂 %d" % [int(_player.get("gold")), int(_player.get("potions"))]
    if _dialogue_panel.visible and is_instance_valid(_nearby_npc) and _nearby_npc != _npc:
        _open_npc_dialogue()

func _forge_equipment() -> void:
    if not is_instance_valid(_player):
        return
    var weapon_ok: bool = _player.call("forge_equipment", "weapon")
    var armor_ok: bool = _player.call("forge_equipment", "armor")
    var count := int(weapon_ok) + int(armor_ok)
    _notice_text.text = "符文锻造完成：%d 件装备" % count if count > 0 else "锻造失败：每件需100金币、2枚符文碎片，且锻造等级最多+3"
    _open_npc_dialogue()
    _refresh_inventory()

func _awaken_equipment() -> void:
    if not is_instance_valid(_player):
        return
    var awakened := 0
    for slot in ["weapon", "armor", "necklace"]:
        if _player.call("awaken_equipment", slot):
            awakened += 1
    _notice_text.text = "装备觉醒成功：%d 件" % awakened if awakened > 0 else "觉醒未完成：检查装备套装/传说品质、区域材料、符文与金币；每件最多觉醒3阶"
    _open_npc_dialogue()
    _refresh_inventory()

func _cycle_teleport() -> void:
    if is_instance_valid(_nearby_npc) and str(_nearby_npc.get("service_type")) == "blacksmith":
        var weapon_ok: bool = _player.call("upgrade_equipment", "weapon")
        var armor_ok: bool = _player.call("upgrade_equipment", "armor")
        _notice_text.text = "装备强化完成" if weapon_ok or armor_ok else "强化失败：需装备武器/护甲且每件消耗50金币（最多5级）"
        _open_npc_dialogue()
        _refresh_inventory()
        return
    var unlocked := _get_unlocked_teleports()
    if unlocked.size() <= 1:
        _dialogue_text.text = "目前仅开放新手村。亲自探索进入新区域后，向导会开放对应传送点。"
        return
    var current_position := unlocked.find(_teleport_index)
    var next_position := (current_position + 1) % unlocked.size()
    _teleport_index = unlocked[next_position]
    _dialogue_text.text = "选择目的地：%s\n已探索区域免费传送。" % str(TELEPORTS[_teleport_index].name)

func _get_unlocked_teleports() -> Array[int]:
    var result: Array[int] = []
    for index in range(TELEPORTS.size()):
        if _player.call("is_region_unlocked", str(TELEPORTS[index].id)):
            result.append(index)
    return result

func _first_unlocked_teleport_index() -> int:
    var unlocked := _get_unlocked_teleports()
    return unlocked[0] if not unlocked.is_empty() else 0

func _on_gold_changed(_amount: int) -> void:
    if is_instance_valid(_currency_text):
        _currency_text.text = "金币 %d  ·  药剂 %d" % [int(_player.get("gold")), int(_player.get("potions"))]
    _refresh_inventory()

func _cast_skill() -> void:
    if is_instance_valid(_combat) and _combat.call("cast_class_skill"):
        _update_class_skill_button()

func _cycle_class() -> void:
    var current := str(_player.get("class_id"))
    var next_class := "mage" if current == "warrior" else ("taoist" if current == "mage" else "warrior")
    _player.call("switch_class", next_class)
    _notice_text.text = "已转职为%s：%s" % [str(_player.call("get_class_name")), str(_player.call("get_skill_name"))]
    _refresh_inventory()
    _update_class_skill_button()

func _update_class_skill_button() -> void:
    if is_instance_valid(_skill_button) and is_instance_valid(_player):
        _skill_button.text = str(_player.call("get_skill_name"))

func _use_potion() -> void:
    if _player.call("use_health_potion"):
        _notice_text.text = "使用生命药剂，恢复 60 点生命"
    elif int(_player.get("potions")) <= 0:
        _notice_text.text = "没有生命药剂，请前往商人处购买"
    else:
        _notice_text.text = "生命值已满，无需使用药剂"
    _refresh_inventory()

func _toggle_inventory() -> void:
    _inventory_panel.visible = not _inventory_panel.visible
    _refresh_inventory()

func _refresh_inventory() -> void:
    if not is_instance_valid(_inventory_text) or not is_instance_valid(_player):
        return
    var items: Array = _player.get("inventory")
    var lines := PackedStringArray(["职业：%s" % str(_player.call("get_class_name")), str(_player.call("get_equipment_summary")), "", "背包物品："])
    if items.is_empty():
        lines.append("（空）击败森林劫掠者寻找装备")
    else:
        for item in items:
            var slot_labels := {"weapon":"武器", "helmet":"头盔", "necklace":"项链", "bracelet":"手镯", "ring":"戒指", "armor":"衣服", "belt":"腰带", "boots":"鞋子"}
            var slot_name := str(slot_labels.get(str(item.get("slot", "")), "其他"))
            var bonus_parts := PackedStringArray()
            var stat_labels := {"attack":"攻击", "health":"生命", "defense":"防御", "critical_chance":"暴击%", "attack_speed":"攻速%"}
            for stat in ["attack", "health", "defense", "critical_chance", "attack_speed"]:
                var stat_value := float(item.get(stat, 0))
                if stat_value > 0.0:
                    bonus_parts.append("+%s%s" % [str(snappedf(stat_value, 0.1)), stat_labels[stat]])
            var quality_label := str(item.get("quality", "common"))
            var source_label := str(item.get("drop_source", ""))
            lines.append("[%s] %s [%s] %s%s" % [quality_label, str(item.get("name", "装备")), slot_name, " ".join(bonus_parts), " · 来源：" + source_label if not source_label.is_empty() else ""])
    lines.append("")
    lines.append("套装效果与收集进度：")
    lines.append(str(_player.call("get_set_bonus_summary")))
    lines.append(str(_player.call("get_collection_summary")))
    var materials: Dictionary = _player.get("materials")
    lines.append("金币：%d    生命药剂：%d" % [int(_player.get("gold")), int(_player.get("potions"))])
    lines.append("锻造材料：符文碎片 ×%d" % int(materials.get("rune_fragment", 0)))
    lines.append(str(_player.call("get_awaken_material_summary")))
    for slot in ["weapon", "armor", "necklace"]:
        var equipped_item: Dictionary = _player.get("equipment").get(slot, {})
        if not equipped_item.is_empty():
            lines.append("%s觉醒：+%d/3" % [str(equipped_item.get("name", slot)), int(equipped_item.get("awaken_level", 0))])
    _inventory_text.text = "\n".join(lines)
    _class_button.text = "当前：%s · 点击切换职业" % str(_player.call("get_class_name"))
    _potion_button.disabled = int(_player.get("potions")) <= 0 or float(_player.get("health")) >= float(_player.get("max_health"))
    _currency_text.text = "金币 %d  ·  药剂 %d" % [int(_player.get("gold")), int(_player.get("potions"))]
    _weapon_button.disabled = not _has_upgrade("weapon")
    _armor_button.disabled = not _has_upgrade("armor")

func _has_upgrade(slot: String) -> bool:
    var items: Array = _player.get("inventory")
    var gear: Dictionary = _player.get("equipment")
    var equipped: Dictionary = gear.get(slot, {})
    var current := float(_player.call("get_equipment_score", equipped))
    for item in items:
        var value := float(_player.call("get_equipment_score", item))
        if str(item.get("slot", "")) == slot and value > current:
            return true
    return false

func _equip_weapon() -> void:
    _player.call("equip_best", "weapon")
    _refresh_inventory()

func _equip_armor() -> void:
    _player.call("equip_best", "armor")
    _refresh_inventory()

func _equip_all() -> void:
    var count := int(_player.call("equip_best_all"))
    _notice_text.text = "已自动穿戴 %d 件更优装备" % count if count > 0 else "当前装备已是最佳搭配"
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
    if not is_instance_valid(target):
        _target_text.text = "目标：未锁定"
    elif bool(target.get("is_boss")):
        _target_text.text = "目标：首领 · " + str(target.get("boss_title"))
    elif bool(target.get("is_elite")):
        _target_text.text = "目标：精英 · " + str(target.get("elite_title")) + "（Lv.%d）" % int(target.get("enemy_level"))
    else:
        _target_text.text = "目标：森林劫掠者（Lv.%d）" % int(target.get("enemy_level"))

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

func _on_quest_updated(title: String, description: String, progress: String, completed: bool) -> void:
    if is_instance_valid(_quest_text):
        _quest_text.text = "%s · %s\n%s%s" % [title, progress, description, " · 完成" if completed else ""]

func _on_region_changed(region_name: String, recommended_level: int) -> void:
    if is_instance_valid(_region_text):
        _region_text.text = "区域：%s · 推荐等级 %d" % [region_name, recommended_level]

func _on_save_status(message: String) -> void:
    if is_instance_valid(_save_text):
        _save_text.text = "存档：" + message
