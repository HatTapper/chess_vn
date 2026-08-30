const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")
const AudioHandler = require(ReplicatedStorage.AudioHandler)
const DialogueStorage = require(script.DialogueStorage)

const Events = ReplicatedStorage.Events
const playChapterBindable = Events.PlayChapter

const player = Players.LocalPlayer
const playerGui = player.PlayerGui

const vnScreenGui = playerGui:WaitForChild("VisualNovel")
const vnContainer = vnScreenGui.Container
const vnDialogContainer = vnContainer.DialogContainer
const vnContentContainer = vnDialogContainer.ContentContainer
const vnTitleContainer = vnDialogContainer.TitleContainer
const vnPortraitContainer = vnContainer.PortraitContainer

type ChapterData = DialogueStorage.ChapterData
type SegmentData = DialogueStorage.SegmentData

local currentTheme: "Dark" | "Light" = "Light"
local playerMovedOn = false

const IN_DIALOGUE_TAG = "InDialogue"
const TIME_PER_SOUND = 0.1
const PORTRAIT_VISIBLE_POSITION = UDim2.fromScale(0.5, 0.5)
const PORTRAIT_HIDDEN_POSITION = UDim2.fromScale(1.6, 0.5)

const portraits = {
	["King"] = vnPortraitContainer.King,
	["Queen"] = vnPortraitContainer.Queen,
	["Knight"] = vnPortraitContainer.Knight,
	["Rook"] = vnPortraitContainer.Rook,
} :: { [string]: ImageLabel }

for _, portrait in portraits do
	portrait.ImageTransparency = 1
end

local activePortrait = nil :: ImageLabel?

-- this has to be like the two-billionth time ive written a dialogue system from scratch

const function updatePortrait(title: string)
	const portrait: ImageLabel = portraits[title]
	const tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)

	if activePortrait == portrait then
		activePortrait.Size = UDim2.fromScale(1.1, 1.1)
		activePortrait.Rotation = math.random(-10, 10)
		TweenService:Create(activePortrait, tweenInfo, { Size = UDim2.fromScale(1, 1), Rotation = 0 }):Play()

		return
	end

	if activePortrait then
		TweenService:Create(
			activePortrait,
			tweenInfo,
			{ ImageColor3 = Color3.new(170, 170, 170), Position = PORTRAIT_HIDDEN_POSITION, ImageTransparency = 1 }
		):Play()
	end

	activePortrait = portrait
	activePortrait.Position = PORTRAIT_HIDDEN_POSITION

	TweenService:Create(
		activePortrait,
		tweenInfo,
		{ ImageColor3 = Color3.new(255, 255, 255), Position = PORTRAIT_VISIBLE_POSITION, ImageTransparency = 0 }
	):Play()
end

const function setTitle(title: string, font: Enum.Font)
	const label = vnTitleContainer.TitleLabel

	label.Font = font
	label.Text = title

	updatePortrait(title)
end

const function setTheme(theme: "Dark" | "Light")
	if currentTheme == theme then
		return
	end
	currentTheme = theme

	type Theme = {
		Instances: { [Instance]: Color3 },
		UIStroke: Color3,
		Texture: ImageLabel,
	}

	const titleLabel = vnTitleContainer.TitleLabel
	const contentLabel = vnContentContainer.ContentLabel

	const tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine)
	const function tween(instance: Instance, property: string, goal: any)
		TweenService:Create(instance, tweenInfo, { [property] = goal }):Play()
	end

	const C3_BLACK = Color3.new(0, 0, 0)
	const C3_WHITE = Color3.new(1, 1, 1)

	const lightTheme: Theme = {
		Instances = {
			[vnDialogContainer] = C3_WHITE,
			[vnContentContainer] = C3_WHITE,
			[vnTitleContainer] = C3_WHITE,
			[titleLabel] = C3_BLACK,
			[contentLabel] = C3_BLACK,
		},
		UIStroke = C3_BLACK,
		Texture = vnDialogContainer.Texture,
	}

	const darkTheme: Theme = {
		Instances = {
			[vnDialogContainer] = C3_BLACK,
			[vnContentContainer] = C3_BLACK,
			[vnTitleContainer] = C3_BLACK,
			[titleLabel] = C3_WHITE,
			[contentLabel] = C3_WHITE,
		},
		UIStroke = C3_WHITE,
		Texture = vnDialogContainer.Texture,
	}

	const themeToUse = if theme == "Dark" then darkTheme else lightTheme

	for instance, color in themeToUse.Instances do
		if instance:IsA("Frame") then
			tween(instance, "BackgroundColor3", color)
		elseif instance:IsA("TextLabel") then
			tween(instance, "TextColor3", color)
		end
	end

	for _, uiStroke in vnDialogContainer:QueryDescendants("UIStroke") do
		tween(uiStroke, "Color", themeToUse.UIStroke)
	end

	if theme == "Dark" then
		TweenService:Create(themeToUse.Texture, tweenInfo, { BackgroundTransparency = 0.85, ImageTransparency = 0 })
			:Play()
	else
		TweenService:Create(themeToUse.Texture, tweenInfo, { BackgroundTransparency = 1, ImageTransparency = 0.9 })
			:Play()
	end
end

const function displayContent(
	content: string,
	font: Enum.Font,
	splitOperand: "" | " ",
	timeBetween: number,
	sound: AudioPlayer
)
	const contentLabel = vnContentContainer.ContentLabel
	contentLabel.Font = font

	const splitContent = content:split(splitOperand)

	local timeSinceLastSound = TIME_PER_SOUND

	for i = 1, #splitContent do
		contentLabel.Text ..= splitContent[i]

		if timeSinceLastSound >= TIME_PER_SOUND then
			AudioHandler.PlaySFXPooled(sound)

			timeSinceLastSound -= TIME_PER_SOUND
		end

		timeSinceLastSound += task.wait(timeBetween)
	end
end

const function parseSegmentData(segmentData: SegmentData)
	const theme = segmentData.Theme
	const font = segmentData.Font
	const title = segmentData.Title
	const timeBetween = segmentData.TimeBetween
	const content = segmentData.Content
	const startCallback = segmentData.StartCallback
	const splitOperand = segmentData.SplitOperand
	const sound = segmentData.Sound

	const contentLabel = vnContentContainer.ContentLabel
	contentLabel.Text = ""

	startCallback()
	setTheme(theme)
	setTitle(title, font)
	displayContent(content, font, splitOperand, timeBetween, sound)
end

const function playChapterData(chapterData: ChapterData)
	assert(chapterData, ":(")

	player:AddTag(IN_DIALOGUE_TAG)

	const GOAL_POSITION = UDim2.fromScale(0.5, 1)
	const START_POSITION = UDim2.fromScale(0.5, 1.5)

	vnDialogContainer.Position = START_POSITION
	TweenService:Create(
		vnDialogContainer,
		TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
		{ Position = GOAL_POSITION }
	):Play()

	vnScreenGui.Enabled = true

	for _, segmentData in chapterData do
		parseSegmentData(segmentData)

		playerMovedOn = false
		repeat
			task.wait()
		until playerMovedOn
	end

	player:RemoveTag(IN_DIALOGUE_TAG)
	vnScreenGui.Enabled = false
end

const function onPlayChapter(chapterName: string)
	playChapterData(DialogueStorage[chapterName])
end

const function onInputBegan(inputObject: InputObject, processed: boolean)
	if processed then
		return
	end

	if not player:HasTag(IN_DIALOGUE_TAG) then
		return
	end

	if inputObject.KeyCode == Enum.KeyCode.F and not playerMovedOn then
		playerMovedOn = true
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
playChapterBindable.Event:Connect(onPlayChapter)
