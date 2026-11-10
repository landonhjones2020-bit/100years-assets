--!strict
--[[
	Rules.ClassShop: the Daily Class Shop, the wishlist and the free trial (bible Section 14).
	Pure, so ClassShopService, the Class Shop screen and the data tests share it. The numbers are
	Tuning.ClassShop; the shop itself is the profile's ClassShop record:

		{ Day, Slots = { class ids }, RerollsUsed, Wishlist?, WishDay?, Trial?, TrialUsed? }

	* "4 classes you don't own, refreshed daily at 00:00 UTC": Day(now) is the shop day; Refresh
	  rolls new slots when the record's day is an older one. A player who owns all but a few
	  classes gets fewer slots.
	* "One free reroll a day (two with VIP), then 99 Robux per reroll": Reroll draws again, away
	  from the classes it replaces where it can. FreeLeft says how many free ones are left today.
	* "A class you wishlist turns up in your shop within 3 days": a wish not seen for WishlistDays
	  shop days is put in the slots (WishDue), and stays through that day's rerolls. Seeing it in
	  the shop, by luck or not, restarts the count, so a wish the player couldn't afford comes back.
	* "Free trial: one run a day with a random class from your shop that you don't own yet": each
	  day's roll picks the trial class among the slots; TrialUsed is set when a run leaves with it.
	* Only today's slots can be bought (CanBuy); owned classes and the trial can be played (CanPlay).
	* Settle puts the profile's loadout back on a class that can be played, after anything that may
	  have taken the trial away (a new day, a reroll that moved it, the trial run leaving).
]]

local Config = require(script.Parent.Parent.Config)

local ClassShop = {}

export type Shop = {
	Day: number,
	Slots: { string },
	RerollsUsed: number,
	Wishlist: string?,
	WishDay: number?,
	Trial: string?,
	TrialUsed: boolean?,
}

local DAY = 86400

local function tuning(): any
	return Config.Get("Tuning", "ClassShop")
end

-- The shop day: whole days since the epoch, counted from the reset hour (00:00 UTC).
function ClassShop.Day(now: number): number
	return math.floor((now - tuning().ResetHourUTC * 3600) / DAY)
end

function ClassShop.SecondsToReset(now: number): number
	local offset = tuning().ResetHourUTC * 3600
	return math.max(0, (ClassShop.Day(now) + 1) * DAY + offset - now)
end

-- The classes this player could still buy, in catalogue order.
function ClassShop.Unowned(owned: { [string]: any }): { string }
	local out = {}
	for _, id in Config.Ids("Classes") do
		local class = Config.Get("Classes", id)
		if class.Price > 0 and not owned[id] then
			table.insert(out, id)
		end
	end
	return out
end

-- The wish has waited long enough: it must be in today's shop.
function ClassShop.WishDue(shop: Shop, owned: { [string]: any }, day: number): boolean
	local wish = shop.Wishlist
	if not wish or owned[wish] or not Config.Find("Classes", wish) then
		return false
	end
	return day - (shop.WishDay or day) >= tuning().WishlistDays
end

--[[
	Up to Slots classes the player doesn't own. `must` (a due wish) is always in; classes in
	`avoid` (the slots a reroll replaces) come back only when there aren't enough others.
]]
function ClassShop.Roll(owned: { [string]: any }, must: string?, avoid: { string }?, rng: Random): { string }
	local slots = tuning().Slots
	local fresh, stale = {}, {}
	for _, id in ClassShop.Unowned(owned) do
		if id ~= must then
			table.insert(if avoid and table.find(avoid, id) then stale else fresh, id)
		end
	end
	local out: { string } = {}
	if must and not owned[must] and Config.Find("Classes", must) then
		table.insert(out, must)
	end
	for _, pool in { fresh, stale } do
		while #out < slots and #pool > 0 do
			table.insert(out, table.remove(pool, rng:NextInteger(1, #pool)) :: string)
		end
	end
	-- show them in catalogue order, so the shop doesn't look shuffled
	local order = Config.Ids("Classes")
	table.sort(out, function(a, b)
		return (table.find(order, a) or 0) < (table.find(order, b) or 0)
	end)
	return out
end

local function pickTrial(shop: Shop, rng: Random)
	shop.Trial = if #shop.Slots > 0 then shop.Slots[rng:NextInteger(1, #shop.Slots)] else nil
end

local function sawWish(shop: Shop, day: number)
	if shop.Wishlist and table.find(shop.Slots, shop.Wishlist) then
		shop.WishDay = day
	end
end

-- A new day's shop when the record is an older day's. True when it changed.
function ClassShop.Refresh(shop: Shop, owned: { [string]: any }, day: number, rng: Random): boolean
	if shop.Day == day then
		return false
	end
	local must = if ClassShop.WishDue(shop, owned, day) then shop.Wishlist else nil
	shop.Slots = ClassShop.Roll(owned, must, nil, rng)
	shop.Day = day
	shop.RerollsUsed = 0
	shop.TrialUsed = nil
	pickTrial(shop, rng)
	sawWish(shop, day)
	return true
end

function ClassShop.FreeRerolls(vip: boolean): number
	local t = tuning()
	return if vip then t.VIPFreeRerolls else t.FreeRerolls
end

function ClassShop.FreeLeft(shop: Shop, vip: boolean): number
	return math.max(0, ClassShop.FreeRerolls(vip) - shop.RerollsUsed)
end

--[[
	Draws today's slots again (the caller has checked it is free or paid for). A wish that was due
	today stays; an unused trial moves to one of the new slots, a used one stays used.
]]
function ClassShop.Reroll(shop: Shop, owned: { [string]: any }, day: number, rng: Random)
	local wish = shop.Wishlist
	local keep = if wish and not owned[wish] and table.find(shop.Slots, wish) and shop.WishDay == day then wish else nil
	shop.Slots = ClassShop.Roll(owned, keep, shop.Slots, rng)
	shop.RerollsUsed += 1
	if not shop.TrialUsed then
		pickTrial(shop, rng)
	end
	sawWish(shop, day)
end

-- Sets or clears the wish. A wish already in today's shop counts as seen today.
function ClassShop.Wish(shop: Shop, owned: { [string]: any }, classId: string?, day: number): (boolean, string?)
	if classId == nil then
		shop.Wishlist, shop.WishDay = nil, nil
		return true, nil
	end
	local class = Config.Find("Classes", classId)
	if not class or class.Price <= 0 then
		return false, "THAT CLASS CAN'T BE WISHED FOR"
	end
	if owned[classId] then
		return false, "YOU OWN THAT CLASS"
	end
	shop.Wishlist, shop.WishDay = classId, day
	return true, nil
end

-- Whether this profile can buy the class now, and why not.
function ClassShop.CanBuy(profile: any, classId: string, day: number): (boolean, string?)
	local class = Config.Find("Classes", classId)
	if not class or class.Price <= 0 then
		return false, "THAT CLASS ISN'T FOR SALE"
	end
	if profile.Classes[classId] then
		return false, "YOU OWN THAT CLASS"
	end
	local shop: Shop = profile.ClassShop
	if shop.Day ~= day or not table.find(shop.Slots, classId) then
		return false, "IT ISN'T IN TODAY'S SHOP: WISHLIST IT"
	end
	if profile.Glowshards < class.Price then
		return false, `{class.Price - profile.Glowshards} MORE GLOWSHARDS NEEDED`
	end
	return true, nil
end

-- Today's free-trial class, while the trial run hasn't left and the class is still not owned.
function ClassShop.Trial(shop: Shop, owned: { [string]: any }, day: number): string?
	local trial = shop.Trial
	if shop.Day ~= day or shop.TrialUsed or not trial or owned[trial] or not table.find(shop.Slots, trial) then
		return nil
	end
	return trial
end

-- Whether the player can take this class into a run: (allowed, as a trial).
function ClassShop.CanPlay(profile: any, classId: string, day: number): (boolean, boolean)
	if not Config.Find("Classes", classId) then
		return false, false
	end
	if profile.Classes[classId] then
		return true, false
	end
	return ClassShop.Trial(profile.ClassShop, profile.Classes, day) == classId, true
end

-- The class a profile brings: its loadout's, if it can still be played; else the Survivor.
function ClassShop.Loadout(profile: any, day: number): (string, boolean)
	local wanted = profile.Loadout and profile.Loadout.Class
	if type(wanted) == "string" then
		local ok, trial = ClassShop.CanPlay(profile, wanted, day)
		if ok then
			return wanted, trial
		end
	end
	return "Survivor", false
end

-- Puts the loadout on a class the profile can play now. True when it had to change.
function ClassShop.Settle(profile: any, day: number): boolean
	local class = ClassShop.Loadout(profile, day)
	if type(profile.Loadout) ~= "table" then
		profile.Loadout = { Class = class }
		return true
	elseif profile.Loadout.Class ~= class then
		profile.Loadout.Class = class
		return true
	end
	return false
end

return table.freeze(ClassShop)
