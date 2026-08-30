const RunService = game:GetService("RunService")

const LASER_THICKNESS = 6
const BULLET_DEFAULT_RANGE = 3

const EnemyUtilities = {}

export type Projectile = {
	Image: ImageLabel,
	Active: boolean,
	Cancel: (Projectile) -> (),
}

export type BoomerangConfig = {
	Image: ImageLabel,
	Arena: Frame,

	Spawn: Vector2,
	Target: Vector2,

	TravelSpeed: number, -- arena heights per second, not pixels per second
	RotationSpeed: number, -- degrees per second

	Curve: number?, -- launch angle off the straight line, in degrees. 0 is a straight out-and-back.

	Hitbox: Frame?,
	OnHit: ((Projectile) -> ())?,
}

export type BulletConfig = {
	Image: ImageLabel,
	Arena: Frame,

	Spawn: Vector2,
	Target: Vector2,

	TravelSpeed: number, -- arena heights per second, not pixels per second
	Deceleration: number?,

	Range: number?, -- arena heights travelled before it despawns

	Hitbox: Frame?,
	OnHit: ((Projectile) -> ())?,
}

function EnemyUtilities.GetCenter(gui: GuiObject): Vector2
	return gui.AbsolutePosition + gui.AbsoluteSize / 2
end

-- 2d raycast yayayayayayayayayayay
function EnemyUtilities.RayToBounds(origin: Vector2, direction: Vector2, bounds: Vector2): number
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

-- shoddy hitbox check, but it's really easy to do
function EnemyUtilities.Overlaps(a: GuiObject, b: GuiObject): boolean
	const aPos, aSize = a.AbsolutePosition, a.AbsoluteSize
	const bPos, bSize = b.AbsolutePosition, b.AbsoluteSize

	return aPos.X < bPos.X + bSize.X
		and bPos.X < aPos.X + aSize.X
		and aPos.Y < bPos.Y + bSize.Y
		and bPos.Y < aPos.Y + aSize.Y
end

function EnemyUtilities.StepProjectile(
	position: Vector2,
	direction: Vector2,
	speed: number,
	deceleration: number,
	dt: number
): (Vector2, number)
	const stopDt = if deceleration > 0 then speed / deceleration else math.huge
	const stepDt = math.min(dt, stopDt)

	-- yay kinematics equation
	const distance = speed * stepDt - 0.5 * deceleration * stepDt * stepDt

	return position + direction * distance, math.max(speed - deceleration * stepDt, 0)
end

-- only returning true when funny bouncing logic needs to be done
const function reflect(value: number, min: number, max: number): (number, boolean)
	const width = max - min

	if width <= 0 then
		return min, false
	end

	const wrapped = (value - min) % (2 * width)

	if wrapped > width then
		return min + (2 * width - wrapped), true
	end

	return min + wrapped, false
end

-- i have to add halfExtent as a parameter because
-- .AbsoluteSize is a nightmare sometimes and will feed you
-- bad values, so i can't just do (.AbsoluteSize / 2)
function EnemyUtilities.StepBouncingProjectile(
	position: Vector2,
	direction: Vector2,
	speed: number,
	deceleration: number,
	dt: number,
	bounds: Vector2,
	halfExtent: number
): (Vector2, Vector2, number, boolean)
	const candidate, remaining = EnemyUtilities.StepProjectile(position, direction, speed, deceleration, dt)

	const x, flippedX = reflect(candidate.X, halfExtent, math.max(bounds.X - halfExtent, halfExtent))
	const y, flippedY = reflect(candidate.Y, halfExtent, math.max(bounds.Y - halfExtent, halfExtent))

	const facing =
		Vector2.new(if flippedX then -direction.X else direction.X, if flippedY then -direction.Y else direction.Y)

	return Vector2.new(x, y), facing, remaining, flippedX or flippedY
end

function EnemyUtilities.FireBoomerang(config: BoomerangConfig): Projectile
	const arena = config.Arena
	const curveDegrees = config.Curve or 0
	const localSpawn = config.Spawn - arena.AbsolutePosition

	const image = config.Image:Clone()

	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Rotation = 0
	image.Visible = true
	image.Position = UDim2.fromOffset(localSpawn.X, localSpawn.Y)
	image.Parent = arena

	const projectile: Projectile = {
		Image = image,
		Active = true,
		Cancel = function(self: Projectile)
			if not self.Active then
				return
			end
			self.Active = false
			self.Image:Destroy()
		end,
	}

	const arenaSize = arena.AbsoluteSize

	-- i actually hate having to scale this to arena-space
	const from = (config.Spawn - arena.AbsolutePosition) / arenaSize.Y
	const to = (config.Target - arena.AbsolutePosition) / arenaSize.Y
	const span = to - from

	const distance = span.Magnitude
	if distance <= 0 then
		projectile:Cancel()
		return projectile
	end

	const perpendicular = Vector2.new(-span.Unit.Y, span.Unit.X)

	const curveRad = math.rad(curveDegrees)
	const curve = (distance * math.tan(curveRad)) / 2

	-- this is some stupid trig
	const function getPositionAt(t: number): Vector2
		-- fraction along trip towards target
		const traveled = math.sin(math.pi * t)

		-- how far offsetted from span, the direct line from origin to target
		const offset = math.sin(2 * math.pi * t) * curve

		return from + (span * traveled) + (perpendicular * offset)
	end

	-- needed so i can destroy the boomerang once it reaches the end
	local arcLength = 0
	do
		const SAMPLES = 24
		local previous = getPositionAt(0)
		for index = 1, SAMPLES do
			const current = getPositionAt(index / SAMPLES)
			arcLength += (current - previous).Magnitude
			previous = current
		end
	end

	const duration = arcLength / config.TravelSpeed

	local elapsed = 0
	local hasHit = false
	local connection: RBXScriptConnection? = nil

	connection = RunService.Heartbeat:Connect(function(dt: number)
		if not projectile.Active then
			if connection then
				connection:Disconnect()
				connection = nil
			end
			return
		end

		elapsed += dt
		const t = math.min(elapsed / duration, 1)

		const point = getPositionAt(t)

		const pixels = point * arena.AbsoluteSize.Y
		image.Position = UDim2.fromOffset(pixels.X, pixels.Y)
		image.Rotation += config.RotationSpeed * dt

		const hitbox = config.Hitbox
		if not hasHit and hitbox and EnemyUtilities.Overlaps(image.Hitbox, hitbox) then
			hasHit = true
			if config.OnHit then
				config.OnHit(projectile)
			end
		end

		if t >= 1 then
			projectile:Cancel()
		end
	end)

	return projectile
end

function EnemyUtilities.FireBullet(config: BulletConfig): Projectile
	const arena = config.Arena
	const deceleration = config.Deceleration or 0
	const range = config.Range or BULLET_DEFAULT_RANGE

	const image = config.Image:Clone()

	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Rotation = 0
	image.Visible = true
	const localSpawn = config.Spawn - arena.AbsolutePosition
	image.Position = UDim2.fromOffset(localSpawn.X, localSpawn.Y)
	image.Parent = arena

	const projectile: Projectile = {
		Image = image,
		Active = true,
		Cancel = function(self: Projectile)
			if not self.Active then
				return
			end
			self.Active = false
			self.Image:Destroy()
		end,
	}

	const arenaSize = arena.AbsoluteSize
	if arenaSize.Y <= 0 or config.TravelSpeed <= 0 then
		projectile:Cancel()
		return projectile
	end

	const from = (config.Spawn - arena.AbsolutePosition) / arenaSize.Y
	const to = (config.Target - arena.AbsolutePosition) / arenaSize.Y

	const span = to - from
	if span.Magnitude <= 0 then
		projectile:Cancel()
		return projectile
	end

	const direction = span.Unit
	const imageHitbox = image:FindFirstChild("Hitbox") or image

	local position = from
	local speed = config.TravelSpeed
	local travelled = 0
	local hasHit = false
	local connection: RBXScriptConnection? = nil

	connection = RunService.Heartbeat:Connect(function(dt: number)
		if not projectile.Active then
			if connection then
				connection:Disconnect()
				connection = nil
			end
			return
		end

		const previous = position
		position, speed = EnemyUtilities.StepProjectile(position, direction, speed, deceleration, dt)
		travelled += (position - previous).Magnitude

		const pixels = position * arena.AbsoluteSize.Y
		image.Position = UDim2.fromOffset(pixels.X, pixels.Y)

		const hitbox = config.Hitbox
		if not hasHit and hitbox and EnemyUtilities.Overlaps(imageHitbox, hitbox) then
			hasHit = true
			if config.OnHit then
				config.OnHit(projectile)
			end
		end

		if travelled >= range or speed <= 0 then
			projectile:Cancel()
		end
	end)

	return projectile
end

function EnemyUtilities.FireMissile() end

function EnemyUtilities.DrawLaser(
	parent: Instance,
	origin: Vector2,
	direction: Vector2,
	magnitude: number,
	thickness: number?
): Frame
	const facing = if direction.Magnitude > 0 then direction.Unit else Vector2.xAxis

	local parentOrigin = Vector2.zero
	if parent:IsA("GuiObject") or parent:IsA("LayerCollector") then
		parentOrigin = parent.AbsolutePosition
	end

	const center = origin + facing * (magnitude / 2) - parentOrigin

	const laser = Instance.new("Frame")
	laser.AnchorPoint = Vector2.new(0.5, 0.5)
	laser.Position = UDim2.fromOffset(center.X, center.Y)
	laser.Size = UDim2.fromOffset(magnitude, thickness or LASER_THICKNESS)
	laser.Rotation = math.deg(math.atan2(facing.Y, facing.X))
	laser.BackgroundColor3 = Color3.new(1, 1, 1)
	laser.BorderSizePixel = 0
	laser.Parent = parent

	return laser
end

function EnemyUtilities.UpdateLaser(
	laser: Frame,
	origin: Vector2,
	direction: Vector2,
	magnitude: number,
	thickness: number?
)
	const facing = if direction.Magnitude > 0 then direction.Unit else Vector2.xAxis
	const parent = laser.Parent

	local parentOrigin = Vector2.zero
	if parent:IsA("GuiObject") or parent:IsA("LayerCollector") then
		parentOrigin = parent.AbsolutePosition
	end

	const center = origin + facing * (magnitude / 2) - parentOrigin

	laser.Position = UDim2.fromOffset(center.X, center.Y)
	laser.Size = UDim2.fromOffset(magnitude, thickness or LASER_THICKNESS)
	laser.Rotation = math.deg(math.atan2(facing.Y, facing.X))
end

return EnemyUtilities
