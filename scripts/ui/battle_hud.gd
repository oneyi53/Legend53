extends CanvasLayer

## Runtime health/mode/target HUD for the vertical combat slice.

var _player: Node
var _combat: Node
var _health_bar: ProgressBar
var _health_text: Label
var _mode_text: Label
var _target_text: Label

func _ready() -> void:
    _player = get_tree().get_first_node_in_group("player")
    _combat = get_tree().get_first_node_in_group("combat_director")
    _build_hud()
    if is_instance_valid(_player):
        _player.connect("health_changed", Callable(self, "_on_health_changed"))
        _player.connect("died", Callable(self, "_on_player_died"))
        _player.connect("respawned", Callable(self, "_on_player_respawned"))
        _on_health_changed(float(_player.get("health")), float(_player.get("max_health")))
    if is_instance_valid(_combat):
        _combat.connect("mode_changed", Callable(self, "_on_mode_changed"))
        _combat.target_changed.connect(_on_target_changed)
        _on_mode_changed(bool(_combat.get("auto_combat_enabled")))

func _build_hud() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    _health_text = Label.new()
    _health_text.position = Vector2(24.0, 94.0)
    _health_text.size = Vector2(260.0, 24.0)
    _health_text.add_theme_font_size_override("font_size", 16)
    _health_text.add_theme_color_override("font_color", Color("#f4e9d2"))
    root.add_child(_health_text)

    _health_bar = ProgressBar.new()
    _health_bar.position = Vector2(24.0, 120.0)
    _health_bar.size = Vector2(260.0, 16.0)
    _health_bar.show_percentage = false
    _health_bar.max_value = 120.0
    root.add_child(_health_bar)

    _mode_text = Label.new()
    _mode_text.position = Vector2(24.0, 148.0)
    _mode_text.size = Vector2(240.0, 24.0)
    _mode_text.add_theme_font_size_override("font_size", 15)
    _mode_text.add_theme_color_override("font_color", Color("#d8e3c8"))
    root.add_child(_mode_text)

    _target_text = Label.new()
    _target_text.position = Vector2(24.0, 176.0)
    _target_text.size = Vector2(300.0, 24.0)
    _target_text.add_theme_font_size_override("font_size", 14)
    _target_text.add_theme_color_override("font_color", Color("#e4b69a"))
    _target_text.text = "目标：未锁定"
    root.add_child(_target_text)

func _on_health_changed(current: float, maximum: float) -> void:
    if not is_instance_valid(_health_bar):
        return
    _health_bar.max_value = maximum
    _health_bar.value = current
    _health_text.text = "生命  %d / %d" % [roundi(current), roundi(maximum)]

func _on_mode_changed(is_auto: bool) -> void:
    if is_instance_valid(_mode_text):
        _mode_text.text = "战斗模式：自动" if is_auto else "战斗模式：手动"

func _on_target_changed(target: Node2D) -> void:
    if not is_instance_valid(_target_text):
        return
    _target_text.text = "目标：森林劫掠者" if is_instance_valid(target) else "目标：未锁定"

func _on_player_died() -> void:
    _health_text.text = "生命耗尽 · 2秒后重返战场"

func _on_player_respawned() -> void:
    _on_health_changed(float(_player.get("health")), float(_player.get("max_health")))
