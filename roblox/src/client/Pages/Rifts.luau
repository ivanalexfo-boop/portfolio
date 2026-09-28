-- Разломы: сетка кейсов, открытие до 5 за раз, горизонтальная рулетка
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

return function(page: Frame, Core)
	local Config, Ui, L = Core.Config, Core.Ui, Core.L
	local C, new = Ui.C, Ui.new
	local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)
	local state = Core.state
	local openCount = 1

	local countBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = page })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = countBar })
	Ui.label(L("Open at once:", "Открыть сразу:"), 15, C.muted, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36), TextWrapped = false, LayoutOrder = 0, Parent = countBar })
	local countButtons: { [number]: TextButton } = {}
	local render: () -> ()
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
			render()
		end)
	end

	local scroll = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.violet,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = page,
	})
	new("UIGridLayout", { CellSize = UDim2.fromOffset(180, 262), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

	local openButtons: { [string]: TextButton } = {}
	local ticketButtons: { [string]: TextButton } = {}
	local open: (rf: any, byTicket: boolean) -> ()

	for i, rf in Config.RIFTS do
		local card = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, Parent = scroll }, {
			Ui.corner(16),
			Ui.stroke(rf.c1, 2, 0.4),
			Ui.grad(rf.c2:Lerp(Color3.fromRGB(12, 10, 40), 0.55), Color3.fromRGB(12, 10, 40), 90),
		})
		local art = Core.riftArt(rf, 120)
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.new(0.5, 0, 0, 10)
		art.Parent = card
		Ui.label(L(rf.en, rf.ru), 16, C.text, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(6, 136), Size = UDim2.new(1, -12, 0, 22), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		Ui.label(L(rf.ru, rf.en), 12, rf.c1, { Position = UDim2.fromOffset(6, 158), Size = UDim2.new(1, -12, 0, 16), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		local b = Ui.button("", rf.button, { Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -24, 0, 50), Parent = card })
		openButtons[rf.id] = b
		b.Activated:Connect(function()
			open(rf, false)
		end)
		local tb = Ui.button("", "purple", { Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(1, -24, 0, 28), TextSize = 13, Visible = false, Parent = card })
		ticketButtons[rf.id] = tb
		tb.Activated:Connect(function()
			open(rf, true)
		end)
	end

	render = function()
		for n, b in countButtons do
			b.BackgroundColor3 = if n == openCount then C.violet else C.panel
		end
		for _, rf in Config.RIFTS do
			local cost = rf.price * openCount
			local b = openButtons[rf.id]
			b.Text = L("OPEN", "ОТКРЫТЬ") .. "\n" .. Core.fmt(cost)
			b.TextTransparency = if state.balance >= cost then 0 else 0.45
			local t = state.tickets[rf.id] or 0
			ticketButtons[rf.id].Visible = t > 0
			ticketButtons[rf.id].Text = "🎟 " .. L("Free open", "Бесплатно") .. " ×" .. t
		end
	end

	-- ===== прокрутка =====
	local CW, GAP, WIN_AT = 120, 8, 48
	local function spinRow(p: Frame, riftId: string, item, y: number, rowH: number, stripW: number, dur: number, withTicks: boolean)
		local strip = new("Frame", { Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(stripW, rowH), BackgroundColor3 = Color3.fromRGB(11, 8, 38), ClipsDescendants = true, Parent = p }, {
			Ui.corner(14),
			Ui.stroke(C.line, 1.5, 0),
		})
		local track = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset((CW + GAP) * (WIN_AT + 6), rowH - 16), Parent = strip })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = track })
		local ids = Economy.strip(riftId, WIN_AT + 5, WIN_AT, item.id, function()
			return math.random()
		end)
		local cards = {}
		for i, id in ids do
			local c = Core.auraCard(id, nil, CW, rowH - 16)
			c.LayoutOrder = i
			c.Parent = track
			cards[i] = c
		end
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Parent = strip }, {
			Ui.grad(C.cyan, C.pink, 90),
		})
		Core.lift(strip)
		local cardStart = (WIN_AT - 1) * (CW + GAP)
		local target = -(cardStart + 14 + math.random() * (CW - 28)) + stripW / 2
		local centered = -(cardStart + CW / 2) + stripW / 2
		TweenService:Create(track, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(target, 8) }):Play()
		if withTicks then -- щелчок на каждой карточке, пересёкшей центр
			local last = -1
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local idx = math.floor((stripW / 2 - track.Position.X.Offset) / (CW + GAP))
				if idx ~= last then
					last = idx
					Core.sound("tick", 0.25)
				end
			end)
			task.delay(dur, function()
				conn:Disconnect()
			end)
		end
		task.delay(dur + 0.05, function()
			TweenService:Create(track, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = UDim2.fromOffset(centered, 8) }):Play()
			local s = cards[WIN_AT]:FindFirstChildOfClass("UIStroke")
			if s then
				s.Thickness = 4
				s.Transparency = 0
			end
		end)
	end

	local ERR = {
		no_money = { "Not enough coins", "Не хватает монет" },
		inv_full = { "Inventory is full — sell some auras", "Инвентарь полон — продай часть аур" },
		loading = { "Loading your progress…", "Загружаем прогресс…" },
		no_ticket = { "No tickets", "Нет билетов" },
	}

	open = function(rf, byTicket)
		if Core.busy then
			return
		end
		local n = if byTicket then 1 else openCount
		if not byTicket and state.balance < rf.price * n then
			Core.toast(L("Not enough coins", "Не хватает монет"))
			return
		end
		Core.busy = true
		local res = Core.R.OpenRift:InvokeServer(rf.id, n, byTicket)
		if not res or not res.ok then
			Core.busy = false
			local e = res and ERR[res.err]
			if e then
				Core.toast(L(e[1], e[2]))
			end
			return
		end
		Core.sound("open")
		local rowH = if n == 1 then 190 elseif n == 2 then 160 else 118
		local p = Core.openPanel(900, 70 + n * (rowH + 10) + 10)
		local stripW = p.Size.X.Offset - 40
		Ui.label(L(rf.en, rf.ru), 22, rf.c1, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30), ZIndex = 62, Parent = p })
		local dur = 5.2
		for i, item in res.items do
			spinRow(p, rf.id, item, 60 + (i - 1) * (rowH + 10), rowH, stripW, dur + (i - 1) * 0.25, i == 1)
		end
		task.wait(dur + (n - 1) * 0.25 + 0.9)
		local best = res.items[1]
		for _, it in res.items do
			if it.v > best.v then
				best = it
			end
		end
		local good = best.v >= rf.price
		Core.sound(if good then "win" else "lose")
		Core.showPrize(if n > 1 then L("Your drop", "Твой дроп") else L("You got", "Тебе выпало"), Core.tierOf(best.id).color, res.items)
	end

	return render
end
