--!strict

local Lexer = require("./Lexer")

type Lexer = Lexer.Lexer

export type TypeDatabase = { [string]: Type }
export type Type = {
	kind: "table" | "array" | "function" | "builtin" | "union" | "list",
	args: { [string]: Type },
	name: string,
	
	retcode: number?,
	slots: { string }?,
	list: { Type }?,
}

local function parseList(lexer: Lexer, types: TypeDatabase): Type
	local retcode = {
		kind = "list",
		name = "list",
		slots = {},
		args = {},
	} :: Type

	if not lexer:expect(')') then
		-- retvalue
		repeat
			local name = lexer:expectLiteral() :: string
			lexer:assert(lexer:expect(':'), "expected :")

			retcode.args[name] = assert(parseType(lexer, types))
			table.insert(retcode.slots, name)

			lexer:expect(',')
			lexer:expect(';')
		until lexer:expect(')')
	end
	
	return retcode
end

local function parseBaseType(lexer: Lexer, types: TypeDatabase): Type
	if lexer:expect('{') then
		if lexer:peek() == '}' then
			-- array type
			local typ = assert(types[lexer:expectLiteral() :: string])
			lexer:assert(typ ~= nil, "name expected")
			lexer:assert(lexer:expect('}'), "expected closing }")
			
			return {
				kind = "array",
				name = `\{ {typ.name} \}`,
				args = {},
			}
		end
		
		-- name `:` parseType
		local record = {} :: { [string]: Type }
		repeat
			local name = lexer:expectLiteral() :: string
			lexer:assert(name ~= nil, "need name")
			lexer:expect(':')
			
			record[name] = assert(parseType(lexer, types))
			
			lexer:expect(',')
			lexer:expect(';')
		until lexer:expect('}')

		return {
			kind = "table",
			name = "table",
			args = record,
		}
	elseif lexer:expect('(') then
		-- `(` arglist `)` -> `(` retValue `)`
		local list = { parseList(lexer, types) }
		
		-- arrow
		lexer:assert(lexer:expect('->'), "expected ->")
		
		-- return
		lexer:assert(lexer:expect('('), "expected ret")
		table.insert(list, parseList(lexer, types))
		
		return {
			kind = "function",
			name = "function",
			list = list,
			args = {},
		}
	else
		local what = lexer:consume() :: string
		if not types[what] then
			-- create one, assume it
			-- is built in
			types[what] = {
				kind = "builtin",
				name = what,
				args = { },
			}
			
			return types[what]
		else
			return types[what]
		end
	end
end

local function move<T>(dest: any, src: any)
	-- move from src to dest
	for i, value in src do
		dest[i] = value
	end
end

function parseType(lexer: Lexer, types: TypeDatabase): Type?
	local baseType = parseBaseType(lexer, types)
	if not baseType then
		return nil
	elseif lexer:expect('|') then
		local unionType = {
			kind = "union",
			name = "union",
			list = { baseType },
		} :: Type
		
		repeat
			table.insert(
				unionType.list :: { Type },
				parseBaseType(lexer, types)
			)
		until not lexer:expect('|')
		
		return unionType
	end
	
	return baseType
end

local function types<T>(src: string): Type
	-- quickly go through type information
	local lexer = Lexer(src)
	local db = {} :: TypeDatabase
	local root = {
		kind = "table",
		args = {},
	} :: Type
	
	while not lexer:eof() do
		if lexer:expect("type") then
			-- name `=` `Type`
			local name = lexer:expectLiteral() :: string
			lexer:expect('=')
			
			local reserved = {} :: Type
			db[name] = reserved
			
			move(reserved, parseType(lexer, db))
			root.args[name] = reserved
		elseif lexer:isLiteral() then
			-- name `:` `Type`
			local name = lexer:expectLiteral() :: string
			lexer:expect(':')
			
			db[name] = assert(parseType(lexer, db))
			root.args[name] = db[name]
		else
			lexer:consume()
		end
	end
	
	return root
end

return types