extends Control  # Or any other appropriate node

func _ready():
    # Load the image resource
    var data = Utils.brick_data_from_image("res://assets/map-1.png")
    # Iterate over each pixel
    for d in data:
        # Create a visual representation (e.g., a ColorRect or Sprite)
        var rect: ColorRect = ColorRect.new()
        rect.color = d.color
        Loggie.debug(d.color)
        rect.position = d.pos * 25
        rect.size = Vector2(25, 25)
        Loggie.debug(rect.position)

        # Add the rectangle to the scene
        add_child(rect)

