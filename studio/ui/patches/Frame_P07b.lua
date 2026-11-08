-- In-place patch for a Frame that already has the Command View page (Prompt 7): zone C clips
-- its marks and labels, so a room label at the edge doesn't spill over the tab rail. Changes
-- nothing else, so an AutoScale Lite pass on the page is kept.
local sg = game:GetService("StarterGui"):WaitForChild("Frame")
local view = sg.Cabinet.Pages.CommandView.View
view.ClipsDescendants = true
return "Frame patched: CommandView.View clips (" .. view:GetFullName() .. ")"
