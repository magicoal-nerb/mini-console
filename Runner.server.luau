--!strict

-- Roblox side

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Console = require(ReplicatedStorage["mini-console"])
local LocalPlayer = assert(Players.LocalPlayer)

local ScreenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false

local Suggestions = Console.Types([[
	type print = (args: any) -> (),
	type record = {
		x: number,
		y: number,
		z: number,
		w: string,
		somethingElse: {
			wow: (name: string, value: number) -> (return: string),
		},
	},
]])

local Environment = {
	print = print,
	record = {
		x = 1,
		y = 2,
		z = 3,
		w = "hello world!",
		somethingElse = {
			wow = function(name: string, value: number): string
				return name
			end,
		}
	}
}

local function createElement<T>(
	name: string,
	props: { [string]: any },
	children: { [string]: Instance }?
): T
	local inst = Instance.new(name)
	for name, value in props do
		inst[name] = value
	end
	
	if children then
		for name, child in children do
			child.Parent = inst
			child.Name = name
		end
	end
	
	return inst
end

local textBox = createElement("TextBox", {
	PlaceholderText = "Test here...",
	
	AnchorPoint = Vector2.yAxis,
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 24),
	
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BorderSizePixel = 0,
	
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextColor3 = Color3.fromRGB(247, 247, 247),
	TextSize = 18,
	Text = '',
	
	Font = Enum.Font.BuilderSans,
}, {
	UIPadding = createElement("UIPadding", {
		PaddingBottom = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
	}),
}) :: TextBox

local Autocomplete = createElement("TextLabel", {
	AutomaticSize = Enum.AutomaticSize.XY,
	AnchorPoint = Vector2.yAxis,
	Position = UDim2.new(0, 0, 1, -24),
	Size = UDim2.new(0, 0, 0, 24),

	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextColor3 = Color3.fromRGB(247, 247, 247),
	TextSize = 18,
	Text = '',

	BorderSizePixel = 0,
	Font = Enum.Font.BuilderSans,
}, {
	UIPadding = createElement("UIPadding", {
		PaddingBottom = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
	}),
}) :: TextLabel

local function focusLost(enterPressed: boolean)
	if not enterPressed then
		return		
	end
	
	Console.Interpret(textBox.Text, Environment)
	Autocomplete.Text = ''
	textBox.Text = ''
end

local function textChanged()
	local text = textBox.Text
	if #text ~= 0 then
		Autocomplete.Text = Console.Autocomplete(textBox.Text, Suggestions)
	else
		Autocomplete.Text = ''
	end
end

textBox.Parent = ScreenGui
textBox.FocusLost:Connect(focusLost)
textBox:GetPropertyChangedSignal("Text"):Connect(textChanged)

Autocomplete.Parent = ScreenGui