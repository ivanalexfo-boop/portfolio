-- Инвентарь: продажа по одной и «продать всё», промокоды, статистика
return function(page: Frame, Core)
	local Ui, L = Core.Ui, Core.L
	local C, new = Ui.C, Ui.new
	local state = Core.state

	local head = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = page })
	local title = Ui.label("", 18, C.text, { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -200, 1, 0), Parent = head })
	local sellAll = Ui.button("", "red", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(190, 40), TextSize = 14, Parent = head })

	-- промокод
	local promo = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 40), Parent = page })
	local box = new("TextBox", {
		PlaceholderText = L("Promo code", "Промокод"),
		Text = "",
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C.text,
		PlaceholderColor3 = C.muted,
		BackgroundColor3 = C.panel,
		Size = UDim2.fromOffset(240, 40),
		Parent = promo,
	}, { Ui.corner(10), Ui.stroke(C.line, 1.5, 0) })
	local redeem = Ui.button(L("Redeem", "Активировать"), "purple", { Position = UDim2.fromOffset(250, 0), Size = UDim2.fromOffset(150, 40), TextSize = 14, Parent = promo })
	redeem.Activated:Connect(function()
		local res = Core.R.Redeem:InvokeServer(box.Text)
		if res and res.ok then
			box.Text = ""
			if res.gain then
				Core.toast("+" .. Core.fmt(res.gain) .. L(" coins!", " монет!"))
				Core.sound("win")
			else
				Core.toast(if res.infinite then L("Infinite coins on ∞", "Бесконечные монеты включены ∞") else L("Infinite coins off", "Бесконечные монеты выключены"))
			end
		else
			local err = res and res.err
			Core.toast(if err == "used" then L("Promo code already redeemed", "Промокод уже активирован") else L("No such promo code", "Такого промокода нет"))
		end
	end)
	local statsLabel = Ui.label("", 13, C.muted, { Position = UDim2.fromOffset(410, 0), Size = UDim2.new(1, -410, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = promo })

	local scroll = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 1, -100),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.violet,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = page,
	})
	new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 250), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

	local armed = false
	local render: () -> ()

	sellAll.Activated:Connect(function()
		if not armed then
			armed = true
			render()
			task.delay(3, function()
				if armed then
					armed = false
					render()
				end
			end)
			return
		end
		armed = false
		local res = Core.R.SellAll:InvokeServer()
		if res and res.ok then
			Core.toast(L("Sold everything for ", "Продано всё за ") .. Core.fmt(res.total))
			Core.sound("coin")
		end
	end)

	render = function()
		for _, ch in scroll:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local total = 0
		for _, it in state.inv do
			total += it.v
		end
		title.Text = L("Inventory", "Инвентарь") .. " · " .. #state.inv .. " · " .. Core.fmt(total)
		sellAll.Visible = #state.inv > 0
		sellAll.Text = if armed then L("Sure? Tap again", "Точно? Нажми ещё") else L("Sell all", "Продать всё") .. " · " .. Core.fmt(total)
		local st = state.stats or {}
		statsLabel.Text = L("Rifts opened: ", "Открыто разломов: ") .. (st.opened or 0) .. "  ·  " .. L("Best drop: ", "Лучший дроп: ") .. Core.fmt(st.best or 0)
		if #state.inv == 0 then
			Ui.label(L("Inventory is empty — open a rift.", "Инвентарь пуст — открой разлом."), 16, C.muted, { Size = UDim2.fromOffset(400, 60), Parent = scroll })
			return
		end
		local sorted = table.clone(state.inv)
		table.sort(sorted, function(a, b)
			return a.v > b.v
		end)
		for i, it in sorted do
			if i > 200 then
				break -- показываем 200 самых дорогих, чтобы не тормозило
			end
			local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = scroll })
			Core.auraCard(it.id, it.v, 150, 200).Parent = cell
			local b = Ui.button(L("Sell", "Продать"), "gold", { Position = UDim2.fromOffset(0, 206), Size = UDim2.fromOffset(150, 40), TextSize = 14, Parent = cell })
			b.Activated:Connect(function()
				local res = Core.R.SellItems:InvokeServer({ it.u })
				if res and res.ok then
					Core.sound("coin", 0.3)
				end
			end)
		end
	end
	return render
end
