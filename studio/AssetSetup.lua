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
	queryhull = Enum.CollisionFidelity.Hull, -- a boss's body: raycasts follow its shape (Prompt 15)
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
		local queryOnly = spec.collision == "query" or spec.collision == "queryhull"
		local collide = spec.collision ~= "none" and not queryOnly
		part.Anchored = true
		part.CanCollide = collide
		part.CanQuery = collide or queryOnly
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
	if doc.attrs then -- the generator's scalar meta (HitTime, LayTime, Role...), set by setup_batch.py
		for name, value in doc.attrs do
			model:SetAttribute(name, value)
		end
	end
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

--[[
AssetSetup.rig: the rig step for segmented characters (residents, monsters, bosses). The FBX
holds one MeshPart per bone in the rest pose; doc.rig (from the sidecar) holds the joints.
It runs every check and material step of AssetSetup.run, then:
  1. adds the HumanoidRootPart (doc.rig.hrpSize at doc.rig.hrpCenter, invisible)
  2. joins every bone part to its parent (the root bone to the HumanoidRootPart) with a
     Motor6D named doc.rig.bones[i].jointName, parented to the child part, C0 and C1 at the
     joint position with no rotation, the same convention the clips were keyed in
  3. welds parts that ride on a bone (glow, hair) to that bone's part
  4. adds a Humanoid (R15 physics, HipHeight from the sidecar) with an Animator
  5. puts the face decal on the Head's front face when opts.faceImage is given
  6. writes clip and face ids as attributes (Anim_<Clip>, FaceImage)
Body parts are query-only (hit by raycasts, no collision); the root part collides. The
stored model has its HumanoidRootPart anchored, so it stands when dropped in; spawners
unanchor it.
]]
function AssetSetup.rig(model: Model, doc: any, opts: { assetId: string, swatchHex: { [string]: string }?,
	faceImage: string?, clips: { [string]: string }? }): string
	local rig = doc.rig
	assert(rig, "AssetSetup.rig needs doc.rig")
	local stripped = table.clone(doc)
	stripped.rig = nil
	-- run the shared checks and materials, but keep the model in the pipeline folder
	local category = doc.category
	stripped.category = "__RigStep"
	local report = AssetSetup.run(model, stripped, opts)
	local assets = ServerStorage:WaitForChild("Assets")
	local holder = assets:FindFirstChild("__RigStep")
	if model.Parent ~= holder then
		return report .. "\nrig step skipped: fix the problems above first"
	end
	local pivot = model.WorldPivot

	-- 1. root part
	local hrp = model:FindFirstChild(rig.root)
	if hrp then
		hrp:Destroy()
	end
	local root = Instance.new("Part")
	root.Name = rig.root
	root.Size = vec(rig.hrpSize)
	root.CFrame = pivot * CFrame.new(vec(rig.hrpCenter))
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = true
	root.CanQuery = false
	root.CanTouch = true
	root.CastShadow = false
	root.Parent = model

	-- 2. joints
	local made = 0
	for _, b in rig.bones do
		local part1 = model:FindFirstChild(b.name)
		local part0 = if b.parent then model:FindFirstChild(b.parent) else root
		assert(part1 and part1:IsA("BasePart"), "missing bone part " .. b.name)
		assert(part0 and part0:IsA("BasePart"), "missing parent part for " .. b.name)
		for _, old in part1:GetChildren() do
			if old:IsA("JointInstance") then
				old:Destroy()
			end
		end
		local j = pivot * CFrame.new(vec(b.joint))
		local m = Instance.new("Motor6D")
		m.Name = b.jointName
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = part0.CFrame:ToObjectSpace(j)
		m.C1 = part1.CFrame:ToObjectSpace(j)
		m.Parent = part1
		made += 1
	end

	-- 3. parts riding on a bone, then physics flags for everything
	local boneSet = {}
	for _, b in rig.bones do
		boneSet[b.name] = true
	end
	local welded = 0
	for _, spec in doc.parts do
		local part = model:FindFirstChild(spec.name)
		if part and part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			if not boneSet[spec.name] and spec.bone then
				local host = model:FindFirstChild(spec.bone)
				assert(host and host:IsA("BasePart"), "missing host part " .. spec.bone)
				local w = Instance.new("WeldConstraint")
				w.Name = "RideOn_" .. spec.bone
				w.Part0 = host :: BasePart
				w.Part1 = part
				w.Parent = part
				welded += 1
			end
		end
	end

	-- 4. humanoid
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:Destroy()
	end
	hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = rig.hipHeight
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model
	Instance.new("Animator").Parent = hum
	model.PrimaryPart = root
	-- With a PrimaryPart the model's pivot is the root's pivot, which starts at the root's
	-- centre; setting model.WorldPivot here did not move it (2026-11-08, both rigs came out
	-- 3 studs low). Put the feet pivot on the root explicitly.
	root.PivotOffset = root.CFrame:ToObjectSpace(pivot)

	-- 5. face
	if opts.faceImage then
		local head = model:FindFirstChild("Head")
		if head then
			local face = head:FindFirstChild("face") or Instance.new("Decal")
			face.Name = "face"
			face.Face = Enum.NormalId.Front
			face.Texture = opts.faceImage
			face.Parent = head
			model:SetAttribute("FaceImage", opts.faceImage)
		end
	end

	-- 6. ids
	model:SetAttribute("RigType", rig.rigType)
	model:SetAttribute("HipHeight", rig.hipHeight)
	for clip, id in opts.clips or {} do
		model:SetAttribute("Anim_" .. clip, id)
	end

	local folder = assets:FindFirstChild(category)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = category
		folder.Parent = assets
	end
	local old = folder:FindFirstChild(doc.asset)
	if old and old ~= model then
		old:Destroy()
	end
	model:PivotTo(CFrame.new())
	model.Parent = folder
	if holder and #holder:GetChildren() == 0 then
		holder:Destroy()
	end
	return (report:gsub("__RigStep", category))
		.. string.format("\nrig: %s root, %d Motor6D(s), %d welded part(s), HipHeight %.2f", rig.root, made,
			welded, rig.hipHeight)
end

return AssetSetup
