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
		Rig = Check.enum({ "R15", "HollowMiner", "BurrowTick", "TunnelHound", "SpitterGrub", "BroodMother" }), -- a model's Rig attribute
		Activity = Check.enum({
			"Walk", "Work", "Eat", "Sleep", "Idle", "Down", -- residents (NPCAnimator)
			"GunHold", "GunAim", "Fire", "Reload", "Melee1", "Melee2", "Melee3", "MeleeHeavy", "MeleeCharge",
			"Dodge", "Downed", "Revive", -- players (CombatController, Prompt 11)
			"Attack", "Run", "Stunned", "Latched", "Fight", "Flee", -- monsters and residents in danger (Prompt 12)
			"Roar", "LayEggs", "Stagger", "Death", -- bosses (A4: the Brood Mother; played from Prompt 15)
		}),
		AssetId = Check.string(40, { pattern = "^rbxassetid://%d+$" }), -- (Config adds Id: the entry's key)
		Looped = Check.boolean(),
		Text = F.Short,
	}),
	Entries = {
		-- The Brood Mother (A4; Rig BroodMother; Prompt 15 plays these: Attack's Hit marker 0.8 s,
		-- LayEggs' Lay marker 1.4 s, the model's HitTime and LayTime attributes say the same)
		BroodMotherIdle = { Rig = "BroodMother", Activity = "Idle", AssetId = "rbxassetid://116082078619476", Looped = true,
			Text = "The Brood Mother breathes, palps and fangs twitching (A4, BroodMother_Idle)" },
		BroodMotherWalk = { Rig = "BroodMother", Activity = "Walk", AssetId = "rbxassetid://105510410741576", Looped = true,
			Text = "The Brood Mother's eight-legged creep (A4, BroodMother_Walk)" },
		BroodMotherAttack = { Rig = "BroodMother", Activity = "Attack", AssetId = "rbxassetid://87449889032585", Looped = false,
			Text = "She rears, fangs wide, and slams down (A4, BroodMother_Attack; Hit 0.8 s)" },
		BroodMotherRoar = { Rig = "BroodMother", Activity = "Roar", AssetId = "rbxassetid://104063099850529", Looped = false,
			Text = "Her entrance: rearing high, front legs splayed, fangs shaking (A4, BroodMother_Roar)" },
		BroodMotherLayEggs = { Rig = "BroodMother", Activity = "LayEggs", AssetId = "rbxassetid://125795678354746", Looped = false,
			Text = "The abdomen drops and pulses; an egg sac leaves at 1.4 s (A4, BroodMother_LayEggs)" },
		BroodMotherStagger = { Rig = "BroodMother", Activity = "Stagger", AssetId = "rbxassetid://121846906504911", Looped = false,
			Text = "Her belly is hit: she jolts back, legs splayed (A4, BroodMother_Stagger)" },
		BroodMotherDeath = { Rig = "BroodMother", Activity = "Death", AssetId = "rbxassetid://115302160037147", Looped = false,
			Text = "She collapses and her legs curl in (A4, BroodMother_Death)" },
		-- Monsters (A0 and A4; NPCAnimator replays Attack on each AttackAt)
		HollowMinerAttack = {
			Rig = "HollowMiner",
			Activity = "Attack",
			AssetId = "rbxassetid://99038102545112",
			Looped = false,
			Text = "The Hollow Miner's overhead pickaxe strike (A0, HollowMiner_Attack)",
		},
		BurrowTickAttack = {
			Rig = "BurrowTick",
			Activity = "Attack",
			AssetId = "rbxassetid://98828341050691",
			Looped = false,
			Text = "A Burrow Tick's lunge bite (A4, BurrowTick_Attack; Hit 0.3 s)",
		},
		BurrowTickWalk = {
			Rig = "BurrowTick",
			Activity = "Walk",
			AssetId = "rbxassetid://106449894515190",
			Looped = true,
			Text = "A Burrow Tick's scuttle (A4, BurrowTick_Walk)",
		},
		HollowMinerWalk = {
			Rig = "HollowMiner",
			Activity = "Walk",
			AssetId = "rbxassetid://90905812087558",
			Looped = true,
			Text = "The Hollow Miner's lumbering walk (A4, HollowMiner_Walk)",
		},
		SpitterGrubAttack = {
			Rig = "SpitterGrub",
			Activity = "Attack",
			AssetId = "rbxassetid://122661270451993",
			Looped = false,
			Text = "A Spitter Grub rears, its mouth peels open and it spits (A4 detail pass, SpitterGrub_Attack; goo at 0.85 s)",
		},
		SpitterGrubWalk = {
			Rig = "SpitterGrub",
			Activity = "Walk",
			AssetId = "rbxassetid://140730453067658",
			Looped = true,
			Text = "A Spitter Grub's crawl, mouth petals twitching (A4 detail pass, SpitterGrub_Walk)",
		},
		TunnelHoundAttack = {
			Rig = "TunnelHound",
			Activity = "Attack",
			AssetId = "rbxassetid://134469102219911",
			Looped = false,
			Text = "A Tunnel Hound's lunging bite, the jaw drops and snaps (A4 detail pass, TunnelHound_Attack; Hit 0.45 s)",
		},
		TunnelHoundWalk = {
			Rig = "TunnelHound",
			Activity = "Walk",
			AssetId = "rbxassetid://87238019294136",
			Looped = true,
			Text = "A Tunnel Hound's gallop, jaw hanging (A4 detail pass, TunnelHound_Walk)",
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
