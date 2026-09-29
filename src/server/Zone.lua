local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local Rules = require(game.ReplicatedStorage.DropzoneShared.Rules)
local Zone = {}
Zone.__index = Zone
function Zone.new()
    return setmetatable({center = Vector3.zero, nextCenter = Vector3.zero, radius = 320, nextRadius = 220, phase = 1, remaining = 65, shrinking = false}, Zone)
end
function Zone:reset()
    self.centers = {Vector3.zero}
    local rng = Random.new()
    for i = 1, #Config.ZonePhases do
        local p = Config.ZonePhases[i]
        -- Every next circle is contained, and the finale remains around the central arena.
        local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * math.min(9, (p.radius - p.nextRadius) * 0.2)
        table.insert(self.centers, self.centers[i] + offset)
    end
    self.elapsed = 0
    self:update(0)
end
function Zone:update(dt)
    self.elapsed = self.elapsed + dt
    local phase, alpha, remaining, shrinking = Rules.phaseAt(Config.ZonePhases, self.elapsed)
    local p = Config.ZonePhases[phase]
    self.phase, self.remaining, self.shrinking = phase, remaining, shrinking
    self.radius = p.radius + (p.nextRadius - p.radius) * alpha
    self.center = self.centers[phase]:Lerp(self.centers[phase + 1], alpha)
    self.nextCenter, self.nextRadius, self.damage = self.centers[phase + 1], p.nextRadius, p.damage
end
function Zone:outside(position, margin)
    local flat = Vector3.new(position.X, 0, position.Z) - self.center
    return flat.Magnitude >= math.max(0, self.radius - (margin or 0))
end
function Zone:snapshot()
    return {center = self.center, radius = self.radius, nextCenter = self.nextCenter,
        nextRadius = self.nextRadius, phase = self.phase, remaining = math.ceil(self.remaining), shrinking = self.shrinking}
end
return Zone
