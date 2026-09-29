local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local World = require(script.Parent.World)
local Weapons = require(game.ReplicatedStorage.DropzoneShared.Weapons)
local Loot = {}
Loot.__index = Loot
local kinds = {"Rifle", "Shotgun", "Pistol", "Ammo", "Health", "Shield", "Energy"}
local labels = {Ammo = "弾薬", Health = "回復 +35", Shield = "シールド +30", Energy = "建築エネルギー +40"}
function Loot.new(world, combat, effects)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "Loot", world.dynamic
    return setmetatable({world = world, combat = combat, effects = effects, folder = folder, items = {}}, Loot)
end
function Loot:spawn(position, kind)
    local ground = World.ground(self.world, position)
    local color = Weapons[kind] and Weapons[kind].color or Color3.fromRGB(150, 225, 110)
    local p = World.part(self.folder, kind, Vector3.new(2.5, 1.2, 2.5), CFrame.new(ground + Vector3.new(0, 1.3, 0)), color, Enum.Material.Neon)
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    local gui = Instance.new("BillboardGui")
    gui.Size, gui.StudsOffset, gui.MaxDistance, gui.Parent = UDim2.fromOffset(135, 28), Vector3.new(0, 2, 0), 45, p
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundTransparency, label.TextSize = UDim2.fromScale(1, 1), 1, 14
    label.TextColor3, label.TextStrokeTransparency = Color3.new(1, 1, 1), 0.3
    label.Text, label.Parent = Weapons[kind] and Weapons[kind].label or labels[kind], gui
    self.items[p] = kind
end
function Loot:reset()
    self.folder:ClearAllChildren()
    self.items = {}
    for i, position in ipairs(self.world.loot) do self:spawn(position, kinds[(i - 1) % #kinds + 1]) end
    -- Guaranteed weapon beside every insertion point.
    for i, position in ipairs(self.world.spawns) do self:spawn(position + Vector3.new(0, 0, -6), i % 2 == 0 and "Rifle" or "Pistol") end
end
function Loot:nearest(a, range)
    local nearest, distance = nil, range
    for p, kind in pairs(self.items) do
        local useful = true
        if kind == "Health" and a.humanoid.Health >= a.humanoid.MaxHealth then useful = false end
        if kind == "Shield" and a.shield >= 100 then useful = false end
        if kind == "Energy" and a.energy >= Config.MaxEnergy then useful = false end
        if #a.inventory == 0 and not Weapons[kind] then useful = false end
        local d = (p.Position - a.root.Position).Magnitude
        if useful and d < distance then nearest, distance = p, d end
    end
    return nearest
end
function Loot:pickup(a)
    if not a.alive then return end
    local p = self:nearest(a, Config.PickupRadius)
    if not p then return end
    local kind = self.items[p]
    if Weapons[kind] then self.combat:give(a, kind)
    elseif kind == "Ammo" then for _, item in ipairs(a.inventory) do item.reserve = math.min(240, item.reserve + 30) end
    elseif kind == "Health" then a.humanoid.Health = math.min(a.humanoid.MaxHealth, a.humanoid.Health + 35)
    elseif kind == "Shield" then a.shield = math.min(100, a.shield + 30)
    elseif kind == "Energy" then a.energy = math.min(Config.MaxEnergy, a.energy + 40) end
    self.items[p] = nil
    p:Destroy()
    if a.player then self.effects:FireClient(a.player, "Notice", "取得: " .. (Weapons[kind] and Weapons[kind].label or labels[kind])) end
end
function Loot:clear()
    self.items = {}
    self.folder:ClearAllChildren()
end
return Loot
