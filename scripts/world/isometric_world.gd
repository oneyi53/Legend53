extends Node2D

## A lightweight, code-drawn isometric test field.
## Geometry is generated at runtime so the prototype needs no external art assets.

const GRID_WIDTH: int = 14
const GRID_HEIGHT: int = 10
const TILE_WIDTH: float = 96.0
const TILE_HEIGHT: float = 48.0
const GRID_ORIGIN := Vector2(544.0, 40.0)

const FLOOR_A := Color("#344b42")
const FLOOR_B := Color("#3a5248")
const GRID_LINE := Color("#607568")
const EDGE_COLOR := Color("#9aab83")

func _ready() -> void:
    _create_boundary()
    _create_obstacle(Vector2(430.0, 270.0), 28.0)
    _create_obstacle(Vector2(820.0, 390.0), 34.0)
    _create_obstacle(Vector2(650.0, 500.0), 24.0)
    queue_redraw()

func _iso_point(grid_x: float, grid_y: float) -> Vector2:
    return GRID_ORIGIN + Vector2(
        (grid_x - grid_y) * TILE_WIDTH * 0.5,
        (grid_x + grid_y) * TILE_HEIGHT * 0.5
    )

func _draw() -> void:
    for y in range(GRID_HEIGHT):
        for x in range(GRID_WIDTH):
            var center := _iso_point(float(x) + 0.5, float(y) + 0.5)
            var half := Vector2(TILE_WIDTH * 0.5, TILE_HEIGHT * 0.5)
            var diamond := PackedVector2Array([
                center + Vector2(0.0, -half.y),
                center + Vector2(half.x, 0.0),
                center + Vector2(0.0, half.y),
                center + Vector2(-half.x, 0.0)
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

    # Simple stylized stones matching the circular collision areas.
    _draw_stone(Vector2(430.0, 270.0), 28.0)
    _draw_stone(Vector2(820.0, 390.0), 34.0)
    _draw_stone(Vector2(650.0, 500.0), 24.0)

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
