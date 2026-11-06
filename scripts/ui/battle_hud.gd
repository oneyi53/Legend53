extends CanvasLayer

## Health, experience, level, target and combat mode HUD.

var _player: Node
var _combat: Node
var _health_bar: ProgressBar
var _health_text: Label
var _experience_bar: ProgressBar
var _experience_text: Label
var _mode_text: Label
var _target_text: Label
var _notice_text: Label

func _ready() -> void:
    _player = get_tree().get_first_node_in_group("player")
    _combat = get_tree().get_first_node_in_group("combat_director")
    _build_hud()
    if is_instance_valid(_player):
        _player.connect("health_changed", Callable(self, "_on_health_changed"))
        _player.connect("experience_changed", Callable(self, "_on_experience_changed"))
        _player.connect("level_up", Callable(self, "_on_level_up"))
        _player.connect("died", Callable(self, "_on_player_died"))
        _player.connect("respawned", Callable(self, "_on_player_respawned"))
        _on_health_changed(float(_player.get("health")), float(_player.get("max_health")))
        _on_experience_changed(int(_player.get("experience")), int(_player.get("_experience_required")), int(_player.get("level")))
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
    _notice_text = _make_label(root, Vector2(24, 232), Vector2(360, 22), 13, Color("#8fe6b1"))

func _make_label(parent: Control, position: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = position
    label.size = dimensions
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _on_health_changed(current: float, maximum: float) -> void:
    if not is_instance_valid(_health_bar):
        return
    _health_bar.max_value = maximum
    _health_bar.value = current
    _health_text.text = "生命  %d / %d" % [roundi(current), roundi(maximum)]

func _on_experience_changed(current: int, required: int, current_level: int) -> void:
    if not is_instance_valid(_experience_bar):
        return
    _experience_bar.max_value = required
    _experience_bar.value = current
    _experience_text.text = "等级 %d    经验 %d / %d" % [current_level, current, required]

func _on_level_up(new_level: int) -> void:
    _notice_text.text = "升级！当前等级 %d，生命上限提升" % new_level

func _on_mode_changed(is_auto: bool) -> void:
    _mode_text.text = "战斗模式：自动" if is_auto else "战斗模式：手动"

func _on_target_changed(target: Node2D) -> void:
    _target_text.text = "目标：森林劫掠者" if is_instance_valid(target) else "目标：未锁定"

func _on_loot_message(message: String) -> void:
    _notice_text.text = message

func _on_player_died() -> void:
    _notice_text.text = "生命耗尽 · 2秒后重返战场"

func _on_player_respawned() -> void:
    _on_health_changed(float(_player.get("health")), float(_player.get("max_health")))
    _notice_text.text = "已返回战场"
