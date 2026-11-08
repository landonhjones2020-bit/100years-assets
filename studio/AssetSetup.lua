--!strict
--[[
AssetSetup: finishes an asset after it is inserted from the Assets API (bible Section 19,
step 8). The Studio connector runs it through execute_luau; tools/setup_code.py prints the
code to send (this file plus the call with the asset's sidecar JSON).

For a model inserted from an FBX upload into ServerStorage.Assets.Pipeline it:
  1. removes the PackageLink (assets are plain models; manifest.csv tracks versions)
  2. checks every MeshPart against the sidecar: size and offset from the pivot within
     0.01 studs (the FBX origin is the asset pivot)
  3. sets collision, anchoring, material, shadows and transparency from the sidecar
  4. applies the shared palette: one SurfaceAppearance per MeshPart with the colour,
     metalness and roughness maps (ids are attributes on ServerStorage.Assets), AlphaMode
     Overlay so "tint" faces show MeshPart.Color; Neon and Glass parts get their swatch
     colour instead
  5. writes attributes (AssetId, Category, Tris, FbxSha1, Socket_<name>, Role) and the
     "Asset" tag
  6. moves it to ServerStorage.Assets.<Category>, replacing an older copy
If a check fails, the model stays in ServerStorage.Assets.Pipeline and the report says why.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local AssetSetup = {}

local TOLERANCE = 0.01
local FIDELITY: { [string]: Enum.CollisionFidelity } = {
	none = Enum.CollisionFidelity.Box,
	query = Enum.CollisionFidelity.Box,
	box = Enum.CollisionFidelity.Box,
	hull = Enum.CollisionFidelity.Hull,
	precise = Enum.CollisionFidelity.PreciseConvexDecomposition,
}
local NO_TEXTURE: { [string]: boolean } = { Neon = true, Glass = true, ForceField = true }

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function hexColor(h: string?): Color3
	if not h then
		return Color3.new(1, 1, 1)
	end
	return Color3.fromHex(h)
end

function AssetSetup.run(model: Model, doc: any, opts: { assetId: string, swatchHex: { [string]: string }? }): string
	local report = {}
	local function say(s: string)
		table.insert(report, s)
	end
	local assets = ServerStorage:WaitForChild("Assets")
	local palette = {
		color = assets:GetAttribute("PaletteColor"),
		metalness = assets:GetAttribute("PaletteMetalness"),
		roughness = assets:GetAttribute("PaletteRoughness"),
	}
	assert(palette.color, "ServerStorage.Assets has no PaletteColor attribute")
	if doc.rig then
		return "rigs are set up by the rig step (Motor6Ds from doc.rig), not by AssetSetup.run"
	end

	for _, d in model:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		end
	end
	model.Name = doc.asset

	local pivot = model.WorldPivot
	local problems = 0
	for _, spec in doc.parts do
		local part = model:FindFirstChild(spec.name, true)
		if not (part and part:IsA("MeshPart")) then
			say("missing MeshPart " .. spec.name)
			problems += 1
			continue
		end
		local size = vec(spec.size)
		local offset = vec(spec.offset)
		local rel = pivot:PointToObjectSpace(part.Position)
		if (part.Size - size).Magnitude > TOLERANCE or (rel - offset).Magnitude > TOLERANCE then
			say(string.format("%s: size %s (want %s), offset %s (want %s)", spec.name, tostring(part.Size),
				tostring(size), tostring(rel), tostring(offset)))
			problems += 1
		end
		local collide = spec.collision ~= "none" and spec.collision ~= "query"
		part.Anchored = true
		part.CanCollide = collide
		part.CanQuery = collide or spec.collision == "query"
		part.CanTouch = collide
		part.CollisionFidelity = FIDELITY[spec.collision] or Enum.CollisionFidelity.Box
		part.CastShadow = spec.castShadow
		part.Transparency = spec.transparency
		part.Material = (Enum.Material :: any)[spec.material]
		for _, old in part:GetChildren() do
			if old:IsA("SurfaceAppearance") then
				old:Destroy()
			end
		end
		if NO_TEXTURE[spec.material] then
			local first = spec.swatches[1]
			local hx = opts.swatchHex and first and opts.swatchHex[first]
			part.TextureID = ""
			part.Color = hexColor(hx)
		else
			part.TextureID = ""
			part.Color = hexColor(spec.tint)
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = palette.color
			if palette.metalness then
				sa.MetalnessMap = palette.metalness
			end
			if palette.roughness then
				sa.RoughnessMap = palette.roughness
			end
			sa.AlphaMode = Enum.AlphaMode.Overlay
			sa.Parent = part
		end
		if spec.role then
			part:SetAttribute("Role", spec.role)
		end
	end

	model:SetAttribute("AssetId", opts.assetId)
	model:SetAttribute("Category", doc.category)
	model:SetAttribute("Tris", doc.tris)
	model:SetAttribute("FbxSha1", doc.fbx_sha1)
	if doc.sockets then
		for name, s in doc.sockets do
			model:SetAttribute("Socket_" .. name, CFrame.new(vec(s.p)) * CFrame.Angles(0, math.rad(s.yaw), 0))
		end
	end
	CollectionService:AddTag(model, "Asset")

	if problems > 0 then
		say(string.format("%d problem(s): left in ServerStorage.Assets.Pipeline", problems))
		return table.concat(report, "\n")
	end
	local folder = assets:FindFirstChild(doc.category)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = doc.category
		folder.Parent = assets
	end
	local old = folder:FindFirstChild(doc.asset)
	if old and old ~= model then
		old:Destroy()
	end
	model:PivotTo(CFrame.new())
	model.Parent = folder
	say(string.format("%s ready in ServerStorage.Assets.%s: %d MeshPart(s), %d tris, size %s",
		doc.asset, doc.category, #doc.parts, doc.tris, tostring(vec(doc.size))))
	return table.concat(report, "\n")
end

return AssetSetup
