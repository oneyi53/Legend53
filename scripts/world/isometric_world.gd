extends Node2D

## Portrait-oriented, code-drawn isometric field. No external art assets required.
const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 22
const TILE_WIDTH: float = 96.0
const TILE_HEIGHT: float = 48.0
const GRID_ORIGIN := Vector2(528.0, 64.0)
const GRID_LINE := Color("#607568")
const EDGE_COLOR := Color("#9aab83")
const SAFE_ZONE_END_Y := 390.0
var _astar := AStarGrid2D.new()
signal region_changed(region_name: String, recommended_level: int)
var _current_region_id := ""
const REGIONS := [
    {"id":"village", "name":"守林新手村", "level":1, "min_y":0.0, "max_y":390.0, "color":Color("#52634b")},
    {"id":"entrance", "name":"林间入口", "level":1, "min_y":390.0, "max_y":520.0, "color":Color("#344b42")},
    {"id":"deepwood", "name":"幽暗密林", "level":3, "min_y":520.0, "max_y":700.0, "color":Color("#30483d")},
    {"id":"ruins", "name":"古代遗迹", "level":5, "min_y":700.0, "max_y":900.0, "color":Color("#49483e")},
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

func is_safe_zone_position(world_position: Vector2) -> bool:
    return world_position.y < SAFE_ZONE_END_Y

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
    if player.has_method("unlock_region"):
        player.call("unlock_region", _current_region_id)
    region_changed.emit(str(region.name), int(region.level))

func _iso_point(grid_x: float, grid_y: float) -> Vector2:
    return GRID_ORIGIN + Vector2((grid_x - grid_y) * TILE_HEIGHT * 0.5, (grid_x + grid_y) * TILE_WIDTH * 0.5)

func _draw() -> void:
    draw_rect(Rect2(-600.0, -600.0, 1920.0, 2600.0), Color("#18271f"))
    for y in range(GRID_HEIGHT):
        for x in range(GRID_WIDTH):
            var center := _iso_point(float(x) + 0.5, float(y) + 0.5)
            var half_width := TILE_HEIGHT * 0.5
            var half_height := TILE_WIDTH * 0.5
            var diamond := PackedVector2Array([center + Vector2(0.0,-half_height),center + Vector2(half_width,0.0),center + Vector2(0.0,half_height),center + Vector2(-half_width,0.0)])
            var region := get_region_at(center)
            var base_color: Color = region.color
            var tile_color := base_color.lightened(0.035) if (x + y) % 2 == 0 else base_color
            draw_colored_polygon(diamond, tile_color)
            draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]), GRID_LINE, 0.7, true)
            _draw_tile_detail(center, x, y)
    _draw_world_paths()
    _draw_village_settlement()
    _draw_forest_landmarks()
    _draw_ruins_and_altar()
    var corners := PackedVector2Array([_iso_point(0.0,0.0),_iso_point(float(GRID_WIDTH),0.0),_iso_point(float(GRID_WIDTH),float(GRID_HEIGHT)),_iso_point(0.0,float(GRID_HEIGHT)),_iso_point(0.0,0.0)])
    draw_polyline(corners, EDGE_COLOR, 4.0, true)
    _draw_stone(_iso_point(2.5,5.5),25.0)
    _draw_stone(_iso_point(5.5,9.5),31.0)
    _draw_stone(_iso_point(3.5,12.5),22.0)
    _draw_village_gate()
    var font := ThemeDB.fallback_font
    if font:
        draw_string(font, Vector2(350,150), "守林新手村 · 安全区", HORIZONTAL_ALIGNMENT_CENTER, 240.0, 18, Color("#f2dfa9"))
        draw_string(font, Vector2(350,420), "村外 · 冒险开始", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 16, Color("#d5e4c9"))
        draw_string(font, Vector2(350,600), "幽暗密林 · Lv.3", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 17, Color("#d5e4c9"))
        draw_string(font, Vector2(350,780), "古代遗迹 · Lv.5", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 17, Color("#e2d2a9"))
        draw_string(font, Vector2(350,1040), "遗忘祭坛 · Lv.8", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 17, Color("#e7b79e"))

func _draw_village_gate() -> void:
    var left := Vector2(305,390)
    var right := Vector2(415,390)
    draw_line(left, left + Vector2(0,-34), Color("#9b7950"), 9.0)
    draw_line(right, right + Vector2(0,-34), Color("#9b7950"), 9.0)
    draw_line(left + Vector2(0,-34), right + Vector2(0,-34), Color("#c6a36d"), 9.0)
    draw_line(Vector2(360,356), Vector2(360,390), Color("#d8bd84"), 3.0)
    draw_line(Vector2(320,390), Vector2(400,390), Color("#c6a36d"), 3.0)

func _draw_stone(center: Vector2, radius: float) -> void:
    draw_circle(center + Vector2(0.0,7.0), radius + 3.0, Color("#26362f"))
    draw_circle(center, radius, Color("#78877b"))
    draw_arc(center, radius, PI, TAU, 24, Color("#aab5a1"), 3.0, true)

func _create_boundary() -> void:
    var corners := [_iso_point(0.0,0.0),_iso_point(float(GRID_WIDTH),0.0),_iso_point(float(GRID_WIDTH),float(GRID_HEIGHT)),_iso_point(0.0,float(GRID_HEIGHT))]
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
    _astar.region = Rect2i(0,0,GRID_WIDTH,GRID_HEIGHT)
    _astar.cell_size = Vector2.ONE
    _astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
    _astar.update()
    for cell in [Vector2i(2,5),Vector2i(5,9),Vector2i(3,12)]:
        _astar.set_point_solid(cell,true)

func world_to_grid(world_position: Vector2) -> Vector2i:
    var offset := world_position - GRID_ORIGIN
    var axis_a := offset.x / (TILE_HEIGHT * 0.5)
    var axis_b := offset.y / (TILE_WIDTH * 0.5)
    var gx := int(floor((axis_a + axis_b) * 0.5))
    var gy := int(floor((axis_b - axis_a) * 0.5))
    return Vector2i(clampi(gx,0,GRID_WIDTH - 1),clampi(gy,0,GRID_HEIGHT - 1))

func grid_to_world(cell: Vector2i) -> Vector2:
    return _iso_point(float(cell.x) + 0.5,float(cell.y) + 0.5)

func find_world_path(from_position: Vector2,to_position: Vector2) -> PackedVector2Array:
    var start := world_to_grid(from_position)
    var finish := world_to_grid(to_position)
    if _astar.is_point_solid(finish):
        finish = _nearest_walkable_cell(finish)
    if _astar.is_point_solid(start) or _astar.is_point_solid(finish):
        return PackedVector2Array([to_position])
    var ids := _astar.get_id_path(start,finish)
    var result := PackedVector2Array()
    for id in ids:
        result.append(grid_to_world(id))
    if result.is_empty():
        result.append(to_position)
    else:
        result[result.size() - 1] = to_position
    return result

func _nearest_walkable_cell(origin: Vector2i) -> Vector2i:
    for radius in range(1,4):
        for y in range(maxi(0,origin.y - radius),mini(GRID_HEIGHT,origin.y + radius + 1)):
            for x in range(maxi(0,origin.x - radius),mini(GRID_WIDTH,origin.x + radius + 1)):
                var candidate := Vector2i(x,y)
                if not _astar.is_point_solid(candidate):
                    return candidate
    return origin

func _draw_tile_detail(center: Vector2, cell_x: int, cell_y: int) -> void:
    var seed_value := cell_x * 37 + cell_y * 19
    var fleck := Color("#b1bd83") if cell_y < 8 else Color("#a0a080")
    for index in range(3):
        var dx := float(((seed_value + index * 17) % 31) - 15)
        var dy := float(((seed_value + index * 11) % 19) - 9)
        draw_circle(center + Vector2(dx, dy), 1.2, Color(fleck, 0.20))
    if cell_y >= 3 and cell_y < 18 and seed_value % 4 == 0:
        var tuft := center + Vector2(float((seed_value % 17) - 8), 5.0)
        draw_line(tuft, tuft + Vector2(-3.0, -5.0), Color("#91a56d", 0.72), 1.5, true)
        draw_line(tuft, tuft + Vector2(2.0, -6.0), Color("#b1b77a", 0.72), 1.5, true)

func _draw_world_paths() -> void:
    var path_points := PackedVector2Array([Vector2(356,350),Vector2(365,430),Vector2(348,505),Vector2(374,590),Vector2(350,680),Vector2(365,770),Vector2(342,865),Vector2(365,965),Vector2(350,1060),Vector2(370,1160),Vector2(350,1260),Vector2(360,1370)])
    draw_polyline(path_points, Color("#25352d", 0.34), 46.0, true)
    draw_polyline(path_points, Color("#9a8058", 0.82), 34.0, true)
    draw_polyline(path_points, Color("#b69a6b", 0.36), 25.0, true)

func _draw_tree(point: Vector2, size: float, canopy: Color) -> void:
    draw_circle(point + Vector2(2,size * 0.62), size * 0.78, Color("#17231d", 0.42))
    draw_line(point + Vector2(0,size * 0.25), point + Vector2(0,-size * 0.42), Color("#503a2b"), maxf(4.0,size * 0.17), true)
    draw_line(point + Vector2(-2,size * 0.12), point + Vector2(-size * 0.22,-size * 0.18), Color("#6d4a30"), maxf(2.0,size * 0.07), true)
    draw_line(point + Vector2(1,size * 0.04), point + Vector2(size * 0.24,-size * 0.22), Color("#765237"), maxf(2.0,size * 0.07), true)
    draw_circle(point + Vector2(-size * 0.27,-size * 0.35), size * 0.46, canopy.darkened(0.24))
    draw_circle(point + Vector2(size * 0.22,-size * 0.46), size * 0.50, canopy)
    draw_circle(point + Vector2(0,-size * 0.72), size * 0.42, canopy.lightened(0.12))
    draw_circle(point + Vector2(-size * 0.12,-size * 0.82), size * 0.15, canopy.lightened(0.28))
    draw_circle(point + Vector2(size * 0.34,-size * 0.55), size * 0.12, canopy.lightened(0.22))

func _draw_village_settlement() -> void:
    draw_rect(Rect2(170,214,108,62), Color("#594331"))
    draw_colored_polygon(PackedVector2Array([Vector2(158,220),Vector2(224,176),Vector2(290,220),Vector2(278,232),Vector2(224,198),Vector2(170,232)]), Color("#8e5940"))
    draw_rect(Rect2(207,239,27,37), Color("#302b27"))
    draw_rect(Rect2(181,231,16,17), Color("#e0bd78"))
    draw_rect(Rect2(250,231,16,17), Color("#e0bd78"))
    draw_colored_polygon(PackedVector2Array([Vector2(445,258),Vector2(512,258),Vector2(501,282),Vector2(454,282)]), Color("#9a5945"))
    draw_rect(Rect2(451,282,55,30), Color("#6d5037"))
    draw_rect(Rect2(458,289,18,15), Color("#b58b58"))
    draw_rect(Rect2(482,289,17,15), Color("#9b7448"))
    # Roof shingles, timber frame and warm window glow.
    draw_line(Vector2(169,220),Vector2(224,184),Color("#c18c58"),2.0,true)
    draw_line(Vector2(224,184),Vector2(281,220),Color("#c18c58"),2.0,true)
    for x in [180.0,194.0,208.0,222.0,236.0,250.0,264.0]:
        draw_line(Vector2(x,215),Vector2(x + 4.0,220),Color("#6c4734",0.75),1.2,true)
    draw_rect(Rect2(181,231,16,17),Color("#e0bd78",0.28))
    draw_rect(Rect2(250,231,16,17),Color("#e0bd78",0.28))
    draw_circle(Vector2(355,260), 23, Color("#554b3a"))
    draw_circle(Vector2(355,258), 17, Color("#82908a"))
    draw_circle(Vector2(355,258), 11, Color("#293d3d"))
    draw_line(Vector2(331,238), Vector2(379,238), Color("#8c7049"), 4.0)
    draw_arc(Vector2(355,258),20.0,PI,TAU,32,Color("#c8b18a"),2.0,true)
    # Lanterns at the village gate.
    for lamp_x in [310.0,410.0]:
        draw_line(Vector2(lamp_x,352),Vector2(lamp_x,376),Color("#79583a"),3.0,true)
        draw_circle(Vector2(lamp_x,350),5.0,Color("#e6b86c",0.25))
        draw_circle(Vector2(lamp_x,350),2.5,Color("#ffd58a"))

func _draw_forest_landmarks() -> void:
    var trees := [[Vector2(145,472),25.0],[Vector2(555,480),29.0],[Vector2(205,560),34.0],[Vector2(520,615),31.0],[Vector2(155,700),35.0],[Vector2(570,745),36.0],[Vector2(235,835),30.0],[Vector2(500,900),34.0],[Vector2(135,1010),32.0],[Vector2(570,1090),35.0]]
    for item in trees:
        var point: Vector2 = item[0]
        var tree_size: float = item[1]
        var canopy := Color("#456b49") if point.y < 800.0 else Color("#5b5742")
        _draw_tree(point, tree_size, canopy)
    draw_line(Vector2(250,640), Vector2(277,655), Color("#684a32"), 8.0, true)
    # Ferns, mushrooms and weathered trail stones add scale to the forest.
    for point in [Vector2(182,612),Vector2(536,690),Vector2(205,790),Vector2(518,850),Vector2(160,1080)]:
        draw_line(point,point + Vector2(-7,-14),Color("#77945c"),2.0,true)
        draw_line(point,point + Vector2(5,-17),Color("#8da66a"),2.0,true)
        draw_line(point,point + Vector2(12,-10),Color("#6f8a55"),2.0,true)
    for point in [Vector2(292,575),Vector2(432,735),Vector2(286,950)]:
        draw_line(point, point + Vector2(0,7), Color("#e4d4b8"), 2.0, true)
        draw_circle(point + Vector2(-3,-1), 4.0, Color("#c66f68"))
        draw_circle(point + Vector2(4,-2), 3.5, Color("#e0a06c"))
        draw_line(point + Vector2(-1,2),point + Vector2(-1,10),Color("#e0d3b4"),1.8,true)
    for point in [Vector2(332,492),Vector2(385,685),Vector2(326,865),Vector2(386,1048)]:
        draw_ellipse(point + Vector2(0,5),Vector2(12,5),Color("#202b25",0.35))
        draw_colored_polygon(PackedVector2Array([point+Vector2(-12,0),point+Vector2(-7,-7),point+Vector2(7,-7),point+Vector2(12,0),point+Vector2(7,7),point+Vector2(-8,6)]),Color("#776d59"))
        draw_line(point+Vector2(-5,-4),point+Vector2(4,-5),Color("#b3a58a",0.65),1.5,true)

func _draw_ruins_and_altar() -> void:
    for point in [Vector2(190,930),Vector2(525,970),Vector2(220,1080),Vector2(500,1110)]:
        draw_rect(Rect2(point.x - 7,point.y - 28,14,38), Color("#777466"))
        draw_rect(Rect2(point.x - 11,point.y - 31,22,6), Color("#aaa28a"))
        draw_line(point + Vector2(-3,-22), point + Vector2(4,2), Color("#c0b99f",0.5), 2.0)
        draw_line(point + Vector2(-7,-9),point + Vector2(7,-9),Color("#4c5149"),2.0,true)
        draw_circle(point + Vector2(0,-25),2.0,Color("#b58c5d"))
    draw_circle(Vector2(360,1390), 72, Color("#292e2b",0.48))
    draw_circle(Vector2(360,1382), 58, Color("#71634e"))
    draw_circle(Vector2(360,1378), 42, Color("#403c36"))
    draw_arc(Vector2(360,1378), 47, 0.0, TAU, 48, Color("#c18b56"), 4.0, true)
    draw_circle(Vector2(360,1378), 13, Color("#9e654b"))
    draw_circle(Vector2(360,1378), 6, Color("#f0b66c"))
