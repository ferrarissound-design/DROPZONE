local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local World = require(script.Parent.World)
local Evolution = require(script.Parent.Evolution)
local Cosmetics = require(script.Parent.Cosmetics)
local Theme = require(game.ReplicatedStorage.DropzoneShared.VisualTheme)
local Building = {}
Building.__index = Building
function Building.new(world)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "Builds", world.dynamic
    return setmetatable({world = world, folder = folder, entries = {}, count = 0}, Building)
end
function Building:place(a, kind)
    if kind ~= "Wall" and kind ~= "Floor" and kind ~= "Ramp" then return end
    local now = os.clock()
    local cost = math.ceil(Config.BuildCost * math.max(0.67, 1 - Evolution.total(a, "Builder")))
    if not a.alive or now < (a.nextBuild or 0) or a.energy < cost or self.count >= Config.BuildLimit then return end
    local look = a.root.CFrame.LookVector
    local yaw = math.floor(math.atan2(-look.X, -look.Z) / (math.pi / 2) + 0.5) * (math.pi / 2)
    local forward = CFrame.Angles(0, yaw, 0).LookVector
    local p = a.root.Position + forward * 10
    local grid = Config.BuildGrid
    p = Vector3.new(math.floor(p.X / grid + 0.5) * grid, p.Y, math.floor(p.Z / grid + 0.5) * grid)
    if math.abs(p.X) > 250 or math.abs(p.Z) > 250 then return end
    local ground = World.ground(self.world, p)
    if math.abs(ground.Y - a.root.Position.Y) > 12 then return end
    local size = kind == "Wall" and Vector3.new(8, 9, 1) or kind == "Floor" and Vector3.new(8, 0.6, 8) or Vector3.new(8, 7, 8)
    local cf = CFrame.new(ground + Vector3.new(0, size.Y / 2 + 0.2, 0)) * CFrame.Angles(0, yaw, 0)
    -- Reject intersections with buildings, players, and other builds; avoid entombing actors.
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    -- Every designated ground surface is allowed beneath a build, including the Hill slope.
    params.FilterDescendantsInstances = self.world.groundSurfaces or {}
    for _, hit in ipairs(workspace:GetPartBoundsInBox(cf, size - Vector3.new(0.15, 0.15, 0.15), params)) do
        if hit.CanCollide or hit.Name == "HumanoidRootPart" then return end
    end
    if kind == "Ramp" then cf = cf * CFrame.Angles(0, math.pi, 0) end
    local build = Instance.new(kind == "Ramp" and "WedgePart" or "Part")
    build.Name, build.Size, build.CFrame = kind, size, cf
    build.Anchored, build.Material = true, Enum.Material.Metal
    build.Color, build.Parent = Theme.Blue, self.folder
    Cosmetics.build(build, kind)
    self.entries[build] = {health = Config.BuildHealth, expires = now + Config.BuildLifetime}
    self.count, a.energy, a.nextBuild = self.count + 1, a.energy - cost, now + Config.BuildCooldown
    if a.diagnostics then a.diagnostics.builds = (a.diagnostics.builds or 0) + 1 end
end
function Building:remove(p)
    if self.entries[p] then self.entries[p] = nil; self.count = self.count - 1; p:Destroy() end
end
function Building:damage(p, amount)
    local entry = self.entries[p]
    if entry then
        entry.health = entry.health - amount
        if entry.health <= 0 then self:remove(p) end
    end
end
function Building:step()
    for p, entry in pairs(self.entries) do if os.clock() >= entry.expires then self:remove(p) end end
end
function Building:clear()
    self.folder:ClearAllChildren()
    self.entries, self.count = {}, 0
end
return Building
