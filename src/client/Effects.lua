local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Effects = {}
Effects.__index = Effects
function Effects.new()
    local old = workspace:FindFirstChild("DropzoneLocalEffects")
    if old then old:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "DropzoneLocalEffects", workspace
    local self = setmetatable({folder = folder, rings = {}, tracers = 0}, Effects)
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
function Effects:shot(origin, endpoints, kind, localShot)
    for _, endpoint in ipairs(endpoints) do
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
        end
    end
end
return Effects
