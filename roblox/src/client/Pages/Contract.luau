-- Контракт: от 3 до 10 любых аур → одна новая (чаще — тиром выше)
return function(page: Frame, Core)
	local Config, Ui, L = Core.Config, Core.Ui, Core.L
	local C, new = Ui.C, Ui.new
	local state = Core.state
	local MIN, MAX = Config.CONTRACT_MIN, Config.CONTRACT_MAX
	local sel: { [number]: boolean } = {}

	Ui.label(L("Contract", "Контракт"), 24, C.text, { Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), Parent = page })
	Ui.label(L("Put in 3 to 10 of any auras — get one new aura. The more you put in, the better the chance of a rarer tier.", "Положи от 3 до 10 любых аур — получишь одну новую. Чем больше вложишь, тем выше шанс на тир редче."), 14, C.muted, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = page,
	})
	local bar = new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 12, 52), Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 110), Parent = page }, {
		Ui.corner(16),
		Ui.stroke(C.gold, 2, 0.5),
	})
	local slots = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -260, 1, -24), Parent = bar })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(40, 40), CellPadding = UDim2.fromOffset(6, 6), Parent = slots })
	local info = Ui.label("", 14, C.text, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(230, 44), TextXAlignment = Enum.TextXAlignment.Right, Parent = bar })
	local craft = Ui.button("", "gold", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.fromOffset(230, 46), Parent = bar })

	local scroll = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 194),
		Size = UDim2.new(1, 0, 1, -194),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.violet,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = page,
	})
	new("UIGridLayout", { CellSize = UDim2.fromOffset(110, 120), CellPadding = UDim2.fromOffset(6, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

	local function selected()
		local list, sum, base = {}, 0, 1
		for _, it in state.inv do
			if sel[it.u] then
				table.insert(list, it)
				sum += it.v
				base = math.max(base, Config.TIER_INDEX[Config.AURA_BY_ID[it.id].tier])
			end
		end
		return list, sum, base
	end

	local render: () -> ()
	render = function()
		if Core.busy then
			return
		end
		local exists = {}
		for _, it in state.inv do
			exists[it.u] = true
		end
		for u in sel do
			if not exists[u] then
				sel[u] = nil
			end
		end
		local list, sum, base = selected()
		for _, c in slots:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i = 1, MAX do
			local it = list[i]
			if it then
				local o = Core.auraOrb(it.id, 40)
				o.LayoutOrder = i
				o.Parent = slots
			else
				new("Frame", { BackgroundColor3 = C.panel, LayoutOrder = i, Parent = slots }, { Ui.corner(10), Ui.stroke(if i <= MIN then C.gold else C.line, 1.5, 0.4) })
			end
		end
		local tier = Config.TIERS[base]
		info.Text = if #list > 0 then (#list .. " / " .. MAX .. L(" auras · worth ", " аур · на ") .. Core.fmt(sum) .. "\n" .. L("rarest: ", "самая редкая: ") .. L(tier.en, tier.ru)) else L("Pick auras below", "Выбери ауры ниже")
		craft.Text = if #list < MIN then L("Add ", "Добавь ещё ") .. (MIN - #list) else L("Craft", "Синтез")
		craft.TextTransparency = if #list < MIN then 0.45 else 0
		local inv = table.clone(state.inv)
		table.sort(inv, function(a, b)
			return a.v < b.v
		end)
		Core.fillInvGrid(scroll, inv, function(u)
			return sel[u] == true
		end, function(it)
			if Core.busy then
				return
			end
			if sel[it.u] then
				sel[it.u] = nil
			elseif #list >= MAX then
				Core.toast(L("Up to 10 auras", "Не больше 10 аур"))
				return
			else
				sel[it.u] = true
			end
			render()
		end)
	end

	craft.Activated:Connect(function()
		if Core.busy then
			return
		end
		local list, sum = selected()
		if #list < MIN then
			return
		end
		local uids = {}
		for _, it in list do
			table.insert(uids, it.u)
		end
		Core.busy = true
		local res = Core.R.Contract:InvokeServer(uids)
		table.clear(sel)
		if not res or not res.ok then
			Core.busy = false
			Core.toast(L("Something changed — try again", "Что-то изменилось — попробуй ещё раз"))
			render()
			return
		end
		-- «синтез»: мелькают ауры, потом результат
		local p = Core.openPanel(320, 300)
		Ui.label(L("Crafting…", "Синтез…"), 22, C.gold, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 30), Parent = p })
		Core.lift(p)
		local show = {}
		for _, a in Config.AURAS do
			if a.tier ~= "unique" and a.price >= sum * 0.4 and a.price <= sum * 2.5 then
				table.insert(show, a.id)
			end
		end
		if #show == 0 then
			show = { res.item.id }
		end
		local card
		for k = 1, 16 do
			if card then
				card:Destroy()
			end
			card = Core.auraCard(show[math.random(#show)], nil, 150, 200)
			card.AnchorPoint = Vector2.new(0.5, 0)
			card.Position = UDim2.new(0.5, 0, 0, 60)
			card.Parent = p
			Core.lift(card)
			Core.sound("tick", 0.25)
			task.wait(0.09 + k * 0.01)
		end
		local good = res.up or res.item.v >= sum
		Core.sound(if res.up then "win_big" elseif good then "win" else "lose")
		local tier = Core.tierOf(res.item.id)
		Core.showPrize(
			if res.up then L("Rarer: ", "Редче: ") .. L(tier.en, tier.ru) .. "!" else L("New aura", "Новая аура"),
			if good then C.win else C.lose,
			{ res.item },
			L("Put in ", "Вложено ") .. #list .. L(" auras worth ", " аур на ") .. Core.fmt(sum)
		)
	end)

	return render
end
