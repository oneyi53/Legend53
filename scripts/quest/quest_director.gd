extends Node
signal quest_updated(title: String, description: String, progress: String, completed: bool)
signal quest_notice(message: String)
const SAVE_PATH := "user://hero_world_quests.json"
var kills := 0
var forest_done := false
var forest_claimed := false
var boss_done := false
var finale_claimed := false
var accepted := false

func _ready() -> void:
    add_to_group("quest_director")
    _load_quests()
    var combat := get_tree().get_first_node_in_group("combat_director")
    if is_instance_valid(combat):
        combat.enemy_defeated.connect(_on_enemy_defeated)
    _publish()

func accept_current_quest() -> void:
    if finale_claimed:
        return
    accepted = true
    quest_notice.emit("已接取主线：" + ("前往遗忘祭坛，击败腐化古树" if forest_claimed else "清理林间，击败 3 名森林劫掠者"))
    _save_quests()
    _publish()

func can_turn_in() -> bool:
    return (forest_done and not forest_claimed) or (boss_done and forest_claimed and not finale_claimed)

func turn_in_current_quest() -> bool:
    if forest_done and not forest_claimed:
        forest_claimed = true
        accepted = false
        var player := get_tree().get_first_node_in_group("player")
        if is_instance_valid(player):
            player.add_experience(80)
            player.add_inventory_item({"name":"巡林者徽记","slot":"armor","attack":0,"health":20})
        quest_notice.emit("任务交付成功！获得 80 EXP、巡林者徽记")
    elif boss_done and forest_claimed and not finale_claimed:
        finale_claimed = true
        accepted = false
        quest_notice.emit("主线全部完成！遗忘森林恢复了平静")
    else:
        return false
    _save_quests()
    _publish()
    return true

func get_npc_action_text() -> String:
    if can_turn_in():
        return "交付任务 · 领取奖励"
    if finale_claimed:
        return "查看完成记录"
    if not accepted:
        return "接取任务"
    return "继续冒险"

func get_npc_dialogue() -> String:
    if finale_claimed:
        return "腐化古树已经倒下，森林终于重获安宁。你完成了这段旅程。"
    if can_turn_in() and not forest_claimed:
        return "年轻的冒险者，你已经清除了林间威胁。把徽记收下，继续追查遗忘祭坛的异动。"
    if can_turn_in() and forest_claimed:
        return "腐化古树已被击败。请收下我的感谢，森林终于重获安宁。"
    if forest_claimed and not accepted:
        return "祭坛深处的古树正在苏醒。前往遗忘祭坛，终结这场腐化。"
    if accepted and forest_claimed:
        return "遗忘祭坛就在森林深处。找到腐化古树并击败它。"
    if accepted:
        return "森林劫掠者仍在附近出没。击败三名劫掠者，再回来向我报告。"
    return "欢迎来到新手营地。我是守林村长。林间劫掠者正在威胁村庄，你愿意帮忙清理吗？"

func _on_enemy_defeated(enemy: Node2D) -> void:
    if not accepted:
        return
    if enemy.is_boss:
        if forest_claimed and not boss_done:
            boss_done = true
            quest_notice.emit("腐化古树已被击败，返回村长处交付任务")
    elif not forest_claimed and not forest_done:
        kills = mini(kills + 1, 3)
        if kills >= 3:
            forest_done = true
            quest_notice.emit("林间清理完成！返回村长处交付任务")
    _save_quests()
    _publish()

func _publish() -> void:
    if finale_claimed:
        quest_updated.emit("主线：森林守护者", "遗忘森林威胁解除", "已完成", true)
    elif not forest_claimed:
        if not accepted:
            quest_updated.emit("主线：清理林间", "与守林村长交谈并接取任务", "待接取", false)
        elif not forest_done:
            quest_updated.emit("主线：清理林间", "击败森林劫掠者", "%d / 3" % kills, false)
        else:
            quest_updated.emit("主线：清理林间", "返回村长处交付任务", "待交付", false)
    elif not boss_done:
        quest_updated.emit("主线：遗忘祭坛", "击败腐化古树" if accepted else "与村长交谈并接取下一章", "进行中" if accepted else "待接取", false)
    else:
        quest_updated.emit("主线：遗忘祭坛", "返回村长处交付任务", "待交付", false)

func _save_quests() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify({"version":2,"kills":kills,"forest_done":forest_done,"forest_claimed":forest_claimed,"boss_done":boss_done,"finale_claimed":finale_claimed,"accepted":accepted}))
    file.close()

func _load_quests() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Dictionary and int(parsed.get("version",0)) in [1,2]:
        kills = clampi(int(parsed.get("kills",0)),0,3)
        forest_done = bool(parsed.get("forest_done",false))
        forest_claimed = bool(parsed.get("forest_claimed",false))
        boss_done = bool(parsed.get("boss_done",false))
        finale_claimed = bool(parsed.get("finale_claimed",false))
        accepted = bool(parsed.get("accepted", kills > 0 or forest_done or forest_claimed))
