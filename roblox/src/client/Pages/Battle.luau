-- Битва аур 1 на 1 с ботом: одинаковые разломы, у кого дроп дороже — забирает всё
local TweenService = game:GetService("TweenService")

return function(page: Frame, Core)
	local Config, Ui, L = Core.Config, Core.Ui, Core.L
	local C, new = Ui.C, Ui.new
	local state = Core.state
	local picked: { string } = {}
	local lobbies = {}

	local function cost(list: { string }): number
		local s = 0
		for _, id in list do
			s += Config.RIFT_BY_ID[id].price
		end
		return s
	end
	local function riftIcon(rf, size: number): Frame
		return new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1) }, {
			Ui.corner(8),
			Ui.grad(rf.c1, rf.c2, 45),
			Ui.stroke(rf.c1, 1.5, 0.2),
			Ui.label(string.sub(rf.en, 1, 1), math.floor(size * 0.5), Color3.new(1, 1, 1), { Font = Enum.Font.GothamBlack, Size = UDim2.fromScale(1, 1) }),
		})
	end
	local function newLobby()
		local cap = math.max(state.balance / 2, Config.RIFTS[1].price)
		local ok = {}
		for _, rf in Config.RIFTS do
			if rf.price <= cap then
				table.insert(ok, rf.id)
			end
		end
		local pool = { table.unpack(ok, math.max(1, #ok - 2)) }
		local rifts = {}
		for _ = 1, math.random(1, 4) do
			table.insert(rifts, pool[math.random(#pool)])
		end
		return { bot = Config.BOTS[math.random(#Config.BOTS)], rifts = rifts }
	end

	-- ===== лобби =====
	local left = new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 12, 52), Size = UDim2.new(0.5, -6, 1, 0), Parent = page }, { Ui.corner(16), Ui.stroke(C.violet, 2, 0.5), Ui.pad(12) })
	Ui.label(L("OPEN LOBBIES", "ОТКРЫТЫЕ ЗАЯВКИ"), 13, C.muted, { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), Parent = left })
	local lobbyList = new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = left })
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lobbyList })

	local right = new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 12, 52), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, -6, 1, 0), Parent = page }, { Ui.corner(16), Ui.stroke(C.pink, 2, 0.5), Ui.pad(12) })
	local createTitle = Ui.label("", 13, C.muted, { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), Parent = right })
	local slotRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 50), Parent = right })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = slotRow })
	local pickGrid = new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 1, -140), ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = right })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 96), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pickGrid })
	local createBtn = Ui.button("", "green", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 48), Parent = right })

	local render: () -> ()
	local runBattle: (rifts: { string }, bot: string?) -> ()

	for i, rf in Config.RIFTS do
		local b = new("TextButton", { Text = "", BackgroundColor3 = C.panel, LayoutOrder = i, Parent = pickGrid }, { Ui.corner(12), Ui.stroke(rf.c1, 1.5, 0.5) })
		local ic = riftIcon(rf, 44)
		ic.AnchorPoint = Vector2.new(0.5, 0)
		ic.Position = UDim2.new(0.5, 0, 0, 6)
		ic.Parent = b
		Ui.label(L(rf.en, rf.ru), 11, C.text, { Position = UDim2.fromOffset(2, 52), Size = UDim2.new(1, -4, 0, 14), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = b })
		Ui.label(Core.fmt(rf.price), 11, C.muted, { Font = Enum.Font.Code, Position = UDim2.fromOffset(2, 68), Size = UDim2.new(1, -4, 0, 14), Parent = b })
		b.Activated:Connect(function()
			if Core.busy or #picked >= Config.BATTLE_MAX_RIFTS then
				return
			end
			table.insert(picked, rf.id)
			render()
		end)
	end

	createBtn.Activated:Connect(function()
		if Core.busy or #picked == 0 then
			return
		end
		if state.balance < cost(picked) then
			Core.toast(L("Not enough coins", "Не хватает монет"))
			return
		end
		createBtn.Text = L("Finding an opponent…", "Ищем соперника…")
		Core.busy = true
		task.wait(1.5 + math.random() * 2)
		Core.busy = false
		runBattle(table.clone(picked), nil)
	end)

	render = function()
		if Core.busy then
			return
		end
		while #lobbies < 5 do
			table.insert(lobbies, newLobby())
		end
		for _, c in lobbyList:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, lb in lobbies do
			local c = cost(lb.rifts)
			local row = new("Frame", { BackgroundColor3 = C.panel, Size = UDim2.new(1, -6, 0, 70), LayoutOrder = i, Parent = lobbyList }, { Ui.corner(12), Ui.stroke(C.line, 1.5, 0) })
			Ui.label(lb.bot, 15, C.text, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -150, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local icons = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -150, 0, 30), Parent = row })
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = icons })
			for _, id in lb.rifts do
				riftIcon(Config.RIFT_BY_ID[id], 28).Parent = icons
			end
			Ui.label(Core.fmt(c), 14, C.gold, { Font = Enum.Font.Code, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(120, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
			local join = Ui.button(L("Join", "Войти"), "green", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(100, 32), TextSize = 14, Parent = row })
			join.TextTransparency = if state.balance >= c then 0 else 0.5
			join.Activated:Connect(function()
				if Core.busy then
					return
				end
				if state.balance < c then
					Core.toast(L("Not enough coins", "Не хватает монет"))
					return
				end
				table.remove(lobbies, table.find(lobbies, lb) :: number)
				runBattle(lb.rifts, lb.bot)
			end)
		end
		createTitle.Text = L("CREATE A LOBBY", "СОЗДАТЬ ЗАЯВКУ") .. "  " .. #picked .. " / " .. Config.BATTLE_MAX_RIFTS
		for _, c in slotRow:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i = 1, Config.BATTLE_MAX_RIFTS do
			local id = picked[i]
			if id then
				local b = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 46), LayoutOrder = i, Parent = slotRow })
				riftIcon(Config.RIFT_BY_ID[id], 46).Parent = b
				b.Activated:Connect(function()
					if not Core.busy then
						table.remove(picked, i)
						render()
					end
				end)
			else
				new("Frame", { BackgroundColor3 = C.panel, Size = UDim2.fromOffset(46, 46), LayoutOrder = i, Parent = slotRow }, { Ui.corner(10), Ui.stroke(C.line, 1.5, 0) })
			end
		end
		local c = cost(picked)
		createBtn.Text = if #picked == 0 then L("Pick rifts above", "Выбери разломы выше") elseif state.balance < c then L("Need ", "Не хватает ") .. Core.fmt(c - state.balance) else L("Create for ", "Создать за ") .. Core.fmt(c)
	end

	-- обновляем лобби время от времени
	task.spawn(function()
		while true do
			task.wait(9)
			if #lobbies > 0 and math.random() < 0.5 then
				table.remove(lobbies, 1)
			end
			if page.Visible then
				render()
			end
		end
	end)

	-- ===== арена =====
	runBattle = function(rifts, bot)
		if Core.busy then
			return
		end
		Core.busy = true
		local res = Core.R.Battle:InvokeServer(rifts, bot)
		if not res or not res.ok then
			Core.busy = false
			Core.toast(if res and res.err == "no_money" then L("Not enough coins", "Не хватает монет") else L("Try again", "Попробуй ещё раз"))
			return
		end
		picked = {}
		local p = Core.openPanel(900, 520)
		local roundLabel = Ui.label("", 20, C.text, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 26), Parent = p })
		Ui.label(L("Pool ", "Пул ") .. Core.fmt(res.cost * 2), 14, C.gold, { Font = Enum.Font.Code, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 18), Parent = p })
		local meter = new("Frame", { BackgroundColor3 = C.pink, Position = UDim2.fromOffset(20, 64), Size = UDim2.new(1, -40, 0, 10), Parent = p }, { Ui.corner(5) })
		local meterA = new("Frame", { BackgroundColor3 = C.cyan, Size = UDim2.fromScale(0.5, 1), Parent = meter }, { Ui.corner(5) })
		local function side(x: number, name: string, color: Color3)
			local f = new("Frame", { BackgroundColor3 = Color3.fromRGB(14, 11, 44), Position = UDim2.new(x, if x > 0 then 10 else 20, 0, 86), Size = UDim2.new(0.5, -30, 1, -106), Parent = p }, {
				Ui.corner(16),
				Ui.stroke(color, 2, 0.3),
			})
			Ui.label(name, 16, C.text, { Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -60, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
			local total = Ui.label("0", 20, color, { Font = Enum.Font.Code, Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -60, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
			local crown = Ui.label("👑", 28, C.gold, { Position = UDim2.new(1, -46, 0, 8), Size = UDim2.fromOffset(36, 36), Visible = false, Parent = f })
			local slot = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 170), Parent = f })
			local won = new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 238), Size = UDim2.new(1, -16, 1, -246), ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X, Parent = f })
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = won })
			return { frame = f, total = total, crown = crown, slot = slot, won = won }
		end
		local A = side(0, Core.player.DisplayName, C.cyan)
		local B = side(0.5, res.bot, C.pink)
		Core.lift(p)
		local tA, tB = 0, 0
		for r, R in res.rounds do
			local rf = Config.RIFT_BY_ID[R.rf]
			roundLabel.Text = if R.extra then L("⚡ Tie! Extra round", "⚡ Ничья! Доп. раунд") else L("Round ", "Раунд ") .. r .. " / " .. #rifts .. " · " .. L(rf.en, rf.ru)
			-- быстро мелькают ауры этого разлома, потом выпадение
			local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)
			local show = Economy.RIFT[R.rf].items
			for k = 1, 12 do
				for _, S in { A, B } do
					for _, c in S.slot:GetChildren() do
						c:Destroy()
					end
					local card = Core.auraCard(show[math.random(#show)], nil, 130, 165)
					card.AnchorPoint = Vector2.new(0.5, 0)
					card.Position = UDim2.new(0.5, 0, 0, 0)
					card.Parent = S.slot
					Core.lift(card)
				end
				Core.sound("tick", 0.2)
				task.wait(0.05 + k * 0.012)
			end
			for i, S in { A, B } do
				local id = if i == 1 then R.a else R.b
				for _, c in S.slot:GetChildren() do
					c:Destroy()
				end
				local card = Core.auraCard(id, nil, 130, 165)
				card.AnchorPoint = Vector2.new(0.5, 0)
				card.Position = UDim2.new(0.5, 0, 0, 0)
				card.Parent = S.slot
				local mini = Core.auraCard(id, nil, 64, 72)
				mini.LayoutOrder = -r
				mini.Parent = S.won
				Core.lift(card)
				Core.lift(mini)
			end
			tA += Config.AURA_BY_ID[R.a].price
			tB += Config.AURA_BY_ID[R.b].price
			A.total.Text = Core.fmt(tA)
			B.total.Text = Core.fmt(tB)
			TweenService:Create(meterA, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(if tA + tB > 0 then tA / (tA + tB) else 0.5, 1) }):Play()
			task.wait(0.9)
		end
		local winner = if res.won then A else B
		winner.crown.Visible = true
		;(winner.frame:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = C.win
		task.wait(1)
		if res.won then
			Core.sound("win")
			local pot = res.A + res.B
			Core.showPrize(L("Victory!", "Победа!"), C.win, res.prize, L("Spent ", "Потрачено ") .. Core.fmt(res.cost) .. L(" · pool ", " · пул ") .. Core.fmt(pot))
		else
			Core.sound("lose")
			Core.showPrize(res.bot .. L(" wins", " побеждает"), C.lose, {}, L("Their drop ", "Его дроп ") .. Core.fmt(res.B) .. L(", yours ", ", твой ") .. Core.fmt(res.A) .. L(". The pool goes to them.", ". Пул ушёл сопернику."))
		end
	end

	return render
end
