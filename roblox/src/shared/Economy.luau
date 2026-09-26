-- Экономика разломов — перенос веб-версии один в один.
-- 30% дропов дешевле разлома, 70% окупают (окуп, профит, джекпот).
-- Веса подбираются так, чтобы в среднем разлом возвращал ~97% цены.
local Config = require(script.Parent.Config)

export type Drop = { id: string, w: number }
export type RiftEconomy = { drops: { Drop }, show: { Drop }, jack: number, profit: number, items: { string } }

local Economy = {}
Economy.RIFT = {} :: { [string]: RiftEconomy }

local AURA = Config.AURA_BY_ID
local ORDER = {} :: { [string]: number }
for i, a in Config.AURAS do
	ORDER[a.id] = i
end

local function priceOf(id: string): number
	return AURA[id].price
end

local function contains(list: { any }, x: any): boolean
	for _, v in list do
		if v == x then
			return true
		end
	end
	return false
end

-- состав разлома по ценовым корзинам: убыток / окуп / профит / джекпот
local function buckets(rf)
	local P = rf.price
	local pool = {}
	for _, a in Config.AURAS do
		if a.tier ~= "unique" then
			table.insert(pool, a)
		end
	end
	local function near(a, b)
		local da, db = math.abs(math.log(a.price / P)), math.abs(math.log(b.price / P))
		if da == db then
			return ORDER[a.id] < ORDER[b.id] -- при равенстве — порядок каталога, как в веб-версии
		end
		return da < db
	end
	local function take(lo: number, hi: number, n: number, must: string?)
		local c = {}
		for _, a in pool do
			if a.price >= lo * P and a.price < hi * P then
				table.insert(c, a)
			end
		end
		table.sort(c, near)
		local out = {}
		for i = 1, math.min(n, #c) do
			out[i] = c[i]
		end
		if must and AURA[must] and #out > 0 then
			local m = AURA[must]
			if not contains(out, m) and m.price >= lo * P and m.price < hi * P then
				out[#out] = m
			end
		end
		return out
	end
	local function spread(lo: number, hi: number, n: number, must: string?)
		local c = {}
		for _, a in pool do
			if a.price >= lo * P and a.price <= hi * P then
				table.insert(c, a)
			end
		end
		table.sort(c, function(a, b)
			return a.price < b.price
		end)
		if #c <= n then
			return c
		end
		local out = {}
		for _, a in { c[1], c[math.floor(#c / 2) + 1], c[#c] } do
			if not contains(out, a) then
				table.insert(out, a)
			end
		end
		if must and AURA[must] then
			local m = AURA[must]
			if contains(c, m) and not contains(out, m) then
				out[1] = m
			end
		end
		return out
	end
	return take(0.05, 1, 4, rf.core[1]), take(1, 2, 3, rf.core[2]), take(2, 20, 3, rf.core[3]), spread(20, 300, 3, rf.core[4])
end

local function split(list, mass: number, e: number): { Drop }
	local raw, t = {}, 0
	for i, a in list do
		raw[i] = a.price ^ e
		t += raw[i]
	end
	if t == 0 then
		t = 1
	end
	local out = {}
	for i, a in list do
		out[i] = { id = a.id, w = mass * raw[i] / t }
	end
	return out
end

local function avg(list, e: number): number
	if #list == 0 then
		return 0
	end
	local s = 0
	for _, d in split(list, 1, e) do
		s += d.w * priceOf(d.id)
	end
	return s
end

local function concat(...: { Drop }): { Drop }
	local out = {}
	for _, list in { ... } do
		for _, d in list do
			if d.w > 1e-9 then
				table.insert(out, d)
			end
		end
	end
	return out
end

for _, rf in Config.RIFTS do
	local L, O, Pr, J = buckets(rf)
	local LOSS = Config.LOSS
	local pick
	local found = false
	for _, pm in { 0.1, 0.09, 0.08, 0.07, 0.06, 0.05, 0.04, 0.03, 0.02 } do
		for _, v in { { 1, 1 }, { 1, 2 }, { 1, 3 }, { 0, 3 }, { 0, 5 }, { -1, 6 }, { -2, 8 }, { -4, 12 } } do
			local eL, t = v[1], v[2]
			local aL, aO, aP, aJ = avg(L, eL), avg(O, -t), avg(Pr, -t), avg(J, -1)
			local base = LOSS * aL + (1 - LOSS - pm) * aO + pm * aP
			local j = if #J > 0 then (Config.RTP * rf.price - base) / (aJ - aP) else 0
			pick = { eL = eL, t = t, pm = pm, j = math.max(0, math.min(0.01, pm * 0.5, j)) }
			if j >= 0.0005 and j <= 0.01 and j < pm * 0.5 then
				found = true
				break
			end
		end
		if found then
			break
		end
	end
	local drops = concat(split(L, LOSS, pick.eL), split(O, 1 - LOSS - pick.pm, -pick.t), split(Pr, pick.pm - pick.j, -pick.t), split(J, pick.j, -1))
	local profit = 0
	local items = {}
	for _, d in drops do
		if priceOf(d.id) >= rf.price then
			profit += d.w
		end
		table.insert(items, d.id)
	end
	Economy.RIFT[rf.id] = {
		drops = drops,
		-- витрина ленты: все ауры мелькают, дорогие реже
		show = concat(split(L, 0.32, 0), split(O, 0.3, 0), split(Pr, 0.24, 0), split(J, 0.14, 0)),
		jack = pick.j,
		profit = profit,
		items = items,
	}
end

function Economy.pickWeighted(list: { Drop }, rand: () -> number): Drop
	local total = 0
	for _, d in list do
		total += d.w
	end
	local r, acc = rand() * total, 0
	for _, d in list do
		acc += d.w
		if r < acc then
			return d
		end
	end
	return list[#list]
end

-- выпадение ауры (решает только сервер)
function Economy.roll(riftId: string, rand: () -> number): string
	return Economy.pickWeighted(Economy.RIFT[riftId].drops, rand).id
end

-- лента для анимации: без одинаковых аур подряд, на позиции winAt — выигрыш
function Economy.strip(riftId: string, len: number, winAt: number, winId: string, rand: () -> number): { string }
	local show = Economy.RIFT[riftId].show
	local out = {}
	for i = 1, len do
		if i == winAt then
			out[i] = winId
		else
			local c = {}
			for _, d in show do
				if d.id ~= out[i - 1] and not (i + 1 == winAt and d.id == winId) then
					table.insert(c, d)
				end
			end
			out[i] = Economy.pickWeighted(c, rand).id
		end
	end
	return out
end

return Economy
