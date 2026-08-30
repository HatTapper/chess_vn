const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const player = Players.LocalPlayer
const playerGui = player.PlayerGui

const screenEffectsGui = playerGui:WaitForChild("ScreenEffects")
const battleGui = playerGui:WaitForChild("Battle")
const contentContainer = battleGui.ContentContainer

local shakeEffectConnection: RBXScriptConnection? = nil

const ScreenEffects = {}

function ScreenEffects.FadeTo(color: Color3, tweenInfo: TweenInfo, goal: number): RBXScriptSignal
	const frame = screenEffectsGui.FullScreen

	const tween = TweenService:Create(frame, tweenInfo, { BackgroundTransparency = goal })
	tween:Play()

	return tween.Completed
end

-- one would think to put this in BattleMenu, but i am too lazy to fix a cyclic dependency
-- since the enemy modules need this callback
function ScreenEffects.ShakeBattleContainer(magnitude: number, duration: number, fade: boolean)
	if shakeEffectConnection then
		shakeEffectConnection:Disconnect()
	end

	contentContainer.Position = UDim2.fromScale(0.5, 0.5)

	local currentMagnitude = magnitude
	local timeRemaining = duration
	shakeEffectConnection = RunService.RenderStepped:Connect(function(dt: number)
		timeRemaining -= dt

		if timeRemaining <= 0 then
			shakeEffectConnection:Disconnect()
			shakeEffectConnection = nil

			contentContainer.Position = UDim2.fromScale(0.5, 0.5)

			return
		end

		-- don't need a clamp here since the prev check should cover it
		const durationAlpha = if fade then timeRemaining / duration else 0
		currentMagnitude = math.lerp(magnitude, 0, durationAlpha)

		const rx, ry = (math.sqrt(math.random())) * currentMagnitude, (math.sqrt(math.random())) * currentMagnitude
		contentContainer.Position = UDim2.new(0.5, math.round(rx), 0.5, math.round(ry))
	end)
end

return ScreenEffects
