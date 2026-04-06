local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local InventoryFrame = LocalPlayer.PlayerGui:WaitForChild("UI", 30).Inventory.Inventory.Inventory.ScrollingFrame
local ItemsMod = require(ReplicatedStorage.SettingModules.ItemIds)
local Remotes = ReplicatedStorage:WaitForChild("Connections")
local DropItemRemote = Remotes:WaitForChild("DropItem")

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()

local selectedItemName = ""

-- Payload Template
local DROP_PAYLOAD_TEMPLATE = {
	{
		SafeId = "", -- this is important
		Quantity = 1,
	},
	"", -- Item name
	"", -- Item name pt 2
	0, -- quantity or amount of item to drop
	1
}

-- Utility Functions (xd)
local PrefixTrie = {}

local function normalize(str)
	str = str:lower()
	str = str:gsub("[\"'`]", "")     -- remove quotes
	str = str:gsub("[%-%_/]", " ")   -- separators -> space
	str = str:gsub("%s+", " ")       -- collapse spaces
	str = str:match("^%s*(.-)%s*$")  -- trim
	return str
end

local function insertWord(word)
	local lower = normalize(word)

	for start = 1, #lower do
		if start == 1 or lower:sub(start-1, start-1) == " " then
			local node = PrefixTrie

			for i = start, #lower do
				local char = string.byte(lower, i)
				node[char] = node[char] or {}
				node = node[char]

				if not node.__first or word < node.__first then
					node.__first = word
				end
			end
		end
	end
end

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local function resolvePrefix(text)
	local lower = normalize(text)
	local node = PrefixTrie

	for i = 1, #lower do
		node = node[string.byte(lower, i)]
		if not node then return end
	end

	return node.__first
end

-- Managers
local InventoryTracker = {
	Labels = {}
}

function InventoryTracker:Add(label)
	if label:IsA("TextLabel") then
		table.insert(self.Labels, label)
	end
end

function InventoryTracker:Remove(label)
	local t = self.Labels
	for i = 1, #t do
		if t[i] == label then
			t[i] = t[#t]
			t[#t] = nil
			break
		end
	end
end

function InventoryTracker:GetSafeId()
	for _, label in ipairs(self.Labels) do
		return label.SafeId.Value
	end
end

function ItemRegistry:Add(name)
	if type(name) == "string" then
		table.insert(self.Items, name)
		insertWord(name)
	end
end

local ItemRegistry = {
	Items = {}
}

function ItemRegistry:Spawn(name, amount)
	local qty = amount or 0
	local safeId = InventoryTracker:GetSafeId()
	if not safeId then return warn("SafeId not found") end

	local payload = deepCopy(DROP_PAYLOAD_TEMPLATE)

	payload[1].SafeId = safeId
	payload[2] = name
	payload[3] = name
	payload[4] = -qty

	DropItemRemote:FireServer(unpack(payload))
	task.wait(0.1)

	payload[4] = qty
	DropItemRemote:FireServer(unpack(payload))
end

-- init yuh
for _, v in pairs(ItemsMod) do
	if v.Name then
		ItemRegistry:Add(v.Name)
	end
end

for _, child in ipairs(InventoryFrame:GetChildren()) do
	if child:IsA("TextLabel") then
		InventoryTracker:Add(child)
	end
end

LocalPlayer.PlayerGui.DescendantAdded:Connect(function(obj)
	if obj.Parent and obj.Parent:FindFirstChild("Grid") then
		InventoryTracker:Add(obj)
	end
end)

LocalPlayer.PlayerGui.DescendantRemoving:Connect(function(obj)
	if obj:IsA("TextLabel") then
		InventoryTracker:Remove(obj)
	end
end)

-- UI
local Window = Library:CreateWindow({
	Title = "State Of Anarchy | Super Sexy Admin Mode",
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0
})

local Tabs = {
	Main = Window:AddTab('Main'),
}

local ControlsGroup = Tabs.Main:AddLeftGroupbox('Controls')

ControlsGroup:AddInput("text_autocorrect", {
	Default = " ",
	Text = "Item Name (auto correct)",
	Tooltip = "Type item name"
})

local SelectedItemLabel = ControlsGroup:AddLabel("...", true)

ControlsGroup:AddInput("Amount", {
	Default = 1,
	Numeric = true,
	Finished = true,
	Text = 'Amount',
	Tooltip = "Spawn amount",

	Callback = function(value)
		ItemRegistry:Spawn(selectedItemName, value)
	end
})

Options.text_autocorrect:OnChanged(function()
	local match = resolvePrefix(Options.text_autocorrect.Value)
	if match then
		SelectedItemLabel:SetText(match)
		selectedItemName = match
	end
end)
