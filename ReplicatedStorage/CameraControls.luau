const TweenService = game:GetService("TweenService")
const function getCamera(): Camera
	repeat
		task.wait()
	until workspace.CurrentCamera

	return workspace.CurrentCamera
end

-- in hindsight this entire thing is so useless except for .TweenTo, this is why you don't let me make a game without planning
const CameraControls = {}

function CameraControls.TweenTo(target: CFrame, tweenInfo: TweenInfo?): RBXScriptSignal?
	const camera = getCamera()

	const tween = TweenService:Create(camera, tweenInfo, { CFrame = target })
	tween:Play()

	return tween.Completed
end

function CameraControls.GoTo(target: CFrame)
	getCamera().CFrame = target
end

function CameraControls.SetType(cameraType: Enum.CameraType)
	getCamera().CameraType = cameraType
end

function CameraControls.GetCFrame(): CFrame
	return getCamera().CFrame
end

return CameraControls
