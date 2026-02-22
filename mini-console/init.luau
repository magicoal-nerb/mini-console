-- tank u so much for using!! :3

local Types = require("@self/Types")

export type Type = Types.Type

return {
	-- main methods
	Autocomplete = require("@self/Autocomplete"),
	Interpret = require("@self/Interpret"),
	Types = require("@self/Types"),
	
	-- helpers
	Lexer = require("@self/Lexer"),
	Parse = require("@self/Parse"),
}