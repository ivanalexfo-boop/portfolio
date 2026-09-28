-- Сервер «Битвы Аур»: вся логика и все шансы — только здесь, клиент лишь показывает.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local DataService = require(script.Parent.DataService)
local Ctx = require(script.Parent.Ctx)

local GetState = Ctx.remote("RemoteFunction", "GetState") :: RemoteFunction
local OpenRift = Ctx.remote("RemoteFunction", "OpenRift") :: RemoteFunction
local SellItems = Ctx.remote("RemoteFunction", "SellItems") :: RemoteFunction
local SellAll = Ctx.remote("RemoteFunction", "SellAll") :: RemoteFunction
local Redeem = Ctx.remote("RemoteFunction", "Redeem") :: RemoteFunction
local Tap = Ctx.remote("RemoteEvent", "Tap") :: RemoteEvent

-- ===== игроки =====
local ready: { [Player]: boolean } = {}

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = ls
	ls.Parent = player
	local data = DataService.load(player)
	Ctx.normalize(data)
	ready[player] = true
	Ctx.leaderstats(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
-- в Studio игрок может зайти раньше, чем скрипт подписался на событие
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	ready[player] = nil
	DataService.release(player)
end)

GetState.OnServerInvoke = function(player)
	local t = os.clock()
	while not ready[player] and player.Parent and os.clock() - t < 30 do
		task.wait(0.1)
	end
	local data = DataService.get(player)
	return data and Ctx.snapshot(data)
end

-- ===== разломы =====
OpenRift.OnServerInvoke = function(player, riftId: any, count: any, byTicket: any)
	local data = DataService.get(player)
	if not data then
		return { ok = false, err = "loading" }
	end
	if type(riftId) ~= "string" or not Config.RIFT_BY_ID[riftId] then
		return { ok = false, err = "bad" }
	end
	count = tonumber(count)
	if not count or count ~= math.floor(count) or count < 1 or count > Config.MAX_OPEN then
		return { ok = false, err = "bad" }
	end
	if not Ctx.throttle(player, "open", 0.5) then
		return { ok = false, err = "too_fast" }
	end
	local rf = Config.RIFT_BY_ID[riftId]
	if byTicket == true then
		if (data.tickets[riftId] or 0) < 1 then
			return { ok = false, err = "no_ticket" }
		end
		count = 1
	elseif data.balance < rf.price * count then
		return { ok = false, err = "no_money" }
	end
	if #data.inv + count > Config.INV_LIMIT then
		return { ok = false, err = "inv_full" }
	end
	if byTicket == true then
		data.tickets[riftId] -= 1
	else
		data.balance -= rf.price * count
	end
	local items = {}
	local luck = Ctx.luck(data)
	for _ = 1, count do
		local item = Ctx.addItem(data, Economy.roll(riftId, Ctx.rand, luck))
		data.stats.opened += 1
		table.insert(items, item)
		Ctx.feed(player, item.id)
	end
	Ctx.sync(player)
	return { ok = true, items = items, balance = data.balance }
end

-- ===== продажа =====
SellItems.OnServerInvoke = function(player, uids: any)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	local picked, keep = Ctx.takeItems(data, uids, 1, Config.INV_LIMIT)
	if not picked then
		return { ok = false }
	end
	local total = 0
	for _, it in picked do
		total += it.v
	end
	data.inv = keep
	data.balance += total
	Ctx.sync(player)
	return { ok = true, total = total, balance = data.balance }
end

SellAll.OnServerInvoke = function(player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	local total = 0
	for _, it in data.inv do
		total += it.v
	end
	data.inv = {}
	data.balance += total
	Ctx.sync(player)
	return { ok = true, total = total, balance = data.balance }
end

-- ===== промокоды =====
Redeem.OnServerInvoke = function(player, code: any)
	local data = DataService.get(player)
	if not data or type(code) ~= "string" then
		return { ok = false, err = "bad" }
	end
	code = string.upper((code:gsub("%s", "")))
	if code == "INFINITY" then
		-- только владелец игры (или тест в Studio)
		if not (RunService:IsStudio() or player.UserId == game.CreatorId) then
			return { ok = false, err = "no_code" }
		end
		data.infinite = not data.infinite
		if not data.infinite then
			data.balance = math.min(data.balance, Config.START_BALANCE)
		end
		Ctx.sync(player)
		return { ok = true, infinite = data.infinite }
	end
	local gain = Config.PROMOS[code]
	if not gain then
		return { ok = false, err = "no_code" }
	end
	if data.promos[code] then
		return { ok = false, err = "used" }
	end
	data.promos[code] = true
	data.balance += gain
	Ctx.sync(player)
	return { ok = true, gain = gain }
end

-- ===== кликер: +150 за тап, не чаще CLICK_MAX_PER_SEC раз в секунду =====
local tapWindow: { [Player]: { t: number, n: number } } = {}
Tap.OnServerEvent:Connect(function(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local now = os.clock()
	local w = tapWindow[player]
	if not w or now - w.t >= 1 then
		w = { t = now, n = 0 }
		tapWindow[player] = w
	end
	if w.n >= Config.CLICK_MAX_PER_SEC then
		return
	end
	w.n += 1
	data.balance += Config.CLICK_GAIN
	data.stats.clicks += 1
	data.stats.clickEarned += Config.CLICK_GAIN
	Ctx.sync(player, true)
end)
Players.PlayerRemoving:Connect(function(player)
	tapWindow[player] = nil
end)

-- ===== AFK-фарм: пока игрок в игре, каждые 10 секунд капают монеты =====
task.spawn(function()
	while true do
		task.wait(Config.AFK_EVERY)
		for player in ready do
			local data = DataService.get(player)
			if data then
				local g = Config.AFK_GAIN * (if Ctx.speed(data) then 2 else 1)
				data.balance += g
				data.stats.afk += g
				Ctx.sync(player, true)
			end
		end
	end
end)

-- ===== остальные режимы =====
require(script.Parent.Modes)
