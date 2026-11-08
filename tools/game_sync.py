"""Install the game code from game/ into the Lobby and Run places (bible Section 23).

    python3 tools/game_sync.py build
        Builds exports/Code/GameCode.rbxmx: one Folder per place (Lobby, Run), each holding
        ReplicatedStorage / ServerScriptService / StarterPlayerScripts / ServerStorage trees.
        Prints the stagedPath/devicePath pair for device_commit_files.

    python3 tools/game_sync.py install <assetId> <Lobby|Run> [--force]
        Prints the one line (execute_luau, Edit) that runs ServerStorage.Tooling.CodeInstaller:
        it loads the latest version of the uploaded build and installs that place's tree,
        refusing when a script was edited in Studio since the last install (unless --force),
        and returns StructureCheck and the data tests.

    python3 tools/game_sync.py tooling
        Prints the Luau that (re)creates ServerStorage.Tooling.CodeInstaller from
        studio/CodeInstaller.lua (once per place, and after changing the installer).

Mapping (Rojo conventions, so the tree could move to Rojo unchanged):
    game/shared/**   -> ReplicatedStorage.Shared                 (both places)
    game/server/**   -> ServerScriptService                      (both places)
    game/client/**   -> StarterPlayer.StarterPlayerScripts       (both places)
    game/docs/ARCHITECTURE.md -> ServerStorage.Documentation.ARCHITECTURE (a ModuleScript
                        returning the text)
    game/places/<Place>/{shared,server,client}/** -> the same, for one place only
    X.server.luau = Script, X.client.luau = LocalScript, X.luau = ModuleScript,
    a folder with init.luau = a ModuleScript whose children are the folder's other files.
ReplicatedStorage.Shared.BuildInfo is generated: build label, commit, place, and the class
and FNV-1a hash of every installed script (StructureCheck compares them with Studio).

Upload the .rbxmx as a Model (contentType model/x-rbxm): POST the first time, then PATCH the
same id (game/BUILD.json keeps it) so every build is a new version of one asset.
"""
from __future__ import annotations

import datetime
import json
import os
import subprocess
import sys
from xml.sax.saxutils import escape

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GAME = os.path.join(REPO, "game")
OUT = os.path.join(REPO, "exports", "Code", "GameCode.rbxmx")
BUILD_JSON = os.path.join(GAME, "BUILD.json")
PLACES = ("Lobby", "Run")
CONTAINERS = {  # build folder name -> path in the DataModel
    "ReplicatedStorage": "ReplicatedStorage",
    "ServerScriptService": "ServerScriptService",
    "StarterPlayerScripts": "StarterPlayer.StarterPlayerScripts",
    "ServerStorage": "ServerStorage",
}
TOPS = {"shared": ("ReplicatedStorage", ["Shared"]), "server": ("ServerScriptService", []),
        "client": ("StarterPlayerScripts", [])}


def fnv1a(text: str) -> str:
    h = 2166136261
    for b in text.encode("utf-8"):
        h ^= b
        h = (h * 16777619) % 4294967296
    return f"{h:08x}"


def node(name: str, cls: str, source: str | None = None, origin: str | None = None) -> dict:
    n = {"name": name, "class": cls, "children": {}}
    if source is not None:
        n["source"] = source
        n["origin"] = origin
    return n


def read(path: str) -> str:
    with open(path, encoding="utf-8", newline="") as f:
        return f.read().replace("\r\n", "\n")


def add(parent: dict, child: dict) -> dict:
    if child["name"] in parent["children"]:
        raise SystemExit(f"two files map to {parent['name']}.{child['name']} ({child.get('origin')})")
    parent["children"][child["name"]] = child
    return child


def walk(directory: str, parent: dict) -> None:
    for entry in sorted(os.listdir(directory)):
        path = os.path.join(directory, entry)
        rel = os.path.relpath(path, REPO)
        if os.path.isdir(path):
            init = os.path.join(path, "init.luau")
            if os.path.exists(init):
                child = add(parent, node(entry, "ModuleScript", read(init), os.path.relpath(init, REPO)))
            else:
                child = add(parent, node(entry, "Folder"))
            walk(path, child)
        elif entry == "init.luau":
            continue
        elif entry.endswith(".server.luau"):
            add(parent, node(entry[:-len(".server.luau")], "Script", read(path), rel))
        elif entry.endswith(".client.luau"):
            add(parent, node(entry[:-len(".client.luau")], "LocalScript", read(path), rel))
        elif entry.endswith(".luau"):
            add(parent, node(entry[:-len(".luau")], "ModuleScript", read(path), rel))


def ensure_folders(parent: dict, names: list[str]) -> dict:
    for name in names:
        parent = parent["children"].get(name) or add(parent, node(name, "Folder"))
    return parent


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", REPO, *args], capture_output=True, text=True).stdout.strip()


def build_info() -> dict:
    meta = json.load(open(BUILD_JSON)) if os.path.exists(BUILD_JSON) else {}
    commit = git("rev-parse", "HEAD") or "unknown"
    dirty = bool(git("status", "--porcelain", "--", "game"))
    label = f"p{meta.get('prompt', 0)}-{commit[:7]}{'+dirty' if dirty else ''}"
    return {"meta": meta, "commit": commit, "label": label,
            "built": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}


def scripts(n: dict, path: str, out: dict) -> None:
    for child in n["children"].values():
        p = f"{path}.{child['name']}"
        if "source" in child:
            out[p] = {"Class": child["class"], "Hash": fnv1a(child["source"]), "From": child["origin"]}
        scripts(child, p, out)


def lua_string(s: str) -> str:
    return json.dumps(s)  # a JSON string literal is a valid Luau string literal


def place_tree(place: str, info: dict) -> tuple[dict, dict]:
    root = node(place, "Folder")
    containers = {name: add(root, node(name, "Folder")) for name in CONTAINERS}
    for base in (GAME, os.path.join(GAME, "places", place)):
        for top, (container, prefix) in TOPS.items():
            d = os.path.join(base, top)
            if os.path.isdir(d):
                walk(d, ensure_folders(containers[container], prefix))
    doc = read(os.path.join(GAME, "docs", "ARCHITECTURE.md"))
    level = "=" * next(i for i in range(1, 10) if f"]{'=' * i}]" not in doc)
    docs = ensure_folders(containers["ServerStorage"], ["Documentation"])
    add(docs, node("ARCHITECTURE", "ModuleScript", f"--!strict\nreturn [{level}[\n{doc}]{level}]\n",
                   "game/docs/ARCHITECTURE.md"))

    files: dict = {}
    for name, container in containers.items():
        scripts(container, CONTAINERS[name], files)
    entries = "\n".join(
        f'\t\t[{lua_string(p)}] = table.freeze({{ Class = "{f["Class"]}", Hash = "{f["Hash"]}" }}),'
        for p, f in sorted(files.items()))
    source = (
        "--!strict\n-- Generated by tools/game_sync.py; don't edit. StructureCheck compares every installed\n"
        "-- script with the class and hash recorded here.\nreturn table.freeze({\n"
        f"\tLabel = {lua_string(info['label'])},\n\tPrompt = {int(info['meta'].get('prompt', 0))},\n"
        f"\tCommit = {lua_string(info['commit'])},\n\tBuilt = {lua_string(info['built'])},\n"
        f"\tPlace = {lua_string(place)},\n\tFiles = table.freeze({{\n{entries}\n\t}}),\n}})\n")
    shared = containers["ReplicatedStorage"]["children"]["Shared"]
    add(shared, node("BuildInfo", "ModuleScript", source, "(generated)"))
    return root, files


def cdata(s: str) -> str:
    return s.replace("]]>", "]]]]><![CDATA[>")


def to_xml(n: dict, counter: list) -> str:
    counter[0] += 1
    props = [f'<string name="Name">{escape(n["name"])}</string>']
    if "source" in n:
        props.append(f'<ProtectedString name="Source"><![CDATA[{cdata(n["source"])}]]></ProtectedString>')
    kids = "".join(to_xml(c, counter) for _, c in sorted(n["children"].items()))
    return (f'<Item class="{n["class"]}" referent="RBX{counter[0]:08X}"><Properties>{"".join(props)}'
            f'</Properties>{kids}</Item>')


def build() -> None:
    info = build_info()
    counter = [0]
    items, summary = [], {}
    for place in PLACES:
        tree, files = place_tree(place, info)
        items.append(to_xml(tree, counter))
        summary[place] = files
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           '<External>null</External><External>nil</External>' + "".join(items) + "</roblox>")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)
    with open(OUT.replace(".rbxmx", ".json"), "w") as f:
        json.dump({"label": info["label"], "commit": info["commit"], "built": info["built"],
                   "places": summary}, f, indent=1, sort_keys=True)
    sys.path.insert(0, os.path.dirname(__file__))
    from stage_import import stage
    staged = stage(OUT)
    print(json.dumps({"label": info["label"], "bytes": len(xml.encode()), "scripts":
                      {p: len(s) for p, s in summary.items()}, **staged}, indent=1))


INSTALL = r'''-- installs build __LABEL__ of game code asset __ASSET__ into the __PLACE__ place
local ASSET_ID, PLACE, FORCE = __ASSET__, "__PLACE__", __FORCE__
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local PLACE_IDS = { Lobby = 135073046693952, Run = 72892455946761 }
if game.PlaceId ~= 0 and PLACE_IDS[PLACE] ~= game.PlaceId then
	return "NOT INSTALLED: this studio is place " .. game.PlaceId .. ", not " .. PLACE
end
local tools = ServerScriptService:FindFirstChild("DevTools")
local oldCheck = tools and tools:FindFirstChild("StructureCheck")
if oldCheck and not FORCE then
	local ok, check = pcall(require, oldCheck)
	if ok then
		local edited = {}
		for _, line in check.Run({ Sources = true }).Warnings do
			if string.find(line, "edited in Studio", 1, true) then
				table.insert(edited, line)
			end
		end
		if #edited > 0 then
			return "NOT INSTALLED (bring these edits into the repo, or pass --force):\n" .. table.concat(edited, "\n")
		end
	end
end
local model = InsertService:LoadAssetVersion(InsertService:GetLatestAssetVersionAsync(ASSET_ID))
local root = model:FindFirstChild(PLACE)
if not root then
	model:Destroy()
	return "NOT INSTALLED: the build has no " .. PLACE .. " tree"
end
for _, item in model:GetDescendants() do
	if item:IsA("PackageLink") then
		item:Destroy()
	end
end
local function replaceChildren(from, into)
	for _, item in from:GetChildren() do
		local old = into:FindFirstChild(item.Name)
		if old then
			old:Destroy()
		end
		item.Parent = into
	end
end
replaceChildren(root.ReplicatedStorage, ReplicatedStorage)
replaceChildren(root.ServerScriptService, ServerScriptService)
replaceChildren(root.StarterPlayerScripts, StarterPlayerScripts)
replaceChildren(root.ServerStorage, ServerStorage)
model:Destroy()
workspace:SetAttribute("PlaceKind", PLACE)
local leftover = ServerStorage:FindFirstChild("NS_Pipeline")
if leftover then
	leftover:Destroy()
end
local check = require(ServerScriptService.DevTools.StructureCheck)
local tests = require(ServerScriptService.DevTools.DataTests)
local info = require(ReplicatedStorage.Shared.BuildInfo)
return "installed " .. info.Label .. " in " .. PLACE .. "\n" .. check.Format(check.Run({ Sources = true }))
	.. "\n" .. tests.Format(tests.Run())
'''


def install(asset_id: str, place: str, force: bool) -> None:
    """The one line that runs ServerStorage.Tooling.CodeInstaller (see `tooling`)."""
    if place not in PLACES:
        raise SystemExit(f"place must be one of {PLACES}")
    print(f'return require(game:GetService("ServerStorage").Tooling.CodeInstaller)'
          f'({int(asset_id)}, "{place}", {"true" if force else "false"})')


def tooling() -> None:
    """Luau that (re)creates ServerStorage.Tooling.CodeInstaller from studio/CodeInstaller.lua."""
    source = read(os.path.join(REPO, "studio", "CodeInstaller.lua"))
    level = "=" * next(i for i in range(1, 10) if f"]{'=' * i}]" not in source)
    print(f'''local ServerStorage = game:GetService("ServerStorage")
local folder = ServerStorage:FindFirstChild("Tooling") or Instance.new("Folder")
folder.Name = "Tooling"
folder.Parent = ServerStorage
local old = folder:FindFirstChild("CodeInstaller")
if old then old:Destroy() end
local module = Instance.new("ModuleScript")
module.Name = "CodeInstaller"
module.Source = [{level}[{source}]{level}]
module.Parent = folder
return "CodeInstaller installed"''')


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["build"]:
        build()
    elif args[:1] == ["install"] and len(args) >= 3:
        install(args[1], args[2], "--force" in args)
    elif args[:1] == ["tooling"]:
        tooling()
    else:
        print(__doc__)
        sys.exit(1)
