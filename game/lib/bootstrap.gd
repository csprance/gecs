class_name Bootstrap

static func bootstrap():
	# Turn on game logging
	Loggie.set_domain_enabled("game", true)
	# Turn off the ECS domain logging
	Loggie.set_domain_enabled("ecs", true)
	# turn on logging from ui
	Loggie.set_domain_enabled("ui", true)
