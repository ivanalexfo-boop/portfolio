-- Колесо Фортуны раз в сутки: круглое колесо из цветных секторов, указатель сверху
local TweenService = game:GetService("TweenService")

return function(Core)
	local Config, Ui, L = Core.Config, Core.Ui, Core.L
	local C, new = Ui.C, Ui.new
	local N = #Config.WHEEL
	local SEG = 360 / N

	local function segText(s): string
		if s.t == "coins" then
			return Core.fmt(s.v)
		end
		return L(s.en, s.ru)
	end
	local function hms(sec: number): string
		local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
		return if h > 0 then h .. L("h ", " ч ") .. m .. L("m", " мин") else m .. L(" min", " мин")
	end

	-- колесо рисуется «лучами»: много узких полосок от центра, каждая своего сектора
	local function buildWheel(parent: Instance, D: number): Frame
		local R = D / 2
		local wheel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(D, D), BackgroundTransparency = 1, Parent = parent })
		local step = 1.5
		local w = math.ceil(R * math.rad(step)) + 2
		for ang = 0, 360 - step, step do
			local idx = math.floor((ang + step / 2) / SEG) % N + 1
			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = ang, Parent = wheel })
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(w, R), BorderSizePixel = 0, BackgroundColor3 = Config.WHEEL[idx].color, Parent = holder })
		end
		-- разделители и подписи секторов
		for i, s in Config.WHEEL do
			local line = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = (i - 1) * SEG, Parent = wheel })
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(3, R), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(7, 6, 26), Parent = line })
			local lab = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = (i - 0.5) * SEG, Parent = wheel })
			local t = Ui.label(segText(s), if #segText(s) > 6 then 12 else 16, Color3.new(1, 1, 1), {
				Font = Enum.Font.GothamBlack,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 16),
				Size = UDim2.fromOffset(80, 22),
				TextWrapped = false,
				Parent = lab,
			})
			Ui.textStroke(Color3.new(0, 0, 0), 1.5, 0.35).Parent = t
		end
		-- обод и центр
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(D + 8, D + 8), BackgroundTransparency = 1, Parent = parent }, {
			Ui.corner(UDim.new(1, 0)),
			Ui.stroke(C.gold, 5, 0),
		})
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.fromRGB(21, 18, 58), Parent = parent }, {
			Ui.corner(UDim.new(1, 0)),
			Ui.stroke(Color3.new(1, 1, 1), 3, 0),
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.new(1, 1, 1) }, {
				Ui.corner(UDim.new(1, 0)),
				Ui.grad(C.pink, C.cyan, 45),
			}),
		})
		-- указатель сверху
		Ui.label("▼", 34, C.gold, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, -R + 14), Size = UDim2.fromOffset(40, 40), Parent = parent })
		return wheel
	end

	local angle = 0
	return function()
		if Core.busy then
			return
		end
		local left = (Core.state.lastWheel or 0) + Config.WHEEL_COOLDOWN - Core.now()
		local D = math.min(360, Core.H - 250)
		local p = Core.openPanel(math.max(440, D + 80), D + 230)
		Ui.label(L("Wheel of Fortune", "Колесо Фортуны"), 24, C.gold, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 30), Parent = p })
		Ui.label(if left > 0 then L("Next spin in ", "Следующая прокрутка через ") .. hms(left) else L("One free spin every 24 hours", "Бесплатная прокрутка раз в 24 часа"), 14, C.muted, { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 18), Parent = p })
		local area = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, D + 20), Parent = p })
		local wheel = buildWheel(area, D)
		wheel.Rotation = angle % 360
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
			-- поворачиваем колесо так, чтобы центр выпавшего сектора встал под указатель
			local jitter = (math.random() - 0.5) * SEG * 0.6
			local target = angle - (angle % 360) + 360 * 6 - ((res.index - 0.5) * SEG) + jitter
			angle = target
			TweenService:Create(wheel, TweenInfo.new(5.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = target }):Play()
			local last = math.floor(wheel.Rotation / SEG)
			local t0 = os.clock()
			while os.clock() - t0 < 5.6 do
				task.wait()
				local k = math.floor(wheel.Rotation / SEG)
				if k ~= last then
					last = k
					Core.sound("tick", 0.3)
				end
			end
			Core.busy = false
			local s = Config.WHEEL[res.index]
			Core.sound("win")
			spin.Text = (segText(s):gsub("\n", " ")) .. "!"
			Core.toast(L("You won: ", "Выигрыш: ") .. segText(s))
			if res.item then
				Core.showPrize(L("FORTUNE!", "ФОРТУНА!"), C.gold, { res.item })
			end
		end)
	end
end
