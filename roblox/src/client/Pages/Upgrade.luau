-- Апгрейд: до 8 своих аур → одна дороже. Шанс = (сумма + буст) / цена цели, максимум 80%.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

return function(page: Frame, Core)
	local Config, Ui, L = Core.Config, Core.Ui, Core.L
	local C, new = Ui.C, Ui.new
	local state = Core.state
	local MAX = Config.UPGRADE_MAX_CHANCE

	local sel: { [number]: boolean } = {}
	local targetId: string? = nil
	local boostPart = 0 -- 0, 0.25, 0.5, 1 — доля от максимального буста
	local pick = { p = 0.5 } :: { p: number?, m: number? }

	local function selected()
		local list, v = {}, 0
		for _, it in state.inv do
			if sel[it.u] then
				table.insert(list, it)
				v += it.v
			end
		end
		return list, v
	end
	local function maxBoost(v: number): number
		if not targetId then
			return 0
		end
		return math.max(0, math.min(state.balance, math.floor(MAX * Config.AURA_BY_ID[targetId].price - v)))
	end
	local function boostValue(v: number): number
		return math.floor(maxBoost(v) * boostPart)
	end
	local function chanceFor(v: number, boost: number): number
		if not targetId or v <= 0 then
			return 0
		end
		return math.min(MAX, (v + boost) / Config.AURA_BY_ID[targetId].price)
	end
	local function targets(v: number)
		local list = {}
		for _, a in Config.AURAS do
			if a.tier ~= "unique" and a.price > v then
				table.insert(list, a)
			end
		end
		table.sort(list, function(a, b)
			return a.price < b.price
		end)
		return list
	end
	-- цель подбирается под выбранный шанс или икс
	local function autoTarget()
		local _, v = selected()
		if v <= 0 then
			targetId = nil
			return
		end
		local list = targets(v)
		if #list == 0 then
			targetId = nil
			Core.toast(L("Nothing pricier to upgrade into", "Дороже ничего нет"))
			return
		end
		local best, bd = nil, math.huge
		for _, a in list do
			local d = if pick.p then math.abs(v / a.price - pick.p) else math.abs(math.log(a.price / (v * (pick.m :: number))))
			if d < bd then
				best, bd = a, d
			end
		end
		targetId = best.id
	end

	-- ===== верх: ставка — круг — цель =====
	local top = new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 12, 52), Size = UDim2.new(1, 0, 0, 270), Parent = page }, {
		Ui.corner(18),
		Ui.stroke(C.violet, 2, 0.5),
	})
	local srcBox = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0.5, -150, 1, -28), Parent = top })
	local dstBox = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0.5, -150, 1, -28), Parent = top })

	local DIAL = 240
	local dial = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(DIAL, DIAL), BackgroundColor3 = Color3.fromRGB(10, 8, 34), Parent = top }, {
		Ui.corner(UDim.new(1, 0)),
		Ui.stroke(C.cyan, 3, 0.2),
	})
	local SEG = 60
	local segs = {}
	for i = 0, SEG - 1 do
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = (i + 0.5) * 360 / SEG, Parent = dial })
		segs[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(9, 22), BorderSizePixel = 0, BackgroundColor3 = C.lose, Parent = holder }, { Ui.corner(3) })
	end
	local core = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(DIAL - 90, DIAL - 90), BackgroundColor3 = Color3.new(1, 1, 1), Parent = dial }, {
		Ui.corner(UDim.new(1, 0)),
		Ui.grad(Color3.fromRGB(58, 42, 154), Color3.fromRGB(10, 8, 40), 90),
	})
	local chanceLabel = Ui.label("0%", 34, C.win, { Font = Enum.Font.GothamBlack, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(150, 40), Parent = core })
	local multLabel = Ui.label("", 14, Color3.fromRGB(191, 233, 255), { Font = Enum.Font.Code, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromOffset(150, 20), Parent = core })
	local needle = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = dial })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(14, 38), BackgroundColor3 = Color3.new(1, 1, 1), Parent = needle }, {
		Ui.corner(7),
		Ui.stroke(Color3.fromRGB(26, 15, 58), 2, 0),
		Ui.grad(Color3.new(1, 1, 1), C.gold, 90),
	})

	-- ===== кнопки выбора цели и буста =====
	local controls = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 280), Size = UDim2.new(1, 0, 0, 40), Parent = page })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = controls })
	local pickButtons = {}
	local renderAll: () -> ()
	for i, opt in { { p = 0.75 }, { p = 0.5 }, { p = 0.25 }, { p = 0.1 }, { m = 2 }, { m = 5 }, { m = 10 } } do
		local b = new("TextButton", {
			Text = if opt.p then math.floor(opt.p * 100) .. "%" else "x" .. opt.m,
			TextSize = 14,
			Font = Enum.Font.Code,
			TextColor3 = C.text,
			Size = UDim2.fromOffset(56, 36),
			BackgroundColor3 = C.panel,
			LayoutOrder = i,
			Parent = controls,
		}, { Ui.corner(10), Ui.stroke(C.violet, 1.5, 0.5) })
		table.insert(pickButtons, { b = b, opt = opt })
		b.Activated:Connect(function()
			if Core.busy then
				return
			end
			if next(sel) == nil then
				Core.toast(L("Pick your auras first", "Сначала выбери свои ауры"))
				return
			end
			pick = opt
			boostPart = 0
			autoTarget()
			renderAll()
		end)
	end
	Ui.label("  ⚡ " .. L("Boost", "Буст"), 14, C.muted, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36), TextWrapped = false, LayoutOrder = 20, Parent = controls })
	local boostButtons = {}
	for i, part in { 0, 0.25, 0.5, 1 } do
		local b = new("TextButton", {
			Text = if part == 0 then L("off", "нет") elseif part == 1 then "MAX" else "+" .. math.floor(part * 100) .. "%",
			TextSize = 13,
			Font = Enum.Font.Code,
			TextColor3 = C.text,
			Size = UDim2.fromOffset(52, 36),
			BackgroundColor3 = C.panel,
			LayoutOrder = 20 + i,
			Parent = controls,
		}, { Ui.corner(10), Ui.stroke(C.win, 1.5, 0.5) })
		table.insert(boostButtons, { b = b, part = part })
		b.Activated:Connect(function()
			if Core.busy then
				return
			end
			boostPart = part
			renderAll()
		end)
	end
	local go = Ui.button(L("Upgrade", "Апгрейд"), "green", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 280), Size = UDim2.fromOffset(200, 42), Parent = page })

	-- ===== нижние списки =====
	local function column(x: number, titleText: string)
		local f = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 330), Size = UDim2.new(0.5, -6, 1, -330), Parent = page })
		local t = Ui.label(titleText, 15, C.text, { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), Parent = f })
		local s = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 1, -26),
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = C.violet,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = f,
		})
		new("UIGridLayout", { CellSize = UDim2.fromOffset(110, 120), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = s })
		return s, t
	end
	local invScroll, invTitle = column(0, L("Your auras (up to 8)", "Твои ауры (до 8)"))
	local tgtScroll = column(0.5, L("What you want", "Что хочешь получить"))

	local function renderTop()
		local list, v = selected()
		for _, c in srcBox:GetChildren() do
			c:Destroy()
		end
		for _, c in dstBox:GetChildren() do
			c:Destroy()
		end
		Ui.label(L("YOUR AURAS", "ТВОИ АУРЫ"), 11, C.muted, { Size = UDim2.new(1, 0, 0, 14), Parent = srcBox })
		if #list == 0 then
			Ui.label(L("Pick auras below", "Выбери ауры ниже"), 14, C.muted, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -20), Parent = srcBox })
		elseif #list == 1 then
			local c = Core.auraCard(list[1].id, list[1].v, 150, 210)
			c.AnchorPoint = Vector2.new(0.5, 0)
			c.Position = UDim2.new(0.5, 0, 0, 20)
			c.Parent = srcBox
		else
			local g = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -50), Parent = srcBox })
			new("UIGridLayout", { CellSize = UDim2.fromOffset(70, 80), CellPadding = UDim2.fromOffset(4, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = g })
			for _, it in list do
				Core.auraCard(it.id, it.v, 70, 80).Parent = g
			end
			Ui.label(#list .. L(" auras · ", " аур · ") .. Core.fmt(v), 14, C.win, { Font = Enum.Font.Code, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 24), Parent = srcBox })
		end
		Ui.label(L("TARGET", "ЦЕЛЬ"), 11, C.muted, { Size = UDim2.new(1, 0, 0, 14), Parent = dstBox })
		if targetId then
			local c = Core.auraCard(targetId, nil, 150, 210)
			c.AnchorPoint = Vector2.new(0.5, 0)
			c.Position = UDim2.new(0.5, 0, 0, 20)
			c.Parent = dstBox
		else
			Ui.label(L("Pick the aura you want", "Выбери ауру, которую хочешь"), 14, C.muted, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -20), Parent = dstBox })
		end
		local boost = boostValue(v)
		local ch = chanceFor(v, boost)
		chanceLabel.Text = if ch > 0 and ch < 0.1 then string.format("%.2f%%", ch * 100) else string.format("%.1f%%", ch * 100):gsub("%.0%%", "%%")
		multLabel.Text = if targetId and v > 0 then "x" .. string.format("%.2f", Config.AURA_BY_ID[targetId].price / v):gsub("%.?0+$", "") else ""
		for i = 0, SEG - 1 do
			segs[i].BackgroundColor3 = if (i + 0.5) / SEG < ch then C.win else Color3.fromRGB(120, 30, 55)
		end
		go.Text = if boost > 0 then L("Upgrade · boost ", "Апгрейд · буст ") .. Core.fmt(boost) else L("Upgrade", "Апгрейд")
		go.TextTransparency = if ch > 0 then 0 else 0.5
		for _, x in pickButtons do
			local on = (x.opt.p ~= nil and x.opt.p == pick.p) or (x.opt.m ~= nil and x.opt.m == pick.m)
			x.b.BackgroundColor3 = if on then C.violet else C.panel
		end
		for _, x in boostButtons do
			x.b.BackgroundColor3 = if x.part == boostPart then Color3.fromRGB(31, 154, 58) else C.panel
		end
	end

	local function renderLists()
		local list, v = selected()
		local inv = table.clone(state.inv)
		table.sort(inv, function(a, b)
			return a.v > b.v
		end)
		invTitle.Text = L("Your auras", "Твои ауры") .. " · " .. #list .. " / " .. Config.UPGRADE_MAX_ITEMS
		Core.fillInvGrid(invScroll, inv, function(u)
			return sel[u] == true
		end, function(it)
			if Core.busy then
				return
			end
			if sel[it.u] then
				sel[it.u] = nil
			elseif #list >= Config.UPGRADE_MAX_ITEMS then
				Core.toast(L("Up to 8 auras at once", "Не больше 8 аур за раз"))
				return
			else
				sel[it.u] = true
			end
			boostPart = 0
			autoTarget()
			renderAll()
		end)
		for _, c in tgtScroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, a in targets(v) do
			local card = Core.auraCard(a.id, nil, 110, 120, { button = true, selected = a.id == targetId })
			card.LayoutOrder = i
			if v > 0 then
				Ui.label(math.floor(math.min(MAX, v / a.price) * 100 + 0.5) .. "%", 11, C.win, { Font = Enum.Font.Code, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(40, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			end
			card.Parent = tgtScroll
			;(card :: TextButton).Activated:Connect(function()
				if Core.busy then
					return
				end
				targetId = a.id
				pick = {}
				boostPart = 0
				renderAll()
			end)
		end
	end

	renderAll = function()
		-- убираем из выбора то, чего уже нет
		local exists = {}
		for _, it in state.inv do
			exists[it.u] = true
		end
		for u in sel do
			if not exists[u] then
				sel[u] = nil
			end
		end
		local _, v = selected()
		if targetId and Config.AURA_BY_ID[targetId].price <= v then
			targetId = nil
		end
		renderTop()
		renderLists()
	end

	local angle = 0
	go.Activated:Connect(function()
		if Core.busy then
			return
		end
		local list, v = selected()
		if #list == 0 or not targetId then
			Core.toast(L("Pick your auras and a target", "Выбери свои ауры и цель"))
			return
		end
		local uids = {}
		for _, it in list do
			table.insert(uids, it.u)
		end
		Core.busy = true
		local res = Core.R.Upgrade:InvokeServer(uids, targetId, boostValue(v))
		if not res or not res.ok then
			Core.busy = false
			Core.toast(L("Something changed — try again", "Что-то изменилось — попробуй ещё раз"))
			renderAll()
			return
		end
		-- стрелка останавливается на r*360° — зелёный сектор это [0, шанс)
		local target = angle - (angle % 360) + 360 * 6 + res.r * 360
		angle = target
		local last = math.floor(needle.Rotation / 18)
		local conn = RunService.RenderStepped:Connect(function()
			local k = math.floor(needle.Rotation / 18)
			if k ~= last then
				last = k
				Core.sound("tick", 0.2)
			end
		end)
		TweenService:Create(needle, TweenInfo.new(6.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = target }):Play()
		task.wait(6.3)
		conn:Disconnect()
		table.clear(sel)
		targetId = nil
		boostPart = 0
		if res.win then
			Core.sound("win")
			Core.showPrize(L("Upgrade successful!", "Апгрейд удался!"), C.win, { res.item })
		else
			Core.sound("lose")
			Core.showPrize(L("Missed", "Мимо"), C.lose, {}, L("The auras burned. Chance was ", "Ауры сгорели. Шанс был ") .. string.format("%.1f%%", res.chance * 100))
		end
	end)

	return function()
		if not Core.busy then
			renderAll()
		end
	end
end
