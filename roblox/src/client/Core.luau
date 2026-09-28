-- Общее для всех экранов клиента: состояние, сервер, язык, звуки, карточки аур, окна
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local C = Ui.C
local new = Ui.new

local Core = {}
Core.Config = Config
Core.Ui = Ui
Core.player = Players.LocalPlayer

-- ===== язык =====
Core.RU = false
pcall(function()
	Core.RU = string.sub(LocalizationService.RobloxLocaleId, 1, 2) == "ru"
end)
function Core.L(en: string, ru: string): string
	return if Core.RU then ru else en
end
local L = Core.L

-- ===== сервер =====
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
Core.R = setmetatable({}, {
	__index = function(t, name)
		local r = Remotes:WaitForChild(name)
		rawset(t, name, r)
		return r
	end,
}) :: any

-- ===== состояние =====
Core.state = {
	balance = 0,
	inv = {} :: { { u: number, id: string, v: number } },
	collected = {} :: { [string]: boolean },
	lastWheel = 0,
	luckUntil = 0,
	speedUntil = 0,
	tickets = {} :: { [string]: number },
	stats = {} :: { [string]: number },
	infinite = false,
}
Core.busy = false
local timeOffset = 0
function Core.now(): number
	return os.time() + timeOffset
end

local listeners: { () -> () } = {}
function Core.onChange(fn: () -> ())
	table.insert(listeners, fn)
end
function Core.changed()
	for _, fn in listeners do
		task.spawn(fn)
	end
end
function Core.apply(s)
	if not s then
		return
	end
	for k, v in s do
		if k == "now" then
			timeOffset = v - os.time()
		else
			(Core.state :: any)[k] = v
		end
	end
	Core.changed()
end

function Core.fmt(n: number): string
	return Format.coins(n)
end
function Core.balanceText(): string
	return if Core.state.infinite then "∞" else Format.coins(Core.state.balance)
end

-- ===== звуки =====
local soundCache: { [string]: Sound } = {}
Core.soundOn = true
function Core.sound(name: string, volume: number?)
	if not Core.soundOn then
		return
	end
	local id = Config.SOUNDS[name]
	if not id or id == "" then
		return
	end
	local s = soundCache[name]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = id
		s.Parent = SoundService
		soundCache[name] = s
	end
	s.Volume = volume or 0.5
	SoundService:PlayLocalSound(s)
end

-- ===== ауры =====
function Core.tierOf(id: string)
	local a = Config.AURA_BY_ID[id]
	return Config.TIERS[Config.TIER_INDEX[a.tier]]
end

-- сфера ауры: картинка, если загружена, иначе цветной шар по цветам ауры
function Core.auraOrb(id: string, size: number): GuiObject
	local a = Config.AURA_BY_ID[id]
	if a.image ~= "" then
		return new("ImageLabel", { BackgroundTransparency = 1, Image = a.image, Size = UDim2.fromOffset(size, size), ScaleType = Enum.ScaleType.Fit })
	end
	local c1 = a.colors[1]
	local c2 = a.colors[2] or c1
	local orb = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1) }, {
		Ui.corner(UDim.new(1, 0)),
		Ui.grad(c1, c2, 45),
		Ui.stroke(Core.tierOf(id).color, 2, 0.2),
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

-- карточка ауры; opts.button — сделать карточку кнопкой, opts.selected — подсветка выбора
function Core.auraCard(id: string, value: number?, w: number, h: number, opts: { [string]: any }?): GuiObject
	local o: { [string]: any } = opts or {}
	local a = Config.AURA_BY_ID[id]
	local tier = Core.tierOf(id)
	local card = new(if o.button then "TextButton" else "Frame", {
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.fromRGB(14, 11, 44),
	}, {
		Ui.corner(12),
		Ui.stroke(if o.selected then C.cyan else tier.color, if o.selected then 3 else 2, if o.selected then 0 else 0.25),
		new("UIGradient", {
			Color = ColorSequence.new(tier.color:Lerp(Color3.fromRGB(14, 11, 44), 0.7), Color3.fromRGB(14, 11, 44)),
			Rotation = 90,
		}),
	})
	if o.button then
		(card :: TextButton).Text = ""
		;(card :: TextButton).AutoButtonColor = true
	end
	local small = h < 130
	local orbSize = math.floor(math.min(w * 0.62, h * (if small then 0.42 else 0.48)))
	local orb = Core.auraOrb(id, orbSize)
	orb.AnchorPoint = Vector2.new(0.5, 0)
	orb.Position = UDim2.new(0.5, 0, 0, if small then 6 else 8)
	orb.Parent = card
	local y = orbSize + (if small then 8 else 12)
	Ui.label(string.upper(a.en), if small then 11 else 13, C.text, {
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(4, y),
		Size = UDim2.new(1, -8, 0, 15),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	if not small then
		Ui.label(L(tier.en, tier.ru), 11, tier.color, { Position = UDim2.fromOffset(4, y + 17), Size = UDim2.new(1, -8, 0, 14), Parent = card })
		y += 16
	end
	Ui.label(Format.coins(value or a.price), if small then 11 else 13, C.text, { Font = Enum.Font.Code, Position = UDim2.fromOffset(4, y + 17), Size = UDim2.new(1, -8, 0, 15), Parent = card })
	if o.selected then
		Ui.label("✓", 16, C.cyan, { Font = Enum.Font.GothamBlack, Position = UDim2.new(1, -24, 0, 4), Size = UDim2.fromOffset(20, 20), Parent = card })
	end
	return card
end

-- ===== всплывающие уведомления и окна (создаются в Main) =====
Core.root = nil :: Frame?
Core.W = 1000
Core.H = 700
local toastLabel: TextLabel? = nil
local toastId = 0
function Core.toast(text: string)
	if not toastLabel then
		toastLabel = Ui.label("", 16, C.text, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 40),
			BackgroundColor3 = C.panel2,
			BackgroundTransparency = 0,
			TextWrapped = false,
			Visible = false,
			ZIndex = 100,
			Parent = Core.root,
		})
		Ui.corner(20).Parent = toastLabel
		Ui.pad(0, 18).Parent = toastLabel
		Ui.stroke(C.violet, 1.5, 0.3).Parent = toastLabel
	end
	local t = toastLabel :: TextLabel
	toastId += 1
	local id = toastId
	t.Text = text
	t.Visible = true
	task.delay(2.4, function()
		if id == toastId then
			t.Visible = false
		end
	end)
end

-- модальное окно поверх всего экрана
local overlay: Frame? = nil
local panel: Frame? = nil
function Core.openPanel(w: number, h: number): Frame
	if not overlay then
		overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, ZIndex = 60, Active = true, Parent = Core.root })
		panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.bg2, ZIndex = 61, Parent = overlay }, {
			Ui.corner(20),
			Ui.stroke(C.violet, 2, 0.3),
		})
	end
	local p = panel :: Frame
	for _, ch in p:GetChildren() do
		if not ch:IsA("UICorner") and not ch:IsA("UIStroke") then
			ch:Destroy()
		end
	end
	p.Size = UDim2.fromOffset(math.min(w, Core.W - 24), math.min(h, Core.H - 24))
	;(overlay :: Frame).Visible = true
	return p
end
function Core.closePanel()
	if overlay then
		overlay.Visible = false
	end
end

-- все элементы внутри окна должны быть выше затемнения
function Core.lift(inst: Instance, z: number?)
	local zz = z or 62
	if inst:IsA("GuiObject") then
		inst.ZIndex = zz
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = zz
		end
	end
end

-- окно результата: заголовок, карточки, кнопки «Продать» / «Забрать»
function Core.showPrize(titleText: string, titleColor: Color3, items, subText: string?, onClose: (() -> ())?)
	local n = #items
	local cw, ch = 150, 200
	local pw = math.max(440, math.min(Core.W - 24, n * (cw + 12) + 40))
	local p = Core.openPanel(pw, ch + 210)
	pw = p.Size.X.Offset
	local total = 0
	for _, it in items do
		total += it.v
	end
	Ui.label(titleText, 24, titleColor, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30), Parent = p })
	Ui.label(subText or (L("Total: ", "Всего: ") .. Format.coins(total)), 15, C.muted, { Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 34), Parent = p })
	local row = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 90),
		Size = UDim2.new(1, -24, 0, ch + 10),
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = p,
	})
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), Parent = row })
	table.sort(items, function(a, b)
		return a.v > b.v
	end)
	for i, it in items do
		local c = Core.auraCard(it.id, it.v, cw, ch)
		c.LayoutOrder = i
		c.Parent = row
	end
	local function close()
		Core.closePanel()
		Core.busy = false
		Core.changed()
		if onClose then
			onClose()
		end
	end
	if n > 0 then
		local sell = Ui.button(L("Sell for ", "Продать за ") .. Format.coins(total), "gold", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -8, 1, -18), Size = UDim2.fromOffset(math.min(210, pw / 2 - 20), 50), Parent = p })
		sell.Activated:Connect(function()
			local uids = {}
			for _, it in items do
				table.insert(uids, it.u)
			end
			local res = Core.R.SellItems:InvokeServer(uids)
			if res and res.ok then
				Core.toast(L("Sold for ", "Продано за ") .. Format.coins(res.total))
				Core.sound("coin")
			end
			close()
		end)
	end
	local keep = Ui.button(if n > 0 then L("Keep", "Забрать") else L("OK", "Ок"), "green", {
		AnchorPoint = Vector2.new(if n > 0 then 0 else 0.5, 1),
		Position = UDim2.new(0.5, if n > 0 then 8 else 0, 1, -18),
		Size = UDim2.fromOffset(math.min(210, pw / 2 - 20), 50),
		Parent = p,
	})
	keep.Activated:Connect(close)
	Core.lift(p)
end

-- выбор ауры из инвентаря (сетка карточек-кнопок), используется в апгрейде и контракте
function Core.fillInvGrid(scroll: ScrollingFrame, list, isSelected: (number) -> boolean, onPick: (any) -> (), cw: number?, ch: number?)
	for _, c in scroll:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if #list == 0 then
		Ui.label(L("No auras yet — open a rift.", "Аур пока нет — открой разлом."), 14, C.muted, { Size = UDim2.fromOffset(260, 40), Parent = scroll })
		return
	end
	for i, it in list do
		local card = Core.auraCard(it.id, it.v, cw or 110, ch or 120, { button = true, selected = isSelected(it.u) })
		card.LayoutOrder = i
		card.Parent = scroll
		;(card :: TextButton).Activated:Connect(function()
			onPick(it)
		end)
	end
end

return Core
