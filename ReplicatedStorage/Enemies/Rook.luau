const CollectionService = game:GetService("CollectionService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const AudioHandler = require(ReplicatedStorage.AudioHandler)
const Chapters = require(ReplicatedStorage.Chapters)
const EnemyUtilities = require(ReplicatedStorage.EnemyUtilities)
const ScreenEffects = require(ReplicatedStorage.ScreenEffects)

type State = "Idle" | "Tracing" | "Launching" | "Aiming" | "Crushing"

const EnemyAssets = ReplicatedStorage.EnemyAssets
const RookMiniTemplate = EnemyAssets.Minis.Rook
const ArrowTemplate = EnemyAssets.Attacks.Arrow

const IN_DIALOGUE_TAG = "InDialogue"

const Events = ReplicatedStorage.Events
const playChapterBindable = Events.PlayChapter

const player = Players.LocalPlayer

const MAX_CHARGE = 100
const MINI_SIZE = 0.125
const MINI_HALF = MINI_SIZE / 2
const TRACE_DURATION = 0.9
const LOCK_DURATION = 0.2
const LAUNCH_SPEED = 1.8
const DECELERATION = 0.9
const RAM_DAMAGE = 30
const DAMAGE_COOLDOWN = 0.5
const LASER_THICKNESS_START = 3
const LASER_COLOR = Color3.new(1, 0, 0)
const LASER_TRANSPARENCY_START = 0.9
const LASER_TRANSPARENCY_END = 0.35
const MAX_STEP = 1 / 30

const ARROW_SIZE = 0.15
const ARROW_HALF = ARROW_SIZE / 2
const ARROW_ROTATION_OFFSET = 90
const ARROW_WARNING_DURATION = 0.25
const ARROW_SPEED = 2.6
const ARROW_DAMAGE = 20
const ARROW_LIFETIME = 4
const ARROW_FADE_DURATION = 0.5
const ARROW_MAX_FLIGHT_TIME = 3

const CRUSH_GAP = 0.22
const CRUSH_GAP_HALF = CRUSH_GAP / 2
const CRUSH_CLOSE_DURATION = 1.7
const CRUSH_HOLD_DURATION = 0.35
const CRUSH_RETRACT_DURATION = 0.25
const CRUSH_TRANSPARENCY = 0.25
const CRUSH_DAMAGE = 25
const CRUSH_COLOR = Color3.new(1, 0, 0)

const Rook = {}
Rook.Arena = nil :: Frame
Rook.IconHitbox = nil :: Frame
Rook.Portrait = nil :: ImageLabel
Rook.Origin = UDim2.fromScale(0.5, 0.24)
Rook.Phase = 1
Rook.RunningConnection = nil :: RBXScriptConnection?
Rook.SineTime = 0
Rook.TimeSinceLastAttack = 0
Rook.State = "Idle" :: State
Rook.AnimatePortrait = true
Rook.Active = false
Rook.Mini = nil :: ImageLabel?
Rook.MiniPosition = Vector2.zero
Rook.MiniDirection = Vector2.zero
Rook.MiniSpeed = 0
Rook.Laser = nil :: Frame?
Rook.ActiveArrows = {} :: { ImageLabel }
Rook.CrushRestSizes = {} :: { [Frame]: UDim2 }

const function damagePlayer(amount: number)
	const playerCharge = player:GetAttribute("Charge") or 0
	player:SetAttribute("Charge", playerCharge - amount)

	AudioHandler.PlaySFX(AudioHandler.SFX.PlayerHit)
	AudioHandler.DoEffect("PlayerHit")

	ScreenEffects.ShakeBattleContainer(5, 0.05, true)
end

const function updatePortrait(dt: number)
	const AMPLITUDE = 16
	const SPEED_MULTIPLIER = 1.5
	const sineResult = math.sin(Rook.SineTime) * AMPLITUDE
	Rook.SineTime += (dt * SPEED_MULTIPLIER)

	const currentPosition = Rook.Portrait.Position

	Rook.Portrait.Position = UDim2.new(currentPosition.X.Scale, 0, currentPosition.Y.Scale, sineResult)
end

const function arenaBounds(arena: Frame): Vector2
	const size = arena.AbsoluteSize

	if size.Y <= 0 then
		return Vector2.one
	end

	return Vector2.new(size.X / size.Y, 1)
end

const function rayToWall(origin: Vector2, direction: Vector2, bounds: Vector2): number
	local best = math.huge

	if math.abs(direction.X) > 1e-6 then
		const target = if direction.X > 0 then bounds.X else 0
		best = math.min(best, (target - origin.X) / direction.X)
	end

	if math.abs(direction.Y) > 1e-6 then
		const target = if direction.Y > 0 then bounds.Y else 0
		best = math.min(best, (target - origin.Y) / direction.Y)
	end

	if best == math.huge then
		return 0
	end

	return math.max(best, 0)
end

const function updateMiniPosition(mini: ImageLabel, arena: Frame)
	const height = arena.AbsoluteSize.Y

	if height <= 0 then
		return
	end

	const pixels = Rook.MiniPosition * height
	mini.Position = UDim2.fromOffset(pixels.X, pixels.Y)
end

const function ramAttack()
	if Rook.State ~= "Idle" then
		return
	end

	const arena = Rook.Arena
	const mini = Rook.Mini

	if not arena or not mini then
		return
	end

	Rook.State = "Tracing"

	local appliedDamage = false

	AudioHandler.PlaySFX(AudioHandler.SFX.Alert)

	task.spawn(function()
		local elapsed = 0
		local aim = Vector2.zero
		local aborted = false

		while true do
			const dt = RunService.Heartbeat:Wait()

			if not Rook.Active or Rook.Phase ~= 1 then
				aborted = true
				break
			end

			elapsed += dt

			const height = arena.AbsoluteSize.Y

			if height > 0 and Rook.IconHitbox then
				updateMiniPosition(mini, arena)

				const origin = EnemyUtilities.GetCenter(mini)
				const toPlayer = EnemyUtilities.GetCenter(Rook.IconHitbox) - origin

				if toPlayer.Magnitude > 0 then
					aim = toPlayer.Unit

					const reach = rayToWall(Rook.MiniPosition, aim, arenaBounds(arena)) * height

					const chargeAlpha = math.clamp(elapsed / TRACE_DURATION, 0, 1)
					const revealAlpha = chargeAlpha * chargeAlpha
					const thickness = math.lerp(LASER_THICKNESS_START, MINI_SIZE * height, revealAlpha)

					if Rook.Laser then
						EnemyUtilities.UpdateLaser(Rook.Laser, origin, aim, reach, thickness)
					else
						const laser = EnemyUtilities.DrawLaser(arena, origin, aim, reach, thickness)
						laser.ZIndex = -1
						laser.BackgroundColor3 = LASER_COLOR

						Rook.Laser = laser
					end

					Rook.Laser.BackgroundTransparency =
						math.lerp(LASER_TRANSPARENCY_START, LASER_TRANSPARENCY_END, revealAlpha)
				end
			end

			if elapsed >= TRACE_DURATION then
				break
			end
		end

		if not aborted and aim.Magnitude > 0 then
			local held = 0

			while held < LOCK_DURATION do
				const dt = RunService.Heartbeat:Wait()

				if not Rook.Active or Rook.Phase ~= 1 or Rook.Arena ~= arena or Rook.Mini ~= mini then
					aborted = true
					break
				end

				held += dt

				const height = arena.AbsoluteSize.Y

				if height > 0 and Rook.Laser then
					const origin = EnemyUtilities.GetCenter(mini)
					const reach = rayToWall(Rook.MiniPosition, aim, arenaBounds(arena)) * height

					EnemyUtilities.UpdateLaser(Rook.Laser, origin, aim, reach, MINI_SIZE * height)

					Rook.Laser.BackgroundTransparency = LASER_TRANSPARENCY_END
				end
			end
		end

		if Rook.Laser then
			Rook.Laser:Destroy()
			Rook.Laser = nil
		end

		if aborted or aim.Magnitude == 0 then
			Rook.State = "Idle"
			Rook.TimeSinceLastAttack = 0

			return
		end

		Rook.State = "Launching"
		Rook.MiniDirection = aim
		Rook.MiniSpeed = LAUNCH_SPEED

		AudioHandler.PlaySFX(AudioHandler.SFX.ThrowHeavy)

		while true do
			const rawDt = RunService.Heartbeat:Wait()

			if not Rook.Active or Rook.Phase ~= 1 or Rook.Arena ~= arena or Rook.Mini ~= mini then
				return
			end

			local bounced

			Rook.MiniPosition, Rook.MiniDirection, Rook.MiniSpeed, bounced = EnemyUtilities.StepBouncingProjectile(
				Rook.MiniPosition,
				Rook.MiniDirection,
				Rook.MiniSpeed,
				DECELERATION,
				math.min(rawDt, MAX_STEP),
				arenaBounds(arena),
				MINI_HALF
			)

			updateMiniPosition(mini, arena)

			if bounced then
				AudioHandler.PlaySFXPooled(AudioHandler.SFX.RookBounce)
				ScreenEffects.ShakeBattleContainer(10, 0.05, true)
			end

			if not appliedDamage and Rook.IconHitbox and EnemyUtilities.Overlaps(mini.Hitbox, Rook.IconHitbox) then
				appliedDamage = true

				task.delay(DAMAGE_COOLDOWN, function()
					appliedDamage = false
				end)

				damagePlayer(RAM_DAMAGE)
			end

			if Rook.MiniSpeed <= 0 then
				break
			end
		end

		Rook.State = "Idle"
		Rook.TimeSinceLastAttack = 0
	end)
end

const function arrowAttack()
	if Rook.State ~= "Idle" then
		return
	end

	const arena = Rook.Arena
	const portrait = Rook.Portrait
	const iconHitbox = Rook.IconHitbox

	if not arena or not portrait or not iconHitbox then
		return
	end

	const height = arena.AbsoluteSize.Y

	if height <= 0 then
		return
	end

	const bounds = arenaBounds(arena)
	const spawn = (EnemyUtilities.GetCenter(portrait) - arena.AbsolutePosition) / height
	const toTarget = (EnemyUtilities.GetCenter(iconHitbox) - arena.AbsolutePosition) / height - spawn

	if toTarget.Magnitude == 0 then
		return
	end

	const direction = toTarget.Unit
	const travel = rayToWall(spawn, direction, bounds)
	const stickPosition = Vector2.new(
		math.clamp(spawn.X + direction.X * travel, ARROW_HALF, bounds.X - ARROW_HALF),
		math.clamp(spawn.Y + direction.Y * travel, ARROW_HALF, bounds.Y - ARROW_HALF)
	)

	Rook.State = "Aiming"

	AudioHandler.PlaySFX(AudioHandler.SFX.Alert)

	task.spawn(function()
		local warned = 0

		while warned < ARROW_WARNING_DURATION do
			const dt = RunService.Heartbeat:Wait()

			if not Rook.Active or Rook.Phase ~= 2 then
				if Rook.Laser then
					Rook.Laser:Destroy()
					Rook.Laser = nil
				end

				Rook.State = "Idle"

				return
			end

			warned += dt

			const currentHeight = arena.AbsoluteSize.Y

			if currentHeight > 0 then
				const origin = arena.AbsolutePosition + spawn * currentHeight
				const reach = travel * currentHeight
				const revealAlpha = math.clamp(warned / ARROW_WARNING_DURATION, 0, 1)

				if Rook.Laser then
					EnemyUtilities.UpdateLaser(Rook.Laser, origin, direction, reach, LASER_THICKNESS_START)
				else
					const laser = EnemyUtilities.DrawLaser(arena, origin, direction, reach, LASER_THICKNESS_START)
					laser.ZIndex = -1
					laser.BackgroundColor3 = LASER_COLOR

					Rook.Laser = laser
				end

				Rook.Laser.BackgroundTransparency =
					math.lerp(LASER_TRANSPARENCY_START, LASER_TRANSPARENCY_END, revealAlpha)
			end
		end

		if Rook.Laser then
			Rook.Laser:Destroy()
			Rook.Laser = nil
		end

		Rook.State = "Idle"

		const arrow = ArrowTemplate:Clone()
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Size = UDim2.fromScale(1, ARROW_SIZE)
		arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + ARROW_ROTATION_OFFSET
		arrow.ZIndex = 0
		arrow.Visible = true

		const arrowHitbox = arrow.Hitbox :: Frame

		local position = spawn
		arrow.Position = UDim2.fromOffset(position.X * height, position.Y * height)
		arrow.Parent = arena

		table.insert(Rook.ActiveArrows, arrow)

		AudioHandler.PlaySFXPooled(AudioHandler.SFX.ThrowLight)

		local flightTime = 0
		local travelled = 0
		local hitPlayer = false

		while true do
			const rawDt = RunService.Heartbeat:Wait()

			if not Rook.Active or Rook.Phase ~= 2 or Rook.Arena ~= arena then
				arrow:Destroy()

				const index = table.find(Rook.ActiveArrows, arrow)
				if index then
					table.remove(Rook.ActiveArrows, index)
				end

				return
			end

			const currentHeight = arena.AbsoluteSize.Y

			if currentHeight > 0 then
				const step = math.min(rawDt, MAX_STEP)

				flightTime += step
				travelled += ARROW_SPEED * step

				local stuck = false

				if travelled >= travel then
					position = stickPosition
					stuck = true
				else
					position = spawn + direction * travelled
				end

				arrow.Position = UDim2.fromOffset(position.X * currentHeight, position.Y * currentHeight)

				if not hitPlayer and Rook.IconHitbox and EnemyUtilities.Overlaps(arrowHitbox, Rook.IconHitbox) then
					hitPlayer = true

					damagePlayer(ARROW_DAMAGE)
				end

				if stuck then
					AudioHandler.PlaySFXPooled(AudioHandler.SFX.RookBounce)

					break
				end
			end

			if flightTime >= ARROW_MAX_FLIGHT_TIME then
				arrow:Destroy()

				const index = table.find(Rook.ActiveArrows, arrow)
				if index then
					table.remove(Rook.ActiveArrows, index)
				end

				return
			end
		end

		task.wait(ARROW_LIFETIME)

		if arrow.Parent then
			TweenService:Create(arrow, TweenInfo.new(ARROW_FADE_DURATION), { ImageTransparency = 1 }):Play()

			task.wait(ARROW_FADE_DURATION)
		end

		arrow:Destroy()

		const index = table.find(Rook.ActiveArrows, arrow)
		if index then
			table.remove(Rook.ActiveArrows, index)
		end
	end)
end

const function crushAttack()
	if Rook.State ~= "Idle" then
		return
	end

	const arena = Rook.Arena
	const container = arena.RookAttack
	const frames = {
		Left = container.LeftFrame,
		Right = container.RightFrame,
		Top = container.TopFrame,
		Bottom = container.BottomFrame,
	}

	if not frames then
		return
	end

	const horizontal = math.random() < 0.5
	const first = if horizontal then frames.Left else frames.Top
	const second = if horizontal then frames.Right else frames.Bottom

	const gapCenter = math.lerp(CRUSH_GAP_HALF, 1 - CRUSH_GAP_HALF, math.random())
	const firstExtent = gapCenter - CRUSH_GAP_HALF
	const secondExtent = 1 - (gapCenter + CRUSH_GAP_HALF)

	Rook.State = "Crushing"

	first.BackgroundColor3 = CRUSH_COLOR
	second.BackgroundColor3 = CRUSH_COLOR

	AudioHandler.PlaySFX(AudioHandler.SFX.Alert)

	task.spawn(function()
		local elapsed = 0
		local damaged = false
		local slammed = false

		while true do
			const dt = RunService.Heartbeat:Wait()

			if not Rook.Active or Rook.Phase ~= 3 then
				for _, frame: Frame in frames do
					frame.Size = Rook.CrushRestSizes[frame] or frame.Size
					frame.BackgroundTransparency = 1
				end

				Rook.State = "Idle"

				return
			end

			elapsed += dt

			local alpha: number
			local transparency: number

			if elapsed < CRUSH_CLOSE_DURATION then
				const closeAlpha = elapsed / CRUSH_CLOSE_DURATION

				alpha = closeAlpha
				transparency = math.lerp(1, CRUSH_TRANSPARENCY, closeAlpha)
			elseif elapsed < CRUSH_CLOSE_DURATION + CRUSH_HOLD_DURATION then
				alpha = 1
				transparency = 0

				if not slammed then
					slammed = true

					AudioHandler.PlaySFX(AudioHandler.SFX.KnightFork)
					ScreenEffects.ShakeBattleContainer(10, 0.1, true)
				end
			else
				const retractAlpha =
					math.clamp((elapsed - CRUSH_CLOSE_DURATION - CRUSH_HOLD_DURATION) / CRUSH_RETRACT_DURATION, 0, 1)

				alpha = 1 - retractAlpha
				transparency = retractAlpha
			end

			if horizontal then
				first.Size = UDim2.fromScale(firstExtent * alpha, 1)
				second.Size = UDim2.fromScale(secondExtent * alpha, 1)
			else
				first.Size = UDim2.fromScale(1, firstExtent * alpha)
				second.Size = UDim2.fromScale(1, secondExtent * alpha)
			end

			first.BackgroundTransparency = transparency
			second.BackgroundTransparency = transparency

			if slammed and not damaged and Rook.IconHitbox then
				if
					EnemyUtilities.Overlaps(first, Rook.IconHitbox)
					or EnemyUtilities.Overlaps(second, Rook.IconHitbox)
				then
					damaged = true

					damagePlayer(CRUSH_DAMAGE)
				end
			end

			if elapsed >= CRUSH_CLOSE_DURATION + CRUSH_HOLD_DURATION + CRUSH_RETRACT_DURATION then
				break
			end
		end

		for _, frame: Frame in frames do
			frame.Size = Rook.CrushRestSizes[frame] or frame.Size
			frame.BackgroundTransparency = 1
		end

		Rook.State = "Idle"
		Rook.TimeSinceLastAttack = 0
	end)
end

function Rook.Tick(dt: number)
	if Rook.AnimatePortrait then
		updatePortrait(dt)
	end

	if not Rook.Active then
		return
	end

	Rook.TimeSinceLastAttack += dt

	const phase = Rook.Phase

	if phase == 1 then
		const mini = Rook.Mini

		if mini and Rook.State == "Idle" then
			updateMiniPosition(mini, Rook.Arena)
		end

		const currentCharge = player:GetAttribute("Charge") or 0
		const chargeAlpha = math.clamp(currentCharge / MAX_CHARGE, 0, 1)
		const TIME_BETWEEN_ATTACK = math.lerp(1.5, 0, chargeAlpha)

		if Rook.State == "Idle" and Rook.TimeSinceLastAttack >= TIME_BETWEEN_ATTACK then
			Rook.TimeSinceLastAttack = 0

			ramAttack()
		end
	elseif phase == 2 then
		const currentCharge = player:GetAttribute("Charge") or 0
		const chargeAlpha = math.clamp(currentCharge / MAX_CHARGE, 0, 1)
		const TIME_BETWEEN_ATTACK = math.lerp(1.6, 0.9, chargeAlpha)

		if Rook.State == "Idle" and Rook.TimeSinceLastAttack >= TIME_BETWEEN_ATTACK then
			Rook.TimeSinceLastAttack = 0

			arrowAttack()
		end
	else
		const currentCharge = player:GetAttribute("Charge") or 0
		const chargeAlpha = math.clamp(currentCharge / MAX_CHARGE, 0, 1)
		const TIME_BETWEEN_ATTACK = math.lerp(2.5, 1.5, chargeAlpha)

		if Rook.State == "Idle" and Rook.TimeSinceLastAttack >= TIME_BETWEEN_ATTACK then
			Rook.TimeSinceLastAttack = 0

			crushAttack()
		end
	end
end

function Rook.Begin(arena: Frame, iconHitbox: Frame, portrait: ImageLabel)
	player:AddTag("InBattle")

	Rook.Arena = arena
	Rook.IconHitbox = iconHitbox
	Rook.Portrait = portrait
	Rook.Origin = portrait.Position
	Rook.Phase = 1
	Rook.SineTime = 0
	Rook.TimeSinceLastAttack = 0
	Rook.State = "Idle"
	Rook.AnimatePortrait = true
	Rook.Active = true

	const mini = RookMiniTemplate:Clone()
	mini.AnchorPoint = Vector2.new(0.5, 0.5)
	mini.Rotation = 0
	mini.ZIndex = 0
	mini.Size = UDim2.fromScale(1, MINI_SIZE)
	mini.Visible = true

	Rook.MiniPosition = arenaBounds(arena) / 2

	updateMiniPosition(mini, arena)
	mini.Parent = arena

	Rook.Mini = mini

	const frames = Rook.Arena.RookAttack:GetChildren()
	for _, frame in frames do
		Rook.CrushRestSizes[frame] = frame.Size
	end

	Rook.RunningConnection = RunService.Heartbeat:Connect(Rook.Tick)

	const fadeIn = false
	AudioHandler.PlayMusic(AudioHandler.Music.Rook1, fadeIn)
end

function Rook.PlayerAttack(cyclicFix: (inputEnabled: boolean, chargeEnabled: boolean, resetCharge: boolean) -> ())
	AudioHandler.PlaySFX(AudioHandler.SFX.ChargeHit)

	const fadeOut = true
	const capturedPhase = Rook.Phase

	Rook.Active = false

	const function playPhaseDialogue()
		if capturedPhase >= 3 then
			return
		end

		cyclicFix(false, false, true)

		if capturedPhase == 1 then
			playChapterBindable:Fire(Chapters.RookFinishPhaseOne)
		else
			playChapterBindable:Fire(Chapters.RookFinishPhaseTwo)
		end

		CollectionService:GetInstanceRemovedSignal(IN_DIALOGUE_TAG):Wait()

		Rook.Active = true

		const fadeIn = false
		AudioHandler.PlayMusic(AudioHandler.Music.Rook1, fadeIn)

		cyclicFix(true, true, true)
	end

	const stoppedMusic = AudioHandler.StopMusic(fadeOut)

	if stoppedMusic then
		stoppedMusic:Once(playPhaseDialogue)
	else
		task.spawn(playPhaseDialogue)
	end

	if Rook.Phase == 1 then
		Rook.Phase = 2

		if Rook.Laser then
			Rook.Laser:Destroy()
			Rook.Laser = nil
		end

		if Rook.Mini then
			Rook.Mini:Destroy()
			Rook.Mini = nil
		end

		Rook.MiniDirection = Vector2.zero
		Rook.MiniSpeed = 0
		Rook.State = "Idle"
	elseif Rook.Phase == 2 then
		Rook.Phase = 3

		if Rook.Laser then
			Rook.Laser:Destroy()
			Rook.Laser = nil
		end

		for _, arrow: ImageLabel in Rook.ActiveArrows do
			arrow:Destroy()
		end

		table.clear(Rook.ActiveArrows)

		Rook.State = "Idle"

		TweenService:Create(
			Rook.Portrait,
			TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
			{ Position = Rook.Origin }
		):Play()
	else
		Rook.End()
	end
end

function Rook.End()
	player:RemoveTag("InBattle")

	if Rook.RunningConnection then
		Rook.RunningConnection:Disconnect()
		Rook.RunningConnection = nil
	end

	Rook.Active = false

	for _, frame: Frame in Rook.Arena.RookAttack:GetChildren() do
		frame.Size = Rook.CrushRestSizes[frame] or frame.Size
		frame.BackgroundTransparency = 1
	end

	Rook.Arena = nil
	Rook.IconHitbox = nil
	Rook.Portrait = nil
end

return Rook
