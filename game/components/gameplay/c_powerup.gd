class_name C_Powerup
extends Component

enum PowerupEnum{
    # The ball speeds up
    SPEED = 0,
    # The ball can break through multiple bricks without bouncing
    MEGA = 1,
    # The ball will be captured the next time it touches the paddle
    CAPTURE = 2
}


@export var is_type: PowerupEnum