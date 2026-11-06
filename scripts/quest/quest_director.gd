extends Node
signal quest_updated(title: String, description: String, progress: String, completed: bool)
signal quest_notice(message: String)
var kills := 0
var forest_done := false
var boss_done := false

func _ready() -> void:
    add_to_group("quest_director")
    var combat := get_tree().get_first_node_in_group("combat_director")
    if is_instance_valid(combat):
        combat.enemy_defeated.connect(_on_enemy_defeated)
    _publish()

func _on_enemy_defeated(enemy: Node2D) -> void:
    if enemy.is_boss:
        boss_done = true
        quest_notice.emit("遗忘森林主线完成！")
    elif not forest_done:
        kills = mini(kills + 1, 3)
        if kills == 3:
            forest_done = true
            quest_notice.emit("清理林间任务完成！")
    _publish()

func _publish() -> void:
    if not forest_done:
        quest_updated.emit("主线：清理林间", "击败森林劫掠者", "%d / 3" % kills, false)
    elif not boss_done:
        quest_updated.emit("主线：遗忘祭坛", "击败腐化古树", "等待挑战首领", false)
    else:
        quest_updated.emit("主线：森林守护者", "遗忘森林威胁解除", "已完成", true)
