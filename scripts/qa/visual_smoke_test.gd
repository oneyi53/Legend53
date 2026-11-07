extends SceneTree

const MAIN_SCENE := preload("res://scenes/boot/main.tscn")
const SAMPLE_STEP := 8

var _output_dir := ""

func _initialize() -> void:
    call_deferred("_run_visual_checks")

func _run_visual_checks() -> void:
    _output_dir = OS.get_environment("VISUAL_OUTPUT_DIR")
    if _output_dir.is_empty():
        _output_dir = "user://visual-artifacts"
    if _output_dir.begins_with("user://"):
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
        _output_dir = ProjectSettings.globalize_path(_output_dir)
    else:
        DirAccess.make_dir_recursive_absolute(_output_dir)

    var scene := MAIN_SCENE.instantiate()
    root.add_child(scene)
    for _frame in range(45):
        await process_frame

    var player := scene.get_node_or_null("Player")
    var world := scene.get_node_or_null("World")
    var hud := scene.get_node_or_null("HUD")
    var touch_controls := scene.get_node_or_null("HUD/TouchControls")
    if not is_instance_valid(player) or not is_instance_valid(world) or not is_instance_valid(hud) or not is_instance_valid(touch_controls):
        push_error("Visual smoke test: required Player/World/HUD/TouchControls node missing.")
        quit(1)
        return

    player.global_position = Vector2(360.0, 320.0)
    for _frame in range(12):
        await process_frame
    if not _capture_viewport("hero-world-startup.png"):
        quit(1)
        return

    if not hud.has_method("_toggle_inventory"):
        push_error("Visual smoke test: inventory toggle is unavailable.")
        quit(1)
        return
    hud.call("_toggle_inventory")
    for _frame in range(4):
        await process_frame
    var inventory_panel = hud.get("_inventory_panel")
    if not is_instance_valid(inventory_panel) or not inventory_panel.visible:
        push_error("Visual smoke test: inventory panel did not become visible.")
        quit(1)
        return
    for control_name in ["_skill_upgrade_button", "_potion_button", "_weapon_button", "_armor_button", "_equip_all_button"]:
        var action_control := hud.get(control_name) as Control
        if not is_instance_valid(action_control) or not action_control.visible:
            push_error("Visual smoke test: inventory action %s is missing or hidden." % control_name)
            quit(1)
            return
        var action_rect := action_control.get_global_rect()
        if action_rect.position.y < 0.0 or action_rect.end.y > root.get_viewport().get_visible_rect().size.y:
            push_error("Visual smoke test: inventory action %s is outside the visible screen." % control_name)
            quit(1)
            return
    if not is_instance_valid(hud.get("_dialogue_awaken_button")):
        push_error("Visual smoke test: blacksmith awakening action is missing.")
        quit(1)
        return
    if not _capture_viewport("hero-world-inventory.png"):
        quit(1)
        return

    print("Visual smoke test passed. Screenshots saved to: ", _output_dir)
    quit(0)

func _capture_viewport(file_name: String) -> bool:
    var viewport := root.get_viewport()
    var image := viewport.get_texture().get_image()
    if image.is_empty():
        push_error("Visual smoke test: viewport image is empty.")
        return false
    var width_override := int(ProjectSettings.get_setting("display/window/size/window_width_override"))
    var height_override := int(ProjectSettings.get_setting("display/window/size/window_height_override"))
    var expected_size := Vector2i(
        width_override if width_override > 0 else int(ProjectSettings.get_setting("display/window/size/viewport_width")),
        height_override if height_override > 0 else int(ProjectSettings.get_setting("display/window/size/viewport_height"))
    )
    if image.get_size() != expected_size:
        push_error("Visual smoke test: unexpected viewport size %s (expected %s)." % [str(image.get_size()), str(expected_size)])
        return false

    var background := image.get_pixel(0, 0)
    var varied_samples := 0
    for y in range(0, image.get_height(), SAMPLE_STEP):
        for x in range(0, image.get_width(), SAMPLE_STEP):
            var pixel := image.get_pixel(x, y)
            var distance := absf(pixel.r - background.r) + absf(pixel.g - background.g) + absf(pixel.b - background.b)
            if distance > 0.12:
                varied_samples += 1
    if varied_samples < 120:
        push_error("Visual smoke test: rendered frame appears blank or incomplete (%d varied samples)." % varied_samples)
        return false

    var output_path := _output_dir.path_join(file_name)
    var error := image.save_png(output_path)
    if error != OK:
        push_error("Visual smoke test: failed to save screenshot (%s), error %d." % [output_path, error])
        return false
    print("Captured ", output_path, " | size=", image.get_size(), " | varied_samples=", varied_samples)
    return true
