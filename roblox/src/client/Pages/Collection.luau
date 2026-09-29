-- Коллекция: все ауры игры, собранные подсвечены
return function(page: Frame, Core)
	local Config, Ui, L = Core.Config, Core.Ui, Core.L
	local C, new = Ui.C, Ui.new
	local title = Ui.label("", 18, C.text, { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), Parent = page })
	local bar = new("Frame", { BackgroundColor3 = C.panel, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 10), Parent = page }, { Ui.corner(5) })
	local fill = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), Parent = bar }, { Ui.corner(5), Ui.grad(C.cyan, C.pink, 0) })
	local scroll = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.violet,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = page,
	})
	new("UIGridLayout", { CellSize = UDim2.fromOffset(140, 190), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	local sorted = table.clone(Config.AURAS)
	table.sort(sorted, function(a, b)
		return a.price > b.price
	end)
	return function()
		for _, ch in scroll:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local have = 0
		for i, a in sorted do
			local got = Core.state.collected[a.id] == true
			if got then
				have += 1
			end
			local card = Core.auraCard(a.id, nil, 140, 190)
			card.LayoutOrder = i
			if not got then
				for _, d in card:GetDescendants() do
					if d:IsA("TextLabel") then
						d.TextTransparency = 0.6
					elseif d:IsA("Frame") or d:IsA("ImageLabel") then
						d.BackgroundTransparency = math.max(d.BackgroundTransparency, 0.75)
					end
				end
			else
				Ui.label("✓", 18, C.win, { Font = Enum.Font.GothamBlack, Position = UDim2.new(1, -26, 0, 4), Size = UDim2.fromOffset(22, 22), Parent = card })
			end
			card.Parent = scroll
		end
		title.Text = L("Collection: ", "Коллекция: ") .. have .. " / " .. #sorted
		fill.Size = UDim2.fromScale(have / #sorted, 1)
	end
end
