--!strict

local Parse = require("./Parse")
local Lexer = require("./Lexer")
local Types = require("./Types")

type TypeDatabase = Types.TypeDatabase
type Environment = Parse.Environment
type Type = Types.Type

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
		for name, typ in kind.args do
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

local function konsoleAutocomplete(
	src: string,
	env: Type
): string
	local lexer = Lexer(src)
	local typ: Type = Parse(lexer, {
		handleLiteral = function(state: Environment, literal: any)
			return nil -- StringType
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

		handleProp = function(state: Environment, base: Type, key: string): any
			if base then
				return base.args[key] or base
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
			return env.args[key]
		end,

		handleGlobalAssign = function(state: any, key: any, value: any)
			return value	
		end,
	}) or env
	
	return Kind[typ.kind](typ) or "<error type>"
end

return konsoleAutocomplete