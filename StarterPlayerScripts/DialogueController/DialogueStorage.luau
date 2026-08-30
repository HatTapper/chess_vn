const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")
const AudioHandler = require(ReplicatedStorage.AudioHandler)
const CameraControls = require(ReplicatedStorage.CameraControls)
const Chapters = require(ReplicatedStorage.Chapters)

export type ChapterData = { [number]: SegmentData }
export type SegmentData = {
	Title: string,
	Font: Enum.Font,
	Sound: AudioPlayer,
	TimeBetween: number?,
	SplitOperand: "" | " ",
	StartCallback: () -> (),
	Theme: "Dark" | "Light",

	Content: string,
}

const function tweenPieceToSquare(piece: UnionOperation, square: Attachment)
	const tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
	const squarePosition = square.WorldPosition
	const offset = Vector3.new(squarePosition.X - piece.Position.X, 0, squarePosition.Z - piece.Position.Z)

	TweenService:Create(piece, tweenInfo, { Position = piece.Position + offset }):Play()
end

const chessBoard = workspace:WaitForChild("CheckmateEvent")
const whitePieces = chessBoard:WaitForChild("White")
const blackPieces = chessBoard:WaitForChild("Black")
const boardParts = chessBoard:WaitForChild("Board")

const emptyFunc = function() end

const DialogueStorage: { [string]: ChapterData } = {
	[Chapters.Introduction] = {
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Checkmate, huh?",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "...There has to be a way out of this.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Let's see...",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = function()
				const blackRook = blackPieces.Rook

				CameraControls.TweenTo(
					CFrame.lookAt(CameraControls.GetCFrame().Position, blackRook.Position),
					TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
				):Wait()
			end,
			Theme = "Light",

			Content = "The rook's right there, I need to get off the line.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = function()
				const blackKnight = blackPieces.Knight

				CameraControls.TweenTo(
					CFrame.lookAt(CameraControls.GetCFrame().Position, blackKnight.Position),
					TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
				):Wait()
			end,
			Theme = "Light",

			Content = "I can move to the left, but the knight's holding there...",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = function()
				const whiteKing = whitePieces.King

				CameraControls.TweenTo(
					CFrame.lookAt(CameraControls.GetCFrame().Position, whiteKing.Position),
					TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
				):Wait()
			end,
			Theme = "Light",

			Content = "So, that's it?",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "I can't defend myself, I can't escape...",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Is this where it ends?",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.75,
			SplitOperand = "",
			StartCallback = function()
				task.wait(1)
			end,
			Theme = "Light",

			Content = "No.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "I'll face that knight head on. Maybe he'll listen to reason!",
		},
	},

	[Chapters.KnightEncounter] = {
		{
			Title = "Knight",
			Font = Enum.Font.PatrickHand,
			Sound = AudioHandler.SFX.KnightType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Hey, hey! Where do you think you're going?",
		},
		{
			Title = "Knight",
			Font = Enum.Font.PatrickHand,
			Sound = AudioHandler.SFX.KnightType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "This square is under MY protection, buddy!",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Yea, I know. Listen, could we just... talk this out?",
		},
		{
			Title = "Knight",
			Font = Enum.Font.PatrickHand,
			Sound = AudioHandler.SFX.KnightType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Talk it out? Haha! What kind of King are you?",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "The kind of King that doesn't want to get captured.",
		},
		{
			Title = "Knight",
			Font = Enum.Font.PatrickHand,
			Sound = AudioHandler.SFX.KnightType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Oh, really? Miss Queen told me that you might try something funny.",
		},
		{
			Title = "Knight",
			Font = Enum.Font.PatrickHand,
			Sound = AudioHandler.SFX.KnightType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Tell you what. You get past me, the square's yours.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "I'm gonna have to fight him, aren't I?",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "I really didn't want to have it come down to this...",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "So be it. Bring it on!",
		},
	},

	[Chapters.KnightFinishPhaseOne] = {
		{
			Title = "Knight",
			Font = Enum.Font.PatrickHand,
			Sound = AudioHandler.SFX.KnightType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Heh... Is that all you've got?",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Guess it'll take a few hits to finish him off...",
		},
	},

	[Chapters.KnightFinishPhaseTwo] = {
		{
			Title = "Knight",
			Font = Enum.Font.PatrickHand,
			Sound = AudioHandler.SFX.KnightType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "I'm not done yet!",
		},
	},

	[Chapters.PostKnight] = {
		{
			Title = "Knight",
			Font = Enum.Font.PatrickHand,
			Sound = AudioHandler.SFX.KnightType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Ha! That was pretty fun!",
		},
		{
			Title = "Knight",
			Font = Enum.Font.PatrickHand,
			Sound = AudioHandler.SFX.KnightType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "You've earned the square. Let's do that again sometime!",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Uh.. sure, yea...",
		},
	},

	[Chapters.PreRook] = {
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Maybe this game isn't lost yet...",
		},
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = function()
				const blackRook = blackPieces.Rook
				const origin = blackRook.Position + Vector3.new(0, 2, 2)

				CameraControls.TweenTo(
					CFrame.lookAt(origin, blackRook.Position),
					TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
				)
			end,
			Theme = "Dark",

			Content = "You should not be standing.",
		},
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = function()
				const blackRook = blackPieces.Rook
				const origin = boardParts.H1.WorldPosition + Vector3.new(0, 2, 2)

				AudioHandler.PlaySFX(AudioHandler.SFX.ChessMove)

				tweenPieceToSquare(blackRook, boardParts.H1)

				CameraControls.TweenTo(
					CFrame.lookAt(origin, boardParts.H1.WorldPosition),
					TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
				)
			end,
			Theme = "Dark",

			Content = "Halt!",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = function()
				const whiteKing = whitePieces.King
				const origin = whiteKing.Position + Vector3.new(0, 2, 2)

				CameraControls.TweenTo(
					CFrame.lookAt(origin, whiteKing.Position),
					TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
				)
			end,
			Theme = "Light",

			Content = "Oh no...",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Listen, we don't have to fight!",
		},
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = function()
				const blackRook = blackPieces.Rook
				const origin = blackRook.Position + Vector3.new(0, 2, 2)

				CameraControls.TweenTo(
					CFrame.lookAt(origin, blackRook.Position),
					TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
				)
			end,
			Theme = "Dark",

			Content = "The Knight plays. I do not.",
		},
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "I hold this line, for this line is my duty.",
		},
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "By her Majesty's orders, you must be stopped.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = function()
				const whiteKing = whitePieces.King
				const origin = whiteKing.Position + Vector3.new(0, 2, 2)

				CameraControls.TweenTo(
					CFrame.lookAt(origin, whiteKing.Position),
					TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
				)
			end,
			Theme = "Light",

			Content = "Ugh... I have no other option but to fight him.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Here we go...",
		},
	},

	[Chapters.RookFinishPhaseOne] = {
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Hmph. Tougher than I expected.",
		},
	},

	[Chapters.RookFinishPhaseTwo] = {
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "I must not fail my Queen.",
		},
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "This is the end of the line for you, King!",
		},
	},

	[Chapters.PostRook] = {
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Defeated... by a mere King?",
		},
		{
			Title = "Rook",
			Font = Enum.Font.Michroma,
			Sound = AudioHandler.SFX.RookType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Forgive me, my Majesty, for I have failed to uphold my sacred duty.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "That was close...",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "No King has ever survived an encounter like that! Maybe... maybe I could fight them head-on?",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "No. I musn't fantasize such things.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "What I need to do is get out of this alive.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Now that the Rook is gone, I just need to move-",
		},
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "How interesting...",
		},
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "You have bested my Knight in wits, and defeated my Rook in strength.",
		},
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "You're much more powerful than any other King I have faced.",
		},
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = function()
				task.wait(1)
			end,
			Theme = "Dark",

			Content = "It truly is a shame that I have to kill you.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "W-wait! Let's just-",
		},
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Prepare yourself.",
		},
	},

	[Chapters.QueenFinishPhaseOne] = {
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "...",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "..?",
		},
	},

	[Chapters.QueenFinishPhaseTwo] = {
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Enough.",
		},
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "Your survival thus far has been a mere coincidence. A critical failure to uphold the rules of this game.",
		},
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "And I intend to fix it. Right here. Right now.",
		},
	},

	[Chapters.PostQueen] = {
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.04,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "N-no...",
		},
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.04,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "I... I thought...",
		},
		{
			Title = "Queen",
			Font = Enum.Font.Fondamento,
			Sound = AudioHandler.SFX.QueenType,
			TimeBetween = 0.04,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Dark",

			Content = "How could you..?",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "It's over, Queen.",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.02,
			SplitOperand = "",
			StartCallback = emptyFunc,
			Theme = "Light",

			Content = "Heh, I guess I'm not as weak as you thought!",
		},
		{
			Title = "King",
			Font = Enum.Font.Highway,
			Sound = AudioHandler.SFX.KingType,
			TimeBetween = 0.05,
			SplitOperand = "",
			StartCallback = function()
				const whiteKing = whitePieces.King
				const origin = whiteKing.Position + Vector3.new(0, 1, 1)

				CameraControls.TweenTo(
					CFrame.lookAt(origin, whiteKing.Position),
					TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
				):Wait()
			end,
			Theme = "Light",

			Content = "HOW DID I JUST DO THAT???????",
		},
	},
}

return DialogueStorage
