-- Маленькие помощники для построения интерфейса кодом
local Ui = {}

Ui.C = {
	bg = Color3.fromRGB(7, 6, 26),
	bg2 = Color3.fromRGB(15, 12, 46),
	panel = Color3.fromRGB(21, 18, 58),
	panel2 = Color3.fromRGB(30, 26, 77),
	line = Color3.fromRGB(46, 40, 112),
	text = Color3.fromRGB(241, 240, 255),
	muted = Color3.fromRGB(155, 151, 207),
	cyan = Color3.fromRGB(34, 230, 255),
	violet = Color3.fromRGB(139, 92, 255),
	pink = Color3.fromRGB(255, 61, 203),
	gold = Color3.fromRGB(255, 197, 61),
	win = Color3.fromRGB(62, 240, 143),
	lose = Color3.fromRGB(255, 77, 109),
}

Ui.BUTTON = {
	green = { Color3.fromRGB(95, 227, 107), Color3.fromRGB(31, 154, 58) },
	blue = { Color3.fromRGB(74, 168, 255), Color3.fromRGB(29, 78, 216) },
	purple = { Color3.fromRGB(192, 92, 255), Color3.fromRGB(109, 40, 217) },
	gold = { Color3.fromRGB(255, 212, 107), Color3.fromRGB(201, 138, 0) },
	red = { Color3.fromRGB(255, 120, 140), Color3.fromRGB(200, 40, 70) },
}

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local o = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(o :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = o
		end
	end
	if parent then
		o.Parent = parent
	end
	return o
end

function Ui.corner(r: number | UDim?): UICorner
	local c = Instance.new("UICorner")
	if typeof(r) == "UDim" then
		c.CornerRadius = r
	else
		c.CornerRadius = UDim.new(0, (r :: number?) or 12)
	end
	return c
end

function Ui.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

function Ui.textStroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	return s
end

function Ui.grad(c1: Color3, c2: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation or 90
	return g
end

function Ui.pad(t: number, r: number?, b: number?, l: number?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, t)
	p.PaddingRight = UDim.new(0, r or t)
	p.PaddingBottom = UDim.new(0, b or t)
	p.PaddingLeft = UDim.new(0, l or r or t)
	return p
end

function Ui.label(text: string, size: number, color: Color3?, props: { [string]: any }?): TextLabel
	local p = {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or Ui.C.text,
		Font = Enum.Font.GothamBold,
		TextWrapped = true,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Ui.new("TextLabel", p)
end

-- цветная кнопка с объёмом (градиент + обводка + тень снизу)
function Ui.button(text: string, kind: string, props: { [string]: any }?): TextButton
	local cols = Ui.BUTTON[kind] or Ui.BUTTON.green
	local p = {
		Text = text,
		TextSize = 16,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = cols[1]:Lerp(cols[2], 0.55),
		AutoButtonColor = true,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Ui.new("TextButton", p, {
		Ui.corner(10),
		Ui.stroke(cols[1], 2, 0.2),
	})
end

-- монетка (голубой шарик)
function Ui.coin(size: number): Frame
	return Ui.new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1) }, {
		Ui.corner(UDim.new(1, 0)),
		Ui.grad(Color3.fromRGB(200, 250, 255), Color3.fromRGB(34, 150, 255), 45),
		Ui.stroke(Color3.fromRGB(34, 230, 255), 1, 0.3),
	})
end

return Ui
