const StarterGui = game:GetService("StarterGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

repeat
	local success = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
	task.wait(1)
until success
