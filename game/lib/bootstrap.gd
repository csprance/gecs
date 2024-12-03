class_name Bootstrap

static func bootstrap():
	# Turn on game logging
	Loggie.set_domain_enabled("game", true)
	# turn on logging from ui
	Loggie.set_domain_enabled("ui", true)
