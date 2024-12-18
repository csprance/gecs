@tool
@icon('res://game/assets/icons/gear.svg')
class_name Gear
extends Node3D

# Reference to the default skeleton used in the editor.
@onready var default_skeleton: Skeleton3D = $DefaultSkeleton
@onready var inputs_node: Node = $Inputs
@onready var outputs_node: Node = $Outputs

var io: Dictionary[Node3D, Node3D] = {
	# Dictionary maps from input -> output
}

## Path to the external skeleton, set during runtime by the GearSystem.
var skeleton_path: NodePath
## The entity that the gear is attached to.
var entity: Entity

func _ready() -> void:
	for nodes in Utils.zip(outputs_node.get_children(), inputs_node.get_children()):
		io[nodes[0]] = nodes[1]
	# When in-game, remove the default skeleton and set up external skeletons for BoneAttachments.
	if not Engine.is_editor_hint():
		remove_child(default_skeleton)
		# Iterate over all BoneAttachment3D nodes and set the external skeleton.
		for child in find_children('*', 'BoneAttachment3D'):
			var bone_attach: BoneAttachment3D = child
			bone_attach.set_external_skeleton(skeleton_path)
			bone_attach.set_use_external_skeleton(true)

# Retrieves an input node by name (used for connecting gear inputs during assembly).
func get_input(name):
	return get_node("Inputs/" + name)

# Retrieves an output node by name (used for providing connection points to other gears).
func get_output(name):
	return get_node("Outputs/" + name)

# Connects this gear's outputs to the target gear's inputs.
# This function is crucial for assembling gears as described in gear.md.
func connect_inputs_outputs(target_gear):
	var my_outputs = get_node("Outputs")
	var target_inputs: Node = target_gear.get_node("Inputs")
	# Iterate through all output nodes.
	for input_node in io:
		var output_node = io[input_node]
		# Check if the target gear has a corresponding input node.
		# Create a RemoteTransform3D to synchronize transforms between output and input nodes.
		var remote_transform = RemoteTransform3D.new()
		remote_transform.remote_path = output_node.get_path()
		input_node.add_child(remote_transform)
