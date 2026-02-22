--!nolint

local Console = require("../mini-console")

local autocomplete = Console.Autocomplete
local interpret = Console.Interpret
local types = Console.Types

-- Testing suite
local function describe(label, fn)
	local succ, err = pcall(fn)
	if not succ then
		print(string.format("test failed: %s", err))
	else
		print(string.format("test passed: %s", label))
	end
end

local function it(label, fn)
	local succ, err = pcall(fn)
	if not succ then
		error(string.format("%s: %s", label, err))
	end
end

local function expect(expr, what)
	if expr ~= what then
		error(string.format("expected: %s, got %s", what, expr))
	end
end

describe("Autocomplete", function()
	it("should provide method information", function()
		local suggestions = types([[
			type hello = (arg1: string, arg2: number) -> (ok: number)
		]])
		
		expect(autocomplete("hello(a, ", suggestions), "(arg1: string, arg2: number)")
		expect(autocomplete("hello(a", suggestions), "(arg1: string, arg2: number)")
		expect(autocomplete("hello(a, 123)", suggestions), "(ok: number)")
	end)
	
	it("should provide record information", function()
		local suggestions = types([[
			type record = {
				a: number,
				b: number,
			}
			
			type nested = {
				depth1: {
					depth2: {
						depth3: number,
					}
				}
			}
		]])
		
		expect(autocomplete("record.", suggestions), "{ a: number, b: number }")
		expect(autocomplete("nested.", suggestions), "{ depth1: { depth2: { depth3: number } } }")
		expect(autocomplete("nested.depth1.depth2.de", suggestions), "{ depth3: number }")
	end)
end)

describe("Interpretor", function()
	it("should do order of operations", function()
		expect(interpret("7 * 9 + 3 - 6 / 2 + 2^2 - 11", {}), 56)
	end)
	
	it("should do chained ops of operations", function()
		local chain = {
			x = {
				y = {
					z = "wrong",
				}
			}
		}
		
		interpret("f().x.y.z = hi", {f = function() return chain end})
		expect(chain.x.y.z, "hi")
	end)
	
	it("should set globals", function()
		local env = {}
		interpret("lol = 67", env)
		expect(env.lol, 67)
	end)
	
	it("should handle vargs", function()
		local env = {
			f = function()
				return 1, 2, 3, 4, 5, 6, 7, 8
			end,
		}
		
		interpret("lol = f()", env)
		expect(env.lol, 1)
		
		interpret("test = { f() }", env)
		expect(#env.test, 1)
		expect(env.test[1], 1)

		interpret("test2 = { 1, 2, 3, 4, 5, 6, 7 }", env)
		expect(#env.test2, 7)
		expect(env.test2[7], 7)
	end)
	
	it("should work on args", function()
		local set = {}
		local env = {
			f = function(...)
				set = { ... }
			end,
		}
		
		interpret("f(1, 2, 3, 4, 5, 6, 7, 8)", env)
		expect(#set, 8)
		
		interpret("f({1, 2}, {3, 4}, {hi = world})", env)
		expect(set[3].hi, "world")
	end)
	
	it("should construct tables", function()
		local set = {}
		local env = {
			f = function(tab)
				set = tab
			end,
		}
		
		interpret("f({a = b, c = { d = e, f = {}, a, b, c }})", env)
		expect(set.a, "b")
		expect(set.c.d, "e")
		expect(set.c[1], "a")
		expect(set.c[3], "c")
	end)
end)