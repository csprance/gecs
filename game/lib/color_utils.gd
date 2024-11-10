class_name ColorUtils

static func randomColor(rng: RandomNumberGenerator):
    rng.randomize()
    return Color.from_hsv(rng.randf_range(.3, 1.), .8, .9)