-- Own only a touch that started on the active Fire GUI. Standard screen drags
-- remain Roblox's responsibility; this rotation is persistent, unlike recoil.
local FireDrag = {}
FireDrag.__index = FireDrag
function FireDrag.new(config)
    return setmetatable({config=config, dx=0, dy=0}, FireDrag)
end
function FireDrag:begin(input)
    if self.input then return false end
    self.input, self.position, self.dx, self.dy = input, input.Position, 0, 0
    return true
end
function FireDrag:move(input)
    if input ~= self.input then return end
    local position = input.Position
    self.dx = self.dx + position.X - self.position.X
    self.dy = self.dy + position.Y - self.position.Y
    self.position = position
end
function FireDrag:clear()
    self.input, self.position, self.dx, self.dy = nil, nil, 0, 0
end
function FireDrag:apply(camera)
    local dx, dy = self.dx, self.dy
    self.dx, self.dy = 0, 0
    if not self.input or not camera or camera.CameraType ~= Enum.CameraType.Custom
        or (dx == 0 and dy == 0) then return end
    local look = camera.CFrame.LookVector
    local config = self.config
    -- Degrees per screen pixel. No dt multiplier: accumulate input once/frame.
    local yaw = math.atan2(-look.X, -look.Z) - math.rad(dx * config.MobileFireDragSensitivity)
    local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1))
        - math.rad(dy * config.MobileFireDragVerticalSensitivity),
        -math.rad(config.MobileFireDragPitchLimit), math.rad(config.MobileFireDragPitchLimit))
    local direction = Vector3.new(-math.sin(yaw)*math.cos(pitch), math.sin(pitch), -math.cos(yaw)*math.cos(pitch))
    local focus = camera.Focus.Position
    local distance = (camera.CFrame.Position - focus).Magnitude
    local position = focus - direction * distance
    -- Orbit the existing focus instead of panning in place: the standard camera
    -- can continue subject tracking, zoom and occlusion using this new look.
    camera.CFrame = CFrame.lookAt(position, position + direction)
end
return FireDrag
