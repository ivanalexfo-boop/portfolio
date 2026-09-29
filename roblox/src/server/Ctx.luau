-- Общие серверные помощники: предметы, синхронизация с клиентом, удача, бесконечный баланс
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)

local Ctx = {}
Ctx.INF = 1e15

local rng = Random.new()
function Ctx.rand(): number
	return rng:NextNumber()
end

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
function Ctx.remote(className: string, name: string): any
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local StateChanged = Ctx.remote("RemoteEvent", "StateChanged") :: RemoteEvent
local Feed = Ctx.remote("RemoteEvent", "Feed") :: RemoteEvent

function Ctx.luck(data): boolean
	return (data.luckUntil or 0) > os.time()
end
function Ctx.speed(data): boolean
	return (data.speedUntil or 0) > os.time()
end

-- бесконечный баланс (промокод INFINITY) держит монеты на квадриллионе
function Ctx.normalize(data)
	if data.infinite and data.balance < Ctx.INF then
		data.balance = Ctx.INF
	end
end

function Ctx.addItem(data, id: string)
	local item = { u = data.uid, id = id, v = Config.AURA_BY_ID[id].price }
	data.uid += 1
	table.insert(data.inv, 1, item)
	data.collected[id] = true
	data.stats.best = math.max(data.stats.best, item.v)
	return item
end

-- снять предметы по списку uid; вернёт nil, если хоть одного нет или есть повторы
function Ctx.takeItems(data, uids: any, minN: number, maxN: number)
	if type(uids) ~= "table" or #uids < minN or #uids > maxN then
		return nil
	end
	local want = {}
	for _, u in uids do
		if type(u) ~= "number" or want[u] then
			return nil
		end
		want[u] = true
	end
	local picked, keep = {}, {}
	for _, it in data.inv do
		if want[it.u] then
			table.insert(picked, it)
		else
			table.insert(keep, it)
		end
	end
	if #picked ~= #uids then
		return nil
	end
	return picked, keep
end

function Ctx.leaderstats(player: Player)
	local data = DataService.get(player)
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if data and coins then
		(coins :: StringValue).Value = if data.infinite then "∞" else Format.coins(data.balance)
	end
end

-- полное состояние игрока для клиента
function Ctx.snapshot(data)
	return {
		balance = data.balance,
		inv = data.inv,
		collected = data.collected,
		lastWheel = data.lastWheel,
		luckUntil = data.luckUntil,
		speedUntil = data.speedUntil,
		tickets = data.tickets,
		stats = data.stats,
		infinite = data.infinite,
		now = os.time(),
	}
end

function Ctx.sync(player: Player, balanceOnly: boolean?)
	local data = DataService.get(player)
	if not data then
		return
	end
	Ctx.normalize(data)
	DataService.markDirty(player)
	Ctx.leaderstats(player)
	if balanceOnly then
		StateChanged:FireClient(player, { balance = data.balance })
	else
		StateChanged:FireClient(player, Ctx.snapshot(data))
	end
end

-- лента дропов для всех игроков на сервере (только заметные)
function Ctx.feed(player: Player, id: string)
	local a = Config.AURA_BY_ID[id]
	if a and Config.TIER_INDEX[a.tier] >= 3 then
		Feed:FireAllClients({ name = player.DisplayName, id = id })
	end
end

-- простая защита от спама запросами
local last: { [Player]: { [string]: number } } = {}
function Ctx.throttle(player: Player, key: string, gap: number): boolean
	local t = last[player]
	if not t then
		t = {}
		last[player] = t
	end
	local now = os.clock()
	if t[key] and now - t[key] < gap then
		return false
	end
	t[key] = now
	return true
end
game:GetService("Players").PlayerRemoving:Connect(function(p)
	last[p] = nil
end)

return Ctx
