--!strict
--[[
	Animations: the clips the game plays (bible Section 19: clips are made in Blender, uploaded
	under the game's owner, and their ids go in Config). NPCAnimator (client) plays a rig's clip
	for the Activity attribute its model carries (Section 23: animations play on clients from a
	replicated Activity attribute). Players' clips (holding and aiming a gun, firing, reloading,
	the melee swings, the dodge, downed, reviving) are played by CombatController on the local
	character. More clips come with the art steps (A3 residents working, eating and sleeping;
	A4 monsters).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Rig = Check.enum({ "R15", "HollowMiner", "BurrowTick", "TunnelHound", "SpitterGrub" }), -- a model's Rig attribute
		Activity = Check.enum({
			"Walk", "Work", "Eat", "Sleep", "Idle", "Down", -- residents (NPCAnimator)
			"GunHold", "GunAim", "Fire", "Reload", "Melee1", "Melee2", "Melee3", "MeleeHeavy", "MeleeCharge",
			"Dodge", "Downed", "Revive", -- players (CombatController, Prompt 11)
			"Attack", "Run", "Stunned", "Latched", "Fight", "Flee", -- monsters and residents in danger (Prompt 12)
		}),
		AssetId = Check.string(40, { pattern = "^rbxassetid://%d+$" }), -- (Config adds Id: the entry's key)
		Looped = Check.boolean(),
		Text = F.Short,
	}),
	Entries = {
		-- Monsters (A0 and A4; NPCAnimator replays Attack on each AttackAt)
		HollowMinerAttack = {
			Rig = "HollowMiner",
			Activity = "Attack",
			AssetId = "rbxassetid://99038102545112",
			Looped = false,
			Text = "The Hollow Miner's overhead pickaxe strike (A0, HollowMiner_Attack)",
		},
		ResidentWalk = {
			Rig = "R15",
			Activity = "Walk",
			AssetId = "rbxassetid://125264708961546",
			Looped = true,
			Text = "A resident walking (A0, R15_ResidentWalk)",
		},
		PlayerGunHold = {
			Rig = "R15",
			Activity = "GunHold",
			AssetId = "rbxassetid://137332197362680",
			Looped = true,
			Text = "A one-handed gun held forward at the hip, the barrel straight (Prompt 11, R15_GunHold v3)",
		},
		PlayerGunAim = {
			Rig = "R15",
			Activity = "GunAim",
			AssetId = "rbxassetid://79362406154244",
			Looped = true,
			Text = "Both hands up, the gun at eye line (Prompt 11, R15_GunAim)",
		},
		PlayerReload = {
			Rig = "R15",
			Activity = "Reload",
			AssetId = "rbxassetid://105484451432076",
			Looped = false,
			Text = "The free hand works the gun (sped to the gun's ReloadSeconds) (Prompt 11, R15_Reload)",
		},
		PlayerMelee1 = {
			Rig = "R15",
			Activity = "Melee1",
			AssetId = "rbxassetid://123682829745377",
			Looped = false,
			Text = "A forehand swing, the combo's first hit (Prompt 11, R15_Melee1)",
		},
		PlayerMelee2 = {
			Rig = "R15",
			Activity = "Melee2",
			AssetId = "rbxassetid://135254436742463",
			Looped = false,
			Text = "A backhand swing, the combo's second hit (Prompt 11, R15_Melee2)",
		},
		PlayerMelee3 = {
			Rig = "R15",
			Activity = "Melee3",
			AssetId = "rbxassetid://111391569980975",
			Looped = false,
			Text = "An overhead chop, the combo's third hit (Prompt 11, R15_Melee3)",
		},
		PlayerMeleeHeavy = {
			Rig = "R15",
			Activity = "MeleeHeavy",
			AssetId = "rbxassetid://90496506863891",
			Looped = false,
			Text = "A two-handed smash from overhead (Prompt 11, R15_MeleeHeavy)",
		},
		PlayerMeleeCharge = {
			Rig = "R15",
			Activity = "MeleeCharge",
			AssetId = "rbxassetid://71412901021621",
			Looped = true,
			Text = "The heavy swing's wind-up, held (Prompt 11, R15_MeleeCharge)",
		},
		PlayerDodge = {
			Rig = "R15",
			Activity = "Dodge",
			AssetId = "rbxassetid://133696369331235",
			Looped = false,
			Text = "A forward roll (Prompt 11, R15_Dodge)",
		},
		PlayerDowned = {
			Rig = "R15",
			Activity = "Downed",
			AssetId = "rbxassetid://125021656764766",
			Looped = true,
			Text = "Prone, crawling (Prompt 11, R15_Downed)",
		},
		PlayerRevive = {
			Rig = "R15",
			Activity = "Revive",
			AssetId = "rbxassetid://116360352534328",
			Looped = true,
			Text = "Kneeling over someone, working (Prompt 11, R15_Revive)",
		},
	},
}
