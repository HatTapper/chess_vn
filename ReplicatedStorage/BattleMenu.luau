const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")
const AudioHandler = require(script.Parent.AudioHandler)
const Knight = require(ReplicatedStorage.Enemies.Knight)
const Queen = require(ReplicatedStorage.Enemies.Queen)
const Rook = require(ReplicatedStorage.Enemies.Rook)

const player = Players.LocalPlayer
const playerGui = player.PlayerGui
const battleGui = playerGui:WaitForChild("Battle")

const contentContainer = battleGui.ContentContainer
const background = battleGui.Background
const texture = background.Texture
const gameWindow = contentContainer.Arena
const icon = gameWindow.Icon
const portraits = contentContainer.Portraits
const chargeBarContainer = contentContainer.ChargeBarContainer

const PAN_SPEED = 80 -- pixels per second
const PAN_ANGLE = math.rad(45)

const MOVE_SPEED = 0.6

const CHARGE_RATE = 3
const MAX_CHARGE = 100
local lastCharge = 0

const panDirection = Vector2.new(math.cos(PAN_ANGLE), math.sin(PAN_ANGLE))
const startPosition = texture.Position
local traveled = Vector2.new(0, 0)

local iconPosition = Vector2.new(icon.Position.X.Scale, icon.Position.Y.Scale)

local currentBattleName = "none"

const BattleMenu = {}
BattleMenu.InputEnabled = false
BattleMenu.ChargeEnabled = false

function BattleMenu.ShowBackground()
	battleGui.Enabled = true
	background.Visible = true
end

function BattleMenu.HideBackground()
	background.Visible = false
end

function BattleMenu.ShowGameWindow()
	gameWindow.Visible = true
	chargeBarContainer.Visible = true
end

function BattleMenu.HideGameWindow()
	gameWindow.Visible = false
	chargeBarContainer.Visible = false
end

function BattleMenu.SetBackgroundColor(color: Color3)
	texture.BackgroundColor3 = color
end

function BattleMenu.DoBattle(battleName: "Knight" | "Rook" | "Queen")
	BattleMenu.HidePortraits()

	currentBattleName = battleName

	if battleName == "Knight" then
		portraits.Knight.Visible = true

		Knight.Begin(gameWindow, icon.Hitbox, portraits.Knight)
	elseif battleName == "Rook" then
		portraits.Rook.Visible = true

		Rook.Begin(gameWindow, icon.Hitbox, portraits.Rook)
	else
		portraits.Queen.Visible = true

		Queen.Begin(gameWindow, icon.Hitbox, portraits.Queen)
	end
end

function BattleMenu.EndBattle()
	BattleMenu.HidePortraits()
end

function BattleMenu.HidePortraits()
	for _, portrait: ImageLabel in portraits:GetChildren() do
		portrait.Visible = false
	end
end

-- im way too lazy to fix this the right way
function BattleMenu.CyclicFix(inputEnabled: boolean, chargeEnabled: boolean, resetCharge: boolean)
	BattleMenu.InputEnabled = inputEnabled
	BattleMenu.ChargeEnabled = chargeEnabled

	if resetCharge then
		BattleMenu.ResetCharge()
	end
end

function BattleMenu.TryAttack()
	const currentCharge = player:GetAttribute("Charge")

	if currentCharge >= MAX_CHARGE then
		player:SetAttribute("Charge", 0)
		BattleMenu.ChargeEnabled = false

		if currentBattleName == "Knight" then
			Knight.PlayerAttack(BattleMenu.CyclicFix)
		elseif currentBattleName == "Rook" then
			Rook.PlayerAttack(BattleMenu.CyclicFix)
		else
			Queen.PlayerAttack(BattleMenu.CyclicFix)
		end

		BattleMenu.ChargeEnabled = true
	end
end

function BattleMenu.ResetCharge()
	player:SetAttribute("Charge", 0)
end

const function chargeBarTick(dt: number)
	const bar = chargeBarContainer.Bar
	const barFill = bar.Fill
	const barFillBg = bar.Background
	const chargeLabel = chargeBarContainer.Label

	const currentCharge = player:GetAttribute("Charge") or 0
	local newCharge
	if BattleMenu.ChargeEnabled then
		newCharge = math.clamp(currentCharge + (CHARGE_RATE * dt), 0, MAX_CHARGE)
	else
		newCharge = math.clamp(currentCharge, 0, MAX_CHARGE)
	end

	if newCharge >= MAX_CHARGE and chargeLabel.Text ~= "READY" then
		chargeLabel.Text = "READY"

		AudioHandler.PlaySFX(AudioHandler.SFX.ChargeReady)
	elseif newCharge < MAX_CHARGE then
		chargeLabel.Text = "CHARGE"
	end

	if newCharge < lastCharge then
		barFillBg.Size = barFill.Size
		barFillBg.BackgroundTransparency = 0.2

		TweenService:Create(barFillBg, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
	end

	barFill.Size = UDim2.fromScale(1, newCharge / MAX_CHARGE)

	lastCharge = newCharge
	player:SetAttribute("Charge", newCharge)
end

const function inputTick(dt: number)
	if not BattleMenu.InputEnabled or not gameWindow.Visible then
		return
	end

	const wDown = UserInputService:IsKeyDown(Enum.KeyCode.W)
	const aDown = UserInputService:IsKeyDown(Enum.KeyCode.A)
	const sDown = UserInputService:IsKeyDown(Enum.KeyCode.S)
	const dDown = UserInputService:IsKeyDown(Enum.KeyCode.D)

	const leftRight = ((aDown and -1) or 0) + ((dDown and 1) or 0)
	const upDown = ((wDown and -1) or 0) + ((sDown and 1) or 0)

	const rawInput = Vector2.new(leftRight, upDown)
	if rawInput.Magnitude == 0 then
		return
	end

	const inputResult = rawInput.Unit

	const arenaSize = gameWindow.AbsoluteSize
	if arenaSize.X <= 0 or arenaSize.Y <= 0 then
		return
	end

	const pixelsPerSecond = MOVE_SPEED * arenaSize.Y
	const delta = Vector2.new(
		inputResult.X * pixelsPerSecond * dt / arenaSize.X,
		inputResult.Y * pixelsPerSecond * dt / arenaSize.Y
	)

	const iconSize = icon.AbsoluteSize
	const maxX = math.max(0, 1 - iconSize.X / arenaSize.X)
	const maxY = math.max(0, 1 - iconSize.Y / arenaSize.Y)

	iconPosition =
		Vector2.new(math.clamp(iconPosition.X + delta.X, 0, maxX), math.clamp(iconPosition.Y + delta.Y, 0, maxY))

	icon.Position = UDim2.fromScale(iconPosition.X, iconPosition.Y)
end

-- i hate making seamless effects like this
const function backgroundTick(dt: number)
	if not background.Visible then
		return
	end

	const size = texture.AbsoluteSize
	const tileSize = texture.TileSize
	const period =
		Vector2.new(tileSize.X.Scale * size.X + tileSize.X.Offset, tileSize.Y.Scale * size.Y + tileSize.Y.Offset)
	if period.X <= 0 or period.Y <= 0 then
		return
	end

	traveled += panDirection * PAN_SPEED * dt
	traveled = Vector2.new(traveled.X % period.X, traveled.Y % period.Y)

	texture.Position = startPosition + UDim2.fromOffset(traveled.X, traveled.Y)
end

RunService.RenderStepped:Connect(backgroundTick)
RunService.RenderStepped:Connect(chargeBarTick)
RunService:BindToRenderStep("BattleInputStep", Enum.RenderPriority.Input.Value + 1, inputTick)

return BattleMenu
