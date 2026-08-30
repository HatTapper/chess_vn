const CollectionService = game:GetService("CollectionService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const AudioHandler = require(ReplicatedStorage.AudioHandler)
const Chapters = require(ReplicatedStorage.Chapters)
const EnemyUtilities = require(ReplicatedStorage.EnemyUtilities)
const ScreenEffects = require(ReplicatedStorage.ScreenEffects)

type State = "Idle" | "Ramming" | "Slashing"

const IN_DIALOGUE_TAG = "InDialogue"

const Events = ReplicatedStorage.Events
const playChapterBindable = Events.PlayChapter

const player = Players.LocalPlayer

const MAX_CHARGE = 100
const PROJECTILE_DAMAGE = 25
const TELEGRAPH_DURATION = 1
const LASER_THICKNESS = 4
const LASER_COLOR = Color3.new(1, 0, 0)
const LASER_TRANSPARENCY_START = 0.9
const LASER_TRANSPARENCY_END = 0.35

const BISHOP_SPEED = 0.8
const TRAIL_PLACE_INTERVAL = 0.3
const TRAIL_LIFETIME = 1.6
const TRAIL_FADE_DURATION = 0.5
const TRAIL_TRANSPARENCY = 0.15
const TRAIL_DAMAGE = 15
const TRAIL_DAMAGE_COOLDOWN = 0.6

const MAX_STEP = 1 / 30
const RAM_DIRECTIONS = { 0, 45, 90, 135, 180, 225, 270, 315 }
const TIME_UNTIL_DASH = 0.8
const DISTANCE_FROM_PLAYER = 0.45
const RAM_SPEED = 1.6
const RAM_TRAVEL = DISTANCE_FROM_PLAYER * 2
const RAM_DAMAGE = 30

const LINE_TELEGRAPH_DURATION = 0.9
const LINE_TELEGRAPH_TRANSPARENCY = 0.55
const LINE_FLASH_TRANSPARENCY = 0.2
const LINE_FADE_DURATION = 0.4
const LINE_HIGHLIGHT_COLOR = Color3.new(1, 1, 1)
const LINE_FLASH_COLOR = Color3.new(1, 0, 0)
const LINE_DASH_SPEED = 2.5
const LINE_DASH_START = 0.8

const minisFolder = ReplicatedStorage.EnemyAssets.Minis
const queenMiniTemplate = minisFolder.Queen
const pawnMiniTemplate = minisFolder.Pawn
const knightMiniTemplate = minisFolder.Knight
const bishopMiniTemplate = minisFolder.Bishop
const rookMiniTemplate = minisFolder.Rook

const bishopTrailTemplate = ReplicatedStorage.EnemyAssets.Attacks.BishopTrail

const promotionChoices = { knightMiniTemplate, bishopMiniTemplate, rookMiniTemplate } :: { ImageLabel }

const Queen = {}
Queen.Arena = nil :: Frame
Queen.IconHitbox = nil :: Frame
Queen.Portrait = nil :: ImageLabel
Queen.Origin = UDim2.fromScale(0.5, 0.24)
Queen.Phase = 1
Queen.RunningConnection = nil :: RBXScriptConnection?
Queen.SineTime = 0
Queen.TimeSinceLastAttack = 0
Queen.State = "Idle" :: State
Queen.AnimatePortrait = true
Queen.Active = false
Queen.ActiveProjectiles = {} :: { EnemyUtilities.Projectile }
Queen.TimeSinceLastLine = 0

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

const function updatePortrait(dt: number)
	const AMPLITUDE = 16
	const SPEED_MULTIPLIER = 1.5
	const sineResult = math.sin(Queen.SineTime) * AMPLITUDE
	Queen.SineTime += (dt * SPEED_MULTIPLIER)

	const currentPosition = Queen.Portrait.Position

	Queen.Portrait.Position = UDim2.new(currentPosition.X.Scale, 0, currentPosition.Y.Scale, sineResult)
end

local trailOnCooldown = false

const function spawnTrailSegment(arena: Frame, center: Vector2, phase: number)
	const localPos = center - arena.AbsolutePosition

	const segment = bishopTrailTemplate:Clone()
	segment.Position = UDim2.fromOffset(localPos.X, localPos.Y)
	segment.BackgroundTransparency = TRAIL_TRANSPARENCY
	segment.Visible = true
	segment.Parent = arena

	const trail: EnemyUtilities.Projectile = {
		Image = segment,
		Active = true,
		Cancel = function(self: EnemyUtilities.Projectile)
			if not self.Active then
				return
			end
			self.Active = false
			self.Image:Destroy()
		end,
	}

	table.insert(Queen.ActiveProjectiles, trail)

	task.spawn(function()
		local elapsed = 0

		while trail.Active do
			const dt = RunService.Heartbeat:Wait()

			if not Queen.Active or Queen.Arena ~= arena or Queen.Phase ~= phase then
				trail:Cancel()
				break
			end

			elapsed += dt

			const fadeStart = TRAIL_LIFETIME - TRAIL_FADE_DURATION

			if elapsed > fadeStart then
				const fadeAlpha = math.clamp((elapsed - fadeStart) / TRAIL_FADE_DURATION, 0, 1)

				segment.BackgroundTransparency = math.lerp(TRAIL_TRANSPARENCY, 1, fadeAlpha)
			end

			if not trailOnCooldown and EnemyUtilities.Overlaps(segment.Hitbox, Queen.IconHitbox) then
				trailOnCooldown = true

				task.delay(TRAIL_DAMAGE_COOLDOWN, function()
					trailOnCooldown = false
				end)

				damagePlayer(TRAIL_DAMAGE)
			end

			if elapsed >= TRAIL_LIFETIME then
				trail:Cancel()
				break
			end
		end

		const index = table.find(Queen.ActiveProjectiles, trail)
		if index then
			table.remove(Queen.ActiveProjectiles, index)
		end
	end)
end

const function emitBishopTrail(arena: Frame, projectile: EnemyUtilities.Projectile, phase: number)
	task.spawn(function()
		local sinceLast = TRAIL_PLACE_INTERVAL

		while projectile.Active do
			const dt = RunService.Heartbeat:Wait()

			if not Queen.Active or Queen.Arena ~= arena or Queen.Phase ~= phase or not projectile.Active then
				return
			end

			sinceLast += dt

			if sinceLast >= TRAIL_PLACE_INTERVAL then
				sinceLast -= TRAIL_PLACE_INTERVAL

				spawnTrailSegment(arena, EnemyUtilities.GetCenter(projectile.Image), phase)

				AudioHandler.PlaySFXPooled(AudioHandler.SFX.BishopTrail)
			end
		end
	end)
end

const function pawnPromotionAttack()
	const arena = Queen.Arena
	const portrait = Queen.Portrait

	if not arena or not portrait then
		return
	end

	const firedPhase = Queen.Phase
	const summonSlots = arena.Parent.QueenSummons:GetChildren() :: { Frame }
	const shortTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)

	AudioHandler.PlaySFX(AudioHandler.SFX.KnightJump)

	for _, slot in summonSlots do
		const originPos = EnemyUtilities.GetCenter(portrait) - arena.AbsolutePosition
		const goalPos = EnemyUtilities.GetCenter(slot) - arena.AbsolutePosition

		const pawn = pawnMiniTemplate:Clone()
		pawn.AnchorPoint = Vector2.new(0.5, 0.5)
		pawn.Position = UDim2.fromOffset(originPos.X, originPos.Y)
		pawn.Size = UDim2.fromScale(1, 0.3)
		pawn.Parent = arena

		const spawnTween = TweenService:Create(
			pawn,
			shortTweenInfo,
			{ Position = UDim2.fromOffset(goalPos.X, goalPos.Y), Size = UDim2.fromScale(1, 0.15) }
		)

		spawnTween:Play()
		spawnTween.Completed:Once(function()
			if not Queen.Active or Queen.Arena ~= arena or Queen.Phase ~= firedPhase then
				pawn:Destroy()

				return
			end

			const promotedTemplate = promotionChoices[math.random(1, #promotionChoices)]
			const spawnCenter = EnemyUtilities.GetCenter(pawn)
			const targetCenter = EnemyUtilities.GetCenter(Queen.IconHitbox)

			const promotedLocal = spawnCenter - arena.AbsolutePosition

			const promoted = promotedTemplate:Clone()
			promoted.AnchorPoint = Vector2.new(0.5, 0.5)
			promoted.Position = UDim2.fromOffset(promotedLocal.X, promotedLocal.Y)
			promoted.Size = UDim2.fromScale(1, 0.15)
			promoted.ImageColor3 = Color3.new(1, 0, 0)
			promoted.Visible = true
			promoted.Parent = arena

			pawn:Destroy()

			TweenService:Create(promoted, shortTweenInfo, { ImageColor3 = Color3.new(1, 1, 1) }):Play()

			local laser
			if promotedTemplate == rookMiniTemplate then
				const toTarget = targetCenter - spawnCenter
				const height = arena.AbsoluteSize.Y

				if toTarget.Magnitude > 0 and height > 0 then
					const facing = toTarget.Unit
					const bounds = Vector2.new(arena.AbsoluteSize.X / height, 1)
					const from = (spawnCenter - arena.AbsolutePosition) / height
					const reach = EnemyUtilities.RayToBounds(from, facing, bounds) * height

					laser = EnemyUtilities.DrawLaser(arena, spawnCenter, facing, reach, LASER_THICKNESS)
					laser.ZIndex = -1
					laser.BackgroundColor3 = LASER_COLOR
					laser.BackgroundTransparency = LASER_TRANSPARENCY_START
				end
			end

			local telegraphed = 0

			while telegraphed < TELEGRAPH_DURATION do
				const dt = RunService.Heartbeat:Wait()

				if not Queen.Active or Queen.Arena ~= arena or Queen.Phase ~= firedPhase then
					if laser then
						laser:Destroy()
					end

					promoted:Destroy()

					return
				end

				telegraphed += dt

				if laser then
					const alpha = math.clamp(telegraphed / TELEGRAPH_DURATION, 0, 1)

					laser.BackgroundTransparency =
						math.lerp(LASER_TRANSPARENCY_START, LASER_TRANSPARENCY_END, alpha * alpha)
				end
			end

			if laser then
				laser:Destroy()
			end

			local projectile: EnemyUtilities.Projectile

			-- this is such a dumb attack to write why did i come up with this
			if promotedTemplate == knightMiniTemplate then
				-- basically a copy and paste of the knight
				const boomerangConfig: EnemyUtilities.BoomerangConfig = {
					Image = promoted,
					Arena = arena,

					Spawn = spawnCenter,
					Target = targetCenter,

					TravelSpeed = 0.8,
					RotationSpeed = 1080,

					Curve = if math.random() < 0.5 then -40 else 40,

					Hitbox = Queen.IconHitbox,
					OnHit = onProjectileHit,
				}

				projectile = EnemyUtilities.FireBoomerang(boomerangConfig)

				AudioHandler.PlaySFXPooled(AudioHandler.SFX.ThrowLight)
			elseif promotedTemplate == rookMiniTemplate then
				-- direct fire bullet
				const bulletConfig: EnemyUtilities.BulletConfig = {
					Image = promoted,
					Arena = arena,

					Spawn = spawnCenter,
					Target = targetCenter,

					TravelSpeed = 2.5,
					Deceleration = 0,
					Range = 3, -- should be enough to off-screen

					Hitbox = Queen.IconHitbox,
					OnHit = onProjectileHit,
				}

				projectile = EnemyUtilities.FireBullet(bulletConfig)

				AudioHandler.PlaySFXPooled(AudioHandler.SFX.ThrowHeavy)
			elseif promotedTemplate == bishopMiniTemplate then
				-- direct fire bullet but slower and leaves a trail
				const bulletConfig: EnemyUtilities.BulletConfig = {
					Image = promoted,
					Arena = arena,

					Spawn = spawnCenter,
					Target = targetCenter,

					TravelSpeed = BISHOP_SPEED,
					Deceleration = 0,
					Range = 3, -- should be enough to off-screen

					Hitbox = Queen.IconHitbox,
					OnHit = onProjectileHit,
				}

				projectile = EnemyUtilities.FireBullet(bulletConfig)

				AudioHandler.PlaySFXPooled(AudioHandler.SFX.BishopThrow)

				emitBishopTrail(arena, projectile, firedPhase)
			else
				error("???")
			end

			promoted:Destroy()

			projectile.Image.AnchorPoint = Vector2.new(0.5, 0.5)

			table.insert(Queen.ActiveProjectiles, projectile)
		end)
	end
end

const function placeOnCircle(mini: ImageLabel, arena: Frame, target: Vector2, degrees: number, radius: number)
	const height = arena.AbsoluteSize.Y

	if height <= 0 then
		return
	end

	const angle = math.rad(degrees)
	const point = target + Vector2.new(math.cos(angle), math.sin(angle)) * radius
	const pixels = point * height

	mini.Position = UDim2.fromOffset(pixels.X, pixels.Y)
end

const function ramAttack()
	if Queen.State ~= "Idle" then
		return
	end

	const arena = Queen.Arena
	const iconHitbox = Queen.IconHitbox

	if not arena or not iconHitbox or arena.AbsoluteSize.Y <= 0 then
		return
	end

	Queen.State = "Ramming"

	const ramDirection = RAM_DIRECTIONS[math.random(1, #RAM_DIRECTIONS)]
	const angle = math.rad(ramDirection)
	const offset = Vector2.new(math.cos(angle), math.sin(angle))
	const facing = -offset

	const queenMini = queenMiniTemplate:Clone()
	queenMini.AnchorPoint = Vector2.new(0.5, 0.5)
	queenMini.Rotation = 0
	queenMini.Visible = true
	queenMini.Parent = arena

	AudioHandler.PlaySFX(AudioHandler.SFX.Alert)

	task.spawn(function()
		local elapsed = 0
		local laser: Frame? = nil
		local origin = Vector2.zero

		while elapsed < TIME_UNTIL_DASH do
			const dt = RunService.Heartbeat:Wait()

			if not Queen.Active or Queen.Arena ~= arena then
				if laser then
					laser:Destroy()
				end

				queenMini:Destroy()

				Queen.State = "Idle"

				return
			end

			elapsed += dt

			const height = arena.AbsoluteSize.Y

			if height > 0 then
				const target = (EnemyUtilities.GetCenter(iconHitbox) - arena.AbsolutePosition) / height

				origin = target + offset * DISTANCE_FROM_PLAYER

				placeOnCircle(queenMini, arena, target, ramDirection, DISTANCE_FROM_PLAYER)

				const bounds = Vector2.new(arena.AbsoluteSize.X / height, 1)
				const originAbsolute = arena.AbsolutePosition + origin * height
				const reach = EnemyUtilities.RayToBounds(origin, facing, bounds) * height

				if laser then
					EnemyUtilities.UpdateLaser(laser, originAbsolute, facing, reach, LASER_THICKNESS)
				else
					const drawn = EnemyUtilities.DrawLaser(arena, originAbsolute, facing, reach, LASER_THICKNESS)
					drawn.ZIndex = -1
					drawn.BackgroundColor3 = LASER_COLOR

					laser = drawn
				end

				const alpha = math.clamp(elapsed / TIME_UNTIL_DASH, 0, 1)

				if laser then
					laser.BackgroundTransparency =
						math.lerp(LASER_TRANSPARENCY_START, LASER_TRANSPARENCY_END, alpha * alpha)
				end
			end
		end

		if laser then
			laser:Destroy()
		end

		AudioHandler.PlaySFX(AudioHandler.SFX.ThrowHeavy)

		local position = origin
		local speed = RAM_SPEED
		local travelled = 0
		local damaged = false

		while travelled < RAM_TRAVEL do
			const rawDt = RunService.Heartbeat:Wait()

			if not Queen.Active or Queen.Arena ~= arena then
				break
			end

			const height = arena.AbsoluteSize.Y

			if height > 0 then
				const previous = position

				position, speed = EnemyUtilities.StepProjectile(position, facing, speed, 0, math.min(rawDt, MAX_STEP))
				travelled += (position - previous).Magnitude

				const pixels = position * height
				queenMini.Position = UDim2.fromOffset(pixels.X, pixels.Y)

				if not damaged and EnemyUtilities.Overlaps(queenMini.Hitbox, Queen.IconHitbox) then
					damaged = true

					damagePlayer(RAM_DAMAGE)
				end
			end
		end

		queenMini:Destroy()

		Queen.State = "Idle"
		Queen.TimeSinceLastAttack = 0
	end)
end

const function queenLines(): { Frame }?
	const arena = Queen.Arena

	if not arena then
		return nil
	end

	const container = arena:FindFirstChild("QueenAttack")

	if not container then
		return nil
	end

	const lines = {}

	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end

	if #lines == 0 then
		return nil
	end

	return lines
end

const function hideQueenLines()
	const lines = queenLines()

	if not lines then
		return
	end

	for _, line: Frame in lines do
		line.BackgroundTransparency = 1
	end
end

const function lineDirection(line: Frame): Vector2
	const size = line.AbsoluteSize
	const base = if size.X >= size.Y then Vector2.xAxis else Vector2.yAxis
	const angle = math.rad(line.Rotation)
	const cos, sin = math.cos(angle), math.sin(angle)

	return Vector2.new(base.X * cos - base.Y * sin, base.X * sin + base.Y * cos)
end

const function lineAttack()
	if Queen.State ~= "Idle" then
		return
	end

	const arena = Queen.Arena
	const lines = queenLines()

	if not arena or not lines or arena.AbsoluteSize.Y <= 0 then
		return
	end

	Queen.State = "Slashing"

	const line = lines[math.random(1, #lines)]
	const along = lineDirection(line)
	const direction = if math.random() < 0.5 then along else -along

	const queenMini = queenMiniTemplate:Clone()
	queenMini.AnchorPoint = Vector2.new(0.5, 0.5)
	queenMini.Rotation = 0
	queenMini.Visible = false
	queenMini.Parent = arena

	AudioHandler.PlaySFX(AudioHandler.SFX.Alert)

	task.spawn(function()
		local elapsed = 0

		while elapsed < LINE_TELEGRAPH_DURATION do
			const dt = RunService.Heartbeat:Wait()

			if not Queen.Active or Queen.Arena ~= arena then
				queenMini:Destroy()
				hideQueenLines()

				Queen.State = "Idle"

				return
			end

			elapsed += dt

			const alpha = math.clamp(elapsed / LINE_TELEGRAPH_DURATION, 0, 1)

			line.BackgroundColor3 = LINE_HIGHLIGHT_COLOR
			line.BackgroundTransparency = math.lerp(1, LINE_TELEGRAPH_TRANSPARENCY, alpha)
		end

		line.BackgroundColor3 = LINE_FLASH_COLOR
		line.BackgroundTransparency = LINE_FLASH_TRANSPARENCY

		AudioHandler.PlaySFX(AudioHandler.SFX.ThrowHeavy)
		ScreenEffects.ShakeBattleContainer(8, 0.1, true)

		const height = arena.AbsoluteSize.Y
		const center = Vector2.new(arena.AbsoluteSize.X / height, 1) / 2

		local position = center - direction * LINE_DASH_START
		local speed = LINE_DASH_SPEED
		local travelled = 0
		local damaged = false

		queenMini.Visible = true

		while travelled < LINE_DASH_START * 2 do
			const rawDt = RunService.Heartbeat:Wait()

			if not Queen.Active or Queen.Arena ~= arena then
				break
			end

			const currentHeight = arena.AbsoluteSize.Y

			if currentHeight > 0 then
				const previous = position

				position, speed =
					EnemyUtilities.StepProjectile(position, direction, speed, 0, math.min(rawDt, MAX_STEP))
				travelled += (position - previous).Magnitude

				const pixels = position * currentHeight
				queenMini.Position = UDim2.fromOffset(pixels.X, pixels.Y)

				if not damaged and Queen.IconHitbox and EnemyUtilities.Overlaps(queenMini.Hitbox, Queen.IconHitbox) then
					damaged = true

					damagePlayer(RAM_DAMAGE)
				end
			end
		end

		queenMini:Destroy()

		local faded = 0

		while faded < LINE_FADE_DURATION do
			const dt = RunService.Heartbeat:Wait()

			if not Queen.Active or Queen.Arena ~= arena then
				break
			end

			faded += dt

			const alpha = math.clamp(faded / LINE_FADE_DURATION, 0, 1)

			line.BackgroundTransparency = math.lerp(LINE_FLASH_TRANSPARENCY, 1, alpha)
		end

		line.BackgroundTransparency = 1

		Queen.State = "Idle"
	end)
end

function Queen.Tick(dt: number)
	if Queen.AnimatePortrait then
		updatePortrait(dt)
	end

	if not Queen.Active then
		return
	end

	Queen.TimeSinceLastAttack += dt
	Queen.TimeSinceLastLine += dt

	const currentCharge = player:GetAttribute("Charge") or 0
	const chargeAlpha = math.clamp(currentCharge / MAX_CHARGE, 0, 1)

	const phase = Queen.Phase

	if phase == 1 then
		const TIME_BETWEEN_ATTACK = math.lerp(3, 2, chargeAlpha)

		if Queen.TimeSinceLastAttack >= TIME_BETWEEN_ATTACK then
			Queen.TimeSinceLastAttack -= TIME_BETWEEN_ATTACK

			pawnPromotionAttack()
		end
	elseif phase == 2 then
		const TIME_BETWEEN_ATTACK = math.lerp(1.5, 0, chargeAlpha)

		if Queen.State == "Idle" and Queen.TimeSinceLastAttack >= TIME_BETWEEN_ATTACK then
			Queen.TimeSinceLastAttack = 0

			ramAttack()
		end
	else
		const PROMOTION_INTERVAL = math.lerp(4, 2, chargeAlpha)
		const LINE_INTERVAL = math.lerp(2.4, 1.6, chargeAlpha)

		if Queen.TimeSinceLastAttack >= PROMOTION_INTERVAL then
			Queen.TimeSinceLastAttack -= PROMOTION_INTERVAL

			pawnPromotionAttack()
		end

		if Queen.State == "Idle" and Queen.TimeSinceLastLine >= LINE_INTERVAL then
			Queen.TimeSinceLastLine = 0

			lineAttack()
		end
	end
end

function Queen.Begin(arena: Frame, iconHitbox: Frame, portrait: ImageLabel)
	player:AddTag("InBattle")

	Queen.Arena = arena
	Queen.IconHitbox = iconHitbox
	Queen.Portrait = portrait
	Queen.Origin = portrait.Position
	Queen.Phase = 1
	Queen.SineTime = 0
	Queen.TimeSinceLastAttack = 0
	Queen.TimeSinceLastLine = 0
	Queen.State = "Idle"
	Queen.AnimatePortrait = true
	Queen.Active = true

	hideQueenLines()

	Queen.RunningConnection = RunService.Heartbeat:Connect(Queen.Tick)

	const fadeIn = true
	AudioHandler.PlayMusic(AudioHandler.Music.Queen1, fadeIn)
end

function Queen.PlayerAttack(cyclicFix: (inputEnabled: boolean, chargeEnabled: boolean, resetCharge: boolean) -> ())
	AudioHandler.PlaySFX(AudioHandler.SFX.ChargeHit)

	const fadeOut = true
	const capturedPhase = Queen.Phase

	Queen.Active = false

	const function playPhaseDialogue()
		if capturedPhase >= 3 then
			return
		end

		cyclicFix(false, false, true)

		if capturedPhase == 1 then
			playChapterBindable:Fire(Chapters.QueenFinishPhaseOne)
		else
			playChapterBindable:Fire(Chapters.QueenFinishPhaseTwo)
		end

		CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()

		Queen.Active = true

		const fadeIn = false
		AudioHandler.PlayMusic(AudioHandler.Music.Queen1, fadeIn)

		cyclicFix(true, true, true)
	end

	const stoppedMusic = AudioHandler.StopMusic(fadeOut)

	if stoppedMusic then
		stoppedMusic:Once(playPhaseDialogue)
	else
		task.spawn(playPhaseDialogue)
	end

	if Queen.Phase == 1 then
		Queen.Phase = 2

		Queen.State = "Idle"

		for _, projectile: EnemyUtilities.Projectile in Queen.ActiveProjectiles do
			projectile:Cancel()
		end
		table.clear(Queen.ActiveProjectiles)
	elseif Queen.Phase == 2 then
		Queen.Phase = 3

		Queen.State = "Idle"
		Queen.TimeSinceLastLine = 0

		TweenService:Create(
			Queen.Portrait,
			TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
			{ Position = Queen.Origin }
		):Play()
	else
		Queen.End()
	end
end

function Queen.End()
	player:RemoveTag("InBattle")

	if Queen.RunningConnection then
		Queen.RunningConnection:Disconnect()
		Queen.RunningConnection = nil
	end

	Queen.Active = false

	hideQueenLines()

	Queen.Arena = nil
	Queen.IconHitbox = nil
	Queen.Portrait = nil
end

return Queen
