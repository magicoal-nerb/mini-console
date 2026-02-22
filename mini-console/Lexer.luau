--!strict

local WHITESPACE = {
	[string.byte(' ')] = true,
	[string.byte('\f')] = true,
	[string.byte('\n')] = true,
	[string.byte('\t')] = true,
	[string.byte('\r')] = true,
	[string.byte('\v')] = true,
}

local SPECIAL = {
	[0x3d3d] = true, -- ==
	[0x3d3c] = true, -- <=
	[0x3d3e] = true, -- >=
	[0x3d7e] = true, -- ~=
	[0x2e2e] = true, -- ..
	[0x3e2d] = true, -- ->
}

local function isNumeric(code: number): boolean
	return string.byte('0') <= code and code <= string.byte('9')
end

local function isAlphanumeric(code: number): boolean
	return string.byte('A') <= code and code <= string.byte('Z')
		or string.byte('a') <= code and code <= string.byte('z')
		or string.byte('0') <= code and code <= string.byte('9')
		or string.byte('_') == code
end

local Lexer = {}
Lexer.__index = Lexer

export type Lexer = typeof(setmetatable({} :: {
	cursor: number,
	length: number,
	lexemes: { string },
}, Lexer))

function Lexer.new(lexemes: { string })
	return setmetatable({
		cursor = 1,
		length = #lexemes,
		lexemes = lexemes,
	}, Lexer)
end

function Lexer.tell(self: Lexer): number
	-- gets the cursor
	return self.cursor
end

function Lexer.set(self: Lexer, length: number)
	-- sets size
	self.length = length
end

function Lexer.is(self: Lexer, what: string): boolean
	-- is it a certain thing?
	return self.lexemes[self.cursor] == what
end

function Lexer.get(self: Lexer): string
	-- get current lexeme
	return self.lexemes[self.cursor]
end

function Lexer.assert(self: Lexer, expr: boolean, what: string)
	-- for handling errors
	if not expr then
		error(`current lexeme: {self.lexemes[self.cursor]}; {what}`)
	end
end

function Lexer.expect(self: Lexer, what: string): boolean
	-- is it the string we have?
	if self.lexemes[self.cursor] == what then
		self.cursor += 1
		return true
	end

	return false
end

function Lexer.expectLiteral(self: Lexer): string?
	-- we expect a literal
	local current = self.lexemes[self.cursor]
	if isAlphanumeric(string.byte(current, 1)) then
		self.cursor += 1
		return current
	end

	return nil
end

function Lexer.isLiteral(self: Lexer): boolean
	-- are we a literal?
	local current = self.lexemes[self.cursor]
	if not self:eof() then
		return isAlphanumeric(string.byte(current, 1))
	else
		return false
	end
end

function Lexer.isNumeric(self: Lexer): boolean
	-- are we a numeric?
	local current = self.lexemes[self.cursor]
	if not self:eof() then
		return isNumeric(string.byte(current, 1))
	else
		return false
	end
end

function Lexer.consume(self: Lexer): string
	-- skip and return
	self.cursor += 1
	return self.lexemes[self.cursor - 1]
end

function Lexer.eof(self: Lexer): boolean
	-- are we at the end yet?
	return self.cursor >= self.length
end

function Lexer.peek(self: Lexer): string
	-- check for the next element for what it is
	return self.lexemes[self.cursor + 1]
end

local function createLexer(content: string)
	local data = buffer.fromstring(content)
	local length = buffer.len(data)
	local cursor = 0

	local lexemes = {}
	while cursor < length do
		local byte = buffer.readu8(data, cursor)
		if WHITESPACE[byte] then
			-- skip whitespace
			cursor += 1
			continue
		elseif byte == string.byte('"') then
			-- keep reading the string stuff
			cursor += 1

			local start = cursor
			while cursor < length and buffer.readu8(data, cursor) ~= string.byte('"') do
				cursor += 1
			end

			table.insert(lexemes, content:sub(start + 1, cursor))
			cursor += 1
		elseif isNumeric(byte) then
			-- keep being numeric
			local start = cursor
			while cursor < length and isNumeric(buffer.readu8(data, cursor)) do
				cursor += 1
			end

			table.insert(lexemes, content:sub(start + 1, cursor))
		elseif isAlphanumeric(byte) then
			-- keep reading alphanumeric stuff
			local start = cursor
			while cursor < length and isAlphanumeric(buffer.readu8(data, cursor)) do
				cursor += 1
			end
			
			table.insert(lexemes, content:sub(start + 1, cursor))
		else
			-- only 1 character at a time
			local after = if cursor < length - 1
				then buffer.readu8(data, cursor + 1)
				else 0
			
			local id = bit32.lshift(after, 8) + byte
			if SPECIAL[id] then
				table.insert(lexemes, content:sub(cursor + 1, cursor + 2))
				cursor += 2
			else
				cursor += 1
				table.insert(lexemes, string.char(byte))
			end
		end
	end

	return Lexer.new(lexemes)
end

return createLexer