-- Аура Кликер: тап → +150 монет (сервер не даёт больше 12 тапов в секунду)
local TweenService = game:GetService("TweenService")

return function(page: Frame, Core)
	local Config, Ui, L = Core.Config, Core.Ui, Core.L
	local C, new = Ui.C, Ui.new

	Ui.label(L("Tom Aura Clicker", "Том Аура Кликер"), 26, C.text, { Font = Enum.Font.GothamBlack, Size = UDim2.new(1, 0, 0, 34), Parent = page })
	Ui.label(L("Tap Tom and get coins on your balance — +150 for every tap!", "Тапай Тома и получай монеты на баланс — +150 за каждый тап!"), 15, C.muted, { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 20), Parent = page })
	local stage = new("Frame", { BackgroundColor3 = Color3.fromRGB(12, 10, 40), Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), ClipsDescendants = true, Parent = page }, {
		Ui.corner(20),
		Ui.stroke(C.gold, 2, 0.5),
	})
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(260, 260),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "TAP",
		TextSize = 44,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Parent = stage,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.grad(Color3.fromRGB(127, 251, 230), Color3.fromRGB(109, 60, 255), 60),
		Ui.stroke(C.gold, 4, 0.2),
		Ui.textStroke(Color3.fromRGB(40, 20, 80), 2, 0.3),
	})
	local scale = new("UIScale", { Parent = btn })
	if Config.IMAGES.tom ~= "" then
		btn.Text = ""
		btn.BackgroundTransparency = 1
		btn.Size = UDim2.new(0, 300, 1, -24)
		for _, ch in btn:GetChildren() do
			if ch:IsA("UICorner") or ch:IsA("UIGradient") or ch:IsA("UIStroke") then
				ch:Destroy()
			end
		end
		new("ImageLabel", { BackgroundTransparency = 1, Image = Config.IMAGES.tom, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, Parent = btn })
	end

	local lastTap = 0
	btn.Activated:Connect(function()
		local now = os.clock()
		if now - lastTap < 1 / Config.CLICK_MAX_PER_SEC then
			return
		end
		lastTap = now
		Core.R.Tap:FireServer()
		Core.state.balance += Config.CLICK_GAIN -- сразу показываем, сервер пришлёт точное значение
		Core.changed()
		Core.sound("tap", 0.35)
		local pop = Ui.label("+" .. Config.CLICK_GAIN, 30, C.gold, {
			Font = Enum.Font.GothamBlack,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.random(-70, 70), 0.5, math.random(-90, -30)),
			Size = UDim2.fromOffset(140, 40),
			ZIndex = 5,
			Parent = stage,
		})
		Ui.textStroke(Color3.fromRGB(90, 40, 0), 2, 0.2).Parent = pop
		TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pop.Position - UDim2.fromOffset(0, 100), TextTransparency = 1 }):Play()
		task.delay(1.15, function()
			pop:Destroy()
		end)
		scale.Scale = 0.93
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)

	return function() end
end
