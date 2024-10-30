class_name ReplTokenizer
extends Resource

## Handles tokanizing text

func msg_error_at(instruction, index):
	## Get a message that says there's an error in the instruction at the given index
	## the message will have the line and column number
	var line = 1
	var char = 1
	var i = 0
	while i < index:
		if instruction[i] in '\r\n':
			line += 1
			char = 1
		else:
			char += 1
		i += 1
	return ('Error at (%s, %s)' % [line, char])
			


func tokenize(instruction: String) -> Array:
	## On failure, returns [true, "error message"]
	## On success, returns [false, (Array[ReplToken])]
	## Leading whitespace is preserved, but inner whitespace is discarded
	var tokens:Array[ReplToken] = []
	
	var alphabetical = RegEx.create_from_string("[a-zA-Z]")
	var word_start_chars = RegEx.create_from_string("[a-zA-Z_]")
	var word_end_chars = RegEx.create_from_string("[a-zA-Z_0-9]")

	var index = 0
	while index < instruction.length():
		if word_start_chars.search(instruction[index]):
			var token = instruction[index]
			index += 1
			while index < instruction.length() and word_end_chars.search(instruction[index]):
				token += instruction[index]
				index += 1
			var rToken = ReplToken.new()
			rToken.content = token
			# just assume all variable names / constants are identifiers
			rToken.ttype = ReplToken.TokenType.TK_IDENTIFIER
			tokens.append(rToken)
		elif index < instruction.length() and instruction[index] in '1234567890.':
			var token = instruction[index]
			index += 1
			if token == '0' and index < instruction.length() and instruction[index] == 'b':
				token += instruction[index]
				index += 1
				while index < instruction.length() and instruction[index] in '01':
					token += instruction[index]
					index += 1
				if index < instruction.length() and alphabetical.search(instruction[index]):
					return [
						true,
						msg_error_at(instruction, index) + ': Invalid numeric notation.'
					]
				
				var rToken = ReplToken.new()
				rToken.content = token
				rToken.ttype = ReplToken.TokenType.TK_BASIC_TYPE
				tokens.append(rToken)
			elif token == '0' and index < instruction.length() and instruction[index] == 'x':
				token += instruction[index]
				index += 1
				while index < instruction.length() and instruction[index] in '01234567890abcdefABCDEF':
					token += instruction[index]
					index += 1
				if index < instruction.length() and alphabetical.search(instruction[index]):
					return [
						true,
						msg_error_at(instruction, index) + ': Invalid numeric notation.'
					]
				var rToken = ReplToken.new()
				rToken.content = token
				rToken.ttype = ReplToken.TokenType.TK_BASIC_TYPE
				tokens.append(rToken)
			elif token == '.' and index < instruction.length() and word_start_chars.search(instruction[index]):
				# found a period, but it's a method invocation
				var rToken = ReplToken.new()
				rToken.content = token
				rToken.ttype = ReplToken.TokenType.TK_BASIC_TYPE
				tokens.append(rToken)
			else:
				var e_ct = 0
				while index < instruction.length() and instruction[index] in '1234567890.E':
					if instruction[index] == 'E':
						e_ct += 1
					token += instruction[index]
					index += 1
				if index < instruction.length() and alphabetical.search(instruction[index]):
					return [
						true,
						msg_error_at(instruction, index) + ': Invalid numeric notation.'
					]
				if e_ct > 1:
					return [false, "Too many E's in " + token ]
				var rToken = ReplToken.new()
				rToken.content = token
				rToken.ttype = ReplToken.TokenType.TK_BASIC_TYPE
				tokens.append(rToken)
				
		elif instruction[index] in '*<>':
			# could be *, *=, or **=
			# or >, >=, or >>=
			# or <, <=, or <<=
			var token = instruction[index]
			index += 1
			if index < instruction.length() and instruction[index] == token:
				token += instruction[index]
				index += 1
			if index < instruction.length() and instruction[index] == '=':
				token += instruction[index]
				index += 1
			
			var rToken = ReplToken.new()
			rToken.content = token
			tokens.append(rToken)
			match token:
				'*':
					rToken.ttype = ReplToken.TokenType.TK_OP_MUL
				'*=':
					rToken.ttype = ReplToken.TokenType.TK_OP_MUL_EQUAL
				'**=':
					rToken.ttype = ReplToken.TokenType.TK_OP_POW_EQUAL
				'<':
					rToken.ttype = ReplToken.TokenType.TK_OP_LESS
				'>':
					rToken.ttype = ReplToken.TokenType.TK_OP_GREATER
				'<=':
					rToken.ttype = ReplToken.TokenType.TK_OP_LESS_EQUAL
				'>=':
					rToken.ttype = ReplToken.TokenType.TK_OP_GREATER_EQUAL
				'>>=':
					rToken.ttype = ReplToken.TokenType.TK_OP_SHIFT_RIGHT_EQUAL
				'<<=':
					rToken.ttype = ReplToken.TokenType.TK_OP_SHIFT_LEFT_EQUAL
		elif instruction[index] in '|&':
			# could be |, ||, |=, &, &&, &=
			var token = instruction[index]
			index += 1
			if index < instruction.length() and instruction[index] == token:
				token += instruction[index]
				index += 1
			elif index < instruction.length() and instruction[index] == '=':
				token += instruction[index]
				index += 1
			var rToken = ReplToken.new()
			rToken.content = token
			tokens.append(rToken)
			match token:
				'|':
					rToken.ttype = ReplToken.TokenType.TK_OP_BIT_OR
				'||':
					rToken.ttype = ReplToken.TokenType.TK_OP_OR
				'|=':
					rToken.ttype = ReplToken.TokenType.TK_OP_BIT_OR_EQUAL
				'&':
					rToken.ttype = ReplToken.TokenType.TK_OP_BIT_AND
				'&&':
					rToken.ttype = ReplToken.TokenType.TK_OP_AND
				'&=':
					rToken.ttype = ReplToken.TokenType.TK_OP_BIT_AND_EQUAL
		elif instruction[index] in ':!+-/%^=':
			# could be ! or !=
			var token = instruction[index]
			index += 1
			if index < instruction.length() and instruction[index] == '=':
				token += instruction[index]
				index += 1
			var rToken = ReplToken.new()
			rToken.content = token
			tokens.append(rToken)
			match token:
				'!':
					rToken.ttype = ReplToken.TokenType.TK_OP_NOT
				'!=':
					rToken.ttype = ReplToken.TokenType.TK_OP_NOT_EQUAL
				'+':
					rToken.ttype = ReplToken.TokenType.TK_OP_ADD
				'+=':
					rToken.ttype = ReplToken.TokenType.TK_OP_ADD_EQUAL
				'-':
					rToken.ttype = ReplToken.TokenType.TK_OP_SUB
				'-=':
					rToken.ttype = ReplToken.TokenType.TK_OP_SUB_EQUAL
				'/':
					rToken.ttype = ReplToken.TokenType.TK_OP_DIV
				'/=':
					rToken.ttype = ReplToken.TokenType.TK_OP_DIV_EQUAL
				'%':
					rToken.ttype = ReplToken.TokenType.TK_OP_MOD
				'%=':
					rToken.ttype = ReplToken.TokenType.TK_OP_MOD_EQUAL
				'^':
					rToken.ttype = ReplToken.TokenType.TK_OP_BIT_XOR
				'^=':
					rToken.ttype = ReplToken.TokenType.TK_OP_BIT_XOR_EQUAL
				'=':
					rToken.ttype = ReplToken.TokenType.TK_OP_EQUAL
				'==':
					rToken.ttype = ReplToken.TokenType.TK_OP_EQUAL_EQUAL
				':':
					rToken.ttype = ReplToken.TokenType.TK_COLON
				':=':
					rToken.ttype = ReplToken.TokenType.TK_OP_COLON_EQUAL
		elif instruction[index] in '()[]{} \t\r\n,':
			var token = instruction[index]
			var rToken = ReplToken.new()
			rToken.content = token
			tokens.append(rToken)
			index += 1
			match token:
				'(':
					rToken.ttype = ReplToken.TokenType.TK_PARENTHESIS_OPEN
				')':
					rToken.ttype = ReplToken.TokenType.TK_PARENTHESIS_CLOSE
				'[':
					rToken.ttype = ReplToken.TokenType.TK_BRACKET_OPEN
				']':
					rToken.ttype = ReplToken.TokenType.TK_BRACKET_CLOSE
				'{':
					rToken.ttype = ReplToken.TokenType.TK_CURLY_BRACKET_OPEN
				'}':
					rToken.ttype = ReplToken.TokenType.TK_CURLY_BRACKET_CLOSE
				' ':
					rToken.ttype = ReplToken.TokenType.TK_WHITESPACE
				'\t':
					rToken.ttype = ReplToken.TokenType.TK_WHITESPACE
				'\r':
					rToken.ttype = ReplToken.TokenType.TK_NEWLINE
				'\n':
					rToken.ttype = ReplToken.TokenType.TK_NEWLINE
				',':
					rToken.ttype = ReplToken.TokenType.TK_COMMA
		elif instruction[index] == "'":
			if index + 2 < instruction.length() and instruction.substr(index, 3) == "'''":
				# triple single quoted string
				var token = "'''"
				index += 3
				while index + 2 < instruction.length() and instruction.substr(index, 3) != "'''":
					if instruction[index] == '\\':
						token += instruction[index]
						index += 1
					token += instruction[index]
					index += 1
				# still haven't looked at the last three quotes
				if instruction.substr(index, 3) != "'''":
					return [true, "Unterminated triple string"]
				token += "'''"
				index += 3
				var rToken = ReplToken.new()
				rToken.content = token
				tokens.append(rToken)
				rToken.ttype = ReplToken.TokenType.TK_STR_TSQ
			else:
				# normal single quoted string
				var token = instruction[index]
				index += 1
				while index < instruction.length() and instruction[index] != "'":
					if instruction[index] == '\\':
						token += instruction[index]
						index += 1
					token += instruction[index]
					index += 1
				token += instruction[index]
				index += 1
				var rToken = ReplToken.new()
				rToken.content = token
				tokens.append(rToken)
				rToken.ttype = ReplToken.TokenType.TK_STR_SQ
		elif instruction[index] == '"':
			if index + 2 < instruction.length() and instruction.substr(index, 3) == '"""':
				# triple double quoted string
				var token = '"""'
				index += 3
				while index + 2 < instruction.length() and instruction.substr(index, 3) != '"""':
					if instruction[index] == '\\':
						token += instruction[index]
						index += 1
					token += instruction[index]
					index += 1
				# still haven't looked at the last three quotes
				if instruction.substr(index, 3) != '"""':
					return [true, "Unterminated triple string"]
				token += '"""'
				index += 3
				var rToken = ReplToken.new()
				rToken.content = token
				tokens.append(rToken)
				rToken.ttype = ReplToken.TokenType.TK_STR_TDQ
			else:
				# normal double quoted string
				var token = instruction[index]
				index += 1
				while index < instruction.length() and instruction[index] != '"':
					if instruction[index] == '\\':
						token += instruction[index]
						index += 1
					token += instruction[index]
					index += 1
				token += instruction[index]
				index += 1
				var rToken = ReplToken.new()
				rToken.content = token
				tokens.append(rToken)
				rToken.ttype = ReplToken.TokenType.TK_STR_TDQ
		else:
			var err = """failed to parse:
				tokens: {tokens}
				character: {character}
				instruction: {instruction}
			""".format({
				'tokens': tokens,
				'character': instruction[index],
				'instruction': instruction,
			})
			return [true, err]
	
	var final_tokens = []
	var is_leading_whitespace = true
	for token in tokens:
		var is_newline = token.content in '\r\n'
		var is_whitespace = token.content in ' \t'
		
		if is_leading_whitespace:
			if not is_whitespace and not is_newline:
				is_leading_whitespace = false
			final_tokens.append(token)
		else:
			if is_newline:
				is_leading_whitespace = true
			if is_whitespace:
				continue
			final_tokens.append(token)
	
	return [false, final_tokens]
