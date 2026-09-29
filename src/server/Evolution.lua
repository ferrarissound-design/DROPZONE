local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local Theme = require(game.ReplicatedStorage.DropzoneShared.VisualTheme)
local Movement = require(script.Parent.Movement)
local Evolution = {}
Evolution.__index = Evolution

-- Values are deliberately diminishing. Rank is capped per ability.
Evolution.abilities = {
    {id="SwiftLegs", name="Swift Legs", category="Mobility", limb="LeftLowerLeg", icon="LEGS",
        values={0.08,0.06,0.04}, descriptions={"移動速度 +8%", "移動速度 +6%", "移動速度 +4%"}},
    {id="IronSkin", name="Iron Skin", category="Survival", limb="UpperTorso", icon="ARMOR",
        values={20,15,10}, descriptions={"最大HP +20", "最大HP +15", "最大HP +10"}},
    {id="HunterEyes", name="Hunter Eyes", category="Attack", limb="Head", icon="SIGHT",
        values={0.10,0.08,0.06}, descriptions={"Spread -10%", "Spread -8%", "Spread -6%"}},
    {id="QuickHands", name="Quick Hands", category="Attack", limb="RightHand", icon="HANDS",
        values={0.12,0.09,0.06}, descriptions={"Reload time -12%", "Reload time -9%", "Reload time -6%"}},
    {id="Builder", name="Builder", category="Utility", limb="LeftHand", icon="BUILDER",
        values={0.15,0.10,0.08}, descriptions={"建築Energy -15%", "建築Energy -10%", "建築Energy -8%"}},
    {id="HighJump", name="High Jump", category="Mobility", limb="RightLowerLeg", icon="JUMP",
        values={0.12,0.10,0.08}, descriptions={"JumpPower +12%", "JumpPower +10%", "JumpPower +8%"}},
    {id="Regeneration", name="Regeneration", category="Survival", limb="UpperTorso", icon="REGEN",
        values={2,1.5,1}, descriptions={"静穏時 2 HP/s", "静穏時 1.5 HP/s", "静穏時 1 HP/s"}},
    {id="Scavenger", name="Scavenger", category="Utility", limb="LowerTorso", icon="SCAVENGE",
        values={0.20,0.15,0.10}, descriptions={"Ammo取得 +20%", "Ammo取得 +15%", "Ammo取得 +10%"}},
    {id="Adrenaline", name="Adrenaline", category="Mobility", limb="LeftFoot", icon="RUSH",
        values={0.08,0.06,0.04}, descriptions={"撃破後5秒 Speed +8%", "同効果 +6%", "同効果 +4%"}},
    {id="CombatShield", name="Combat Shield", category="Survival", limb="UpperTorso", icon="SHIELD",
        values={10,7,5}, descriptions={"撃破時 Shield +10", "撃破時 Shield +7", "撃破時 Shield +5"}},
    {id="Overcharge", name="Overcharge", category="Utility", limb="LowerTorso", icon="ENERGY",
        values={25,15,10}, descriptions={"最大Energy +25", "最大Energy +15", "最大Energy +10"}},
}
Evolution.maxRank = Config.MaxEvolutionRank
Evolution.draftSeconds = Config.EvolutionDraftSeconds
local byId = {}
for _, ability in ipairs(Evolution.abilities) do byId[ability.id] = ability end
local rng = Random.new()
local roman = {"I", "II", "III"}

function Evolution.definition(id)
    return byId[id]
end
function Evolution.rank(a, id)
    return (a.evolutionStacks and a.evolutionStacks[id]) or 0
end
function Evolution.total(a, id)
    local def = byId[id]
    local amount = 0
    for rank = 1, Evolution.rank(a, id) do amount = amount + (def and def.values[rank] or 0) end
    return amount
end
function Evolution.maxEnergy(a)
    return Config.MaxEnergy + Evolution.total(a, "Overcharge")
end
local function refreshStats(a)
    local swift = Evolution.total(a, "SwiftLegs")
    local adrenaline = Evolution.rank(a, "Adrenaline") > 0 and os.clock() < (a.adrenalineUntil or 0)
        and Evolution.total(a, "Adrenaline") or 0
    a.humanoid.WalkSpeed = math.min(Config.MaxMoveSpeed, Config.BaseSpeed * (1 + swift + adrenaline) * Movement.speedMultiplier(a))
    a.humanoid.UseJumpPower = true
    a.humanoid.JumpPower = Movement.canJump(a) and Config.BaseJump * (1 + Evolution.total(a, "HighJump")) or 0
    Movement.applyPosture(a)
    a.humanoid.MaxHealth = Config.BaseHealth + Evolution.total(a, "IronSkin")
    a.energy = math.min(a.energy, Evolution.maxEnergy(a))
end
local function visualLimb(a, ability)
    local limb = a.model:FindFirstChild(ability.limb)
    if not limb then
        local fallback = ability.category == "Mobility" and (ability.limb:find("Leg") and "Left Leg" or "Right Leg")
            or ability.category == "Attack" and (ability.limb == "Head" and "Head" or "Right Arm")
            or ability.id == "Builder" and "Left Arm" or "Torso"
        limb = a.model:FindFirstChild(fallback) or a.model:FindFirstChild("Torso") or a.root
    end
    return limb
end
local palette = Theme.Category
local function addMutation(a, ability, rank)
    local folder = a.mutationFolder
    if not folder or not folder.Parent then
        folder = Instance.new("Folder")
        folder.Name, folder.Parent = "Mutation", a.model
        a.mutationFolder = folder
    end
    local limb = visualLimb(a, ability)
    local part = Instance.new("Part")
    part.Name, part.Material = ability.id .. rank, Enum.Material.Neon
    part.Color, part.Transparency = palette[ability.category], 0.12
    part.Anchored, part.Massless = false, true
    part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
    part.CastShadow = false
    part.Size = ability.category == "Survival" and Vector3.new(.65,.55,.16)
        or ability.category == "Utility" and Vector3.new(.42,.65,.22)
        or Vector3.new(.24,.75 + rank*.08,.18)
    local side = (rank % 2 == 0 and -1 or 1)
    part.CFrame = limb.CFrame * CFrame.new(side * (limb.Size.X / 2 + 0.11), (rank-2)*.3, -limb.Size.Z / 2 - 0.12)
    part.Parent = folder
    local weld = Instance.new("WeldConstraint")
    weld.Part0, weld.Part1, weld.Parent = limb, part, part
end
local function apply(a, id)
    if not a.alive or not a.model.Parent then return nil end
    local ability = byId[id]
    if not ability then return nil end
    local oldRank = Evolution.rank(a, id)
    if oldRank >= Evolution.maxRank then return nil end
    local newRank = oldRank + 1
    a.evolutionStacks[id] = newRank
    a.evolutions[id] = newRank -- kept as the existing public rank map
    a.evolutionCount = a.evolutionCount + 1
    table.insert(a.evolutionHistory, id)
    if id == "Adrenaline" then a.adrenalineUntil = os.clock() + Config.AdrenalineSeconds end
    if id == "IronSkin" then
        a.humanoid.MaxHealth = Config.BaseHealth + Evolution.total(a, id)
        a.humanoid.Health = math.min(a.humanoid.MaxHealth, a.humanoid.Health + ability.values[newRank])
    elseif id == "CombatShield" then
        a.shield = math.min(100, a.shield + ability.values[newRank])
    elseif id == "Overcharge" then
        a.energy = math.min(Evolution.maxEnergy(a), a.energy + ability.values[newRank])
    end
    refreshStats(a)
    addMutation(a, ability, newRank)
    return {id=id, name=ability.name, rank=newRank, rankText=roman[newRank]}
end
local function eligible(a)
    local list = {}
    for _, ability in ipairs(Evolution.abilities) do
        if Evolution.rank(a, ability.id) < Evolution.maxRank then table.insert(list, ability) end
    end
    return list
end
local function shuffle(list)
    for i = #list, 2, -1 do
        local j = rng:NextInteger(1, i)
        list[i], list[j] = list[j], list[i]
    end
end
function Evolution.makeChoices(a)
    local available, categories, seen = eligible(a), {}, {}
    local byCategory = {}
    for _, ability in ipairs(available) do
        byCategory[ability.category] = byCategory[ability.category] or {}
        table.insert(byCategory[ability.category], ability)
        if not seen[ability.category] then seen[ability.category] = true; table.insert(categories, ability.category) end
    end
    shuffle(categories)
    local chosen, chosenIds = {}, {}
    -- Prefer three different build directions when the eligible pool allows it.
    for _, category in ipairs(categories) do
        if #chosen == 3 then break end
        local pool = byCategory[category]
        local ability = pool[rng:NextInteger(1, #pool)]
        table.insert(chosen, ability)
        chosenIds[ability.id] = true
    end
    if #chosen < 3 then
        local remaining = {}
        for _, ability in ipairs(available) do if not chosenIds[ability.id] then table.insert(remaining, ability) end end
        shuffle(remaining)
        for _, ability in ipairs(remaining) do
            if #chosen == 3 then break end
            table.insert(chosen, ability)
        end
    end
    local options = {}
    for index, ability in ipairs(chosen) do
        local nextRank = Evolution.rank(a, ability.id) + 1
        table.insert(options, {index=index, id=ability.id, name=ability.name,
            category=ability.category, rank=nextRank, rankText=roman[nextRank], description=ability.descriptions[nextRank]})
    end
    return options
end
local function publicDraft(draft)
    return {id=draft.id, seconds=math.max(0, draft.expiresAt - os.clock()), options=draft.options}
end
local startNext
local function automaticChoice(options, a, zone)
    local best, bestScore = {}, -math.huge
    local lowHealth = a.humanoid.Health / math.max(1, a.humanoid.MaxHealth) < 0.45
    local outside = zone and zone:outside(a.root.Position, 45) or false
    local equipped = a.inventory[a.slot]
    for _, option in ipairs(options) do
        local score = rng:NextNumber(0, 0.75)
        if lowHealth and (option.category == "Survival" or option.id == "IronSkin") then score = score + 3 end
        if outside and option.category == "Mobility" then score = score + 3 end
        if equipped and equipped.kind == "Shotgun" and (option.category == "Mobility" or option.id == "IronSkin") then score = score + 1.5 end
        if option.id == "CombatShield" and a.shield < 35 then score = score + 1.2 end
        if score > bestScore then best, bestScore = {option}, score
        elseif score == bestScore then table.insert(best, option) end
    end
    local selected = best[rng:NextInteger(1, #best)]
    return selected and selected.index
end
local function showNext(a, roundId)
    if not a.alive or a.roundId ~= roundId or a.evolutionDraft or (a.queuedDrafts or 0) <= 0 then return end
    local options = Evolution.makeChoices(a)
    if #options < 3 then a.queuedDrafts = 0; return end
    a.queuedDrafts = a.queuedDrafts - 1
    a.draftVersion = (a.draftVersion or 0) + 1
    local draft = {id=a.draftVersion, roundId=roundId, options=options, expiresAt=os.clock() + Evolution.draftSeconds}
    a.evolutionDraft = draft -- options and token are kept on the server Actor only
    if not a.player then
        local selected = automaticChoice(options, a, a.currentZone)
        local option = options[selected]
        if option then apply(a, option.id) end
        a.evolutionDraft = nil
        if a.queuedDrafts > 0 then showNext(a, roundId) end
        return
    end
    task.delay(Evolution.draftSeconds, function()
        if os.clock() < draft.expiresAt then return end
        if a.alive and a.roundId == roundId and a.evolutionDraft == draft then
            local selected = automaticChoice(draft.options, a, a.currentZone)
            local option = draft.options[selected]
            a.evolutionDraft = nil
            if option then apply(a, option.id) end
            showNext(a, roundId)
        end
    end)
end
startNext = showNext
function Evolution.onKill(a, roundId, zone)
    if not a or not a.alive or a.roundId ~= roundId then return nil end
    if Evolution.rank(a, "Adrenaline") > 0 then a.adrenalineUntil = os.clock() + Config.AdrenalineSeconds end
    local shieldReward = math.min(30, Evolution.total(a, "CombatShield"))
    if shieldReward > 0 then a.shield = math.min(100, a.shield + shieldReward) end
    a.currentZone = zone
    a.queuedDrafts = math.min(Config.EvolutionMaxQueue, (a.queuedDrafts or 0) + 1)
    if not a.evolutionDraft then startNext(a, roundId) end
    return a.evolutionDraft and publicDraft(a.evolutionDraft) or nil
end
function Evolution.grant(a, abilityId)
    return apply(a, abilityId)
end
function Evolution.select(a, roundId, draftId, index)
    local draft = a and a.evolutionDraft
    if not draft or not a.alive or a.roundId ~= roundId or draft.roundId ~= roundId or draft.id ~= draftId then return nil end
    if os.clock() >= draft.expiresAt then return nil end
    if type(index) ~= "number" or index % 1 ~= 0 then return nil end
    local option = draft.options[index]
    if not option then return nil end
    a.evolutionDraft = nil -- clear first so duplicate/re-entrant picks cannot apply twice
    local result = apply(a, option.id)
    if a.queuedDrafts > 0 then task.defer(function() startNext(a, roundId) end) end
    return result
end
function Evolution.cancel(a)
    if not a then return end
    a.evolutionDraft = nil
    a.queuedDrafts = 0
    a.draftVersion = (a.draftVersion or 0) + 1
end
function Evolution.step(a, dt)
    if not a.alive then return end
    Movement.step(a)
    refreshStats(a)
    local regen = Evolution.total(a, "Regeneration")
    if regen > 0 and os.clock() - a.lastDamage >= 8 then
        a.humanoid.Health = math.min(a.humanoid.MaxHealth, a.humanoid.Health + regen * dt)
    end
end
function Evolution.refresh(a)
    if a and a.alive then refreshStats(a) end
end

function Evolution.snapshot(a)
    local build = {}
    for _, ability in ipairs(Evolution.abilities) do
        local rank = Evolution.rank(a, ability.id)
        if rank > 0 then
            table.insert(build, {id=ability.id, name=ability.name, rank=rank, rankText=roman[rank], category=ability.category})
        end
    end
    return build, a.evolutionDraft and publicDraft(a.evolutionDraft) or nil
end
return Evolution
