extends Area2D

## Small world-space experience crystal. Collected by walking over it.

signal collected(amount: int)

@export var experience_value: int = 12

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    var shape_node := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 24.0
    shape_node.shape = shape
    add_child(shape_node)
    add_to_group("experience_drops")
    body_entered.connect(_on_body_entered)
    queue_redraw()

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    collected.emit(experience_value)
    queue_free()

func _draw() -> void:
    draw_circle(Vector2(0.0, 5.0), 13.0, Color(0.08, 0.12, 0.10, 0.35))
    draw_colored_polygon(
        PackedVector2Array([Vector2(0, -15), Vector2(11, 0), Vector2(0, 15), Vector2(-11, 0)]),
        Color("#8fe6b1")
    )
    draw_polyline(
        PackedVector2Array([Vector2(0, -15), Vector2(11, 0), Vector2(0, 15), Vector2(-11, 0), Vector2(0, -15)]),
        Color("#e0ffe8"),
        2.0,
        true
    )
