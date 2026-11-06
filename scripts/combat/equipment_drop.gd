extends Area2D

signal collected(item: Dictionary)

@export var item_data: Dictionary = {}

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    var hitbox := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 26.0
    hitbox.shape = circle
    add_child(hitbox)
    body_entered.connect(_on_body_entered)
    queue_redraw()

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    if body.has_method("add_inventory_item"):
        body.add_inventory_item(item_data)
    collected.emit(item_data)
    queue_free()

func _draw() -> void:
    draw_circle(Vector2(0, 5), 16, Color(0.08, 0.12, 0.10, 0.4))
    draw_colored_polygon(PackedVector2Array([Vector2(0, -19), Vector2(14, -3), Vector2(10, 15), Vector2(-10, 15), Vector2(-14, -3)]), Color("#d6b66c"))
    draw_arc(Vector2.ZERO, 17, 0, TAU, 32, Color("#fff0bd"), 2.0, true)
