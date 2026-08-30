const CollectionService = game:GetService("CollectionService")
const Lighting = game:GetService("Lighting")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")
const AudioHandler = require(ReplicatedStorage.AudioHandler)
const BattleMenu = require(ReplicatedStorage.BattleMenu)
const CameraControls = require(ReplicatedStorage.CameraControls)
const Chapters = require(ReplicatedStorage.Chapters)
const ScreenEffects = require(ReplicatedStorage.ScreenEffects)

const Events = ReplicatedStorage.Events
const playChapterBindable = Events.PlayChapter

const IN_DIALOGUE_TAG = "InDialogue"
const IN_BATTLE_TAG = "InBattle"

const chessBoard = workspace:WaitForChild("CheckmateEvent")
const whitePieces = chessBoard:WaitForChild("White")
const blackPieces = chessBoard:WaitForChild("Black")
const boardSquares = chessBoard:WaitForChild("Board")

-- way too lazy to integrate this into CameraControls.luau, it is 5am and i WILL finish this project
const camera = workspace.CurrentCamera
const cameraPart = workspace:WaitForChild("CameraPart")
const blurEffect = Lighting:WaitForChild("Blur")

camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = cameraPart.CFrame

blurEffect.Enabled = true

const playerGui = Players.LocalPlayer.PlayerGui
const openingMenu = playerGui:WaitForChild("Opening")
openingMenu.Enabled = true

const menuContainer = openingMenu.Container
const playButton = menuContainer.PlayButton
const subtitleLabel = menuContainer.SubtitleLabel

task.spawn(function()
	const AMPLITUDE = 10
	const ROTATION_ORIGIN = subtitleLabel.Rotation
	local elapsed = 0

	while openingMenu.Enabled do
		elapsed += RunService.RenderStepped:Wait()

		subtitleLabel.Rotation = ROTATION_ORIGIN + (math.sin(elapsed) * AMPLITUDE)
	end
end)

playButton.MouseButton1Click:Wait()

openingMenu.Enabled = false
TweenService:Create(blurEffect, TweenInfo.new(1), { Size = 0 }):Play()

-- end of opening menu

const function tweenPieceToSquare(piece: UnionOperation, square: Attachment)
	const tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
	const squarePosition = square.WorldPosition
	const offset = Vector3.new(squarePosition.X - piece.Position.X, 0, squarePosition.Z - piece.Position.Z)

	TweenService:Create(piece, tweenInfo, { Position = piece.Position + offset }):Play()
end

const function playGame()
	CameraControls.SetType(Enum.CameraType.Scriptable)

	const whiteKing = whitePieces:WaitForChild("King")
	const blackKnight = blackPieces:WaitForChild("Knight")
	const h1Square = boardSquares:WaitForChild("H1")

	CameraControls.GoTo(CFrame.lookAt(whiteKing.Position + Vector3.new(0, 1, -1), whiteKing.Position))
	task.wait(1)
	playChapterBindable:Fire(Chapters.Introduction)

	-- hacky way to just wait for dialogue to finish
	CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()

	const g1Square = boardSquares.G1

	CameraControls.GoTo(CFrame.lookAt(g1Square.WorldPosition + Vector3.new(0, 2, 2), g1Square.WorldPosition))

	AudioHandler.PlaySFX(AudioHandler.SFX.ChessMove)
	tweenPieceToSquare(whiteKing, g1Square)
	task.wait(2)

	AudioHandler.PlaySFX(AudioHandler.SFX.ChessMove)
	tweenPieceToSquare(blackKnight, g1Square)

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(1, Enum.EasingStyle.Sine), 0)
	task.wait(2)

	BattleMenu.HideGameWindow()
	BattleMenu.HidePortraits()
	BattleMenu.ShowBackground()

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(0.5), 1):Wait()
	playChapterBindable:Fire(Chapters.KnightEncounter)

	CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()
	BattleMenu.ShowGameWindow()
	BattleMenu.ResetCharge()
	BattleMenu.InputEnabled = true
	BattleMenu.ChargeEnabled = true
	BattleMenu.DoBattle("Knight")

	blackKnight.Transparency = 1

	CollectionService:GetInstanceRemovedSignal(IN_BATTLE_TAG):Wait()

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(1, Enum.EasingStyle.Sine), 0):Wait()
	BattleMenu.HideBackground()
	BattleMenu.HideGameWindow()
	BattleMenu.HidePortraits()
	BattleMenu.InputEnabled = false
	BattleMenu.ChargeEnabled = false

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(0.5), 1):Wait()
	playChapterBindable:Fire(Chapters.PostKnight)

	CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()

	playChapterBindable:Fire(Chapters.PreRook)

	CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()

	tweenPieceToSquare(whiteKing, h1Square)

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(1, Enum.EasingStyle.Sine), 0)
	task.wait(2)

	BattleMenu.ShowBackground()
	BattleMenu.ShowGameWindow()

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(1, Enum.EasingStyle.Sine), 1):Wait()

	BattleMenu.ResetCharge()
	BattleMenu.InputEnabled = true
	BattleMenu.ChargeEnabled = true
	BattleMenu.DoBattle("Rook")

	const blackRook = blackPieces.Rook
	blackRook.Transparency = 1

	CollectionService:GetInstanceRemovedSignal(IN_BATTLE_TAG):Wait()

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(1, Enum.EasingStyle.Sine), 0):Wait()
	BattleMenu.HideBackground()
	BattleMenu.HideGameWindow()
	BattleMenu.HidePortraits()
	BattleMenu.InputEnabled = false
	BattleMenu.ChargeEnabled = false

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(0.5), 1):Wait()

	CameraControls.TweenTo(
		CFrame.lookAt(whiteKing.Position + Vector3.new(0, 2, 2), whiteKing.Position),
		TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
	):Wait()

	playChapterBindable:Fire(Chapters.PostRook)

	CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()

	const blackQueen = blackPieces.Queen

	tweenPieceToSquare(blackQueen, h1Square)

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(1, Enum.EasingStyle.Sine), 0):Wait()

	BattleMenu.ShowBackground()
	BattleMenu.ShowGameWindow()
	BattleMenu.SetBackgroundColor(Color3.fromRGB(60, 60, 60))

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(0.5), 1):Wait()

	BattleMenu.ResetCharge()
	BattleMenu.InputEnabled = true
	BattleMenu.ChargeEnabled = true
	BattleMenu.DoBattle("Queen")

	blackQueen.Transparency = 1

	CollectionService:GetInstanceRemovedSignal(IN_BATTLE_TAG):Wait()

	ScreenEffects.ShakeBattleContainer(20, 3, false)
	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(2, Enum.EasingStyle.Sine), 0):Wait()
	BattleMenu.HideBackground()
	BattleMenu.HideGameWindow()
	BattleMenu.HidePortraits()
	BattleMenu.InputEnabled = false
	BattleMenu.ChargeEnabled = false

	ScreenEffects.FadeTo(Color3.new(1, 1, 1), TweenInfo.new(0.5), 1):Wait()

	CameraControls.TweenTo(
		CFrame.lookAt(whiteKing.Position + Vector3.new(0, 2, 2), whiteKing.Position),
		TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
	):Wait()

	playChapterBindable:Fire(Chapters.PostQueen)

	CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()

	TweenService:Create(blurEffect, TweenInfo.new(1), { Size = 40 }):Play()

	task.wait(1.5)

	const endingGui = playerGui.Ending
	const label = endingGui.VictoryLabel
	TweenService:Create(label, TweenInfo.new(3), { TextTransparency = 0 }):Play()
end

const function onInputBegan(inputObject: InputObject, processed: boolean)
	if processed then
		return
	end

	if inputObject.KeyCode == Enum.KeyCode.Space and BattleMenu.InputEnabled then
		BattleMenu.TryAttack()
	end
end

repeat
	task.wait()
until AudioHandler.Initialized

UserInputService.InputBegan:Connect(onInputBegan)

task.wait(2)

--[[BattleMenu.ShowBackground()
BattleMenu.ShowGameWindow()
BattleMenu.InputEnabled = true
BattleMenu.ChargeEnabled = true
BattleMenu.DoBattle("Knight")]]

--[[BattleMenu.ShowBackground()
BattleMenu.ShowGameWindow()
BattleMenu.InputEnabled = true
BattleMenu.ChargeEnabled = true
BattleMenu.DoBattle("Rook")]]

--[[CameraControls.SetType(Enum.CameraType.Scriptable)
playChapterBindable:Fire(Chapters.PreRook)]]

--playChapterBindable:Fire(Chapters.PostRook)

playGame()
