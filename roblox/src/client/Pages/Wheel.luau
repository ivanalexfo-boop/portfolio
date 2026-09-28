-- Колесо удачи раз в сутки: лента призов прокручивается до выпавшего сектора
local TweenService = game:GetService("TweenService")

return function(Core)
	local Config, Ui, L = Core.Config, Core.Ui, Core.L
	local C, new = Ui.C, Ui.new

	local function segText(s): string
		if s.t == "coins" then
			return Core.fmt(s.v)
		end
		local t = L(s.en, s.ru)
		if s.t == "ticket" then
			t ..= "\n" .. L(Config.RIFT_BY_ID[s.rift].en, Config.RIFT_BY_ID[s.rift].ru)
		end
		return t
	end
	local function hms(sec: number): string
		local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
		return if h > 0 then h .. L("h ", " ч ") .. m .. L("m", " мин") else m .. L(" min", " мин")
	end

	return function()
		if Core.busy then
			return
		end
		local left = (Core.state.lastWheel or 0) + Config.WHEEL_COOLDOWN - Core.now()
		local p = Core.openPanel(760, 360)
		local pw = p.Size.X.Offset
		Ui.label(L("Wheel of Fortune", "Колесо Фортуны"), 24, C.gold, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 30), Parent = p })
		Ui.label(if left > 0 then L("Next spin in ", "Следующая прокрутка через ") .. hms(left) else L("One free spin every 24 hours", "Бесплатная прокрутка раз в 24 часа"), 14, C.muted, { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 18), Parent = p })
		local CW, GAP = 110, 8
		local stripW = pw - 40
		local strip = new("Frame", { Position = UDim2.fromOffset(20, 80), Size = UDim2.fromOffset(stripW, 150), BackgroundColor3 = Color3.fromRGB(11, 8, 38), ClipsDescendants = true, Parent = p }, { Ui.corner(14) })
		local track = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(4000, 130), Parent = strip })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = track })
		local N = 50
		local order = {}
		for i = 1, N do
			order[i] = ((i - 1) % #Config.WHEEL) + 1
		end
		local function tile(i: number, idx: number)
			local s = Config.WHEEL[idx]
			local f = new("Frame", { Size = UDim2.fromOffset(CW, 130), BackgroundColor3 = s.color, LayoutOrder = i, Parent = track }, {
				Ui.corner(12),
				Ui.stroke(Color3.new(1, 1, 1), 2, 0.6),
			})
			Ui.label(segText(s), 16, Color3.new(1, 1, 1), { Font = Enum.Font.GothamBlack, Size = UDim2.fromScale(1, 1), Parent = f })
			Ui.textStroke(Color3.new(0, 0, 0), 1.5, 0.4).Parent = f:FindFirstChildOfClass("TextLabel")
			if s.t == "fortune" then
				Ui.grad(C.pink, C.cyan, 45).Parent = f
			end
			return f
		end
		local tiles = {}
		for i, idx in order do
			tiles[i] = tile(i, idx)
		end
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 4, 1, 0), BorderSizePixel = 0, BackgroundColor3 = C.gold, Parent = strip })
		local spin = Ui.button(if left > 0 then L("Already spun today", "Уже крутил сегодня") else L("Spin!", "Крутить!"), "gold", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(240, 50), Parent = p })
		spin.TextTransparency = if left > 0 then 0.45 else 0
		local close = Ui.button(L("Close", "Закрыть"), "purple", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(160, 40), TextSize = 14, Parent = p })
		Core.lift(p)
		close.Activated:Connect(function()
			if not Core.busy then
				Core.closePanel()
			end
		end)
		local done = false
		spin.Activated:Connect(function()
			if done or Core.busy or left > 0 then
				return
			end
			Core.busy = true
			local res = Core.R.SpinWheel:InvokeServer()
			if not res or not res.ok then
				Core.busy = false
				Core.toast(L("Come back later", "Возвращайся позже"))
				return
			end
			done = true
			-- ставим выпавший сектор на позицию 42 и крутим к ней
			local WIN_AT = 42
			for _, c in tiles[WIN_AT]:GetChildren() do
				c:Destroy()
			end
			tiles[WIN_AT]:Destroy()
			tiles[WIN_AT] = tile(WIN_AT, res.index)
			Core.lift(tiles[WIN_AT])
			local startX = (WIN_AT - 1) * (CW + GAP)
			local target = -(startX + 10 + math.random() * (CW - 20)) + stripW / 2
			TweenService:Create(track, TweenInfo.new(5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(target, 10) }):Play()
			local last = -1
			for _ = 1, 100 do
				task.wait(0.05)
				local idx = math.floor((stripW / 2 - track.Position.X.Offset) / (CW + GAP))
				if idx ~= last then
					last = idx
					Core.sound("tick", 0.25)
				end
			end
			Core.busy = false
			local s = Config.WHEEL[res.index]
			Core.sound("win")
			spin.Text = segText(s):gsub("\n", " ") .. "!"
			if res.item then
				Core.showPrize(L("FORTUNE!", "ФОРТУНА!"), C.gold, { res.item })
			end
		end)
	end
end
