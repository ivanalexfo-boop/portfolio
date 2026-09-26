--!strict
-- Каталог аур и разломов. Перенесено из веб-версии «Битва Аур».
-- image: сюда можно вписать rbxassetid://... загруженной картинки ауры (пока пусто — рисуется цветная сфера).
local Config = {}

Config.START_BALANCE = 1_000_000
Config.CLICK_GAIN = 150          -- монет за один тап в кликере
Config.CLICK_MAX_PER_SEC = 12    -- защита от автокликера
Config.RTP = 0.97                -- в среднем разлом возвращает 97% цены
Config.LOSS = 0.3                -- 30% дропов дешевле разлома, 70% окупают
Config.MAX_OPEN = 5              -- сколько разломов можно открыть за раз
Config.INV_LIMIT = 400           -- лимит предметов в инвентаре (чтобы сохранение не разрасталось)
Config.CLICKER_IMAGE = ""         -- rbxassetid://... картинки персонажа для кликера (пусто — светящаяся сфера TAP)

Config.TIERS = {
	{ key = "common",   en = "Common",   ru = "Обычная",    color = Color3.fromRGB(195, 202, 216) },
	{ key = "uncommon", en = "Uncommon", ru = "Необычная",  color = Color3.fromRGB(62, 240, 143) },
	{ key = "rare",     en = "Rare",     ru = "Редкая",     color = Color3.fromRGB(75, 139, 255) },
	{ key = "epic",     en = "Epic",     ru = "Эпическая",  color = Color3.fromRGB(176, 77, 255) },
	{ key = "mythic",   en = "Mythic",   ru = "Мифическая", color = Color3.fromRGB(255, 197, 61) },
	{ key = "anomaly",  en = "Anomaly",  ru = "Аномалия",   color = Color3.fromRGB(255, 106, 43) },
	{ key = "unique",   en = "Unique",   ru = "Уникальная", color = Color3.fromRGB(255, 255, 255) },
}
Config.TIER_INDEX = {} :: { [string]: number }
for i, t in Config.TIERS do
	Config.TIER_INDEX[t.key] = i
end

export type Aura = { id: string, en: string, ru: string, tier: string, price: number, colors: { Color3 }, image: string }
export type Rift = { id: string, en: string, ru: string, price: number, c1: Color3, c2: Color3, button: string, core: { string }, image: string }

Config.AURAS = {
	{ id = "dust", en = "Dust", ru = "Пыль", tier = "common", price = 750, colors = { Color3.fromRGB(227, 194, 143), Color3.fromRGB(138, 109, 59) }, image = "" },
	{ id = "sparkle", en = "Sparkle", ru = "Искра", tier = "common", price = 5000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "blizzard", en = "Blizzard", ru = "Метель", tier = "rare", price = 15000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "bubbles", en = "Bubbles", ru = "Пузыри", tier = "common", price = 25000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "acidrain", en = "Acid Rain", ru = "Кислотный дождь", tier = "epic", price = 80000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "wind", en = "Wind", ru = "Ethereal", tier = "uncommon", price = 150000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "static", en = "Static", ru = "Статика", tier = "common", price = 500000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "neonpulse", en = "Neon Pulse", ru = "Неоновый пульс", tier = "rare", price = 500000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "poltergeist", en = "Poltergeist", ru = "Полтергейст", tier = "epic", price = 1750000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "earthroot", en = "Earth Root", ru = "Корень Земли", tier = "common", price = 2500000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "sglaz", en = "Evil Eye", ru = "Сглаз", tier = "uncommon", price = 7500000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "hacker", en = "Hacker's Domain", ru = "Домен Хакера", tier = "epic", price = 8000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "gluhwein", en = "Glühwein", ru = "Глинтвейн", tier = "rare", price = 25000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "vampire", en = "Vampire Swarm", ru = "Рой вампиров", tier = "epic", price = 80000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "mirageshard", en = "Mirage Shard", ru = "Осколок миража", tier = "uncommon", price = 100000000, colors = { Color3.fromRGB(241, 228, 255), Color3.fromRGB(183, 125, 255), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "phantasm", en = "Phantasm", ru = "Фантазм", tier = "epic", price = 350000000, colors = { Color3.fromRGB(233, 213, 255), Color3.fromRGB(126, 34, 206) }, image = "" },
	{ id = "stardust", en = "Stardust", ru = "Звёздная пыль", tier = "uncommon", price = 500000000, colors = { Color3.fromRGB(255, 246, 216), Color3.fromRGB(255, 197, 61), Color3.fromRGB(255, 122, 26) }, image = "" },
	{ id = "leviathan", en = "Leviathan's Gaze", ru = "Взгляд Левиафана", tier = "mythic", price = 850000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "nebula", en = "Nebula", ru = "Туманность", tier = "epic", price = 1500000000, colors = { Color3.fromRGB(255, 214, 236), Color3.fromRGB(255, 61, 203), Color3.fromRGB(109, 40, 217) }, image = "" },
	{ id = "halo", en = "Halo", ru = "Нимб", tier = "rare", price = 2500000000, colors = { Color3.fromRGB(255, 251, 230), Color3.fromRGB(255, 227, 138), Color3.fromRGB(255, 197, 61) }, image = "" },
	{ id = "angelic", en = "Angelic Rings", ru = "Ангельские Кольца", tier = "mythic", price = 3000000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "timestop", en = "Time Stop", ru = "Остановка времени", tier = "mythic", price = 8000000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "quantumflux", en = "Quantum Flux", ru = "Квантовый поток", tier = "rare", price = 10000000000, colors = { Color3.fromRGB(233, 213, 255), Color3.fromRGB(139, 92, 255), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "blackout", en = "Blackout", ru = "Затемнение", tier = "anomaly", price = 15000000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "singularity", en = "Singularity Pulse", ru = "Пульс сингулярности", tier = "anomaly", price = 35000000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "solar", en = "Solar System", ru = "Солнечная система", tier = "anomaly", price = 65000000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "chronos", en = "Chronos", ru = "Хронос", tier = "anomaly", price = 250000000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "eclipse", en = "Eclipse", ru = "Затмение", tier = "anomaly", price = 1500000000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
	{ id = "fortune", en = "Fortune", ru = "Фортуна", tier = "unique", price = 3000000000000, colors = { Color3.fromRGB(255, 197, 61), Color3.fromRGB(62, 240, 143), Color3.fromRGB(255, 61, 203), Color3.fromRGB(34, 230, 255) }, image = "" },
} :: { Aura }

Config.RIFTS = {
	{ id = "echo", en = "Echo Sphere", ru = "Эхо-Сфера", price = 5000, c1 = Color3.fromRGB(62, 240, 143), c2 = Color3.fromRGB(29, 107, 58), button = "green", core = { "dust", "sparkle", "blizzard", "wind" }, image = "" },
	{ id = "bio", en = "Bio-Capsule", ru = "Био-Капсула", price = 25000, c1 = Color3.fromRGB(125, 255, 74), c2 = Color3.fromRGB(29, 107, 58), button = "green", core = { "sparkle", "bubbles", "acidrain", "poltergeist" }, image = "" },
	{ id = "prism", en = "Prismatic Rift", ru = "Призматический Разлом", price = 150000, c1 = Color3.fromRGB(34, 230, 255), c2 = Color3.fromRGB(29, 78, 216), button = "green", core = { "bubbles", "wind", "neonpulse", "hacker" }, image = "" },
	{ id = "vault", en = "Clockwork Vault", ru = "Механический Сейф", price = 500000, c1 = Color3.fromRGB(224, 168, 74), c2 = Color3.fromRGB(107, 74, 29), button = "green", core = { "acidrain", "static", "poltergeist", "gluhwein" }, image = "" },
	{ id = "cyber", en = "Cyber Core", ru = "Кибер-Ядро", price = 2500000, c1 = Color3.fromRGB(75, 139, 255), c2 = Color3.fromRGB(139, 92, 255), button = "blue", core = { "static", "earthroot", "hacker", "leviathan" }, image = "" },
	{ id = "trench", en = "Abyssal Trench", ru = "Бездна Океана", price = 7500000, c1 = Color3.fromRGB(34, 166, 255), c2 = Color3.fromRGB(11, 42, 107), button = "blue", core = { "poltergeist", "sglaz", "gluhwein", "leviathan" }, image = "" },
	{ id = "shadow", en = "Shadow Monolith", ru = "Теневой Монолит", price = 25000000, c1 = Color3.fromRGB(255, 61, 90), c2 = Color3.fromRGB(126, 34, 206), button = "purple", core = { "sglaz", "gluhwein", "vampire", "angelic" }, image = "" },
	{ id = "mirage", en = "Mirage Glass", ru = "Зеркало Иллюзий", price = 100000000, c1 = Color3.fromRGB(183, 125, 255), c2 = Color3.fromRGB(34, 230, 255), button = "purple", core = { "gluhwein", "mirageshard", "phantasm", "blackout" }, image = "" },
	{ id = "cosmic", en = "Cosmic Singularity", ru = "Космическая Сингулярность", price = 500000000, c1 = Color3.fromRGB(255, 197, 61), c2 = Color3.fromRGB(255, 122, 26), button = "purple", core = { "vampire", "stardust", "nebula", "solar" }, image = "" },
	{ id = "gates", en = "Celestial Gates", ru = "Врата Небожителей", price = 2500000000, c1 = Color3.fromRGB(255, 241, 184), c2 = Color3.fromRGB(255, 197, 61), button = "gold", core = { "stardust", "halo", "timestop", "chronos" }, image = "" },
	{ id = "quantum", en = "Quantum Paradox", ru = "Квантовый Парадокс", price = 10000000000, c1 = Color3.fromRGB(182, 156, 255), c2 = Color3.fromRGB(109, 40, 217), button = "gold", core = { "halo", "quantumflux", "singularity", "eclipse" }, image = "" },
} :: { Rift }

Config.AURA_BY_ID = {} :: { [string]: Aura }
for _, a in Config.AURAS do
	Config.AURA_BY_ID[a.id] = a
end
Config.RIFT_BY_ID = {} :: { [string]: Rift }
for _, r in Config.RIFTS do
	Config.RIFT_BY_ID[r.id] = r
end

-- редкость зависит от цены: чем дороже аура, тем выше тир (как в веб-версии)
do
	local list = {}
	for _, a in Config.AURAS do
		if a.tier ~= "unique" then
			table.insert(list, a)
		end
	end
	table.sort(list, function(x, y)
		return x.price < y.price
	end)
	local plan = { "common", "uncommon", "rare", "epic", "mythic", "anomaly" }
	for i, a in list do
		a.tier = plan[math.min(#plan, math.floor((i - 1) / #list * #plan) + 1)]
	end
end

return Config
