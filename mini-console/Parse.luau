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

export type Environment<T> = {
	handleLiteral: (env: Environment<T>, literal: string) -> T,
	handleNumber: (env: Environment<T>, literal: string) -> T,
	handleGlobal: (env: Environment<T>, literal: string) -> T,

	handleUnary: (env: Environment<T>, T) -> T,
	handleNot: (env: Environment<T>, T) -> T,
	handleBinary: (env: Environment<T>, op: string, left: T, right: T) -> T,
	handleCall: (env: Environment<T>, base: T, args: { T }, complete: boolean) -> T,
	handleProp: (env: Environment<T>, base: T, key: T | string) -> T,

	handleAssign: (env: Environment<T>, base: T, key: T | string | number, value: T) -> T,
	handleGlobalAssign: (env: Environment<T>, key: T | string, value: T) -> T,
}

local function parsePrefixExpression<T>(env: Environment<T>, lexer: Lexer): T?
	if lexer:expect('-') then
		-- unary
		return env.handleUnary(env, parsePrefixExpression(env, lexer) :: T)
	elseif lexer:expect("not") then
		-- not
		return env.handleNot(env, parsePrefixExpression(env, lexer) :: T)
	elseif lexer:isNumeric() then
		-- numeric
		return env.handleNumber(env, lexer:expectLiteral() :: string)
	elseif lexer:expect('(') then
		-- control order of ops
		local stat = parseStatement(env, lexer, false)
		lexer:expect(')')
		return stat
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

local function parseTable<T>(env: Environment<T>, lexer: Lexer): T
	local tab = {} :: any
	if lexer:expect('}') then
		return tab
	end

	repeat
		if lexer:peek() == '=' then
			-- index
			local index = lexer:expectLiteral() :: string
			lexer:expect('=')
			env.handleAssign(env, tab, index, parseStatement(env, lexer, false))
		elseif lexer:expect('[') then
			-- open index
			local index = parseStatement(env, lexer, false)
			lexer:expect(']')
			env.handleAssign(env, tab, index, parseStatement(env, lexer, false))
		else
			-- separated
			local eval = parseStatement(env, lexer, false)
			if eval then
				env.handleAssign(env, tab, #tab + 1, eval)
			end
		end
	until lexer:eof()
		or not lexer:expect(',')

	lexer:expect('}')
	return tab
end

local function parseExpression<T>(env: Environment<T>, lexer: Lexer, maybeLimit: number?): T?
	if lexer:expect('{') then
		return parseTable(env, lexer)
	end

	local expr = parsePrefixExpression(env, lexer)
	if expr == nil then
		return nil
	end

	local limit = maybeLimit or 0
	local op = parseOperator(lexer)

	while op and LuaPrecedence[op] > limit do
		local operator = lexer:consume()
		local right = parseExpression(env, lexer, LuaPrecedence[op])
		
		expr = env.handleBinary(env, operator, expr, right :: T)
		op = parseOperator(lexer)
	end

	return expr
end

function parseStatement<T>(env: Environment<T>, lexer: Lexer, canAssign: boolean): T
	local expression = parseExpression(env, lexer) :: T
	local previous = nil
	local index: string | T

	while not lexer:eof() do
		if lexer:expect('.') then
			previous = expression
			index = lexer:expectLiteral() :: string

			expression = env.handleProp(env, expression, index)
		elseif lexer:expect('[') then
			previous = expression
			index = parseStatement(env, lexer, false) :: T

			expression = env.handleProp(env, expression, index)
			lexer:expect(']')
		elseif lexer:expect('(') then
			if lexer:expect(')') then
				expression = env.handleCall(env, expression, {}, true)
				continue
			end

			local args = {}
			repeat
				table.insert(args, parseStatement(env, lexer, false))
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
	
	if not canAssign then
		-- can't assign stuff
		return expression
	elseif previous and lexer:is('=') then
		-- table
		lexer:consume()
		return env.handleAssign(env, previous, index, parseStatement(env, lexer, false))
	elseif lexer:is('=') then
		-- global
		lexer:consume()
		return env.handleGlobalAssign(env, expression, parseStatement(env, lexer, false))
	end

	return expression
end

local function parse<T>(lexer: Lexer, env: Environment<T>): T
	local output
	while not lexer:eof() do
		output = parseStatement(env, lexer, true)
	end

	return output
end

return parse