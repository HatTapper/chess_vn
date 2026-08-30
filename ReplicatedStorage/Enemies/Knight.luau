const CollectionService = game:GetService("CollectionService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const AudioHandler = require(ReplicatedStorage.AudioHandler)
const Chapters = require(ReplicatedStorage.Chapters)
const EnemyUtilities = require(ReplicatedStorage.EnemyUtilities)
const ScreenEffects = require(ReplicatedStorage.ScreenEffects)

type State = "Idle" | "Charging" | "ChargeRelease" | "Leaping" | "Forking"

const IN_DIALOGUE_TAG = "InDialogue"

const EnemyAssets = ReplicatedStorage.EnemyAssets
const KnightMiniTemplate = EnemyAssets.Minis.Knight

const Events = ReplicatedStorage.Events
const playChapterBindable = Events.PlayChapter

const player = Players.LocalPlayer

const ATTACKS_PER_BIG_BOOMERANG = 5
const KNIGHT_ORIGIN = UDim2.fromScale(0.5, 0.24)
const KNIGHT_LANDED_Y = 0.775
const HOP_RISE = 0.3 -- scale above the start position the hop peaks at
const TIME_TO_APEX = 0.5
const TIME_TO_TARGET = TIME_TO_APEX + 1.5
const PROJECTILE_DAMAGE = 20
const HOP_DAMAGE = 25
const FORK_DAMAGE = 20

const Knight = {}
Knight.Arena = nil :: Frame
Knight.IconHitbox = nil :: Frame
Knight.Portrait = nil :: ImageLabel
Knight.Phase = 1
Knight.RunningConnection = nil :: RBXScriptConnection?
Knight.SineTime = 0
Knight.TimeSinceLastAttack = 0
Knight.AttackCount = 0
Knight.State = "Idle" :: State
Knight.ChargeIntensity = 1
Knight.ActiveProjectiles = {} :: { EnemyUtilities.Projectile }
Knight.AnimatePortrait = true
Knight.ActiveSquares = {} :: { Frame }
Knight.Active = false

const function layoutSize(gui: GuiObject): Vector2
	local ancestor = gui.Parent

	while ancestor do
		if ancestor:IsA("GuiObject") or ancestor:IsA("LayerCollector") then
			return ancestor.AbsoluteSize
		end

		ancestor = ancestor.Parent
	end

	return Vector2.zero
end

const function damagePlayer(amount: number)
	const playerCharge = player:GetAttribute("Charge") or 0
	player:SetAttribute("Charge", playerCharge - amount)

	AudioHandler.PlaySFX(AudioHandler.SFX.PlayerHit)
	AudioHandler.DoEffect("PlayerHit")

	ScreenEffects.ShakeBattleContainer(5, 0.05, true)
end

const function onProjectileHit(projectile: EnemyUtilities.Projectile)
	projectile.Image.Visible = false
	projectile.Active = false

	damagePlayer(PROJECTILE_DAMAGE)
end

const function getBoomerangConfig(): EnemyUtilities.BoomerangConfig
	return {
		Image = KnightMiniTemplate,
		Arena = Knight.Arena,

		Spawn = EnemyUtilities.GetCenter(Knight.Portrait),
		Target = EnemyUtilities.GetCenter(Knight.IconHitbox),

		TravelSpeed = 0.6,
		RotationSpeed = 1080,

		Curve = 5,

		Hitbox = Knight.IconHitbox,
		OnHit = onProjectileHit,
	}
end

const function chargeBigBoomerang()
	TweenService:Create(Knight.Portrait, TweenInfo.new(1), { ImageColor3 = Color3.new(1, 0, 0) }):Play()
end

const function hopAttack()
	if Knight.State == "Leaping" then
		return
	end

	Knight.State = "Leaping"

	const portrait = Knight.Portrait

	const startPosition = portrait.Position
	const apexY = startPosition.Y.Scale - HOP_RISE

	const parentWidth = layoutSize(portrait).X
	const pixelTravel = EnemyUtilities.GetCenter(Knight.IconHitbox).X - EnemyUtilities.GetCenter(portrait).X
	const xTravel = if parentWidth > 0 then pixelTravel / parentWidth else 0

	local appliedDamage = false

	AudioHandler.PlaySFX(AudioHandler.SFX.KnightJump)

	task.spawn(function()
		local timeElapsed = 0

		while true do
			const dt = RunService.Heartbeat:Wait()

			if Knight.Portrait ~= portrait then
				return
			end

			if Knight.Phase ~= 2 then
				return
			end

			timeElapsed += dt

			local y: number

			if timeElapsed < TIME_TO_APEX then
				const alpha = timeElapsed / TIME_TO_APEX
				y = math.lerp(startPosition.Y.Scale, apexY, 1 - (1 - alpha) ^ 2)
			else
				const alpha = math.clamp((timeElapsed - TIME_TO_APEX) / (TIME_TO_TARGET - TIME_TO_APEX), 0, 1)
				y = math.lerp(apexY, KNIGHT_LANDED_Y, alpha * alpha)
			end

			const xAlpha = math.clamp(timeElapsed / TIME_TO_TARGET, 0, 1)
			const x = startPosition.X.Scale + xTravel * xAlpha

			portrait.Position = UDim2.fromScale(x, y)

			if EnemyUtilities.Overlaps(portrait.Hitbox, Knight.IconHitbox) and not appliedDamage then
				appliedDamage = true
				task.delay(0.5, function()
					appliedDamage = false
				end)
				damagePlayer(HOP_DAMAGE)
			end

			-- doing it here instead of while condition to be 100% sure the full lerp is completed
			if timeElapsed >= TIME_TO_TARGET then
				break
			end
		end

		AudioHandler.PlaySFX(AudioHandler.SFX.KnightLand)
		ScreenEffects.ShakeBattleContainer(15, 0.1, true)

		Knight.State = "Idle"
		Knight.TimeSinceLastAttack = 0
	end)
end

const function pickFreeSquares(squares: { Frame }, count: number): { Frame }
	const available = {}

	for _, square: Frame in squares do
		if not table.find(Knight.ActiveSquares, square) then
			table.insert(available, square)
		end
	end

	const picked = {}
	const numAvailable = #available

	for _ = 1, math.min(count, numAvailable) do
		const index = math.random(1, numAvailable)
		const square = available[index]

		available[index] = available[numAvailable]
		available[numAvailable] = nil

		table.insert(picked, square)
		table.insert(Knight.ActiveSquares, square)
	end

	return picked
end

const function updatePortrait(dt: number)
	const AMPLITUDE = 16
	const SPEED_MULTIPLIER = 1.5
	const sineResult = math.sin(Knight.SineTime) * AMPLITUDE
	Knight.SineTime += (dt * SPEED_MULTIPLIER)

	const currentPosition = Knight.Portrait.Position

	local randomOffset = Vector2.zero

	if Knight.State == "Charging" or Knight.State == "ChargeRelease" then
		const magnitude = 1 * math.max(Knight.ChargeIntensity, 1)
		randomOffset = Vector2.new(math.random(-magnitude, magnitude), math.random(-magnitude, magnitude))
	end

	Knight.Portrait.Position =
		UDim2.new(currentPosition.X.Scale, randomOffset.X, currentPosition.Y.Scale, sineResult + randomOffset.Y)
end

function Knight.Tick(dt: number)
	if Knight.AnimatePortrait then
		updatePortrait(dt)
	end

	if not Knight.Active then
		return
	end

	-- attack update
	do
		const currentCharge = player:GetAttribute("Charge") or 0
		const MAX_CHARGE = 100
		const chargeAlpha = math.clamp(currentCharge / MAX_CHARGE, 0, 1)

		Knight.TimeSinceLastAttack += dt

		const phase = Knight.Phase

		if phase == 1 then
			const TIME_BETWEEN_ATTACK = math.lerp(2, 1, chargeAlpha)

			if Knight.State == "Charging" then
				Knight.ChargeIntensity += dt
			elseif Knight.State == "ChargeRelease" then
				Knight.ChargeIntensity -= (dt * 2)
			end

			if Knight.ChargeIntensity <= 1 then
				Knight.State = "Idle"
				Knight.ChargeIntensity = 1
			end

			if Knight.TimeSinceLastAttack >= TIME_BETWEEN_ATTACK then
				Knight.TimeSinceLastAttack -= TIME_BETWEEN_ATTACK
				Knight.AttackCount += 1

				local projectile: EnemyUtilities.Projectile

				if Knight.AttackCount >= ATTACKS_PER_BIG_BOOMERANG then
					Knight.AttackCount = 0

					const config = getBoomerangConfig()
					config.Curve = if math.random() < 0.5 then -30 else 30
					config.RotationSpeed = 720
					config.TravelSpeed = 0.8

					projectile = EnemyUtilities.FireBoomerang(config)
					projectile.Image.Size =
						UDim2.fromScale(projectile.Image.Size.X.Scale * 2, projectile.Image.Size.Y.Scale * 2)

					AudioHandler.PlaySFX(AudioHandler.SFX.ThrowHeavy)

					Knight.TimeSinceLastAttack = -1

					Knight.State = "ChargeRelease"
					Knight.ChargeIntensity = 4
					TweenService:Create(Knight.Portrait, TweenInfo.new(0.5), { ImageColor3 = Color3.new(1, 1, 1) })
						:Play()

					ScreenEffects.ShakeBattleContainer(5, 0.2, true)
				else
					if Knight.AttackCount == (ATTACKS_PER_BIG_BOOMERANG - 1) then
						Knight.State = "Charging"
						chargeBigBoomerang()
					end

					projectile = EnemyUtilities.FireBoomerang(getBoomerangConfig())

					AudioHandler.PlaySFX(AudioHandler.SFX.ThrowLight)
				end

				projectile.Image.ImageColor3 = Color3.new(1, 0, 0)
				TweenService:Create(projectile.Image, TweenInfo.new(0.5), { ImageColor3 = Color3.new(1, 1, 1) }):Play()

				-- probably memory leak, but idc
				table.insert(Knight.ActiveProjectiles, projectile)
			end
		elseif phase == 2 then
			const TIME_BETWEEN_ATTACK = math.lerp(3, 1, chargeAlpha)

			if Knight.State ~= "Leaping" and Knight.TimeSinceLastAttack > TIME_BETWEEN_ATTACK then
				Knight.TimeSinceLastAttack -= TIME_BETWEEN_ATTACK

				hopAttack()
			end
		else
			const TIME_BETWEEN_ATTACK = math.lerp(2, 1, chargeAlpha)

			const knightAttackContainer = Knight.Arena.KnightAttack
			const gridSquares = knightAttackContainer:QueryDescendants("Frame")

			if Knight.State ~= "Forking" and Knight.TimeSinceLastAttack > TIME_BETWEEN_ATTACK then
				Knight.State = "Forking"

				AudioHandler.PlaySFX(AudioHandler.SFX.Alert)

				const SQUARE_COUNT = 2
				for _, square: Frame in pickFreeSquares(gridSquares, SQUARE_COUNT) do
					const tween = TweenService:Create(square, TweenInfo.new(0.5), { BackgroundTransparency = 0.7 })
					tween:Play()

					tween.Completed:Once(function()
						task.wait(1)

						square.BackgroundTransparency = 0
						TweenService:Create(square, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()

						if not Knight.IconHitbox then
							return
						end

						if EnemyUtilities.Overlaps(square, Knight.IconHitbox) then
							damagePlayer(FORK_DAMAGE)
						end

						AudioHandler.PlaySFX(AudioHandler.SFX.KnightFork)

						const index = table.find(Knight.ActiveSquares, square)
						if index then
							table.remove(Knight.ActiveSquares, index)
						end
					end)
				end

				Knight.TimeSinceLastAttack = 0
				Knight.State = "Idle"
			end
		end
	end
end

function Knight.Begin(arena: Frame, iconHitbox: Frame, portrait: ImageLabel)
	player:AddTag("InBattle")

	Knight.Arena = arena
	Knight.IconHitbox = iconHitbox
	Knight.Portrait = portrait
	Knight.Active = true

	Knight.RunningConnection = RunService.Heartbeat:Connect(Knight.Tick)

	const fadeIn = false
	AudioHandler.PlayMusic(AudioHandler.Music.Knight1, fadeIn)
end

function Knight.PlayerAttack(cyclicFix: (inputEnabled: boolean, chargeEnabled: boolean, resetCharge: boolean) -> ())
	AudioHandler.PlaySFX(AudioHandler.SFX.ChargeHit)

	const fadeOut = true
	const capturedPhase = Knight.Phase

	Knight.Active = false

	const function playPhaseDialogue()
		if capturedPhase < 3 then
			if capturedPhase == 1 then
				cyclicFix(false, false, true)

				playChapterBindable:Fire(Chapters.KnightFinishPhaseOne)

				CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()
			else
				cyclicFix(false, false, true)

				playChapterBindable:Fire(Chapters.KnightFinishPhaseTwo)

				CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()
			end

			Knight.Active = true

			const fadeIn = false
			AudioHandler.PlayMusic(AudioHandler.Music.Knight1, fadeIn)

			cyclicFix(true, true, true)
		end
	end

	const stoppedMusic = AudioHandler.StopMusic(fadeOut)

	if stoppedMusic then
		stoppedMusic:Once(playPhaseDialogue)
	else
		task.spawn(playPhaseDialogue)
	end

	if Knight.Phase == 1 then
		Knight.Phase = 2

		for _, projectile: EnemyUtilities.Projectile in Knight.ActiveProjectiles do
			if projectile.Active then
				projectile:Cancel()
			end
		end

		table.clear(Knight.ActiveProjectiles)

		task.wait(3)

		Knight.Portrait.ZIndex = 5
		Knight.AnimatePortrait = false
	elseif Knight.Phase == 2 then
		Knight.Phase = 3

		const tween = TweenService:Create(
			Knight.Portrait,
			TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
			{ Position = KNIGHT_ORIGIN }
		)

		tween:Play()

		tween.Completed:Once(function()
			Knight.AnimatePortrait = true
		end)
	else
		Knight.End()
	end
end

function Knight.End()
	player:RemoveTag("InBattle")

	if Knight.RunningConnection then
		Knight.RunningConnection:Disconnect()
		Knight.RunningConnection = nil
	end

	for _, grid in Knight.Arena.KnightAttack:QueryDescendants("Frame") do
		grid.Visible = false
	end

	Knight.Arena = nil
	Knight.IconHitbox = nil
	Knight.Portrait = nil
end

return Knight
