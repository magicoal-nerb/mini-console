--!strict

-- magicoal_nerb :3

local Parse = require("./Parse")
local Lexer = require("./Lexer")
local Types = require("./Types")

local MAX_MATCHES = 5

type TypeDatabase = Types.TypeDatabase
type Environment = Parse.Environment<Type>
type Type = Types.Type

local BoolType = {
	kind = "builtin",
	name = "boolean",
	args = {},
} :: Type

local NumberType = {
	kind = "builtin",
	name = "number",
	args = {},
} :: Type

local StringType = {
	kind = "builtin",
	name = "string",
	args = {},
} :: Type

local Kind = {} :: { [string]: (kind: Type) -> string }
Kind = {
	["table"] = function(kind: Type)
		local fill: { string } = {}
		for i, name in assert(kind.slots) do
			local typ = kind.args[name]
			table.insert(fill, `{name}: {Kind[typ.kind](typ)}`)
		end

		return `\{ {table.concat(fill,', ')} \}`
	end,

	["list"] = function(kind: Type)
		local fill: { string } = {}
		for i, name in assert(kind.slots) do
			local typ = kind.args[name]
			table.insert(fill, `{name}: {Kind[typ.kind](typ)}`)
		end

		return `({table.concat(fill,', ')})`
	end,

	["union"] = function(kind: Type)
		local fill: { string } = {}
		for name, typ in assert(kind.list) do
			table.insert(fill, `\"{Kind[typ.kind](typ)}\"`)
		end

		return table.concat(fill,' | ')
	end,

	["array"] = function(kind: Type)
		return kind.name
	end,

	["builtin"] = function(kind: Type)
		return kind.name
	end,

	["function"] = function(kind: Type)
		-- make suggestion fill in type names...
		local list = assert(kind.list)
		local funcArgs = list[1]
		local funcRets = list[2]

		return `{Kind.list(funcArgs)} -> {Kind.list(funcRets)}`
	end,
}

-- longest common subsequence
local function lcs(a: string, b: string)
	-- dp(i, j) = lcs of a [1..i] and b[1..j] that ends at a[i] and b[j]
	-- dp(i + 1, j + 1) = dp(i, j) + 1 ; a[i+1] == b[j+1]
	--                    0 ; a[i] != b[j]
	local gcp = 0
	
	local lenA, lenB = #a, #b
	local bytesA, bytesB = { a:byte(1, -1) }, { b:byte(1, -1) }
	local curr, prev = table.create(lenB + 1, 0), table.create(lenB + 1, 0)
	
	for i = 2, #a + 1 do
		for j = 2, #b + 1 do
			if bytesA[i - 1] == bytesB[j - 1] then
				curr[j] = prev[j - 1] + 1
				gcp = math.max(gcp, curr[j])
			else
				curr[j] = 0
			end
		end
	end
	
	return gcp
end

local function levenshtein(a: string, b: string)
	local lenA, lenB = #a, #b
	local bytesA, bytesB = { a:byte(1, -1) }, { b:byte(1, -1) }
	local curr, prev = table.create(lenB + 1, 0), table.create(lenB + 1, 0)
	
	-- dp(i + 1, j + 1) = dp(i, j) if a[i+1] == b[j+1]
	-- = min(dp(i, j+1), dp(i+1, j), dp(i, j)) + 1 if a[i] != b[j]
	for i = 1, #b + 1 do
		prev[i] = i - 1
	end

	for i = 2, lenA + 1 do
		curr[1] = i - 1
		for j = 2, lenB + 1 do
			if bytesA[i - 1] == bytesB[j - 1] then
				curr[j] = prev[j - 1]
			else
				curr[j] = math.min(prev[j], curr[j-1], prev[j-1]) + 1
			end
		end

		prev, curr = curr, prev
	end

	return curr[lenB + 1]
end

local function getMatch(t: Type, what: string): Type
	local distName = {} :: { [string]: number }
	local args = {} :: { string }

	for name in t.args do
		local cost = levenshtein(name, what) - lcs(name, what)
		if name:sub(1, #what):lower() == what:lower() then
			cost -= 100	
		end
		
		distName[name] = cost
		table.insert(args, name)
	end

	table.sort(args, function(a: string, b: string)
		return distName[a] < distName[b]
	end)

	local result = {
		kind = "table",
		slots = {},
		args = {},
	} :: Type

	for i = 1, math.min(MAX_MATCHES, #args) do
		assert(result.slots)

		result.args[args[i]] = t.args[args[i]]
		table.insert(result.slots, args[i])
	end

	return result
end

local function autocomplete(
	src: string,
	env: Type
): string
	local lexer = Lexer(src)
	local typ: Type = Parse(lexer, {
		handleLiteral = function(state: Environment, literal: any)
			return nil :: any
		end,

		handleNumber = function(state: Environment, literal: any)
			return NumberType
		end,

		handleUnary = function(state: Environment, what: any)
			return what
		end,

		handleBinary = function(state: Environment, op: string, left: any, right: any): any
			return right
		end,

		handleNot = function(state: Environment, base: Type): Type
			return BoolType
		end,

		handleProp = function(state: Environment, base: Type, key: string): any
			if base then
				return base.args[key] or getMatch(base, key)
			else
				return nil
			end
		end,

		handleCall = function(state: Environment, base: Type, args: { any }, complete: boolean): any
			if not base then
				return
			elseif base.kind ~= "function" then
				return
			end

			local list = assert(base.list)
			local funcArgs = list[1]
			local funcRets = list[2]

			local slots = assert(funcArgs.slots)
			if #slots >= #args and complete then
				return funcRets
			else
				return funcArgs
			end
		end,

		handleAssign = function(state: Environment, base: any, key: any, value: any)
			return value
		end,

		handleGlobal = function(state: Environment, key: string)
			local arg = env.args[key]
			if arg then
				return arg
			else
				return getMatch(env, key)
			end
		end,

		handleGlobalAssign = function(state: any, key: any, value: any)
			return value	
		end,
	} :: Environment) or env

	return Kind[typ.kind](typ) or "<error type>"
end

return autocomplete