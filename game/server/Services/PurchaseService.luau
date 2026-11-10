--!strict
--[[
	PurchaseService: developer product receipts (bible Section 17: "Purchases go through
	ProcessReceipt: grant first, record the receipt id in the player's profile, then confirm, so a
	repeated receipt is never granted twice"). Both places, since Roblox hands a receipt to whichever
	server the buyer is in next. Prompt 21 brings the first product, the Class Shop reroll; Prompt 28
	(the shop) adds Glowshard packs and team boosts as more rows.

	* A product is a row here: its id (from Config, nil until the product exists), and a grant that
	  edits the profile and must not yield (ProfileService:GrantPurchase runs it once per receipt).
	* The Class Shop reroll's grant is the shared rule (Rules.ClassShop.Reroll), so it works in the
	  Run place too if the receipt arrives there.
	* Prompt(player, name) opens Roblox's purchase prompt; Granted(player, name) fires after a grant
	  is saved (the lobby's Class Shop tells the buyer), once per receipt.

	Dev (Studio): purchase.test <Product> runs the grant with a made-up receipt, as a real purchase
	would; products lists them.
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ClassShop = require(Shared.Rules.ClassShop)
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("PurchaseService")

local PurchaseService = {
	Name = "PurchaseService",
	Dependencies = { "ProfileService", "DevService" },
	Granted = Signal.new() :: Signal.Signal<Player, string>,
}

type Product = { Name: string, Id: () -> number?, Grant: (player: Player, data: any) -> () }

local profiles: any = nil
local rng = Random.new()

local PRODUCTS: { Product } = {
	{
		Name = "ClassShopReroll",
		Id = function(): number?
			return Config.Get("Tuning", "ClassShop").RerollProductId
		end,
		-- a paid reroll doesn't use up a free one
		Grant = function(_player: Player, data: any)
			local day = ClassShop.Day(os.time())
			ClassShop.Refresh(data.ClassShop, data.Classes, day, rng)
			local used = data.ClassShop.RerollsUsed
			ClassShop.Reroll(data.ClassShop, data.Classes, day, rng)
			data.ClassShop.RerollsUsed = used
			ClassShop.Settle(data, day) -- the trial moved with the new classes
		end,
	},
}

local function find(name: string): Product?
	for _, product in PRODUCTS do
		if product.Name == name then
			return product
		end
	end
	return nil
end

local function byId(productId: number): Product?
	for _, product in PRODUCTS do
		if product.Id() == productId then
			return product
		end
	end
	return nil
end

local function grant(player: Player, product: Product, receiptId: string): Enum.ProductPurchaseDecision
	local fresh = false
	local decision = profiles:GrantPurchase(player, receiptId, function(data: any)
		fresh = true -- runs once per receipt: a repeated receipt is confirmed, never granted again
		product.Grant(player, data)
	end)
	if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
		log:Info("%s: %s %s (receipt %s)", player.Name, product.Name, if fresh then "granted" else "confirmed again, not granted twice", receiptId)
		if fresh then
			PurchaseService.Granted:Fire(player, product.Name)
		end
	else
		log:Warn("%s: %s not granted yet (receipt %s)", player.Name, product.Name, receiptId)
	end
	return decision
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox asks again when they are next in a server
	end
	local product = byId(info.ProductId)
	if not product then
		log:Warn("a receipt for product %s, which isn't in the list", tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return grant(player, product, tostring(info.PurchaseId))
end

-- The product's id, or nil while it doesn't exist yet.
function PurchaseService:ProductId(name: string): number?
	local product = find(name)
	return if product then product.Id() else nil
end

-- Opens Roblox's purchase prompt for the product. (ok, why?)
function PurchaseService:Prompt(player: Player, name: string): (boolean, string?)
	local id = PurchaseService:ProductId(name)
	if not id then
		return false, "THAT ISN'T ON SALE YET"
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, id)
	end)
	return ok, if ok then nil else string.upper(tostring(err))
end

function PurchaseService:Init(registry)
	profiles = registry.ProfileService
	local dev = registry.DevService
	dev:Register("products", {
		Description = "The developer products the game knows and their ids.",
		Run = function(): string?
			local lines = {}
			for _, product in PRODUCTS do
				table.insert(lines, `{product.Name}: {tostring(product.Id() or "no id yet")}`)
			end
			return table.concat(lines, "\n")
		end,
	})
	dev:Register("purchase.test", {
		Description = "Grant a product as a real purchase would, with a made-up receipt (Studio only).",
		Usage = "purchase.test <Product> [receiptId]",
		Run = function(player: Player?, args): string?
			if not RunService:IsStudio() then
				return "Studio only"
			end
			local buyer = player or Players:GetPlayers()[1]
			local product = find(tostring(args[1] or ""))
			if not buyer or not product then
				return "usage: purchase.test <Product> [receiptId] (see products)"
			end
			local receipt = if args[2] then tostring(args[2]) else `DEV-{HttpService:GenerateGUID(false)}`
			local decision = grant(buyer, product, receipt)
			return `{product.Name} for {buyer.Name}: {decision.Name} (receipt {receipt})`
		end,
	})
end

function PurchaseService:Start()
	MarketplaceService.ProcessReceipt = processReceipt
end

return PurchaseService
