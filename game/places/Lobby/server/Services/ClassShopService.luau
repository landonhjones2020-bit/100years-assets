--!strict
--[[
	ClassShopService: the Daily Class Shop, the wishlist, the free trial and the loadout (bible
	Section 14; the screens are Section 18's Class Shop and Loadout). Lobby only; Prompt 21. The
	rules are Shared.Rules.ClassShop; the shop is the profile's ClassShop record and the loadout its
	Loadout record, so both are saved and the player's own client sees them (the Profiles collection).

	* When a player's session is ready, and again whenever the UTC day turns while they are here,
	  their shop is refreshed: four classes they don't own, a due wish among them, and the day's
	  free-trial class picked from those four.
	* ShopBuy(class): a class in today's shop, paid in Glowshards; it joins the profile at level 1.
	* ShopReroll(): free while a free reroll is left (one a day, two with the VIP pass); after that
	  it opens the 99 Robux purchase (PurchaseService's ClassShopReroll), which rerolls when paid.
	* ShopWish(class | ""): the wish turns up within Tuning.ClassShop.WishlistDays shop days.
	* SetLoadoutClass(class): a class the player owns, or today's free trial.
	* Loadout(player) is what PadService sends with a run; UseTrial(player) marks the day's trial run
	  as taken when a pad leaves with it.

	What the client reads on the Player: ShopDay (the shop day now) and VIP; on ReplicatedStorage:
	ShopResetAt (server time of the next reset).

	Dev: shop, shop.new (a fresh roll, as a new day would), shop.day <n> (pretend it is n days
	later: tests wishes and resets), shop.rerolls <n> (set today's used rerolls), shop.trial
	<used|unused> (today's trial run, as a pad leaving with it would mark it).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ClassShop = require(Shared.Rules.ClassShop)
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)

local log = Log.new("ClassShopService")

local ClassShopService = {
	Name = "ClassShopService",
	Dependencies = { "SessionService", "ProfileService", "PurchaseService", "DevService" },
}

local session: any = nil
local profiles: any = nil
local purchases: any = nil

local rng = Random.new()
local dayOffset = 0 -- dev: pretend it is this many days later
local vip: { [Player]: boolean } = {}

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function today(): number
	return ClassShop.Day(os.time()) + dayOffset
end

local function isVIP(player: Player): boolean
	return vip[player] == true
end

local function checkVIP(player: Player)
	local pass = Config.Find("GamePasses", "VIP")
	local passId = pass and pass.PassId
	if not passId then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	vip[player] = ok and owns == true
	player:SetAttribute("VIP", vip[player])
end

-- A new day's shop if it is due, and a loadout that can still be played. True when anything changed.
local function refresh(player: Player): boolean
	local profile = profiles:Get(player)
	if not profile then
		return false
	end
	local day = today()
	local class = ClassShop.Loadout(profile, day)
	local stale = profile.ClassShop.Day ~= day
	if not stale and profile.Loadout.Class == class then
		player:SetAttribute("ShopDay", day)
		return false
	end
	local ok = profiles:Update(player, function(data: any)
		ClassShop.Refresh(data.ClassShop, data.Classes, day, rng)
		data.Loadout.Class = (ClassShop.Loadout(data, day))
	end)
	player:SetAttribute("ShopDay", day)
	if ok and stale then
		log:Info("%s's shop for day %d: %s (trial %s)", player.Name, day, table.concat(profiles:Get(player).ClassShop.Slots, ", "),
			tostring(profiles:Get(player).ClassShop.Trial))
	end
	return ok
end

local function onBuy(player: Player, classId: string)
	local profile = profiles:Get(player)
	if not profile then
		return
	end
	refresh(player)
	local day = today()
	local ok, why = ClassShop.CanBuy(profile, classId, day)
	if not ok then
		alert(player, "Warning", why or "IT CAN'T BE BOUGHT")
		return
	end
	local class = Config.Get("Classes", classId)
	local done = profiles:Update(player, function(data: any)
		assert(data.Glowshards >= class.Price and not data.Classes[classId], "the purchase no longer fits")
		data.Glowshards -= class.Price
		data.Classes[classId] = { Level = 1, XP = 0 }
		if data.ClassShop.Wishlist == classId then
			data.ClassShop.Wishlist, data.ClassShop.WishDay = nil, nil
		end
	end)
	if not done then
		alert(player, "Warning", "THE PURCHASE DIDN'T GO THROUGH")
		return
	end
	log:Info("%s bought %s for %d Glowshards", player.Name, classId, class.Price)
	alert(player, "Info", string.upper(`{class.Name} IS YOURS · EQUIP IT IN THE LOADOUT`))
	task.spawn(function()
		profiles:SaveNow(player)
	end)
end

local function onReroll(player: Player)
	local profile = profiles:Get(player)
	if not profile then
		return
	end
	refresh(player)
	local day = today()
	if #ClassShop.Unowned(profile.Classes) == 0 then
		alert(player, "Info", "YOU OWN EVERY CLASS")
		return
	end
	if ClassShop.FreeLeft(profile.ClassShop, isVIP(player)) > 0 then
		local ok = profiles:Update(player, function(data: any)
			ClassShop.Reroll(data.ClassShop, data.Classes, day, rng)
		end)
		if ok then
			log:Info("%s rerolled the shop (free): %s", player.Name, table.concat(profiles:Get(player).ClassShop.Slots, ", "))
			alert(player, "Info", "THE SHOP HAS NEW CLASSES")
		end
		return
	end
	local ok, why = purchases:Prompt(player, "ClassShopReroll")
	if not ok then
		alert(player, "Warning", `NO FREE REROLL LEFT TODAY · {why or "TRY AGAIN TOMORROW"}`)
	end
end

local function onWish(player: Player, classId: string)
	local profile = profiles:Get(player)
	if not profile then
		return
	end
	local day = today()
	local wanted: string? = if classId == "" then nil else classId
	local failed: string? = nil
	local ok = profiles:Update(player, function(data: any)
		local good, why = ClassShop.Wish(data.ClassShop, data.Classes, wanted, day)
		if not good then
			failed = why
		end
	end)
	if not ok or failed then
		alert(player, "Warning", failed or "THE WISH DIDN'T TAKE")
		return
	end
	if wanted then
		local class = Config.Get("Classes", wanted)
		alert(player, "Info", string.upper(`{class.Name} WISHLISTED: IN YOUR SHOP WITHIN {Config.Get("Tuning", "ClassShop").WishlistDays} DAYS`))
	else
		alert(player, "Info", "WISH CLEARED")
	end
end

local function onSetClass(player: Player, classId: string)
	local profile = profiles:Get(player)
	if not profile then
		return
	end
	refresh(player)
	local ok, trial = ClassShop.CanPlay(profile, classId, today())
	if not ok then
		alert(player, "Warning", "YOU DON'T OWN THAT CLASS")
		return
	end
	if profile.Loadout.Class == classId then
		return
	end
	local done = profiles:Update(player, function(data: any)
		data.Loadout.Class = classId
	end)
	if done then
		local class = Config.Get("Classes", classId)
		alert(player, "Info", string.upper(`{class.Name} EQUIPPED{if trial then " · TODAY'S FREE TRIAL" else ""}`))
	end
end

-- What the player brings to a run: (class, as a trial).
function ClassShopService:Loadout(player: Player): (string, boolean)
	local profile = profiles:Get(player)
	if not profile then
		return "Survivor", false
	end
	refresh(player)
	return ClassShop.Loadout(profile, today())
end

-- A run is leaving with the player's free trial: today's trial run is taken.
function ClassShopService:UseTrial(player: Player)
	profiles:Update(player, function(data: any)
		data.ClassShop.TrialUsed = true
	end)
	task.spawn(function()
		profiles:SaveNow(player)
	end)
end

local function describe(player: Player): string
	local profile = profiles:Get(player)
	if not profile then
		return `{player.Name}: no profile`
	end
	local shop = profile.ClassShop
	local day = today()
	local class, trial = ClassShop.Loadout(profile, day)
	return string.format(
		"%s: day %d (shop day %d%s), slots %s, rerolls used %d (free left %d%s), wish %s (since day %s%s), trial %s%s, loadout %s%s, %d Glowshards, resets in %d s",
		player.Name, day, shop.Day, if dayOffset ~= 0 then `, offset {dayOffset}` else "",
		if #shop.Slots > 0 then table.concat(shop.Slots, ", ") else "-", shop.RerollsUsed,
		ClassShop.FreeLeft(shop, isVIP(player)), if isVIP(player) then ", VIP" else "", tostring(shop.Wishlist or "-"),
		tostring(shop.WishDay or "-"), if ClassShop.WishDue(shop, profile.Classes, day) then ", due" else "",
		tostring(shop.Trial or "-"), if shop.TrialUsed then " (used)" else "", class, if trial then " (trial)" else "",
		profile.Glowshards, ClassShop.SecondsToReset(os.time()))
end

local function registerCommands(dev: any)
	local function target(player: Player?): Player?
		return player or Players:GetPlayers()[1]
	end
	dev:Register("shop", {
		Description = "Your Class Shop: day, slots, rerolls, wish, trial and loadout.",
		Run = function(player: Player?): string?
			local who = target(player)
			return if who then describe(who) else "no player"
		end,
	})
	dev:Register("shop.new", {
		Description = "Roll your shop again as a new day would (rerolls and the trial reset).",
		Run = function(player: Player?): string?
			local who = target(player)
			if not who then
				return "no player"
			end
			profiles:Update(who, function(data: any)
				data.ClassShop.Day = 0 -- a day long past: the next refresh rolls
			end)
			refresh(who)
			return describe(who)
		end,
	})
	dev:Register("shop.day", {
		Description = "Pretend it is n days later (0: today), then refresh everyone's shop.",
		Usage = "shop.day <n>",
		Run = function(player: Player?, args): string?
			dayOffset = math.floor(tonumber(args[1]) or 0)
			for _, other in session:ReadyPlayers() do
				refresh(other)
			end
			local who = target(player)
			return if who then describe(who) else `day offset {dayOffset}`
		end,
	})
	dev:Register("shop.trial", {
		Description = "Mark today's free-trial run as taken (used) or not (unused).",
		Usage = "shop.trial <used|unused>",
		Run = function(player: Player?, args): string?
			local who = target(player)
			local wanted = string.lower(tostring(args[1] or ""))
			if not who or (wanted ~= "used" and wanted ~= "unused") then
				return "usage: shop.trial <used|unused>"
			end
			if wanted == "used" then
				ClassShopService:UseTrial(who)
			else
				profiles:Update(who, function(data: any)
					data.ClassShop.TrialUsed = nil
				end)
			end
			refresh(who)
			return describe(who)
		end,
	})
	dev:Register("shop.rerolls", {
		Description = "Set how many rerolls you have used today.",
		Usage = "shop.rerolls <n>",
		Run = function(player: Player?, args): string?
			local who = target(player)
			if not who then
				return "no player"
			end
			profiles:Update(who, function(data: any)
				data.ClassShop.RerollsUsed = math.max(0, math.floor(tonumber(args[1]) or 0))
			end)
			return describe(who)
		end,
	})
end

function ClassShopService:Init(registry)
	session = registry.SessionService
	profiles = registry.ProfileService
	purchases = registry.PurchaseService
	Remotes.OnServer("ShopBuy", onBuy)
	Remotes.OnServer("ShopReroll", onReroll)
	Remotes.OnServer("ShopWish", onWish)
	Remotes.OnServer("SetLoadoutClass", onSetClass)
	registerCommands(registry.DevService)
end

function ClassShopService:Start()
	local function onReady(player: Player)
		refresh(player)
		task.spawn(checkVIP, player)
	end
	session.PlayerReady:Connect(onReady)
	for _, player in session:ReadyPlayers() do
		onReady(player)
	end
	session.PlayerLeaving:Connect(function(player: Player)
		vip[player] = nil
	end)
	purchases.Granted:Connect(function(player: Player, product: string)
		if product == "ClassShopReroll" then
			alert(player, "Info", "THE SHOP HAS NEW CLASSES · THANK YOU")
		end
	end)
	ReplicatedStorage:SetAttribute("ShopResetAt", workspace:GetServerTimeNow() + ClassShop.SecondsToReset(os.time()))
	-- the day turns at 00:00 UTC for everyone who is here
	task.spawn(function()
		local last = today()
		while true do
			task.wait(20)
			local day = today()
			if day ~= last then
				last = day
				ReplicatedStorage:SetAttribute("ShopResetAt", workspace:GetServerTimeNow() + ClassShop.SecondsToReset(os.time()))
				for _, player in session:ReadyPlayers() do
					if refresh(player) then
						alert(player, "Info", "A NEW DAY: THE CLASS SHOP HAS RESTOCKED")
					end
				end
			end
		end
	end)
	log:Info("class shop ready: %d classes for sale, day %d", #ClassShop.Unowned({}), today())
end

return ClassShopService
