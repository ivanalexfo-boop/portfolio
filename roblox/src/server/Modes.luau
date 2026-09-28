-- Серверная логика режимов: апгрейд, контракт, битва, краш, колесо.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local DataService = require(script.Parent.DataService)
local Ctx = require(script.Parent.Ctx)

local AURA = Config.AURA_BY_ID
local rand = Ctx.rand

-- ================= апгрейд =================
-- положи до 8 аур → их цены складываются → шанс = (сумма + буст) / цена цели, максимум 80%
local Upgrade = Ctx.remote("RemoteFunction", "Upgrade") :: RemoteFunction
Upgrade.OnServerInvoke = function(player, uids: any, targetId: any, boost: any)
	local data = DataService.get(player)
	if not data or not Ctx.throttle(player, "upgrade", 1) then
		return { ok = false }
	end
	local target = type(targetId) == "string" and AURA[targetId]
	if not target or target.tier == "unique" then
		return { ok = false }
	end
	local picked, keep = Ctx.takeItems(data, uids, 1, Config.UPGRADE_MAX_ITEMS)
	if not picked then
		return { ok = false }
	end
	local v = 0
	for _, it in picked do
		v += it.v
	end
	if target.price <= v then
		return { ok = false, err = "cheap_target" }
	end
	boost = math.floor(tonumber(boost) or 0)
	local maxBoost = math.max(0, math.min(data.balance, math.floor(Config.UPGRADE_MAX_CHANCE * target.price - v)))
	if boost < 0 or boost > maxBoost then
		return { ok = false }
	end
	local chance = math.min(Config.UPGRADE_MAX_CHANCE, (v + boost) / target.price)
	local r = rand()
	local win = r < chance
	data.inv = keep
	data.balance -= boost
	local item = nil
	if win then
		item = Ctx.addItem(data, target.id)
		data.stats.upWin += 1
		Ctx.feed(player, target.id)
	else
		data.stats.upLose += 1
	end
	Ctx.sync(player)
	return { ok = true, win = win, chance = chance, r = r, item = item, lost = picked, boost = boost }
end

-- ================= контракт =================
-- от 3 до 10 любых аур → одна новая; шанс тира выше: 70% (3 ауры) … 100% (10 аур)
local Contract = Ctx.remote("RemoteFunction", "Contract") :: RemoteFunction
Contract.OnServerInvoke = function(player, uids: any)
	local data = DataService.get(player)
	if not data or not Ctx.throttle(player, "contract", 1) then
		return { ok = false }
	end
	local picked, keep = Ctx.takeItems(data, uids, Config.CONTRACT_MIN, Config.CONTRACT_MAX)
	if not picked then
		return { ok = false }
	end
	local sum, base = 0, 1
	for _, it in picked do
		sum += it.v
		base = math.max(base, Config.TIER_INDEX[AURA[it.id].tier])
	end
	local isUp = rand() < Economy.contractUpChance(#picked)
	local id = Economy.pickWeighted(Economy.contractPool(sum, base, isUp), rand).id
	data.inv = keep
	local item = Ctx.addItem(data, id)
	data.stats.contracts += 1
	Ctx.feed(player, id)
	Ctx.sync(player)
	return { ok = true, item = item, sum = sum, up = Config.TIER_INDEX[AURA[id].tier] > base }
end

-- ================= битва аур 1v1 с ботом =================
-- оба открывают одни и те же разломы, у кого дороже — забирает всё. Ничья → доп. раунд.
local Battle = Ctx.remote("RemoteFunction", "Battle") :: RemoteFunction
Battle.OnServerInvoke = function(player, riftIds: any, botName: any)
	local data = DataService.get(player)
	if not data or not Ctx.throttle(player, "battle", 2) then
		return { ok = false }
	end
	if type(riftIds) ~= "table" or #riftIds < 1 or #riftIds > Config.BATTLE_MAX_RIFTS then
		return { ok = false }
	end
	local cost = 0
	for _, id in riftIds do
		local rf = type(id) == "string" and Config.RIFT_BY_ID[id]
		if not rf then
			return { ok = false }
		end
		cost += rf.price
	end
	if data.balance < cost then
		return { ok = false, err = "no_money" }
	end
	if #data.inv + #riftIds * 2 + 10 > Config.INV_LIMIT then
		return { ok = false, err = "inv_full" }
	end
	local bot = if type(botName) == "string" and table.find(Config.BOTS, botName) then botName else Config.BOTS[math.random(#Config.BOTS)]
	local luck = Ctx.luck(data)
	local wantWin = rand() < Config.BATTLE_WIN
	local rounds, A, B
	for _ = 1, 200 do
		rounds, A, B = {}, 0, 0
		for _, id in riftIds do
			local a, b = Economy.roll(id, rand, luck), Economy.roll(id, rand)
			table.insert(rounds, { rf = id, a = a, b = b })
			A += AURA[a].price
			B += AURA[b].price
		end
		local guard = 0
		while A == B and guard < 20 do
			guard += 1
			local id = riftIds[math.random(#riftIds)]
			local a, b = Economy.roll(id, rand, luck), Economy.roll(id, rand)
			table.insert(rounds, { rf = id, a = a, b = b, extra = true })
			A += AURA[a].price
			B += AURA[b].price
		end
		if (A > B) == wantWin then
			break
		end
	end
	local won = A > B
	data.balance -= cost
	data.stats.battles += 1
	local prize = {}
	if won then
		data.stats.battlesWon += 1
		for _, r in rounds do
			table.insert(prize, Ctx.addItem(data, r.a))
			table.insert(prize, Ctx.addItem(data, r.b))
		end
	end
	Ctx.sync(player)
	return { ok = true, rounds = rounds, won = won, A = A, B = B, cost = cost, bot = bot, prize = prize }
end

-- ================= колесо удачи (раз в сутки) =================
local SpinWheel = Ctx.remote("RemoteFunction", "SpinWheel") :: RemoteFunction
SpinWheel.OnServerInvoke = function(player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	local now = os.time()
	local left = (data.lastWheel or 0) + Config.WHEEL_COOLDOWN - now
	if left > 0 then
		return { ok = false, err = "wait", left = left }
	end
	local list = {}
	for i, s in Config.WHEEL do
		list[i] = { id = tostring(i), w = s.w }
	end
	local idx = tonumber(Economy.pickWeighted(list, rand).id) :: number
	local s = Config.WHEEL[idx]
	data.lastWheel = now
	local item = nil
	if s.t == "coins" then
		data.balance += s.v
	elseif s.t == "speed" then
		data.speedUntil = math.max(now, data.speedUntil or 0) + Config.BOOST_TIME
	elseif s.t == "luck" then
		data.luckUntil = math.max(now, data.luckUntil or 0) + Config.BOOST_TIME
	elseif s.t == "ticket" then
		data.tickets[s.rift] = (data.tickets[s.rift] or 0) + 1
	elseif s.t == "fortune" then
		item = Ctx.addItem(data, "fortune")
		Ctx.feed(player, "fortune")
	end
	Ctx.sync(player)
	return { ok = true, index = idx, item = item }
end

-- ================= краш: общие раунды для всех игроков на сервере =================
local CrashBet = Ctx.remote("RemoteFunction", "CrashBet") :: RemoteFunction
local CrashCashout = Ctx.remote("RemoteFunction", "CrashCashout") :: RemoteFunction
local CrashState = Ctx.remote("RemoteEvent", "CrashState") :: RemoteEvent
local GetCrash = Ctx.remote("RemoteFunction", "GetCrash") :: RemoteFunction

type Bet = { name: string, bet: number, auto: number, cashed: number, bot: boolean?, target: number? }
local cr = {
	phase = "bet",
	t0 = workspace:GetServerTimeNow(), -- начало текущей фазы (общие часы сервера и клиентов)
	crashAt = 1,
	bets = {} :: { [any]: Bet },
	hist = {} :: { number },
}

local function mult(): number
	if cr.phase ~= "fly" then
		return 1
	end
	return math.exp(Config.CRASH_SPEED * (workspace:GetServerTimeNow() - cr.t0))
end

local function publicState()
	local players = {}
	for key, b in cr.bets do
		table.insert(players, { name = b.name, bet = b.bet, cashed = b.cashed, me = if typeof(key) == "Instance" then (key :: Player).UserId else nil })
	end
	table.sort(players, function(x, y)
		return x.bet > y.bet
	end)
	return {
		phase = cr.phase,
		t0 = cr.t0,
		betTime = Config.CRASH_BET_TIME,
		afterTime = Config.CRASH_AFTER_TIME,
		speed = Config.CRASH_SPEED,
		crashAt = if cr.phase == "after" then cr.crashAt else nil,
		hist = cr.hist,
		players = players,
	}
end

local function broadcast()
	CrashState:FireAllClients(publicState())
end
GetCrash.OnServerInvoke = function()
	return publicState()
end

local function newRound()
	cr.phase = "bet"
	cr.t0 = workspace:GetServerTimeNow()
	cr.crashAt = Economy.crashPoint(rand)
	cr.bets = {}
	-- несколько ботов для живости таблицы (на баланс игроков не влияют)
	local names = table.clone(Config.BOTS)
	for i = 1, math.random(3, 6) do
		local name = table.remove(names, math.random(#names))
		cr.bets["bot" .. i] = {
			name = name,
			bet = math.floor(10 ^ (1.5 + rand() * 2.3)),
			auto = 0,
			cashed = 0,
			bot = true,
			target = math.max(1.05, math.floor(math.exp(0.15 + rand() * 1.8) * 100) / 100),
		}
	end
	broadcast()
end

local function cashOut(player: Player, b: Bet, m: number)
	if b.cashed > 0 then
		return
	end
	b.cashed = math.floor(m * 100) / 100
	local data = DataService.get(player)
	if data then
		data.balance += math.floor(b.bet * b.cashed)
		data.stats.crashBest = math.max(data.stats.crashBest, b.cashed)
		Ctx.sync(player, true)
	end
end

CrashBet.OnServerInvoke = function(player, bet: any, auto: any)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	if cr.phase ~= "bet" then
		return { ok = false, err = "not_bet" }
	end
	if cr.bets[player] then
		return { ok = false, err = "already" }
	end
	bet = math.floor(tonumber(bet) or 0)
	auto = tonumber(auto) or 0
	if bet < 1 then
		return { ok = false, err = "bad" }
	end
	if bet > data.balance then
		return { ok = false, err = "no_money" }
	end
	if auto > 0 then
		auto = math.clamp(math.floor(auto * 100) / 100, 1.01, Config.CRASH_MAX)
	else
		auto = 0
	end
	data.balance -= bet
	cr.bets[player] = { name = player.DisplayName, bet = bet, auto = auto, cashed = 0 }
	Ctx.sync(player, true)
	broadcast()
	return { ok = true, balance = data.balance }
end

CrashCashout.OnServerInvoke = function(player)
	local b = cr.bets[player]
	if cr.phase ~= "fly" or not b or b.cashed > 0 then
		return { ok = false }
	end
	local m = mult()
	if m >= cr.crashAt then
		return { ok = false }
	end
	cashOut(player, b, m)
	broadcast()
	return { ok = true, cashed = b.cashed, win = math.floor(b.bet * b.cashed) }
end

Players.PlayerRemoving:Connect(function(player)
	-- если вышел во время полёта с автовыводом — ставка остаётся в раунде и может выстрелить
	local b = cr.bets[player]
	if b and cr.phase == "bet" then
		local data = DataService.get(player)
		if data then
			data.balance += b.bet -- раунд ещё не начался — вернём ставку
		end
		cr.bets[player] = nil
	end
end)

task.spawn(function()
	newRound()
	local lastBroadcast = 0
	while true do
		RunService.Heartbeat:Wait()
		local now = workspace:GetServerTimeNow()
		if cr.phase == "bet" then
			if now - cr.t0 >= Config.CRASH_BET_TIME then
				cr.phase = "fly"
				cr.t0 = now
				broadcast()
			end
		elseif cr.phase == "fly" then
			local m = mult()
			local changed = false
			if m >= cr.crashAt then
				cr.phase = "after"
				cr.t0 = now
				table.insert(cr.hist, 1, cr.crashAt)
				if #cr.hist > 16 then
					table.remove(cr.hist)
				end
				broadcast()
			else
				for key, b in cr.bets do
					if b.cashed == 0 then
						if b.bot and b.target and m >= b.target then
							b.cashed = b.target
							changed = true
						elseif typeof(key) == "Instance" and b.auto > 0 and m >= b.auto then
							cashOut(key :: Player, b, b.auto)
							changed = true
						end
					end
				end
				if changed and now - lastBroadcast > 0.2 then
					lastBroadcast = now
					broadcast()
				end
			end
		elseif cr.phase == "after" then
			if now - cr.t0 >= Config.CRASH_AFTER_TIME then
				newRound()
			end
		end
	end
end)

return {}
