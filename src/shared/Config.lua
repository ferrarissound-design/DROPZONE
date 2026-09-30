-- Shared presentation/balance data. The server owns all authoritative state.
return {
    TargetCombatants = 12, MaxPlayers = 20,
    Intermission = 12, ResultsTime = 12,
    BaseHealth = 100, BaseSpeed = 18, BaseJump = 50,
    CrouchSpeedMultiplier = 0.58, CrouchHipDrop = 1.15, CrouchToggleCooldown = 0.15,
    SprintMultiplier = 1.3, SprintCooldown = 0.25, MaxMoveSpeed = 32,
    SlideSpeed = 34, SlideMinSpeed = 20, SlideDuration = 0.65, SlideCooldown = 2.1, SlideSteerMultiplier = 0.35,
    StartEnergy = 60, MaxEnergy = 150,
    MapHalfSize = 250, PickupRadius = 9,
    BotInterval = 0.35, SnapshotInterval = 0.2,
    BotAggroRange = 110, BotOpeningSeconds = 10, BotOpeningLootRange = 90, BotShotgunRange = 32,
    -- Pre-release only: prints one bounded server summary at the end of each round.
    PlaytestDiagnostics = true,
    BuildGrid = 8, BuildCooldown = 0.55, BuildLimit = 100,
    BuildLifetime = 100, BuildCost = 20, BuildHealth = 150,
    MaxEvolutionRank = 3, EvolutionDraftSeconds = 5, EvolutionMaxQueue = 19, AdrenalineSeconds = 5,
    -- Each phase holds its current circle, then contracts toward the next.
    ZonePhases = {
        {radius = 320, nextRadius = 220, hold = 65, shrink = 40, damage = 2},
        {radius = 220, nextRadius = 140, hold = 45, shrink = 35, damage = 4},
        {radius = 140, nextRadius = 75, hold = 40, shrink = 35, damage = 7},
        {radius = 75, nextRadius = 28, hold = 30, shrink = 30, damage = 12},
        {radius = 28, nextRadius = 0, hold = 25, shrink = 30, damage = 22},
    },
    SuddenDeath = 30,
}
