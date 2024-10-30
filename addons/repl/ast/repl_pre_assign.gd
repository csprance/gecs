class_name ReplPreAssign
extends Resource

## command object for assigning a value in the environment

var identifier:String

func _init(identifier:String):
	self.identifier = identifier

func assign(value, env:ReplEnv):
	env.vars[identifier] = value
	return [false, 'Variable assigned']

func access(env:ReplEnv):
	# pull the value from the environment in case it needs to be transformed
	# before reassignment
	return [false, env.vars[identifier]]


class DictionaryPreAssign extends ReplPreAssign:
	# Assign to anything like identifier[key]
	# id needs to be an expression in case it is a nested dict lookup
	#  for example: x[0][1] = 2
	var id_expression:ReplExpression
	var key_expression:ReplExpression
	func _init(id_expression:ReplExpression, key_expression:ReplExpression):
		self.id_expression = id_expression
		self.key_expression = key_expression

	func assign(value, env:ReplEnv):
		var dict = id_expression.evaluate(env)
		if dict[0]:
			return dict
		var key = key_expression.evaluate(env)
		if key[0]:
			return key
		dict[1][key[1]] = value
		return [false, 'Variable assigned']

	func access(env:ReplEnv):
		# pull the value from the environment in case it needs to be transformed
		# before reassignment
		var dict = id_expression.evaluate(env)
		if dict[0]:
			return dict
		var key = key_expression.evaluate(env)
		if key[0]:
			return key
		return [false, dict[1][key[1]]]
