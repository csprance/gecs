class_name ReplExpression
extends Resource
## The AST

var root:ReplExpression

func evaluate(env:ReplEnv):
	return root.evaluate(env)


class REDeclaration extends ReplExpression:
	## declares a null variable in the environment
	var identifier
	
	func _init(identifier):
		self.identifier = identifier
	
	func evaluate(env:ReplEnv):
		env.vars[identifier] = null
		return [false, 'var declared: ' + identifier]


class REDelegated extends ReplExpression:
	## delegates evaluation to the godot evaluator
	var tokens:Array
	
	func _init(tokens):
		self.tokens = tokens
		
	
	func evaluate(env:ReplEnv):
		var parser = ReplParser.new()
		var str = "".join(unpack_tokens(tokens))
		return parser.delegate_evaluation(str, env)

	func unpack_tokens(tokens:Array):
		## Unwrap tokens into an array of strings
		var strs = []
		for token in tokens:
			strs.append(token.content)
		return strs


class REAssignment extends ReplExpression:
	var left:ReplPreAssign
	var op:ReplToken.TokenType
	var right:ReplExpression
	
	func _init(left:ReplPreAssign, op:ReplToken.TokenType, right:ReplExpression):
		self.left = left
		self.op = op
		self.right = right
	
	func evaluate(env):
		var right_result = right.evaluate(env)
		if right_result[0]:
			return right_result  # just propagate errors
			
		var assigned = null
		match op:
			ReplToken.TokenType.TK_OP_EQUAL:
				assigned = left.assign(right_result[1], env)
			ReplToken.TokenType.TK_OP_COLON_EQUAL:
				assigned = left.assign(right_result[1], env)
			ReplToken.TokenType.TK_OP_MUL_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] * right_result[1], env)
			ReplToken.TokenType.TK_OP_POW_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] ** right_result[1], env)
			ReplToken.TokenType.TK_OP_SHIFT_RIGHT_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] >> right_result[1], env)
			ReplToken.TokenType.TK_OP_SHIFT_LEFT_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] << right_result[1], env)
			ReplToken.TokenType.TK_OP_BIT_OR_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] | right_result[1], env)
			ReplToken.TokenType.TK_OP_BIT_AND_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] & right_result[1], env)
			ReplToken.TokenType.TK_OP_BIT_XOR_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] ^ right_result[1], env)
			ReplToken.TokenType.TK_OP_ADD_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] + right_result[1], env)
			ReplToken.TokenType.TK_OP_SUB_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] - right_result[1], env)
			ReplToken.TokenType.TK_OP_DIV_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] / right_result[1], env)
			ReplToken.TokenType.TK_OP_MOD_EQUAL:
				var accessed = left.access(env)
				if accessed[0]:
					return accessed
				assigned = left.assign(accessed[1] % right_result[1], env)
			_:
				return [true, "Assignment op not handled: %s" % op]
		
		if assigned[0]:  # propagate errors
			return assigned
			
		return [false, "Variable assigned"]
		
	
