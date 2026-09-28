-- Краш: общий раунд для всех игроков сервера. Ставь до старта, выводи до взрыва.
local RunService = game:GetService("RunService")

return function(page: Frame, Core)
	local Config, Ui, L = Core.Config, Core.Ui, Core.L
	local C, new = Ui.C, Ui.new
	local st = nil :: any -- состояние раунда от сервера
	local myId = Core.player.UserId

	local function mcol(m: number): Color3
		return if m < 2 then C.cyan elseif m < 5 then C.win elseif m < 10 then C.gold else C.pink
	end

	-- история
	local hist = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -290, 0, 28), Parent = page })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = hist })

	-- сцена
	local stage = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, -290, 1, -150), ClipsDescendants = true, Parent = page }, {
		Ui.corner(18),
		Ui.stroke(C.violet, 2, 0.4),
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 16, 80)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 16)),
			}),
			Rotation = 90,
		}),
	})
	-- звёзды
	local stars = {}
	for i = 1, 60 do
		local s = new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.3 + math.random() * 0.5,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(2, 2),
			Position = UDim2.fromScale(math.random(), math.random()),
			Parent = stage,
		})
		stars[i] = { f = s, x = math.random(), y = math.random(), v = 0.3 + math.random() * 0.9 }
	end
	-- планета
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.92, 1.05), Size = UDim2.fromOffset(260, 260), BackgroundColor3 = Color3.new(1, 1, 1), Parent = stage }, {
		Ui.corner(UDim.new(1, 0)),
		Ui.grad(Color3.fromRGB(122, 92, 255), Color3.fromRGB(18, 10, 58), 45),
		Ui.stroke(Color3.fromRGB(140, 180, 255), 2, 0.5),
	})
	-- кривая из отрезков
	local SEGS = 40
	local segs = {}
	for i = 1, SEGS do
		segs[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = C.cyan, Size = UDim2.fromOffset(0, 4), Visible = false, Parent = stage })
	end
	local rocket = if Config.IMAGES.rocket ~= ""
		then new("ImageLabel", { BackgroundTransparency = 1, Image = Config.IMAGES.rocket, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(190, 133), ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = stage })
		else Ui.label("🚀", 46, C.text, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 60), ZIndex = 3, Parent = stage })
	local boom = Ui.label("💥", 64, C.text, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(90, 90), ZIndex = 3, Visible = false, Parent = stage })
	local multLabel = Ui.label("1.00×", 52, C.text, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(300, 60), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = stage })
	local statusLabel = Ui.label("", 14, Color3.fromRGB(216, 213, 255), { Position = UDim2.fromOffset(20, 74), Size = UDim2.fromOffset(360, 20), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = stage })

	-- управление
	local ctl = new("Frame", { BackgroundColor3 = Color3.fromRGB(12, 10, 40), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, -290, 0, 106), Parent = page }, {
		Ui.corner(16),
		Ui.stroke(C.violet, 2, 0.5),
	})
	local function field(x: number, labelText: string, default: string)
		Ui.label(labelText, 11, C.muted, { Position = UDim2.new(x, 12, 0, 8), Size = UDim2.new(0.33, -16, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = ctl })
		return new("TextBox", {
			Text = default,
			PlaceholderText = L("off", "выкл"),
			ClearTextOnFocus = false,
			Font = Enum.Font.Code,
			TextSize = 18,
			TextColor3 = C.text,
			PlaceholderColor3 = C.muted,
			BackgroundColor3 = Color3.fromRGB(8, 6, 30),
			Position = UDim2.new(x, 12, 0, 26),
			Size = UDim2.new(0.33, -16, 0, 38),
			Parent = ctl,
		}, { Ui.corner(10), Ui.stroke(C.line, 1.5, 0) })
	end
	local betBox = field(0, L("BET", "СТАВКА"), "1000")
	local autoBox = field(0.33, L("AUTO CASH-OUT ×", "АВТОВЫВОД ×"), "")
	local quick = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 70), Size = UDim2.new(0.66, -20, 0, 28), Parent = ctl })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = quick })
	for i, q in { "½", "×2", "Max", "1.5×", "2×", "5×" } do
		local b = new("TextButton", { Text = q, TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.muted, BackgroundColor3 = C.panel2, Size = UDim2.fromOffset(52, 28), LayoutOrder = i, Parent = quick }, { Ui.corner(8) })
		b.Activated:Connect(function()
			local v = tonumber(betBox.Text) or 0
			if q == "½" then
				betBox.Text = tostring(math.max(1, math.floor(v / 2)))
			elseif q == "×2" then
				betBox.Text = tostring(math.max(1, math.floor(math.min(Core.state.balance, v * 2))))
			elseif q == "Max" then
				betBox.Text = tostring(math.floor(math.min(Core.state.balance, 1e12)))
			else
				autoBox.Text = string.gsub(q, "×", "")
			end
		end)
	end
	local go = Ui.button("", "green", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0.33, -16, 0, 70), Parent = ctl })

	-- игроки
	local players = new("Frame", { BackgroundColor3 = Color3.fromRGB(12, 10, 40), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 280, 1, 0), Parent = page }, {
		Ui.corner(16),
		Ui.stroke(C.violet, 2, 0.5),
		Ui.pad(10),
	})
	local potLabel = Ui.label(L("PLAYERS", "ИГРОКИ"), 13, C.muted, { Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = players })
	local plist = new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = players })
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = plist })

	local function mine()
		if not st then
			return nil
		end
		for _, p in st.players do
			if p.me == myId then
				return p
			end
		end
		return nil
	end

	local function renderStatic()
		if not st then
			return
		end
		for _, c in hist:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, v in st.hist do
			local col = if v < 1.5 then C.lose elseif v < 3 then C.cyan elseif v < 10 then C.win else C.gold
			Ui.label(string.format("%.2f×", v), 12, col, { Font = Enum.Font.Code, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), BackgroundColor3 = C.panel, BackgroundTransparency = 0, TextWrapped = false, LayoutOrder = i, Parent = hist })
		end
		for _, c in hist:GetChildren() do
			if c:IsA("TextLabel") then
				Ui.corner(12).Parent = c
				Ui.pad(0, 8).Parent = c
			end
		end
		for _, c in plist:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local pot = 0
		for i, p in st.players do
			pot += p.bet
			local row = new("Frame", { BackgroundColor3 = if p.me == myId then Color3.fromRGB(20, 40, 70) else C.panel, Size = UDim2.new(1, -4, 0, 30), LayoutOrder = i, Parent = plist }, { Ui.corner(8) })
			Ui.label(p.name, 13, C.text, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.45, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
			Ui.label(Core.fmt(p.bet), 12, C.muted, { Font = Enum.Font.Code, Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.3, 0, 1, 0), Parent = row })
			local s, col
			if p.cashed > 0 then
				s, col = string.format("%.2f×", p.cashed), C.win
			elseif st.phase == "after" then
				s, col = L("busted", "сгорел"), C.lose
			elseif st.phase == "fly" then
				s, col = "…", C.muted
			else
				s, col = L("waiting", "ждёт"), C.muted
			end
			Ui.label(s, 12, col, { Font = Enum.Font.Code, Position = UDim2.new(0.75, 0, 0, 0), Size = UDim2.new(0.25, -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		end
		potLabel.Text = L("PLAYERS · pot ", "ИГРОКИ · банк ") .. Core.fmt(pot)
	end

	local lastQ = -1
	local function frame()
		if not st or not page.Visible then
			return
		end
		local now = workspace:GetServerTimeNow()
		local me = mine()
		-- размеры сцены в логических единицах (AbsoluteSize уже умножен на UIScale)
		local k = 1
		local anc: Instance? = stage
		while anc and anc:IsA("GuiObject") do
			local us = anc:FindFirstChildOfClass("UIScale")
			if us then
				k *= us.Scale
			end
			anc = anc.Parent
		end
		local w, h = stage.AbsoluteSize.X / k, stage.AbsoluteSize.Y / k
		if st.phase == "bet" then
			local left = math.max(0, st.betTime - (now - st.t0))
			multLabel.Text = string.format("%.1f", left) .. L("s", " с")
			multLabel.TextColor3 = C.text
			statusLabel.Text = L("Taking bets — launch in", "Приём ставок — старт через")
			for _, s in segs do
				s.Visible = false
			end
			rocket.Visible = true
			boom.Visible = false
			rocket.Position = UDim2.fromOffset(w * 0.1 + (if left < 1.5 then math.random(-2, 2) else 0), h * 0.85)
			rocket.Rotation = 0
			go.Text = if me then L("Bet ", "Ставка ") .. Core.fmt(me.bet) .. L(" placed", " принята") else L("Place bet", "Поставить")
			go.TextTransparency = if me then 0.4 else 0
			return
		end
		local t = if st.phase == "fly" then now - st.t0 else math.log(st.crashAt or 1) / st.speed
		local m = if st.phase == "fly" then math.exp(st.speed * t) else (st.crashAt or 1)
		local maxT, maxM = math.max(8, t * 1.15), math.max(2, m * 1.25)
		local function X(tt: number): number
			return tt / maxT * w * 0.86 + w * 0.06
		end
		local function Y(mm: number): number
			return h - (mm - 1) / (maxM - 1) * h * 0.7 - h * 0.12
		end
		local col = if st.phase == "after" then C.lose else mcol(m)
		local px, py = X(0), Y(1)
		for i = 1, SEGS do
			local tt = t * i / SEGS
			local nx, ny = X(tt), Y(math.exp(st.speed * tt))
			local s = segs[i]
			local dx, dy = nx - px, ny - py
			s.Visible = true
			s.BackgroundColor3 = col
			s.Position = UDim2.fromOffset((px + nx) / 2, (py + ny) / 2)
			s.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 2, 4)
			s.Rotation = math.deg(math.atan2(dy, dx))
			px, py = nx, ny
		end
		multLabel.Text = string.format("%.2f×", m)
		multLabel.TextColor3 = col
		if st.phase == "fly" then
			rocket.Visible = true
			boom.Visible = false
			rocket.Position = UDim2.fromOffset(px, py)
			rocket.Rotation = 0
			statusLabel.Text = if me then (if me.cashed > 0 then L("Cashed out at ", "Выведено на ") .. string.format("%.2f×", me.cashed) else L("Your bet ", "Твоя ставка ") .. Core.fmt(me.bet)) else L("The rocket is flying…", "Ракета летит…")
			go.Text = if me and me.cashed == 0 then L("Cash out ", "Вывести ") .. Core.fmt(math.floor(me.bet * m)) else L("Round in progress", "Раунд идёт")
			go.TextTransparency = if me and me.cashed == 0 then 0 else 0.4
			-- звёзды летят навстречу
			for _, s in stars do
				s.x -= 0.004 * s.v * (1 + math.log(m))
				s.y += 0.002 * s.v * (1 + math.log(m))
				if s.x < 0 then
					s.x += 1
				end
				if s.y > 1 then
					s.y -= 1
				end
				s.f.Position = UDim2.fromScale(s.x, s.y)
			end
			local q = math.floor(m * 4)
			if q ~= lastQ then
				lastQ = q
				if me and me.cashed == 0 then
					Core.sound("tick", 0.2)
				end
			end
		else
			rocket.Visible = false
			boom.Visible = true
			boom.Position = UDim2.fromOffset(px, py)
			statusLabel.Text = L("Exploded at ", "Взрыв на ") .. string.format("%.2f×", st.crashAt or 1)
			go.Text = if me and me.cashed > 0 then L("Cashed out ✓", "Выведено ✓") else L("New round soon", "Новый раунд скоро")
			go.TextTransparency = 0.4
		end
	end
	RunService.RenderStepped:Connect(frame)

	local lastPhase = nil
	local manualCash = false
	Core.R.CrashState.OnClientEvent:Connect(function(s)
		local me0 = mine()
		st = s
		-- автовывод сработал на сервере — тоже радуемся
		local me1 = mine()
		if me0 and me1 and me0.cashed == 0 and me1.cashed > 0 and not manualCash then
			Core.sound(if me1.cashed >= 3 then "win_big" else "win")
			Core.toast(L("Auto cash-out at ", "Автовывод на ") .. string.format("%.2f×", me1.cashed))
		end
		if lastPhase == "fly" and s.phase == "after" then
			local me = mine()
			if me0 and me and me.cashed == 0 then
				Core.sound("lose")
			end
		end
		lastPhase = s.phase
		if page.Visible then
			renderStatic()
		end
	end)
	task.spawn(function()
		st = Core.R.GetCrash:InvokeServer()
		lastPhase = st and st.phase
		renderStatic()
	end)

	go.Activated:Connect(function()
		if not st then
			return
		end
		local me = mine()
		if st.phase == "fly" and me and me.cashed == 0 then
			manualCash = true
			local res = Core.R.CrashCashout:InvokeServer()
			task.delay(1, function()
				manualCash = false
			end)
			if res and res.ok then
				Core.sound(if res.cashed >= 3 then "win_big" else "win")
				Core.toast(L("Cashed out ", "Выведено ") .. Core.fmt(res.win) .. L(" at ", " на ") .. string.format("%.2f×", res.cashed))
			end
			return
		end
		if st.phase ~= "bet" or me then
			return
		end
		local bet = math.floor(tonumber(betBox.Text) or 0)
		if bet < 1 then
			Core.toast(L("Enter a bet", "Введи ставку"))
			return
		end
		if bet > Core.state.balance then
			Core.toast(L("Not enough coins", "Не хватает монет"))
			return
		end
		local res = Core.R.CrashBet:InvokeServer(bet, tonumber(autoBox.Text) or 0)
		if not res or not res.ok then
			Core.toast(if res and res.err == "not_bet" then L("Bets are closed — wait for the next round", "Ставки закрыты — жди следующий раунд") else L("Bet not accepted", "Ставка не принята"))
		end
	end)

	return renderStatic
end
