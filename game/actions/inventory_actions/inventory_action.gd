class_name InventoryAction
extends Action


func _use_item(item: Entity, player: Entity) -> void:
	assert(false, 'You must override this function in your inventory action')

## Call this if you're running the action from somewhere
## We only run the action on the entities that are passed in that match the query
## If no query is provided then they all match
func run_inventory_action(entities: Array, player: Entity, action_meta=null) -> void:
	assert(player, 'Player entity must be passed in')
	assert(entities.size(), 'Entities must be passed in')
	Loggie.info('Running Inventory Action: ', self.meta)
	if action_meta:
		self.meta.merge(action_meta, true)
	self.meta.merge(_meta(), true)
	for entity in query().matches(entities):
		_use_item(entity, player)