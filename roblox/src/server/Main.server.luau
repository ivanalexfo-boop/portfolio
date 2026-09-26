-- Сервер «Битвы Аур»: вся логика и все шансы — только здесь, клиент лишь показывает.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)

-- ===== remotes =====
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className: string, name: string)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local GetState = remote("RemoteFunction", "GetState") :: RemoteFunction
local OpenRift = remote("RemoteFunction", "OpenRift") :: RemoteFunction
local SellItems = remote("RemoteFunction", "SellItems") :: RemoteFunction
local SellAll = remote("RemoteFunction", "SellAll") :: RemoteFunction
local Tap = remote("RemoteEvent", "Tap") :: RemoteEvent
local StateChanged = remote("RemoteEvent", "StateChanged") :: RemoteEvent
remotes.Parent = ReplicatedStorage

local rng = Random.new()
local function rand(): number
	return rng:NextNumber()
end

-- ===== leaderstats =====
local function updateLeaderstats(player: Player)
	local data = DataService.get(player)
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if data and coins then
		(coins :: StringValue).Value = Format.coins(data.balance)
	end
end

local function pushBalance(player: Player)
	local data = DataService.get(player)
	if data then
		StateChanged:FireClient(player, { balance = data.balance })
		updateLeaderstats(player)
	end
end

local ready: { [Player]: boolean } = {}

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = ls
	ls.Parent = player
	DataService.load(player)
	ready[player] = true
	updateLeaderstats(player)
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

local function waitReady(player: Player)
	local t = os.clock()
	while not ready[player] and player.Parent and os.clock() - t < 30 do
		task.wait(0.1)
	end
	return DataService.get(player)
end

GetState.OnServerInvoke = function(player)
	local data = waitReady(player)
	if not data then
		return nil
	end
	return { balance = data.balance, inv = data.inv, stats = data.stats }
end

-- ===== разломы =====
local lastOpen: { [Player]: number } = {}

OpenRift.OnServerInvoke = function(player, riftId: any, count: any)
	local data = DataService.get(player)
	if not data then
		return { ok = false, err = "loading" }
	end
	if type(riftId) ~= "string" or not Config.RIFT_BY_ID[riftId] then
		return { ok = false, err = "bad_rift" }
	end
	count = tonumber(count)
	if not count or count ~= math.floor(count) or count < 1 or count > Config.MAX_OPEN then
		return { ok = false, err = "bad_count" }
	end
	local now = os.clock()
	if lastOpen[player] and now - lastOpen[player] < 0.5 then
		return { ok = false, err = "too_fast" }
	end
	lastOpen[player] = now
	local rf = Config.RIFT_BY_ID[riftId]
	local cost = rf.price * count
	if data.balance < cost then
		return { ok = false, err = "no_money" }
	end
	if #data.inv + count > Config.INV_LIMIT then
		return { ok = false, err = "inv_full" }
	end
	data.balance -= cost
	local items = {}
	for _ = 1, count do
		local id = Economy.roll(riftId, rand)
		local item = { u = data.uid, id = id, v = Config.AURA_BY_ID[id].price }
		data.uid += 1
		table.insert(data.inv, 1, item)
		table.insert(items, item)
		data.stats.opened += 1
		data.stats.best = math.max(data.stats.best, item.v)
	end
	DataService.markDirty(player)
	updateLeaderstats(player)
	return { ok = true, items = items, balance = data.balance }
end

-- ===== продажа =====
SellItems.OnServerInvoke = function(player, uids: any)
	local data = DataService.get(player)
	if not data or type(uids) ~= "table" or #uids > Config.INV_LIMIT then
		return { ok = false }
	end
	local want = {}
	for _, u in uids do
		if type(u) == "number" then
			want[u] = true
		end
	end
	local keep, total, sold = {}, 0, 0
	for _, it in data.inv do
		if want[it.u] then
			total += it.v
			sold += 1
		else
			table.insert(keep, it)
		end
	end
	data.inv = keep
	data.balance += total
	DataService.markDirty(player)
	updateLeaderstats(player)
	return { ok = true, sold = sold, total = total, balance = data.balance }
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
	local sold = #data.inv
	data.inv = {}
	data.balance += total
	DataService.markDirty(player)
	updateLeaderstats(player)
	return { ok = true, sold = sold, total = total, balance = data.balance }
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
	DataService.markDirty(player)
	pushBalance(player)
end)

Players.PlayerRemoving:Connect(function(player)
	tapWindow[player] = nil
	lastOpen[player] = nil
end)
