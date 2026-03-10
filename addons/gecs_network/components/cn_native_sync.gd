class_name CN_NativeSync
extends Component
## CN_NativeSync -- opt-in component for native MultiplayerSynchronizer transform sync.
##
## Add this component to any entity whose position/rotation should be synchronized
## using Godot's built-in MultiplayerSynchronizer (SYNC-04).
## NativeSyncHandler reads this component at spawn time and creates a "_NetSync"
## MultiplayerSynchronizer child node on the entity.
##
## root_path: Target node for sync. ".." = the entity node itself (default).
##   For CharacterBody3D entities, ".." is correct -- the entity IS the CharacterBody3D.
##   Override with a sub-node name if position lives on a child node.
##
## replication_mode: 1 = REPLICATION_MODE_ALWAYS (default, good for moving entities).
##   Set to 2 (REPLICATION_MODE_ON_CHANGE) for mostly-static entities.

@export var sync_position: bool = true
@export var sync_rotation: bool = true
@export var root_path: NodePath = ".."          ## target node; ".." = entity node itself
@export var replication_interval: float = 0.0   ## 0.0 = every frame
@export var replication_mode: int = 1           ## 1 = REPLICATION_MODE_ALWAYS
