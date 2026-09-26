-- Сохранение прогресса игроков в DataStore.
-- Если DataStore недоступен (например, в Studio не включён доступ к API),
-- игрок играет со свежим прогрессом, но он НЕ сохраняется — чтобы не затереть настоящий.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local STORE_NAME = "AuraBattle_v1"
local AUTOSAVE_EVERY = 90

local DataService = {}

export type Item = { u: number, id: string, v: number }
export type Data = {
	v: number,
	balance: number,
	inv: { Item },
	uid: number,
	stats: { opened: number, clicks: number, clickEarned: number, best: number },
}

local store = nil
do
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = res
	else
		warn("[AuraBattle] DataStore недоступен:", res)
	end
end

local profiles: { [Player]: { data: Data, canSave: boolean, dirty: boolean } } = {}

local function fresh(): Data
	return {
		v = 1,
		balance = Config.START_BALANCE,
		inv = {},
		uid = 1,
		stats = { opened = 0, clicks = 0, clickEarned = 0, best = 0 },
	}
end

-- дополняем старые сохранения новыми полями и выкидываем ауры, которых больше нет
local function reconcile(d: any): Data
	local base = fresh()
	if type(d) ~= "table" then
		return base
	end
	for k, v in base do
		if d[k] == nil then
			d[k] = v
		end
	end
	for k, v in base.stats do
		if d.stats[k] == nil then
			d.stats[k] = v
		end
	end
	local inv = {}
	for _, it in d.inv do
		if type(it) == "table" and Config.AURA_BY_ID[it.id] then
			table.insert(inv, it)
		end
	end
	d.inv = inv
	return d
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

function DataService.load(player: Player): Data
	if not store then
		profiles[player] = { data = fresh(), canSave = false, dirty = false }
		return profiles[player].data
	end
	local data, loaded = nil, false
	for attempt = 1, 4 do
		local ok, res = pcall(function()
			return store:GetAsync(key(player))
		end)
		if ok then
			data, loaded = res, true
			break
		end
		warn(("[AuraBattle] загрузка %s, попытка %d: %s"):format(player.Name, attempt, tostring(res)))
		task.wait(attempt)
	end
	profiles[player] = { data = reconcile(data), canSave = loaded, dirty = false }
	if not loaded then
		warn("[AuraBattle] прогресс не загрузился — в этой сессии он не будет сохраняться")
	end
	return profiles[player].data
end

function DataService.get(player: Player): Data?
	local p = profiles[player]
	return p and p.data
end

function DataService.markDirty(player: Player)
	local p = profiles[player]
	if p then
		p.dirty = true
	end
end

function DataService.save(player: Player, force: boolean?)
	local p = profiles[player]
	if not p or not p.canSave or not store then
		return
	end
	if not p.dirty and not force then
		return
	end
	p.dirty = false
	local snapshot = table.clone(p.data)
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function()
			return snapshot
		end)
	end)
	if not ok then
		p.dirty = true
		warn("[AuraBattle] не удалось сохранить", player.Name, err)
	end
end

function DataService.release(player: Player)
	DataService.save(player, true)
	profiles[player] = nil
end

-- автосохранение
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_EVERY)
		for player in profiles do
			task.spawn(DataService.save, player)
		end
	end
end)

-- при выключении сервера сохраняем всех
game:BindToClose(function()
	if RunService:IsStudio() and not store then
		return
	end
	local left = 0
	for _, player in Players:GetPlayers() do
		left += 1
		task.spawn(function()
			DataService.save(player, true)
			left -= 1
		end)
	end
	local t = os.clock()
	while left > 0 and os.clock() - t < 25 do
		task.wait(0.2)
	end
end)

return DataService
