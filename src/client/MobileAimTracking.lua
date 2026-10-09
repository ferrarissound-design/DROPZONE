-- Gentle camera tracking during the mobile AIM toggle only.
-- Never fires, edits damage, or bypasses the server's own shot/cover raycast.
local MobileAimTracking = {}
MobileAimTracking.__index = MobileAimTracking

function MobileAimTracking.new(config)
    return setmetatable({config = config, lockedId = nil, lockedPart = nil,
        nextScan = 0, lastManualLook = -math.huge}, MobileAimTracking)
end

function MobileAimTracking:clear()
    self.lockedId, self.lockedPart, self.nextScan = nil, nil, 0
    self.lastManualLook = -math.huge
end

function MobileAimTracking:manualLook(now)
    self.lastManualLook = now
end

function MobileAimTracking:scan(ray, origin, targets, character, effectsFolder, now, force)
    local config = self.config
    if not force and now < self.nextScan then
        local part = self.lockedPart
        return part and part.Position + Vector3.new(0, .8, 0) or nil
    end
    self.nextScan = now + config.MobileAssistScanInterval
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, effectsFolder}
    params.RespectCanCollide = false

    local acquireDot = math.cos(math.rad(config.MobileAssistAcquireDegrees))
    local keepDot = math.cos(math.rad(config.MobileAssistKeepDegrees))
    local best, bestPart, bestId, bestDot = nil, nil, nil, acquireDot
    local retained, retainedPart, retainedId

    for _, candidate in ipairs(targets or {}) do
        local model = candidate.model
        local part = model and model ~= character and model:FindFirstChild("HumanoidRootPart")
        if part then
            local position = part.Position + Vector3.new(0, .8, 0)
            local cameraDelta = position - ray.Origin
            local shotDelta = position - origin
            if cameraDelta.Magnitude > 1 and cameraDelta.Magnitude <= config.MobileAssistRange
                and shotDelta.Magnitude > 1 and shotDelta:Dot(ray.Direction) > 0 then
                local dot = cameraDelta.Unit:Dot(ray.Direction)
                local identity = candidate.id or model
                if dot >= acquireDot or (identity == self.lockedId and dot >= keepDot) then
                    -- Both camera and authoritative muzzle must see the enemy.
                    -- In particular, camera peeking past cover cannot aim through it.
                    local cameraBlock = workspace:Raycast(ray.Origin, cameraDelta, params)
                    local muzzleBlock = workspace:Raycast(origin, shotDelta, params)
                    local cameraClear = not cameraBlock or cameraBlock.Instance:IsDescendantOf(model)
                    local muzzleClear = not muzzleBlock or muzzleBlock.Instance:IsDescendantOf(model)
                    if cameraClear and muzzleClear then
                        if identity == self.lockedId and dot >= keepDot then
                            retained, retainedPart, retainedId = position, part, identity
                        elseif dot > bestDot then
                            best, bestPart, bestId, bestDot = position, part, identity, dot
                        end
                    end
                end
            end
        end
    end
    if retained then
        self.lockedId, self.lockedPart = retainedId, retainedPart
        return retained
    end
    self.lockedId, self.lockedPart = bestId, bestPart
    return best
end

function MobileAimTracking:track(camera, ray, target, dt, now)
    if not target or not camera or camera.CameraType ~= Enum.CameraType.Custom then return false end
    if now - self.lastManualLook < self.config.MobileAssistManualPause then return false end
    local toTarget = target - ray.Origin
    if toTarget.Magnitude < 1 then return false end
    local look, desired = camera.CFrame.LookVector, toTarget.Unit
    local angle = math.acos(math.clamp(look:Dot(desired), -1, 1))
    if angle < 0.0001 then return false end
    local step = math.rad(self.config.MobileAssistMaxDegreesPerSecond) * math.min(dt, .1)
    local smooth = 1 - math.exp(-self.config.MobileAssistResponse * math.min(dt, .1))
    local alpha = math.min(1, step / angle, smooth)
    local direction = (look + (desired - look) * alpha).Unit
    local focus = camera.Focus.Position
    local distance = (camera.CFrame.Position - focus).Magnitude
    local position = focus - direction * distance
    camera.CFrame = CFrame.lookAt(position, position + direction)
    return true
end

return MobileAimTracking
