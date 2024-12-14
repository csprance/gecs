class_name C_ItemSpawner
extends Component

## The name of the spawner
@export var name: String = "Spawner Name"
## The Items that can be spawned. The chance to spawn will be normalized
## There are Items: Which spawn one item, Groups: Which spawn all items in the group, Spawners: which can combine other spawners together and then run the spawn logic on that collection
@export var spawner_items: Array[C_ItemSpawnerVariants] = []