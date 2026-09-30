local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Effects = {}
Effects.__index = Effects
function Effects.new()
    local old = workspace:FindFirstChild("DropzoneLocalEffects")
    if old then old:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "DropzoneLocalEffects", workspace
    local self = setmetatable({folder = folder, rings = {}, tracers = 0, impacts = 0}, Effects)
    for ring = 1, 2 do
        self.rings[ring] = {}
        for i = 1, 48 do
            local p = Instance.new("Part")
            p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = "ZoneBoundary", true, false, false, false
            p.Material, p.Color = Enum.Material.Neon, ring == 1 and Color3.fromRGB(58, 188, 255) or Color3.fromRGB(231, 240, 248)
            p.Parent = folder
            self.rings[ring][i] = p
        end
    end
    return self
end
function Effects:zone(z, active)
    local previous = self.previousZone
    if previous and previous.active == active and previous.radius == z.radius
        and previous.nextRadius == z.nextRadius and previous.center == z.center
        and previous.nextCenter == z.nextCenter then return end
    self.previousZone = {active=active, radius=z.radius, nextRadius=z.nextRadius, center=z.center, nextCenter=z.nextCenter}
    for ring = 1, 2 do
        local radius, center = ring == 1 and z.radius or z.nextRadius, ring == 1 and z.center or z.nextCenter
        for i, p in ipairs(self.rings[ring]) do
            p.Transparency = active and radius > 0.1 and (ring == 1 and 0.15 or 0.4) or 1
            local angle, nextAngle = (i - 1) * math.pi * 2 / 48, i * math.pi * 2 / 48
            local a = center + Vector3.new(math.cos(angle) * radius, 1.5, math.sin(angle) * radius)
            local b = center + Vector3.new(math.cos(nextAngle) * radius, 1.5, math.sin(nextAngle) * radius)
            if (a - b).Magnitude > 0.01 then
                p.Size = Vector3.new(0.3, ring == 1 and 3 or 0.3, (a - b).Magnitude)
                p.CFrame = CFrame.lookAt((a + b) / 2, b)
            end
        end
    end
end
local function transientPart(folder, name, size, cf, color)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
    p.CastShadow, p.Material, p.Color, p.Parent = false, Enum.Material.Neon, color, folder
    return p
end
function Effects:impact(position, enemy)
    if self.impacts >= 18 then return end
    self.impacts = self.impacts + 1
    local size = enemy and .75 or .42
    local color = enemy and Color3.fromRGB(255, 164, 70) or Color3.fromRGB(255, 238, 160)
    local p = transientPart(self.folder, enemy and "EnemyHit" or "Impact", Vector3.new(size,size,size), CFrame.new(position), color)
    p.Shape = Enum.PartType.Ball
    p.Transparency = enemy and 0 or .12
    TweenService:Create(p, TweenInfo.new(enemy and .16 or .12), {Transparency = 1, Size = p.Size * 1.8}):Play()
    Debris:AddItem(p, enemy and .19 or .15)
    task.delay(enemy and .19 or .15, function() self.impacts = math.max(0, self.impacts - 1) end)
end
function Effects:shot(origin, endpoints, kind, localShot, impacts)
    for index, endpoint in ipairs(endpoints) do
        if self.tracers >= 72 then break end
        local distance = (origin - endpoint).Magnitude
        if distance > 0.01 then
            self.tracers = self.tracers + 1
            local p = Instance.new("Part")
            p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = "Tracer", true, false, false, false
            p.Material, p.Color = Enum.Material.Neon, kind == "Shotgun" and Color3.fromRGB(255, 180, 70) or Color3.fromRGB(255, 240, 150)
            local width = localShot and (kind == "Shotgun" and 0.20 or 0.16) or 0.08
            local life = localShot and 0.18 or 0.10
            p.Size, p.CFrame = Vector3.new(width, width, distance), CFrame.lookAt((origin + endpoint) / 2, endpoint)
            p.Transparency = localShot and 0 or 0.12
            p.Parent = self.folder
            TweenService:Create(p, TweenInfo.new(life), {Transparency = 1}):Play()
            Debris:AddItem(p, life + 0.03)
            task.delay(life + 0.03, function() self.tracers = self.tracers - 1 end)
            if localShot and index == 1 then
                local direction = endpoint - origin
                if direction.Magnitude > 1 then
                    local travel = math.clamp(direction.Magnitude / 1200, .045, .12)
                    local start = origin + direction.Unit * 2
                    local finish = endpoint - direction.Unit * 1.2
                    local streak = transientPart(self.folder, "BulletStreak", Vector3.new(.18,.18,2.8),
                        CFrame.lookAt(start, endpoint), kind == "Shotgun" and Color3.fromRGB(255,180,70) or Color3.fromRGB(255,245,185))
                    TweenService:Create(streak, TweenInfo.new(travel, Enum.EasingStyle.Linear), {CFrame=CFrame.lookAt(finish, endpoint)}):Play()
                    Debris:AddItem(streak, travel + .03)
                end
            end
        end
    end
    if localShot then
        for i, position in ipairs(impacts or {}) do
            if i > (kind == "Shotgun" and 3 or 1) then break end
            self:impact(position, false)
        end
    end
end
return Effects
