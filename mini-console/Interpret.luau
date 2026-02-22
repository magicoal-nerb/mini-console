--!strict

local Parse = require("./Parse")
local Lexer = require("./Lexer")

local OPS = {
	['+'] = function(a: any, b: any) return a + b end,
	['-'] = function(a: any, b: any) return a - b end,
	['*'] = function(a: any, b: any) return a * b end,
	['/'] = function(a: any, b: any) return a / b end,
	['%'] = function(a: any, b: any) return a % b end,
	['^'] = function(a: any, b: any) return a ^ b end,
	['<'] = function(a: any, b: any) return a < b end,
	['>'] = function(a: any, b: any) return a > b end,
	['<='] = function(a: any, b: any) return a <= b end,
	['>='] = function(a: any, b: any) return a >= b end,
	['=='] = function(a: any, b: any) return a == b end,
	['~='] = function(a: any, b: any) return a ~= b end,
	['..'] = function(a: any, b: any) return a .. b end,
	['or'] = function(a: any, b: any) return a or b end,
	['and'] = function(a: any, b: any) return a and b end,
}

type Environment = Parse.Environment

local function konsoleInterpret(src: string, env: any)
	local lexer = Lexer(src)
	return Parse(lexer, {
		env = env,
		
		handleLiteral = function(state: Environment, literal: any)
			if literal == "nil" then
				return nil
			elseif literal == "true" then
				return true
			elseif literal == "false" then
				return false
			end
			
			return literal
		end,

		handleNumber = function(state: Environment, literal: any)
			return tonumber(literal)
		end,

		handleUnary = function(state: Environment, what: any)
			return -what
		end,

		handleBinary = function(state: Environment, op: string, left: any, right: any)
			return OPS[op](left, right)
		end,

		handleProp = function(state: Environment, base: {[string]: any}, key: any)
			return base[key]
		end,

		handleCall = function(state: Environment, base: any, args: { any })
			return base(table.unpack(args))
		end,
		
		handleGlobal = function(state: Environment, name: string)
			return env[name]
		end,

		handleAssign = function(state: Environment, base: any, key: any, value: any)
			base[key] = value	
		end,

		handleGlobalAssign = function(state: any, key: any, value: any)
			state.env[key] = value
		end,
	})
end

return konsoleInterpret