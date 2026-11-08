-- Part of the HUD (included by HUD.lua and patches/HUD_P07.lua): the mini-map's ping marker.
new("ImageLabel", sg.Templates, "MapPing", { anchor = { 0.5, 1 }, size = { 1, 0.09 }, aspect = 1, dom = "H",
	sprite = "Icon_Ping", tint = COL.hazard, z = 5, visible = false })
