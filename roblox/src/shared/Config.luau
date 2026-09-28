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

-- ===== картинки (загружены в Roblox) =====
-- листы: все ауры на одной картинке, все разломы на другой; ATLAS — где какая лежит
Config.IMAGES = {
	auras = "rbxassetid://125384373148579",
	rifts = "rbxassetid://114109902820743",
	tom = "rbxassetid://132231415903419",
	rocket = "rbxassetid://76423203466143",
	background = "rbxassetid://75409017923246",
}
Config.ATLAS = {
	auraCell = 170,
	riftCell = 256,
	auras = {
		dust = { 0, 0 },
		sparkle = { 170, 0 },
		blizzard = { 340, 0 },
		bubbles = { 510, 0 },
		acidrain = { 680, 0 },
		wind = { 850, 0 },
		static = { 0, 170 },
		neonpulse = { 170, 170 },
		poltergeist = { 340, 170 },
		earthroot = { 510, 170 },
		sglaz = { 680, 170 },
		hacker = { 850, 170 },
		gluhwein = { 0, 340 },
		vampire = { 170, 340 },
		mirageshard = { 340, 340 },
		phantasm = { 510, 340 },
		stardust = { 680, 340 },
		leviathan = { 850, 340 },
		nebula = { 0, 510 },
		halo = { 170, 510 },
		angelic = { 340, 510 },
		timestop = { 510, 510 },
		quantumflux = { 680, 510 },
		blackout = { 850, 510 },
		singularity = { 0, 680 },
		solar = { 170, 680 },
		chronos = { 340, 680 },
		eclipse = { 510, 680 },
		fortune = { 680, 680 },
	},
	rifts = {
		echo = { 0, 0 },
		bio = { 256, 0 },
		prism = { 512, 0 },
		vault = { 768, 0 },
		cyber = { 0, 256 },
		trench = { 256, 256 },
		shadow = { 512, 256 },
		mirage = { 768, 256 },
		cosmic = { 0, 512 },
		gates = { 256, 512 },
		quantum = { 512, 512 },
	},
}

-- ===== режимы (значения как в веб-версии) =====
Config.AFK_EVERY = 10            -- каждые 10 секунд онлайн...
Config.AFK_GAIN = 100            -- ...+100 монет (x2 с бустом скорости)
Config.LUCK_REROLL = 0.15        -- удача: 15% шанс перекрутить дроп и взять дороже

Config.UPGRADE_MAX_CHANCE = 0.8  -- максимум шанса апгрейда
Config.UPGRADE_MAX_ITEMS = 8     -- сколько аур можно положить в апгрейд

Config.CONTRACT_MIN = 3
Config.CONTRACT_MAX = 10          -- шанс «тиром выше»: 3 ауры — 70%, 10 аур — 100%

Config.BATTLE_WIN = 0.7           -- шанс игрока выиграть битву с ботом
Config.BATTLE_MAX_RIFTS = 6

Config.CRASH_K = 1.75             -- медиана полёта ≈ 3.5×
Config.CRASH_MAX = 50             -- потолок икса
Config.CRASH_SPEED = 0.12         -- множитель = e^(0.12 × секунды полёта)
Config.CRASH_BET_TIME = 7         -- секунд на ставки
Config.CRASH_AFTER_TIME = 3.2     -- пауза после взрыва

Config.WHEEL_COOLDOWN = 24 * 3600 -- колесо раз в сутки
export type WheelSeg = { t: string, w: number, color: Color3, v: number?, rift: string?, en: string?, ru: string? }
Config.WHEEL = {
	{ t = "coins", v = 1000, w = 25, color = Color3.fromRGB(75, 139, 255) },
	{ t = "speed", w = 10, color = Color3.fromRGB(139, 92, 255), en = "Speed x2", ru = "Скорость x2" },
	{ t = "coins", v = 2500, w = 10, color = Color3.fromRGB(109, 40, 217) },
	{ t = "luck", w = 12, color = Color3.fromRGB(62, 240, 143), en = "Luck +15%", ru = "Удача +15%" },
	{ t = "coins", v = 5000, w = 14, color = Color3.fromRGB(34, 230, 255) },
	{ t = "ticket", rift = "prism", w = 9, color = Color3.fromRGB(255, 61, 203), en = "Ticket", ru = "Билет" },
	{ t = "coins", v = 10000, w = 9, color = Color3.fromRGB(255, 154, 31) },
	{ t = "coins", v = 25000, w = 5, color = Color3.fromRGB(255, 197, 61) },
	{ t = "ticket", rift = "vault", w = 4, color = Color3.fromRGB(176, 77, 255), en = "Ticket+", ru = "Билет+" },
	{ t = "coins", v = 100000, w = 1.9, color = Color3.fromRGB(255, 77, 109) },
	{ t = "fortune", w = 0.1, color = Color3.fromRGB(255, 255, 255), en = "FORTUNE", ru = "FORTUNE" },
} :: { WheelSeg }
Config.BOOST_TIME = 3600          -- удача и скорость с колеса действуют 1 час

-- промокоды: +монеты один раз. INFINITY — бесконечный баланс, только для владельца игры и в Studio
Config.PROMOS = { VANYA1M = 1_000_000 }

Config.BOTS = { "xX_Shadow_Xx", "NeoKid", "auraFarmer", "Lexa228", "zxc_ghost", "Mira", "pro_gamer67", "kittyUwU", "Dimon", "VoidWalker", "sanya_2009", "Nikita_Pro", "ne_vezet", "Grisha", "hellcat", "NoobMaster" }

-- звуки из веб-демо, загружены в Roblox
Config.SOUNDS = {
	tick = "rbxassetid://105329459015835", -- деревянный щелчок прокрутки
	tap = "rbxassetid://90707289737194", -- механическая клавиатура (кликер)
	win = "rbxassetid://117250031511376", -- радостная фанфара
	win_big = "rbxassetid://94131572806172", -- большая фанфара (крупный выигрыш)
	lose = "rbxassetid://130283317842912", -- грустная мелодия
	coin = "rbxassetid://98897028893667", -- звон монет при продаже
	open = "",
}

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
