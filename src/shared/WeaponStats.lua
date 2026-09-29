local Weapons = require(game.ReplicatedStorage.DropzoneShared.Weapons)
local Theme = require(game.ReplicatedStorage.DropzoneShared.VisualTheme)
local WeaponStats = {}
-- Rarity improves handling only: identical damage, magazine, range and fire rate.
WeaponStats.rarities = {
    Common = {rank=1, reload=1, spread=1, color=Theme.Paper, short="C"},
    Rare = {rank=2, reload=.96, spread=.94, color=Theme.Blue, short="R"},
    Epic = {rank=3, reload=.92, spread=.88, color=Theme.Purple, short="E"},
}
local cache = {}
for kind, base in pairs(Weapons) do
    cache[kind] = {}
    for rarity, modifier in pairs(WeaponStats.rarities) do
        local spec = {}
        for key, value in pairs(base) do spec[key] = value end
        spec.reload, spec.spread = base.reload * modifier.reload, base.spread * modifier.spread
        cache[kind][rarity] = spec
    end
end
function WeaponStats.get(kind, rarity)
    local variants = cache[kind]
    return variants and variants[rarity or "Common"]
end
function WeaponStats.rank(rarity)
    local definition = WeaponStats.rarities[rarity or "Common"]
    return definition and definition.rank or 0
end
function WeaponStats.roll(rng)
    local roll = rng:NextNumber()
    return roll < .72 and "Common" or roll < .94 and "Rare" or "Epic"
end
return WeaponStats
