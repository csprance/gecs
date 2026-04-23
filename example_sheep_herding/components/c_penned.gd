## Terminal marker — C_Penned is never removed once added.
## Represents the win-condition state for a sheep that has entered a pen.
## The O_Penned observer strips C_Wander / C_Flee on the ADDED transition so
## the sheep stops moving and settles.
class_name C_Penned
extends Component
