-- Клиент «Битвы Аур»: собирает экран (шапка, вкладки, страницы). Все шансы и баланс считает сервер.
local StarterGui = game:GetService("StarterGui")

local Core = require(script.Parent:WaitForChild("Core"))
local Pages = script.Parent:WaitForChild("Pages")
local Config, Ui, L = Core.Config, Core.Ui, Core.L
local C, new = Ui.C, Ui.new
local state = Core.state

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- ===== корень =====
local gui = new("ScreenGui", { Name = "AuraBattle", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Core.player:WaitForChild("PlayerGui") })
new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = gui }, {
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 20, 96)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 9, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 4, 18)),
		}),
		Rotation = 90,
	}),
})
local root = new("Frame", { BackgroundTransparency = 1, Parent = gui })
local uiScale = new("UIScale", { Parent = root })
Core.root = root

-- ===== шапка =====
local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -32, 0, 52), Position = UDim2.fromOffset(16, 8), Parent = root })
local title = Ui.label("AURA BATTLE", 28, Color3.new(1, 1, 1), { Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0, 260, 1, 0), Parent = header })
Ui.grad(C.cyan, C.pink, 0).Parent = title

local right = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(1, -270, 1, 0), Parent = header })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })

local function chip(order: number, color: Color3): TextLabel
	local c = Ui.label("", 13, color, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0,
		TextWrapped = false,
		LayoutOrder = order,
		Visible = false,
		Parent = right,
	})
	Ui.corner(18).Parent = c
	Ui.pad(0, 12).Parent = c
	Ui.stroke(color, 1.5, 0.4).Parent = c
	return c
end
local luckChip = chip(1, C.win)
local speedChip = chip(2, C.cyan)

local wheelBtn = Ui.button("🎡 " .. L("Wheel", "Колесо"), "purple", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 38), TextSize = 14, LayoutOrder = 3, Parent = right })
Ui.pad(0, 14).Parent = wheelBtn
local sndBtn = new("TextButton", { Text = "🔊", TextSize = 18, Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.panel, LayoutOrder = 4, Parent = right }, { Ui.corner(19), Ui.stroke(C.violet, 1.5, 0.5) })
sndBtn.Activated:Connect(function()
	Core.soundOn = not Core.soundOn
	sndBtn.Text = if Core.soundOn then "🔊" else "🔇"
end)
local balPill = new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 42), BackgroundColor3 = C.panel, LayoutOrder = 5, Parent = right }, {
	Ui.corner(21),
	Ui.stroke(C.cyan, 2, 0.35),
	Ui.pad(0, 16, 0, 12),
})
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), Parent = balPill })
Ui.coin(20).Parent = balPill
local balLabel = Ui.label("…", 20, C.text, { Font = Enum.Font.Code, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 42), TextWrapped = false, Parent = balPill })

-- ===== вкладки =====
local tabsBar = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 64),
	Size = UDim2.new(1, -32, 0, 48),
	ScrollBarThickness = 0,
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	Parent = root,
})
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabsBar })
local feedLabel = Ui.label("", 13, C.muted, { Position = UDim2.fromOffset(16, 114), Size = UDim2.new(1, -32, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = root })
local pagesHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 136), Size = UDim2.new(1, -32, 1, -148), Parent = root })

local TABS = {
	{ key = "Rifts", en = "Rifts", ru = "Разломы", color = C.cyan },
	{ key = "Clicker", en = "Aura Clicker", ru = "Аура Кликер", color = Color3.fromRGB(45, 212, 191) },
	{ key = "Battle", en = "Aura Battle", ru = "Битва аур", color = C.pink },
	{ key = "Upgrade", en = "Upgrade", ru = "Апгрейд", color = C.win },
	{ key = "Contract", en = "Contract", ru = "Контракт", color = C.gold },
	{ key = "Crash", en = "Crash", ru = "Краш", color = Color3.fromRGB(255, 106, 43) },
	{ key = "Collection", en = "Collection", ru = "Коллекция", color = Color3.fromRGB(176, 77, 255) },
	{ key = "Inventory", en = "Inventory", ru = "Инвентарь", color = Color3.fromRGB(75, 139, 255) },
}
local pages: { [string]: Frame } = {}
local renderers: { [string]: () -> () } = {}
local tabButtons: { [string]: TextButton } = {}
local current = "Rifts"

local function setTab(key: string)
	if Core.busy then
		Core.toast(L("Wait until it finishes", "Дождись окончания"))
		return
	end
	current = key
	for k, pg in pages do
		pg.Visible = k == key
	end
	for _, t in TABS do
		local b = tabButtons[t.key]
		local on = t.key == key
		b.BackgroundColor3 = if on then t.color else C.panel
		b.TextColor3 = if on then Color3.fromRGB(10, 8, 30) else C.text
		;(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = if on then 0 else 0.55
	end
	if renderers[key] then
		renderers[key]()
	end
end

for i, t in TABS do
	local b = new("TextButton", {
		Text = L(t.en, t.ru),
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.text,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundColor3 = C.panel,
		LayoutOrder = i,
		Parent = tabsBar,
	}, { Ui.corner(12), Ui.stroke(t.color, 1.5, 0.55), Ui.pad(0, 14) })
	tabButtons[t.key] = b
	local pg = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pagesHolder })
	pages[t.key] = pg
	local ok, res = pcall(function()
		return require(Pages:WaitForChild(t.key))(pg, Core)
	end)
	if ok then
		renderers[t.key] = res
	else
		warn("[AuraBattle] экран " .. t.key .. " не загрузился:", res)
		Ui.label(L("This screen failed to load — see Output", "Экран не загрузился — смотри Output"), 18, C.lose, { Size = UDim2.fromScale(1, 1), Parent = pg })
	end
	b.Activated:Connect(function()
		setTab(t.key)
	end)
end

local openWheel = require(Pages:WaitForChild("Wheel"))(Core)
wheelBtn.Activated:Connect(openWheel)

-- ===== живое обновление шапки =====
local function hms(sec: number): string
	local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), math.floor(sec % 60)
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end
local function renderHeader()
	balLabel.Text = Core.balanceText()
	local now = Core.now()
	local luck = (state.luckUntil or 0) - now
	luckChip.Visible = luck > 0
	luckChip.Text = "🍀 " .. L("Luck +15% · ", "Удача +15% · ") .. hms(math.max(0, luck))
	local sp = (state.speedUntil or 0) - now
	speedChip.Visible = sp > 0
	speedChip.Text = "⚡ " .. L("AFK x2 · ", "AFK x2 · ") .. hms(math.max(0, sp))
	local wl = (state.lastWheel or 0) + Config.WHEEL_COOLDOWN - now
	wheelBtn.Text = "🎡 " .. (if wl > 0 then hms(wl) else L("Wheel", "Колесо"))
end
task.spawn(function()
	while true do
		renderHeader()
		task.wait(1)
	end
end)

Core.onChange(function()
	renderHeader()
	if not Core.busy and renderers[current] then
		renderers[current]()
	end
end)

-- ===== масштаб под экран =====
local function relayout()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local s = math.clamp(math.min(vp.X / 1080, vp.Y / 720), 0.45, 1.3)
	uiScale.Scale = s
	Core.W, Core.H = vp.X / s, vp.Y / s
	root.Size = UDim2.fromOffset(Core.W, Core.H)
end
relayout()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	relayout()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)
	end
end)

-- ===== сервер =====
Core.R.StateChanged.OnClientEvent:Connect(function(s)
	Core.apply(s)
end)
Core.R.Feed.OnClientEvent:Connect(function(f)
	local a = Config.AURA_BY_ID[f.id]
	if a then
		local tier = Config.TIERS[Config.TIER_INDEX[a.tier]]
		feedLabel.Text = "🔴 LIVE  " .. f.name .. L(" got ", " выбил ") .. a.en .. " · " .. L(tier.en, tier.ru) .. " · " .. Core.fmt(a.price)
		feedLabel.TextColor3 = tier.color
	end
end)

setTab("Rifts")
task.spawn(function()
	Core.apply(Core.R.GetState:InvokeServer())
end)
