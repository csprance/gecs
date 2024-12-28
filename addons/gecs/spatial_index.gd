class_name SpatialIndex
extends Object

## SpatialIndex
##
## A simple spatial indexing system that organizes entities based on their positions for efficient spatial queries.
## It divides the space into cells of a fixed size and keeps track of which entities are in which cells.

## Dictionary storing entities in cells.
## Key: `Vector2` cell coordinate.
## Value: Array of entities in that cell.
var cells = {}

## The size of each cell in the spatial grid.
var cell_size = 100.0

## Initializes the spatial index by clearing all cells.
func initialize():
    cells.clear()

## Calculates the cell key for a given position.
## @param position - The position as a `Vector2`.
## @return A `Vector2` representing the cell coordinates.
func _get_cell_key(position: Vector2) -> Vector2:
    return Vector2(floor(position.x / cell_size), floor(position.y / cell_size))

## Adds an entity to the spatial index at a given position.
## @param entity - The entity to add.
## @param position - The position of the entity.
func add_entity(entity: Entity, position: Vector2):
    var key = _get_cell_key(position)
    if not cells.has(key):
        cells[key] = []
    cells[key].append(entity)

## Removes an entity from the spatial index.
## @param entity - The entity to remove.
func remove_entity(entity: Entity):
    # Iterate through all cells to find and remove the entity.
    for key in cells.keys():
        cells[key].erase(entity)
        # Remove the cell entry if it's now empty.
        if cells[key].is_empty():
            cells.erase(key)

## Updates an entity's position in the spatial index.
## @param entity - The entity to update.
## @param position - The new position of the entity.
func update_entity(entity: Entity, position: Vector2):
    # Remove the entity from its old cell(s).
    remove_entity(entity)
    # Add the entity to the new cell based on the updated position.
    add_entity(entity, position)

## Queries the spatial index for entities within a specified area.
## @param area - A `Rect2` defining the area to query.
## @return An array of entities within the specified area.
func query(area: Rect2) -> Array:
    var result = []
    # Calculate the range of cells that overlap with the query area.
    var start_cell = _get_cell_key(area.position)
    var end_cell = _get_cell_key(area.position + area.size)
    # Iterate over the relevant cells.
    for x in range(start_cell.x, end_cell.x + 1):
        for y in range(start_cell.y, end_cell.y + 1):
            var key = Vector2(x, y)
            if cells.has(key):
                # Check each entity in the cell to see if it's within the area.
                for entity in cells[key]:
                    var entity_pos = entity.get_component(C_Transform).transform.origin
                    if area.has_point(entity_pos):
                        result.append(entity)
    return result