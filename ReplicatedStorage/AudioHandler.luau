const ReplicatedStorage = game:GetService("ReplicatedStorage")
const SoundService = game:GetService("SoundService")
const TweenService = game:GetService("TweenService")

export type Effect = "PlayerHit"

-- not sure if ill use these, but might want a warbly effect on hit
-- or during certain events
const AudioEffects = ReplicatedStorage.AudioEffects

-- stores all sfx and music
const AudioAssets = ReplicatedStorage.AudioAssets
const MusicFolder = AudioAssets.Music
const SFXFolder = AudioAssets.SFX

const unfilteredSFX = {
	[SFXFolder.PlayerHit] = true,
}

const MUFFLE_FILTER_NAME = "Muffle"
const MUFFLE_FREQUENCY = 1000
const MUFFLE_OPEN_FREQUENCY = 20000
const muffleOnsetTween = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
const muffleRecoveryTween = TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)

local muffleFilter: AudioFilter? = nil
local muffleTween: Tween? = nil

-- where the audio magic happens
const effectCallbacks = {
	["PlayerHit"] = function()
		const filter = muffleFilter
		if not filter then
			return
		end

		if muffleTween then
			muffleTween:Cancel()
			muffleTween = nil
		end

		const onset = TweenService:Create(filter, muffleOnsetTween, { Frequency = MUFFLE_FREQUENCY })
		muffleTween = onset

		onset:Play()
		onset.Completed:Once(function(state: Enum.PlaybackState)
			if muffleTween ~= onset or state ~= Enum.PlaybackState.Completed then
				return
			end

			const recovery = TweenService:Create(filter, muffleRecoveryTween, { Frequency = MUFFLE_OPEN_FREQUENCY })
			muffleTween = recovery

			recovery:Play()
			recovery.Completed:Once(function()
				if muffleTween == recovery then
					muffleTween = nil
				end
			end)
		end)
	end,
}

const effectChain = {} :: { Instance }

-- saves the desired volumes of audio players so
-- fade in on music knows where to tween to
const savedTargetVolumes = {} :: { [AudioPlayer]: number }
const volumeFadeTween = TweenInfo.new(1, Enum.EasingStyle.Linear)

const POOL_SIZE = 8
const sfxPools = {} :: { [string]: { players: { AudioPlayer }, nextIndex: number } }

const function connect(source: Instance, target: Instance)
	const wire = Instance.new("Wire")
	wire.SourceInstance = source
	wire.TargetInstance = target

	wire.Parent = source
end

const AudioHandler = {}
AudioHandler.ActiveMusicTrack = nil :: AudioPlayer?
AudioHandler.ActiveSFX = {} :: { AudioPlayer }
AudioHandler.FadingOutMusic = false
AudioHandler.Initialized = false

AudioHandler.SFX = {
	KingType = SFXFolder.KingType,
	ChessMove = SFXFolder.ChessMove,
	ThrowHeavy = SFXFolder.ThrowHeavy,
	ThrowLight = SFXFolder.ThrowLight,
	ChargeReady = SFXFolder.AttackReady,
	ChargeHit = SFXFolder.AttackHit,
	PlayerHit = SFXFolder.PlayerHit,
	KnightJump = SFXFolder.KnightJump,
	KnightLand = SFXFolder.KnightLand,
	Alert = SFXFolder.Alert,
	KnightFork = SFXFolder.KnightFork,
	KnightType = SFXFolder.KnightType,
	RookType = SFXFolder.RookType,
	QueenType = SFXFolder.QueenType,
	RookBounce = SFXFolder.RookBounce,
	BishopThrow = SFXFolder.BishopThrow,
	BishopTrail = SFXFolder.BishopTrail,
}

-- leave as 3 in case i make music for each phase
AudioHandler.Music = {
	Knight1 = MusicFolder.Knight1,
	Knight2 = MusicFolder.Knight1,
	Knight3 = MusicFolder.Knight1,
	Queen1 = MusicFolder.Queen1,
	Queen2 = MusicFolder.Queen1,
	Queen3 = MusicFolder.Queen1,
	Rook1 = MusicFolder.Rook1,
	Rook2 = MusicFolder.Rook1,
	Rook3 = MusicFolder.Rook1,
}

function AudioHandler.Initialize()
	const audioDeviceOutput = SoundService:WaitForChild("AudioDeviceOutput") :: AudioDeviceOutput?

	if not audioDeviceOutput then
		error("panic")
	end

	muffleFilter = AudioEffects:FindFirstChild(MUFFLE_FILTER_NAME) :: AudioFilter?

	if muffleFilter then
		muffleFilter.Frequency = MUFFLE_OPEN_FREQUENCY
	end

	for _, effect: Instance in AudioEffects:GetChildren() do
		table.insert(effectChain, effect)
	end

	-- the only scary part about this ordering is i might have
	-- filters clashing for certain things, but im not sure if i care
	-- enough for this to actually deal with that
	for i, effect in effectChain do
		const nextEffect = effectChain[i + 1]
		if nextEffect then
			connect(effect, nextEffect)
		else
			connect(effect, audioDeviceOutput)
		end
	end

	const firstEffect = effectChain[1]

	for _, music: AudioPlayer in MusicFolder:GetChildren() do
		savedTargetVolumes[music] = music.Volume

		if firstEffect then
			connect(music, firstEffect)
		else
			connect(music, audioDeviceOutput)
		end
	end

	for _, sfx: AudioPlayer in SFXFolder:GetChildren() do
		if firstEffect and not unfilteredSFX[sfx] then
			connect(sfx, firstEffect)
		else
			connect(sfx, audioDeviceOutput)
		end

		sfx.Parent = SoundService
	end

	AudioHandler.Initialized = true
end

function AudioHandler.DoEffect(effect: Effect)
	assert(effect and typeof(effect) == "string", "what are you doing")

	const effectCallback = effectCallbacks[effect]
	if effectCallback then
		effectCallback()
	end
end

function AudioHandler.PlaySFX(sfx: AudioPlayer)
	assert(sfx and sfx:IsA("AudioPlayer"), "what are you doing")

	sfx.TimePosition = 0
	sfx:Play()
	table.insert(AudioHandler.ActiveSFX, sfx)

	sfx.Ended:Once(function()
		const i = table.find(AudioHandler.ActiveSFX, sfx)
		if i then
			table.remove(AudioHandler.ActiveSFX, i)
		end
	end)
end

const function getOrCreatePool(template: AudioPlayer): { players: { AudioPlayer }, nextIndex: number }
	local pool = sfxPools[template]
	if pool then
		return pool
	end

	const audioDeviceOutput = SoundService:WaitForChild("AudioDeviceOutput") :: AudioDeviceOutput?
	const firstEffect = effectChain[1]

	const players = {}
	for i = 1, POOL_SIZE do
		const clone = template:Clone()
		clone.Name = template.Name .. "_Pool" .. i
		clone.Parent = template.Parent

		-- re-wire the clone the same way Initialize wired the original
		-- (adjust this call to match your actual connect/effect-chain setup)
		if firstEffect and not unfilteredSFX[template] then
			connect(clone, firstEffect)
		else
			connect(clone, audioDeviceOutput)
		end

		table.insert(players, clone)
	end

	pool = { players = players, nextIndex = 1 }
	sfxPools[template] = pool

	return pool
end

function AudioHandler.PlaySFXPooled(sfx: AudioPlayer): AudioPlayer
	assert(sfx and sfx:IsA("AudioPlayer"), "what are you doing")

	local pool = getOrCreatePool(sfx)

	local player = pool.players[pool.nextIndex]
	pool.nextIndex = (pool.nextIndex % #pool.players) + 1

	player.TimePosition = 0
	player.PlaybackSpeed = math.lerp(0.9, 1.1, math.random())
	player:Play()

	return player
end

function AudioHandler.PlayMusic(music: AudioPlayer, fadeIn: boolean?)
	assert(music and music:IsA("AudioPlayer"), "what are you doing")

	fadeIn = fadeIn or false

	task.spawn(function()
		while AudioHandler.FadingOutMusic do
			task.wait()
		end

		if AudioHandler.ActiveMusicTrack then
			const fadeOut = false
			AudioHandler.StopMusic(fadeOut)
		end

		if fadeIn then
			music.Volume = 0
			TweenService:Create(music, volumeFadeTween, { Volume = savedTargetVolumes[music] or 1 }):Play()
		else
			music.Volume = savedTargetVolumes[music]
		end

		music.TimePosition = 0
		music:Play()

		AudioHandler.ActiveMusicTrack = music
	end)
end

function AudioHandler.StopSFX(sfx: AudioPlayer)
	assert(sfx and sfx:IsA("AudioPlayer"), "what are you doing")

	-- i dont think ill be playing more than one sfx at once, so this is fine
	for i, activeSfx in AudioHandler.ActiveSFX do
		if activeSfx == sfx then
			table.remove(AudioHandler.ActiveSFX, i)

			activeSfx:Stop()
		end
	end
end

function AudioHandler.StopAllSFX()
	for _, sfx in AudioHandler.ActiveSFX do
		sfx:Stop()
	end

	table.clear(AudioHandler.ActiveSFX)
end

function AudioHandler.StopMusic(fadeOut: boolean?): RBXScriptSignal?
	if not AudioHandler.ActiveMusicTrack then
		return nil
	end

	if fadeOut then
		AudioHandler.FadingOutMusic = true

		const tween = TweenService:Create(AudioHandler.ActiveMusicTrack, volumeFadeTween, { Volume = 0 })

		tween:Play()
		tween.Completed:Once(function()
			AudioHandler.ActiveMusicTrack:Stop()
			AudioHandler.ActiveMusicTrack = nil

			AudioHandler.FadingOutMusic = false
		end)

		return tween.Completed
	else
		AudioHandler.ActiveMusicTrack:Stop(0)
		AudioHandler.ActiveMusicTrack = nil

		return nil
	end
end

return AudioHandler
