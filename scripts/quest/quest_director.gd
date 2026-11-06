extends Node
signal quest_updated(title: String, description: String, progress: String, completed: bool)
signal quest_notice(message: String)
const SAVE_PATH := "user://hero_world_quests.json"
var kills := 0
var forest_done := false
var boss_done := false

func _ready() -> void:
    add_to_group("quest_director")
    _load_quests()
    var combat := get_tree().get_first_node_in_group("combat_director")
    if is_instance_valid(combat):
        combat.enemy_defeated.connect(_on_enemy_defeated)
    _publish()

func _on_enemy_defeated(enemy: Node2D) -> void:
    if enemy.is_boss:
        if not boss_done:
            boss_done = true
            quest_notice.emit("遗忘森林主线完成！")
    elif not forest_done:
        kills = mini(kills + 1, 3)
        if kills >= 3:
            forest_done = true
            var player := get_tree().get_first_node_in_group("player")
            if is_instance_valid(player):
                player.add_experience(80)
                player.add_inventory_item({"name":"巡林者徽记","slot":"armor","attack":0,"health":20})
            quest_notice.emit("清理林间任务完成！奖励：80 EXP、巡林者徽记")
    _save_quests()
    _publish()

func _publish() -> void:
    if not forest_done:
        quest_updated.emit("主线：清理林间", "击败森林劫掠者", "%d / 3" % kills, false)
    elif not boss_done:
        quest_updated.emit("主线：遗忘祭坛", "击败腐化古树", "等待挑战首领", false)
    else:
        quest_updated.emit("主线：森林守护者", "遗忘森林威胁解除", "已完成", true)

func _save_quests() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify({"version":1,"kills":kills,"forest_done":forest_done,"boss_done":boss_done}))
    file.close()

func _load_quests() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Dictionary and int(parsed.get("version",0)) == 1:
        kills = clampi(int(parsed.get("kills",0)),0,3)
        forest_done = bool(parsed.get("forest_done",false))
        boss_done = bool(parsed.get("boss_done",false))
