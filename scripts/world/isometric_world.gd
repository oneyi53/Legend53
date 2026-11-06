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

func _ready() -> void:
    add_to_group("world_navigation")
    _setup_navigation()
    _create_boundary()
    _create_obstacle(_iso_point(2.5, 5.5), 25.0)
    _create_obstacle(_iso_point(5.5, 9.5), 31.0)
    _create_obstacle(_iso_point(3.5, 12.5), 22.0)
    queue_redraw()

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
            var tile_color := FLOOR_A if (x + y) % 2 == 0 else FLOOR_B
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
