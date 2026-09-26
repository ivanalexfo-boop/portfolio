-- Форматирование чисел: 1 500 000 → 1.5M, 2 500 000 000 → 2.5B
local Format = {}

local UNITS = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" } }

local function trim(s: string): string
	-- убираем хвостовые нули: 1.50 → 1.5, 2.00 → 2
	s = s:gsub("(%..-)0+$", "%1")
	s = s:gsub("%.$", "")
	return s
end

function Format.coins(n: number): string
	local a = math.abs(n)
	for _, u in UNITS do
		if a >= u[1] then
			local x = n / u[1]
			local s
			if math.abs(x) >= 100 then
				s = string.format("%.0f", x)
			elseif math.abs(x) >= 10 then
				s = trim(string.format("%.1f", x))
			else
				s = trim(string.format("%.2f", x))
			end
			return s .. u[2]
		end
	end
	-- до миллиона — с разделителями тысяч
	local s = tostring(math.floor(n + 0.5))
	local neg = s:sub(1, 1) == "-"
	if neg then
		s = s:sub(2)
	end
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	s = s:gsub("^,", "")
	return (neg and "-" or "") .. s
end

return Format
