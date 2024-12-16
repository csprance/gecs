## When you add a gear component to an entity it has all the gear an entity is currently wearing.
## Then a gear system processes all the gear components and applies the gear to the entity.
class_name C_Gear
extends Component

## The path to the skeleton that the gear is applied to must be of type Skeleton3D
@export_node_path('Skeleton3D') var skeleton_path: NodePath = ""
## The gear items that the entity is currently wearing must be of type Gear
@export var gear_items: Array[PackedScene]= []