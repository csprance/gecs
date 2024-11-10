## BrickSpawnerSystem[br]
## Spawns [Brick] in a Breakout-style grid layout and then removes itself.
extends System
class_name BrickSpawnerSystem

# Exported variables for easy configuration in the Godot Editor
@export var bricks_per_row: int = 5
@export var brick_width: float = 100.0
@export var brick_height: float = 32.0
@export var horizontal_spacing: float = 10.0
@export var vertical_spacing: float = 10.0
@export var start_position: Vector2 = Vector2(300, 300)

# what brick scene should we spawn?
@export var brick_scene: PackedScene

var rng = RandomNumberGenerator.new()

func process(_e, _d) -> void:
	var world = ECS.world as World
	spawn_bricks(world)
	# Remove this system so it only runs once
	world.remove_system(self)


func spawn_bricks(world: World) -> void:
	for i in range(GameState.bricks):
		# Instantiate a new brick from the preloaded scene
		var brick_entity = brick_scene.duplicate(true).instantiate() as Brick
		rng.randomize()
		brick_entity.color = ColorUtils.randomColor(rng)
		Loggie.debug(brick_entity.color)

		# Add the brick entity to the ECS world
		world.add_entity(brick_entity)
		# Calculate the current row and column based on the brick index
		var row = float(i) / float(bricks_per_row)
		var col = float(i % bricks_per_row)

		# Determine the brick's position
		var x = start_position.x + col * (brick_width + horizontal_spacing)
		var y = start_position.y + row * (brick_height + vertical_spacing)
		var position = Vector2(x, y)
		
		# Retrieve and update the Transform component of the brick
		var transform = brick_entity.get_component(C_Transform) as C_Transform
		if transform:
			transform.position = position
		else:
			push_error("Brick entity does not have a Transform component.")

