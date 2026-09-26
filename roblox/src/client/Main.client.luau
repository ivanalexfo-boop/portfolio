-- Клиент «Битвы Аур»: только интерфейс и анимации. Все шансы и баланс считает сервер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local C = Ui.C
local new = Ui.new

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local R = {
	GetState = Remotes:WaitForChild("GetState") :: RemoteFunction,
	OpenRift = Remotes:WaitForChild("OpenRift") :: RemoteFunction,
	SellItems = Remotes:WaitForChild("SellItems") :: RemoteFunction,
	SellAll = Remotes:WaitForChild("SellAll") :: RemoteFunction,
	Tap = Remotes:WaitForChild("Tap") :: RemoteEvent,
	StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent,
}

-- язык: английский, русский — если у игрока русский Roblox
local RU = false
pcall(function()
	RU = string.sub(LocalizationService.RobloxLocaleId, 1, 2) == "ru"
end)
local function L(en: string, ru: string): string
	return if RU then ru else en
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- ===== состояние =====
local state = { balance = 0, inv = {} :: { { u: number, id: string, v: number } } }
local busy = false
local openCount = 1

-- ===== корневой интерфейс =====
local gui = new("ScreenGui", {
	Name = "AuraBattle",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
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
local W, H = 1000, 700 -- логический размер (до масштабирования)

-- ===== шапка =====
local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -32, 0, 56), Position = UDim2.fromOffset(16, 10), Parent = root })
local title = Ui.label("AURA BATTLE", 30, Color3.new(1, 1, 1), {
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(0.6, 0, 1, 0),
	Parent = header,
})
Ui.grad(C.cyan, C.pink, 0).Parent = title

local balPill = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.fromOffset(200, 44),
	BackgroundColor3 = C.panel,
	Parent = header,
}, { Ui.corner(22), Ui.stroke(C.cyan, 2, 0.35), Ui.pad(0, 16, 0, 12) })
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 8),
	Parent = balPill,
})
Ui.coin(20).Parent = balPill
local balLabel = Ui.label("…", 20, C.text, { Font = Enum.Font.Code, Size = UDim2.new(1, -30, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = balPill })

local function renderBalance()
	balLabel.Text = Format.coins(state.balance)
end

-- ===== вкладки =====
local tabsBar = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 72),
	Size = UDim2.new(1, -32, 0, 48),
	ScrollBarThickness = 0,
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	Parent = root,
})
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = tabsBar })

local pagesHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 128), Size = UDim2.new(1, -32, 1, -140), Parent = root })

local TABS = {
	{ key = "rifts", en = "Rifts", ru = "Разломы", color = C.cyan },
	{ key = "clicker", en = "Aura Clicker", ru = "Аура Кликер", color = Color3.fromRGB(45, 212, 191) },
	{ key = "inventory", en = "Inventory", ru = "Инвентарь", color = Color3.fromRGB(75, 139, 255) },
	{ key = "upgrade", en = "Upgrade", ru = "Апгрейд", color = C.win, soon = true },
	{ key = "contract", en = "Contract", ru = "Контракт", color = C.gold, soon = true },
	{ key = "crash", en = "Crash", ru = "Краш", color = Color3.fromRGB(255, 106, 43), soon = true },
	{ key = "battle", en = "Aura Battle", ru = "Битва аур", color = C.pink, soon = true },
}
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local currentTab = "rifts"
local renderers: { [string]: () -> () } = {}

local function setTab(key: string)
	if busy then
		return
	end
	currentTab = key
	for k, page in pages do
		page.Visible = k == key
	end
	for k, b in tabButtons do
		local on = k == key
		local t = nil
		for _, x in TABS do
			if x.key == k then
				t = x
			end
		end
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
		Text = L(t.en, t.ru) .. (if t.soon then " · " .. L("soon", "скоро") else ""),
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.text,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundColor3 = C.panel,
		AutoButtonColor = true,
		LayoutOrder = i,
		Parent = tabsBar,
	}, { Ui.corner(12), Ui.stroke(t.color, 1.5, 0.55), Ui.pad(0, 14) })
	tabButtons[t.key] = b
	pages[t.key] = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pagesHolder })
	b.Activated:Connect(function()
		setTab(t.key)
	end)
end

-- ===== уведомления =====
local toastLabel = Ui.label("", 16, C.text, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 40),
	BackgroundColor3 = C.panel2,
	BackgroundTransparency = 0,
	TextWrapped = false,
	Visible = false,
	ZIndex = 50,
	Parent = root,
})
Ui.corner(20).Parent = toastLabel
Ui.pad(0, 18).Parent = toastLabel
Ui.stroke(C.violet, 1.5, 0.3).Parent = toastLabel
local toastId = 0
local function toast(text: string)
	toastId += 1
	local id = toastId
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(2.4, function()
		if id == toastId then
			toastLabel.Visible = false
		end
	end)
end

-- ===== карточка ауры =====
local function tierOf(id: string)
	local a = Config.AURA_BY_ID[id]
	return Config.TIERS[Config.TIER_INDEX[a.tier]]
end

-- сфера ауры: картинка, если загружена, иначе цветной шар по цветам ауры
local function auraOrb(id: string, size: number): GuiObject
	local a = Config.AURA_BY_ID[id]
	if a.image ~= "" then
		return new("ImageLabel", { BackgroundTransparency = 1, Image = a.image, Size = UDim2.fromOffset(size, size), ScaleType = Enum.ScaleType.Fit })
	end
	local c1 = a.colors[1]
	local c2 = a.colors[2] or c1
	local orb = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1) }, {
		Ui.corner(UDim.new(1, 0)),
		Ui.grad(c1, c2, 45),
		Ui.stroke(tierOf(id).color, 2, 0.2),
	})
	new("Frame", { -- блик
		Size = UDim2.fromScale(0.42, 0.22),
		Position = UDim2.fromScale(0.2, 0.14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		Parent = orb,
	}, { Ui.corner(UDim.new(1, 0)) })
	return orb
end

local function auraCard(id: string, value: number?, w: number, h: number): Frame
	local a = Config.AURA_BY_ID[id]
	local tier = tierOf(id)
	local card = new("Frame", { Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.fromRGB(14, 11, 44) }, {
		Ui.corner(12),
		Ui.stroke(tier.color, 2, 0.25),
		new("UIGradient", {
			Color = ColorSequence.new(tier.color:Lerp(Color3.fromRGB(14, 11, 44), 0.7), Color3.fromRGB(14, 11, 44)),
			Rotation = 90,
		}),
	})
	local orbSize = math.floor(math.min(w * 0.62, h * 0.48))
	local orb = auraOrb(id, orbSize)
	orb.AnchorPoint = Vector2.new(0.5, 0)
	orb.Position = UDim2.new(0.5, 0, 0, 8)
	orb.Parent = card
	Ui.label(string.upper(a.en), 13, C.text, {
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(4, orbSize + 12),
		Size = UDim2.new(1, -8, 0, 16),
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = card,
	})
	Ui.label(L(tier.en, tier.ru), 11, tier.color, { Position = UDim2.fromOffset(4, orbSize + 29), Size = UDim2.new(1, -8, 0, 14), Parent = card })
	Ui.label(Format.coins(value or a.price), 13, C.text, { Font = Enum.Font.Code, Position = UDim2.fromOffset(4, orbSize + 45), Size = UDim2.new(1, -8, 0, 16), Parent = card })
	return card
end

-- ===== разломы =====
local riftsPage = pages.rifts
local countBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = riftsPage })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = countBar })
Ui.label(L("Open at once:", "Открыть сразу:"), 15, C.muted, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36), TextWrapped = false, LayoutOrder = 0, Parent = countBar })
local countButtons: { [number]: TextButton } = {}
local renderRifts: () -> ()
for i, n in { 1, 2, 3, 5 } do
	local b = new("TextButton", {
		Text = "x" .. n,
		TextSize = 15,
		Font = Enum.Font.Code,
		TextColor3 = C.text,
		Size = UDim2.fromOffset(52, 36),
		BackgroundColor3 = C.panel,
		LayoutOrder = i,
		Parent = countBar,
	}, { Ui.corner(10), Ui.stroke(C.violet, 1.5, 0.5) })
	countButtons[n] = b
	b.Activated:Connect(function()
		openCount = n
		renderRifts()
	end)
end

local riftsScroll = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 48),
	Size = UDim2.new(1, 0, 1, -48),
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.violet,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = riftsPage,
})
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(180, 250),
	CellPadding = UDim2.fromOffset(12, 12),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = riftsScroll,
})
local openButtons: { [string]: TextButton } = {}
local openRift: (rf: any) -> ()

for i, rf in Config.RIFTS do
	local card = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, Parent = riftsScroll }, {
		Ui.corner(16),
		Ui.stroke(rf.c1, 2, 0.4),
		Ui.grad(rf.c2:Lerp(Color3.fromRGB(12, 10, 40), 0.55), Color3.fromRGB(12, 10, 40), 90),
	})
	local art: GuiObject
	if rf.image ~= "" then
		art = new("ImageLabel", { BackgroundTransparency = 1, Image = rf.image, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(120, 120) })
	else
		art = new("Frame", { Size = UDim2.fromOffset(110, 110), BackgroundColor3 = Color3.new(1, 1, 1) }, {
			Ui.corner(UDim.new(1, 0)),
			Ui.grad(rf.c1, rf.c2, 45),
			Ui.stroke(rf.c1, 3, 0.1),
		})
		Ui.label(string.sub(rf.en, 1, 1), 44, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, Parent = art })
	end
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0.5, 0, 0, 12)
	art.Parent = card
	Ui.label(L(rf.en, rf.ru), 16, C.text, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(6, 136), Size = UDim2.new(1, -12, 0, 22), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	Ui.label(L(rf.ru, rf.en), 12, rf.c1, { Position = UDim2.fromOffset(6, 158), Size = UDim2.new(1, -12, 0, 16), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local b = Ui.button("", rf.button, { Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -24, 0, 50), Parent = card })
	openButtons[rf.id] = b
	b.Activated:Connect(function()
		openRift(rf)
	end)
end

renderRifts = function()
	for n, b in countButtons do
		local on = n == openCount
		b.BackgroundColor3 = if on then C.violet else C.panel
	end
	for _, rf in Config.RIFTS do
		local cost = rf.price * openCount
		local b = openButtons[rf.id]
		b.Text = L("OPEN", "ОТКРЫТЬ") .. "\n" .. Format.coins(cost)
		b.TextTransparency = if state.balance >= cost then 0 else 0.45
	end
end
renderers.rifts = renderRifts

-- ===== окно прокрутки и результата =====
local overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, ZIndex = 20, Parent = root })
local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.bg2, ZIndex = 21, Parent = overlay }, {
	Ui.corner(20),
	Ui.stroke(C.violet, 2, 0.3),
})

local function clearPanel()
	for _, ch in panel:GetChildren() do
		if not ch:IsA("UICorner") and not ch:IsA("UIStroke") then
			ch:Destroy()
		end
	end
end

local function setZ(inst: Instance, z: number)
	if inst:IsA("GuiObject") then
		inst.ZIndex = z
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = z
		end
	end
end

local CW, GAP, WIN_AT = 120, 8, 48

local function spinRow(riftId: string, item, y: number, rowH: number, stripW: number, dur: number)
	local strip = new("Frame", {
		Position = UDim2.fromOffset(20, y),
		Size = UDim2.fromOffset(stripW, rowH),
		BackgroundColor3 = Color3.fromRGB(11, 8, 38),
		ClipsDescendants = true,
		ZIndex = 22,
		Parent = panel,
	}, { Ui.corner(14), Ui.stroke(C.line, 1.5, 0) })
	local track = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset((CW + GAP) * (WIN_AT + 6), rowH - 16), ZIndex = 22, Parent = strip })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP), Parent = track })
	local ids = Economy.strip(riftId, WIN_AT + 5, WIN_AT, item.id, function()
		return math.random()
	end)
	local cards = {}
	for i, id in ids do
		local c = auraCard(id, nil, CW, rowH - 16)
		c.LayoutOrder = i
		setZ(c, 23)
		c.Parent = track
		cards[i] = c
	end
	-- центральная линия
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 30, Parent = strip }, {
		Ui.grad(C.cyan, C.pink, 90),
	})
	local cardStart = (WIN_AT - 1) * (CW + GAP)
	local inCard = 14 + math.random() * (CW - 28)
	local target = -(cardStart + inCard) + stripW / 2
	local centered = -(cardStart + CW / 2) + stripW / 2
	TweenService:Create(track, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(target, 8) }):Play()
	task.delay(dur + 0.05, function()
		TweenService:Create(track, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = UDim2.fromOffset(centered, 8) }):Play()
		local won = cards[WIN_AT]
		local s = won:FindFirstChildOfClass("UIStroke")
		if s then
			s.Thickness = 4
			s.Transparency = 0
		end
	end)
end

local function showResult(items)
	clearPanel()
	local n = #items
	local cw, ch = 150, 190
	local pw = math.min(W - 32, math.max(420, n * (cw + 12) + 40))
	panel.Size = UDim2.fromOffset(pw, ch + 190)
	local total = 0
	local best = items[1]
	for _, it in items do
		total += it.v
		if it.v > best.v then
			best = it
		end
	end
	local tier = tierOf(best.id)
	Ui.label(if n > 1 then L("Your drop", "Твой дроп") else L("You got", "Тебе выпало"), 24, tier.color, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30), ZIndex = 22, Parent = panel })
	Ui.label(L("Total: ", "Всего: ") .. Format.coins(total), 15, C.muted, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 20), ZIndex = 22, Parent = panel })
	local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, ch), ZIndex = 22, Parent = panel })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), Parent = row })
	local scale = math.min(1, (pw - 40) / math.max(1, n * (cw + 12)))
	for i, it in items do
		local c = auraCard(it.id, it.v, math.floor(cw * scale), math.floor(ch * scale))
		c.LayoutOrder = i
		setZ(c, 23)
		c.Parent = row
	end
	local sell = Ui.button(L("Sell for ", "Продать за ") .. Format.coins(total), "gold", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -8, 1, -20),
		Size = UDim2.fromOffset(200, 50),
		ZIndex = 22,
		Parent = panel,
	})
	local keep = Ui.button(L("Keep", "Забрать"), "green", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 8, 1, -20),
		Size = UDim2.fromOffset(200, 50),
		ZIndex = 22,
		Parent = panel,
	})
	local function close()
		overlay.Visible = false
		busy = false
		clearPanel()
		if renderers[currentTab] then
			renderers[currentTab]()
		end
	end
	keep.Activated:Connect(close)
	sell.Activated:Connect(function()
		local uids = {}
		for _, it in items do
			table.insert(uids, it.u)
		end
		local res = R.SellItems:InvokeServer(uids)
		if res and res.ok then
			state.balance = res.balance
			local gone = {}
			for _, u in uids do
				gone[u] = true
			end
			local keepInv = {}
			for _, it in state.inv do
				if not gone[it.u] then
					table.insert(keepInv, it)
				end
			end
			state.inv = keepInv
			renderBalance()
			toast(L("Sold for ", "Продано за ") .. Format.coins(res.total))
		end
		close()
	end)
end

local ERR = {
	no_money = { "Not enough coins", "Не хватает монет" },
	inv_full = { "Inventory is full — sell some auras", "Инвентарь полон — продай часть аур" },
	loading = { "Loading your progress…", "Загружаем прогресс…" },
}

openRift = function(rf)
	if busy then
		return
	end
	if state.balance < rf.price * openCount then
		toast(L("Not enough coins", "Не хватает монет"))
		return
	end
	busy = true
	local res = R.OpenRift:InvokeServer(rf.id, openCount)
	if not res or not res.ok then
		busy = false
		local e = res and ERR[res.err]
		if e then
			toast(L(e[1], e[2]))
		end
		return
	end
	state.balance = res.balance
	for i = #res.items, 1, -1 do
		table.insert(state.inv, 1, res.items[i])
	end
	renderBalance()
	-- прокрутка
	clearPanel()
	local n = #res.items
	local rowH = if n == 1 then 190 elseif n == 2 then 160 else 118
	local pw = math.min(W - 32, 900)
	local stripW = pw - 40
	panel.Size = UDim2.fromOffset(pw, 70 + n * (rowH + 10) + 10)
	Ui.label(L(rf.en, rf.ru), 22, rf.c1, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30), ZIndex = 22, Parent = panel })
	overlay.Visible = true
	local dur = 5.2
	for i, item in res.items do
		spinRow(rf.id, item, 60 + (i - 1) * (rowH + 10), rowH, stripW, dur + (i - 1) * 0.25)
	end
	task.wait(dur + (n - 1) * 0.25 + 0.9)
	showResult(res.items)
end

-- ===== инвентарь =====
local invPage = pages.inventory
local invHead = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = invPage })
local invTitle = Ui.label("", 18, C.text, { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -190, 1, 0), Parent = invHead })
local sellAllBtn = Ui.button(L("Sell all", "Продать всё"), "red", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(180, 40), TextSize = 14, Parent = invHead })
local invScroll = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(1, 0, 1, -52),
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.violet,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = invPage,
})
new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 240), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = invScroll })

local renderInventory: () -> ()
local sellArmed = false

local function sellOne(it)
	local res = R.SellItems:InvokeServer({ it.u })
	if res and res.ok then
		state.balance = res.balance
		for i, x in state.inv do
			if x.u == it.u then
				table.remove(state.inv, i)
				break
			end
		end
		renderBalance()
		renderInventory()
	end
end

renderInventory = function()
	for _, ch in invScroll:GetChildren() do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	local total = 0
	for _, it in state.inv do
		total += it.v
	end
	invTitle.Text = L("Inventory", "Инвентарь") .. " · " .. #state.inv .. " · " .. Format.coins(total)
	sellAllBtn.Visible = #state.inv > 0
	sellAllBtn.Text = if sellArmed then L("Sure? Tap again", "Точно? Нажми ещё") else L("Sell all", "Продать всё") .. " · " .. Format.coins(total)
	if #state.inv == 0 then
		Ui.label(L("Inventory is empty — open a rift.", "Инвентарь пуст — открой разлом."), 16, C.muted, { Size = UDim2.fromOffset(400, 60), Parent = invScroll })
		return
	end
	local sorted = table.clone(state.inv)
	table.sort(sorted, function(a, b)
		return a.v > b.v
	end)
	for i, it in sorted do
		local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = invScroll })
		local card = auraCard(it.id, it.v, 150, 190)
		card.Parent = cell
		local b = Ui.button(L("Sell", "Продать"), "gold", { Position = UDim2.fromOffset(0, 196), Size = UDim2.fromOffset(150, 40), TextSize = 14, Parent = cell })
		b.Activated:Connect(function()
			sellOne(it)
		end)
	end
end
renderers.inventory = renderInventory

sellAllBtn.Activated:Connect(function()
	if not sellArmed then
		sellArmed = true
		renderInventory()
		task.delay(3, function()
			if sellArmed then
				sellArmed = false
				if currentTab == "inventory" then
					renderInventory()
				end
			end
		end)
		return
	end
	sellArmed = false
	local res = R.SellAll:InvokeServer()
	if res and res.ok then
		state.balance = res.balance
		state.inv = {}
		renderBalance()
		toast(L("Sold everything for ", "Продано всё за ") .. Format.coins(res.total))
	end
	renderInventory()
end)

-- ===== кликер =====
local clkPage = pages.clicker
Ui.label(L("Aura Clicker", "Аура Кликер"), 26, C.text, { Font = Enum.Font.GothamBlack, Size = UDim2.new(1, 0, 0, 34), Parent = clkPage })
Ui.label(L("Tap and get coins on your balance — +150 for every tap!", "Тапай и получай монеты на баланс — +150 за каждый тап!"), 15, C.muted, { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 20), Parent = clkPage })
local clkStage = new("Frame", { BackgroundColor3 = Color3.fromRGB(12, 10, 40), Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), ClipsDescendants = true, Parent = clkPage }, {
	Ui.corner(20),
	Ui.stroke(C.gold, 2, 0.5),
})
local tapBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(260, 260),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "TAP",
	TextSize = 44,
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = false,
	Parent = clkStage,
}, {
	Ui.corner(UDim.new(1, 0)),
	Ui.grad(Color3.fromRGB(127, 251, 230), Color3.fromRGB(109, 60, 255), 60),
	Ui.stroke(C.gold, 4, 0.2),
	Ui.textStroke(Color3.fromRGB(40, 20, 80), 2, 0.3),
})
local tapScale = new("UIScale", { Parent = tapBtn })
if Config.CLICKER_IMAGE and Config.CLICKER_IMAGE ~= "" then
	tapBtn.Text = ""
	tapBtn.BackgroundTransparency = 1
	new("ImageLabel", { BackgroundTransparency = 1, Image = Config.CLICKER_IMAGE, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, Parent = tapBtn })
end

local lastTap = 0
tapBtn.Activated:Connect(function()
	local now = os.clock()
	if now - lastTap < 1 / Config.CLICK_MAX_PER_SEC then
		return
	end
	lastTap = now
	R.Tap:FireServer()
	state.balance += Config.CLICK_GAIN -- сразу показываем, сервер пришлёт точное значение
	renderBalance()
	-- «+150» улетает вверх и тает
	local pop = Ui.label("+" .. Config.CLICK_GAIN, 30, C.gold, {
		Font = Enum.Font.GothamBlack,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.random(-70, 70), 0.5, math.random(-90, -30)),
		Size = UDim2.fromOffset(140, 40),
		ZIndex = 5,
		Parent = clkStage,
	})
	Ui.textStroke(Color3.fromRGB(90, 40, 0), 2, 0.2).Parent = pop
	local up = pop.Position - UDim2.fromOffset(0, 100)
	TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = up, TextTransparency = 1 }):Play()
	task.delay(1.15, function()
		pop:Destroy()
	end)
	tapScale.Scale = 0.93
	TweenService:Create(tapScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end)

-- ===== «скоро» =====
for _, t in TABS do
	if t.soon then
		Ui.label(L("Coming soon", "Скоро"), 28, C.muted, { Font = Enum.Font.GothamBlack, Size = UDim2.fromScale(1, 1), Parent = pages[t.key] })
	end
end

-- ===== масштаб под экран =====
local function relayout()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local s = math.clamp(math.min(vp.X / 1040, vp.Y / 720), 0.5, 1.3)
	uiScale.Scale = s
	W, H = vp.X / s, vp.Y / s
	root.Size = UDim2.fromOffset(W, H)
end
relayout()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(relayout)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)
end

-- ===== загрузка состояния =====
R.StateChanged.OnClientEvent:Connect(function(s)
	if s and s.balance then
		state.balance = s.balance
		renderBalance()
		if currentTab == "rifts" and not busy then
			renderRifts()
		end
	end
end)

setTab("rifts")
task.spawn(function()
	local s = R.GetState:InvokeServer()
	if s then
		state.balance = s.balance
		state.inv = s.inv
		renderBalance()
		if renderers[currentTab] then
			renderers[currentTab]()
		end
	end
end)
