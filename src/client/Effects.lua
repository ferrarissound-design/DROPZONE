local Config = require(game.ReplicatedStorage.DropzoneShared.PresentationConfig)
local Effects = {}
Effects.__index = Effects
function Effects.new()
    local old = workspace:FindFirstChild("DropzoneLocalEffects")
    if old then old:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "DropzoneLocalEffects", workspace
    local self = setmetatable({folder = folder, rings = {}, tracers = {}, impacts = {}, cursors = {}}, Effects)
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
    local function part(name)
        local p = Instance.new("Part")
        p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = name, true, false, false, false
        p.CastShadow, p.Material, p.Transparency, p.Parent = false, Enum.Material.Neon, 1, folder
        return p
    end
    for i = 1, Config.TracerPool do
        self.tracers[i] = {trail=part("Tracer"), streak=part("BulletStreak"), expires=0}
    end
    for i = 1, Config.ImpactPool do
        local slot = {parts={}, expires=0}
        for j = 1, 5 do slot.parts[j] = part(j == 5 and "ImpactMark" or "ImpactSpark") end
        slot.parts[5].Material = Enum.Material.SmoothPlastic
        self.impacts[i] = slot
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
-- Reuse oldest slots within separate local/remote partitions. No shot-time Instances,
-- Tweens, Debris jobs, delayed callbacks or unbounded pending effects.
function Effects:acquire(pool, localShot, localLimit, key)
    local first, last = localShot and 1 or localLimit+1, localShot and localLimit or #pool
    key = key .. (localShot and "Local" or "Remote")
    local index = first + (self.cursors[key] or 0) % (last-first+1)
    self.cursors[key] = index-first+1
    return pool[index]
end
local function line(p, a, b, width)
    local length = (b-a).Magnitude
    if length < .001 then p.Transparency = 1; return end
    p.Size = Vector3.new(width, width, length)
    p.CFrame = CFrame.lookAt((a+b)/2, b)
end
function Effects:impact(position, normal, color, localShot, now)
    normal = normal or Vector3.new(0,1,0)
    local slot = self:acquire(self.impacts, localShot, Config.LocalImpactPool, "impact")
    slot.started, slot.expires = now, now+Config.ImpactLife
    -- Face out of the surface, offset to prevent z-fighting/half-buried sparks.
    local center = position+normal*.045
    local up = math.abs(normal.Y) > .95 and Vector3.new(1,0,0) or Vector3.new(0,1,0)
    local frame = CFrame.lookAt(center, center+normal, up)
    local flash = slot.parts[1]
    flash.Size, flash.CFrame = Vector3.new(.55,.55,.04), frame
    for j=2,4 do
        local angle = (j-2)*math.pi*2/3
        local a = frame:PointToWorldSpace(Vector3.new(math.cos(angle)*.16,math.sin(angle)*.16,-.03))
        local b = frame:PointToWorldSpace(Vector3.new(math.cos(angle)*.9,math.sin(angle)*.9,-.18))
        line(slot.parts[j],a,b,.09)
    end
    local mark = slot.parts[5]
    mark.Size, mark.CFrame, mark.Color = Vector3.new(.3,.3,.025), frame, Color3.fromRGB(40,32,24)
    for j,p in ipairs(slot.parts) do
        if j < 5 then p.Color = color end
        p.Transparency = 0
    end
end
function Effects:shot(origin, endpoints, kind, localShot, impacts, now, serverOrigin, shooterModel)
    now = now or os.clock()
    local color = kind == "Shotgun" and Color3.fromRGB(255,180,70) or Color3.fromRGB(255,240,170)
    local limit = kind == "Shotgun" and Config.ShotgunVisualPellets or 1
    for i,endpoint in ipairs(endpoints) do
        if i > limit then break end
        local traceOrigin = origin
        if serverOrigin and (origin-serverOrigin).Magnitude > .05 then
            -- Muzzle flash is visual-only. If its direct path crosses closer
            -- cover, start the tracer from the server-confirmed origin.
            local path = endpoint-origin
            if path.Magnitude > .05 then
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = shooterModel and {self.folder, shooterModel} or {self.folder}
                local blocker = workspace:Raycast(origin, path, params)
                if blocker and (blocker.Position-endpoint).Magnitude > 1.5 then traceOrigin = serverOrigin end
            end
        end
        local distance = (endpoint-traceOrigin).Magnitude
        if distance > .01 then
            local slot = self:acquire(self.tracers, localShot, Config.LocalTracerPool, "tracer")
            slot.origin, slot.endpoint, slot.distance = traceOrigin, endpoint, distance
            slot.life = localShot and Config.TracerLife or Config.RemoteTracerLife
            slot.started, slot.expires = now, now+slot.life
            slot.width = localShot and Config.TracerWidth or .075
            slot.trail.Color, slot.streak.Color = color, color
            line(slot.trail, traceOrigin, endpoint, slot.width*.65)
            slot.trail.Transparency = .35
            self:streak(slot, 0)
        end
    end
    for i,hit in ipairs(impacts or {}) do
        if i > limit then break end
        self:impact(hit.position, hit.normal, color, localShot, now)
    end
end
function Effects:streak(slot, alpha)
    -- Travel is cosmetic only. Never overshoot a nearby wall or lookAt identical points.
    local direction = (slot.endpoint-slot.origin)/slot.distance
    local length = math.min(slot.distance, 3.5)
    local head = length+(slot.distance-length)*math.min(1,alpha/.7)
    line(slot.streak, slot.origin+direction*(head-length), slot.origin+direction*head, slot.width)
    slot.streak.Transparency = math.max(0,(alpha-.65)/.35)
end
function Effects:step(now)
    for _,slot in ipairs(self.tracers) do
        if slot.expires > 0 then
            if now >= slot.expires then
                slot.trail.Transparency, slot.streak.Transparency, slot.expires = 1,1,0
            else
                local alpha = (now-slot.started)/slot.life
                slot.trail.Transparency = .35+.65*math.clamp((alpha-.2)/.8,0,1)
                self:streak(slot,alpha)
            end
        end
    end
    for _,slot in ipairs(self.impacts) do
        if slot.expires > 0 then
            local alpha = math.clamp((now-slot.started-Config.ImpactHold)/(Config.ImpactLife-Config.ImpactHold),0,1)
            for j,p in ipairs(slot.parts) do p.Transparency = j == 5 and alpha or math.min(1,alpha*1.5) end
            if now >= slot.expires then slot.expires=0 end
        end
    end
end
function Effects:clear()
    self.cursors = {}
    for _,slot in ipairs(self.tracers) do
        slot.trail.Transparency, slot.streak.Transparency, slot.expires = 1,1,0
    end
    for _,slot in ipairs(self.impacts) do
        slot.expires = 0
        for _,p in ipairs(slot.parts) do p.Transparency = 1 end
    end
end
function Effects:destroy()
    self:clear()
    self.folder:Destroy()
end
return Effects
