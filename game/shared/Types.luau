--!strict
--[[
	Types: definitions that cross module or network boundaries.

	Require this module for its types only (`local Types = require(Shared.Types)`, then
	`Types.Module`). Content entry types arrive with Prompt 1 (Config schemas).
]]

export type PlaceKind = "Lobby" | "Run"

-- The registry a service or controller receives in Init: only its declared dependencies
-- can be read from it (Loader enforces this).
export type Registry = { [string]: any }

-- A service (server) or controller (client). Every ModuleScript in Services/ or
-- Controllers/ returns one of these, with Name equal to the ModuleScript's name.
export type Module = {
	Name: string,
	Dependencies: { string }?,
	Init: ((self: any, registry: Registry) -> ())?,
	Start: ((self: any) -> ())?,
	[string]: any,
}

-- One change on the delta channel: { op, collection, key, value } (see Utilities.Delta).
export type DeltaOp = { any }

-- A DevTools command (DevService:Register).
export type DevCommand = {
	Description: string,
	Usage: string?,
	Run: (player: Player?, args: { any }) -> string?,
}

return {}
