extends Node2D

## Portrait-oriented, code-drawn isometric field. No external art assets required.

const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 16
const TILE_WIDTH: float = 96.0
const TILE_HEIGHT: float = 48.0
const GRID_ORIGIN := Vector2(456.0, 64.0)

const FLOOR_A := Color("#344b42")
const FLOOR_B := Color("#3a5248")
const GRID_LINE := Color("#607568")
const EDGE_COLOR := Color("#9aab83")

var _astar := AStarGrid2D.new()

signal region_changed(region_name: String, recommended_level: int)

var _current_region_id := ""
const REGIONS := [
    {"id":"entrance", "name":"林间入口", "level":1, "min_y":0.0, "max_y":390.0, "color":Color("#344b42")},
    {"id":"deepwood", "name":"幽暗密林", "level":3, "min_y":390.0, "max_y":650.0, "color":Color("#30483d")},
    {"id":"ruins", "name":"古代遗迹", "level":5, "min_y":650.0, "max_y":900.0, "color":Color("#49483e")},
    {"id":"clearing", "name":"遗忘祭坛", "level":8, "min_y":900.0, "max_y":1300.0, "color":Color("#51413b")}
]

func _ready() -> void:
    add_to_group("world_navigation")
    _setup_navigation()
    _create_boundary()
    _create_obstacle(_iso_point(2.5, 5.5), 25.0)
    _create_obstacle(_iso_point(5.5, 9.5), 31.0)
    _create_obstacle(_iso_point(3.5, 12.5), 22.0)
    queue_redraw()
    _update_player_region()

func _process(_delta: float) -> void:
    _update_player_region()

func get_region_at(world_position: Vector2) -> Dictionary:
    for region in REGIONS:
        if world_position.y >= float(region.min_y) and world_position.y < float(region.max_y):
            return region
    return REGIONS[0]

func get_current_region() -> Dictionary:
    var player := get_tree().get_first_node_in_group("player") as Node2D
    return get_region_at(player.global_position) if is_instance_valid(player) else REGIONS[0]

func _update_player_region() -> void:
    var player := get_tree().get_first_node_in_group("player") as Node2D
    if not is_instance_valid(player):
        return
    var region := get_region_at(player.global_position)
    if str(region.id) == _current_region_id:
        return
    _current_region_id = str(region.id)
    region_changed.emit(str(region.name), int(region.level))

func _iso_point(grid_x: float, grid_y: float) -> Vector2:
    # Rotated 90 degrees from the usual wide isometric projection.
    return GRID_ORIGIN + Vector2(
        (grid_x - grid_y) * TILE_HEIGHT * 0.5,
        (grid_x + grid_y) * TILE_WIDTH * 0.5
    )

func _draw() -> void:
    for y in range(GRID_HEIGHT):
        for x in range(GRID_WIDTH):
            var center := _iso_point(float(x) + 0.5, float(y) + 0.5)
            var half_width := TILE_HEIGHT * 0.5
            var half_height := TILE_WIDTH * 0.5
            var diamond := PackedVector2Array([
                center + Vector2(0.0, -half_height),
                center + Vector2(half_width, 0.0),
                center + Vector2(0.0, half_height),
                center + Vector2(-half_width, 0.0)
            ])
            var region := get_region_at(center)
            var base_color: Color = region.color
            var tile_color := base_color.lightened(0.035) if (x + y) % 2 == 0 else base_color
            draw_colored_polygon(diamond, tile_color)
            draw_polyline(
                PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
                GRID_LINE,
                1.0,
                true
            )

    var corners := PackedVector2Array([
        _iso_point(0.0, 0.0),
        _iso_point(float(GRID_WIDTH), 0.0),
        _iso_point(float(GRID_WIDTH), float(GRID_HEIGHT)),
        _iso_point(0.0, float(GRID_HEIGHT)),
        _iso_point(0.0, 0.0)
    ])
    draw_polyline(corners, EDGE_COLOR, 4.0, true)

    _draw_stone(_iso_point(2.5, 5.5), 25.0)
    _draw_stone(_iso_point(5.5, 9.5), 31.0)
    _draw_stone(_iso_point(3.5, 12.5), 22.0)
    var font := ThemeDB.fallback_font
    if font:
        draw_string(font, Vector2(350, 170), "林间入口 · Lv.1", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 17, Color("#d5e4c9"))
        draw_string(font, Vector2(350, 470), "幽暗密林 · Lv.3", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 17, Color("#d5e4c9"))
        draw_string(font, Vector2(350, 730), "古代遗迹 · Lv.5", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 17, Color("#e2d2a9"))
        draw_string(font, Vector2(350, 1000), "遗忘祭坛 · Lv.8", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 17, Color("#e7b79e"))

func _draw_stone(center: Vector2, radius: float) -> void:
    draw_circle(center + Vector2(0.0, 7.0), radius + 3.0, Color("#26362f"))
    draw_circle(center, radius, Color("#78877b"))
    draw_arc(center, radius, PI, TAU, 24, Color("#aab5a1"), 3.0, true)

func _create_boundary() -> void:
    var corners := [
        _iso_point(0.0, 0.0),
        _iso_point(float(GRID_WIDTH), 0.0),
        _iso_point(float(GRID_WIDTH), float(GRID_HEIGHT)),
        _iso_point(0.0, float(GRID_HEIGHT))
    ]
    for index in range(corners.size()):
        var wall := StaticBody2D.new()
        wall.name = "BoundaryWall%d" % index
        add_child(wall)

        var collision := CollisionShape2D.new()
        var segment := SegmentShape2D.new()
        segment.a = corners[index]
        segment.b = corners[(index + 1) % corners.size()]
        collision.shape = segment
        wall.add_child(collision)

func _create_obstacle(position_on_map: Vector2, radius: float) -> void:
    var obstacle := StaticBody2D.new()
    obstacle.name = "StoneObstacle"
    obstacle.position = position_on_map
    add_child(obstacle)

    var collision := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = radius
    collision.shape = circle
    obstacle.add_child(collision)


func _setup_navigation() -> void:
    _astar.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
    _astar.cell_size = Vector2.ONE
    _astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
    _astar.update()
    for cell in [Vector2i(2, 5), Vector2i(5, 9), Vector2i(3, 12)]:
        _astar.set_point_solid(cell, true)

func world_to_grid(world_position: Vector2) -> Vector2i:
    var offset := world_position - GRID_ORIGIN
    var axis_a := offset.x / (TILE_HEIGHT * 0.5)
    var axis_b := offset.y / (TILE_WIDTH * 0.5)
    var gx := int(floor((axis_a + axis_b) * 0.5))
    var gy := int(floor((axis_b - axis_a) * 0.5))
    return Vector2i(clampi(gx, 0, GRID_WIDTH - 1), clampi(gy, 0, GRID_HEIGHT - 1))

func grid_to_world(cell: Vector2i) -> Vector2:
    return _iso_point(float(cell.x) + 0.5, float(cell.y) + 0.5)

func find_world_path(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
    var start := world_to_grid(from_position)
    var finish := world_to_grid(to_position)
    if _astar.is_point_solid(finish):
        finish = _nearest_walkable_cell(finish)
    if _astar.is_point_solid(start) or _astar.is_point_solid(finish):
        return PackedVector2Array([to_position])
    var ids := _astar.get_id_path(start, finish)
    var result := PackedVector2Array()
    for id in ids:
        result.append(grid_to_world(id))
    if result.is_empty():
        result.append(to_position)
    else:
        result[result.size() - 1] = to_position
    return result

func _nearest_walkable_cell(origin: Vector2i) -> Vector2i:
    for radius in range(1, 4):
        for y in range(maxi(0, origin.y - radius), mini(GRID_HEIGHT, origin.y + radius + 1)):
            for x in range(maxi(0, origin.x - radius), mini(GRID_WIDTH, origin.x + radius + 1)):
                var candidate := Vector2i(x, y)
                if not _astar.is_point_solid(candidate):
                    return candidate
    return origin
