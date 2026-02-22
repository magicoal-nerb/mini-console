--!strict

local Lexer = require("./Lexer")

type Lexer = Lexer.Lexer

local LuaPrecedence = table.freeze({
	["^"] = 10,
	["*"] = 7,
	["/"] = 7,
	["%"] = 7,
	["+"] = 6,
	["-"] = 6,
	[".."] = 5,
	[">"] = 3,
	["<"] = 3,
	["<="] = 3,
	[">="] = 3,
	["~="] = 3,
	["=="] = 3,
	["and"] = 2,
	["or"] = 1,
}) :: { [string]: number }

export type Environment = {
	handleLiteral: (env: Environment, literal: string) -> any,
	handleNumber: (env: Environment, literal: string) -> any,
	handleGlobal: (env: Environment, literal: string) -> any,
	
	handleUnary: (env: Environment, any) -> any,
	handleBinary: (env: Environment, op: string, left: any, right: any) -> any,
	handleCall: (env: Environment, base: any, args: { any }, complete: boolean) -> (any),
	handleProp: (env: Environment, base: any, key: any) -> (),
	
	handleAssign: (env: Environment, base: any, key: any, value: any) -> (),
	handleGlobalAssign: (env: Environment, key: any, value: any) -> (),
}

local function parsePrefixExpression(env: Environment, lexer: Lexer): any
	if lexer:expect('-') then
		-- unary
		return env.handleUnary(env, parsePrefixExpression(env, lexer))
	elseif lexer:isNumeric() then
		-- numeric
		return env.handleNumber(env, lexer:expectLiteral() :: string)
	elseif not lexer:isLiteral() then
		-- not a literal
		lexer:consume()
		return nil
	end

	local literal = lexer:expectLiteral() :: string
	return env.handleGlobal(env, literal)
		or env.handleLiteral(env, literal)
end

local function parseOperator(lexer: Lexer): string?
	-- get operator
	local operator = lexer:get()	
	return if LuaPrecedence[operator] ~= nil
		then operator
		else nil
end

local function parseTable(env: Environment, lexer: Lexer): any
	local tab = {} :: any
	if lexer:expect('}') then
		return tab
	end
	
	repeat
		if lexer:peek() == '=' then
			-- index
			local index = lexer:expectLiteral()
			lexer:expect('=')
			env.handleAssign(env, tab, index, parseStatement(env, lexer))
		elseif lexer:expect('[') then
			-- open index
			local index = parseStatement(env, lexer)
			lexer:expect(']')
			env.handleAssign(env, tab, index, parseStatement(env, lexer))
		else
			-- separated
			local eval = parseStatement(env, lexer)
			if eval then
				env.handleAssign(env, tab, #tab + 1, eval)
			end
		end
	until lexer:eof()
		or not lexer:expect(',')
	
	lexer:expect('}')
	return tab
end

local function parseExpression(env: Environment, lexer: Lexer, maybeLimit: number?): any
	if lexer:expect('{') then
		return parseTable(env, lexer)
	end
	
	local expr = parsePrefixExpression(env, lexer)
	if not expr then
		return nil
	end
	
	local limit = maybeLimit or 0
	local op = parseOperator(lexer)
	
	while op and LuaPrecedence[op] > limit do
		local operator = lexer:consume()
		local right = parseExpression(env, lexer, LuaPrecedence[op])
		expr = env.handleBinary(env, operator, expr, right)
		op = parseOperator(lexer)
	end
	
	return expr
end

function parseStatement(env: Environment, lexer: Lexer): any
	local expression = parseExpression(env, lexer) :: any
	local previous = nil
	local index
	
	while not lexer:eof() do
		if lexer:expect('.') then
			previous = expression
			index = lexer:expectLiteral()
			
			expression = env.handleProp(env, expression, index)
		elseif lexer:expect('[') then
			previous = expression
			index = parseStatement(env, lexer)

			expression = env.handleProp(env, expression, index)
			lexer:expect(']')
		elseif lexer:expect('(') then
			if lexer:expect(')') then
				expression = env.handleCall(env, expression, {}, true)
				continue
			end

			local args = {}
			repeat
				table.insert(args, parseStatement(env, lexer))
			until not lexer:expect(',')
			
			expression = env.handleCall(
				env,
				expression,
				args,
				lexer:expect(')')
			)
		else
			break
		end
	end
	
	if previous and lexer:is('=') then
		-- table
		lexer:consume()
		return env.handleAssign(env, previous, index, parseStatement(env, lexer))
	elseif lexer:is('=') then
		-- global
		lexer:consume()
		return env.handleGlobalAssign(env, expression, parseStatement(env, lexer))
	end
	
	return expression
end

local function parseKonsole(lexer: Lexer, env: Environment): any
	local output
	while not lexer:eof() do
		output = parseStatement(env, lexer)
	end
	
	return output
end

return parseKonsole