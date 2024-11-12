## The component that indicates an actual powerup is applied
class_name C_Powerup
extends Component

## A PowerupType describes the different power ups we have in the game
enum PowerupType {
    ## The ball speeds up
    SPEED = 0,
    ## The ball can break through multiple bricks without bouncing
    MEGA = 1,
    ## The ball will be captured the next time it touches the paddle
    CAPTURE = 2
}
## What is the specific power up type
@export var type: PowerupType
## How long does this effect have left
@export var time: float