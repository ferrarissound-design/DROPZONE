local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local World = require(script.Parent.World)
local Weapons = require(game.ReplicatedStorage.DropzoneShared.Weapons)
local Evolution = require(script.Parent.Evolution)
local Cosmetics = require(script.Parent.Cosmetics)
local WeaponStats = require(game.ReplicatedStorage.DropzoneShared.WeaponStats)
local Loot = {}
Loot.__index = Loot
local kinds = {"Rifle", "Shotgun", "Pistol", "Ammo", "Health", "Shield", "Energy"}
local labels = {Ammo = "弾薬", Health = "回復 +35", Shield = "シールド +30", Energy = "建築エネルギー +40"}
function Loot.new(world, combat, effects)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "Loot", world.dynamic
    return setmetatable({world = world, combat = combat, effects = effects, folder = folder, items = {}, rng = Random.new()}, Loot)
end
function Loot:spawn(position, kind, starter)
    local rarity = Weapons[kind] and (starter and "Common" or WeaponStats.roll(self.rng)) or nil
    local ground = World.ground(self.world, position)
    local color = Weapons[kind] and Weapons[kind].color or Color3.fromRGB(150, 225, 110)
    local p = World.part(self.folder, kind, Vector3.new(2.5, 1.2, 2.5), CFrame.new(ground + Vector3.new(0, 1.3, 0)), color, Enum.Material.Neon)
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    Cosmetics.loot(p, kind)
    if rarity then
        local tint = WeaponStats.rarities[rarity].color
        Cosmetics.part(p, "RarityFootprint", Vector3.new(3.4,.08,2.4), p.CFrame * CFrame.new(0,-1.1,0), tint, nil, Enum.Material.Neon)
    end
    local gui = Instance.new("BillboardGui")
    gui.Size, gui.StudsOffset, gui.MaxDistance, gui.Parent = UDim2.fromOffset(180, 30), Vector3.new(0, 2, 0), 75, p
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundTransparency, label.TextSize = UDim2.fromScale(1, 1), 1, 14
    label.TextColor3, label.TextStrokeTransparency = rarity and WeaponStats.rarities[rarity].color or Color3.new(1, 1, 1), 0.3
    label.Text, label.Parent = Weapons[kind] and Weapons[kind].label or labels[kind], gui
    if rarity then label.Text = rarity .. " · " .. label.Text end
    if starter then
        label.Text = "▼ 武器を拾え · " .. label.Text
        label.TextSize, gui.Size, gui.MaxDistance = 16, UDim2.fromOffset(250,32), 75
    end
    self.items[p] = {kind=kind, rarity=rarity}
end
function Loot:reset()
    self.folder:ClearAllChildren()
    self.items = {}
    for i, position in ipairs(self.world.loot) do self:spawn(position, kinds[(i - 1) % #kinds + 1]) end
    -- Guaranteed weapon beside every insertion point.
    for i, position in ipairs(self.world.spawns) do self:spawn(position + Vector3.new(0, 0, -6), i % 2 == 0 and "Rifle" or "Pistol", true) end
end
local function useful(a, item)
    local kind = item.kind
    if kind == "Health" then return a.humanoid.Health < a.humanoid.MaxHealth end
    if kind == "Shield" then return a.shield < 100 end
    if kind == "Energy" then return a.energy < Evolution.maxEnergy(a) end
    if kind == "Ammo" then
        for _, weapon in ipairs(a.inventory) do
            if weapon.reserve < 240 then return true end
        end
        return false
    end
    if Weapons[kind] then
        for _, weapon in ipairs(a.inventory) do
            if weapon.kind == kind then
                return WeaponStats.rank(item.rarity) > WeaponStats.rank(weapon.rarity)
                    or weapon.reserve < 240
            end
        end
        return true
    end
    return false
end
function Loot:nearest(a, range)
    local nearest, distance = nil, range
    for p, item in pairs(self.items) do
        local d = (p.Position - a.root.Position).Magnitude
        if useful(a, item) and d < distance then nearest, distance = p, d end
    end
    return nearest
end
function Loot:pickup(a)
    if not a.alive then return end
    local p = self:nearest(a, Config.PickupRadius)
    if not p then return end
    local item = self.items[p]
    if not item then return end
    local kind = item.kind
    local firstWeapon = Weapons[kind] ~= nil and #a.inventory == 0
    self.items[p] = nil -- claim before applying reward; no yields in this transaction
    if Weapons[kind] then self.combat:give(a, kind, item.rarity)
    elseif kind == "Ammo" then local amount = math.floor(30 * (1 + Evolution.total(a, "Scavenger")))
        for _, item in ipairs(a.inventory) do item.reserve = math.min(240, item.reserve + amount) end
    elseif kind == "Health" then a.humanoid.Health = math.min(a.humanoid.MaxHealth, a.humanoid.Health + 35)
    elseif kind == "Shield" then a.shield = math.min(100, a.shield + 30)
    elseif kind == "Energy" then a.energy = math.min(Evolution.maxEnergy(a), a.energy + 40) end
    p:Destroy()
    if a.diagnostics then
        a.diagnostics.pickups = (a.diagnostics.pickups or 0) + 1
        if firstWeapon and a.startTime and a.diagnostics.firstWeaponSeconds == nil then
            a.diagnostics.firstWeaponSeconds = math.max(0, os.clock() - a.startTime)
        end
    end
    if a.player then self.effects:FireClient(a.player, "Pickup", a.roundId, item.rarity) end
    if a.player then self.effects:FireClient(a.player, "Notice", a.roundId, "取得: " .. (item.rarity and item.rarity .. " " or "") .. (Weapons[kind] and Weapons[kind].label or labels[kind])) end
end
function Loot:clear()
    self.items = {}
    self.folder:ClearAllChildren()
end
return Loot
