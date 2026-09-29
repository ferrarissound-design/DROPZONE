local Config = require(game.ReplicatedStorage.DropzoneShared.Config)

local Movement = {}

local function grounded(a)
    local floor = a.humanoid and a.humanoid.FloorMaterial
    return floor == nil or floor ~= Enum.Material.Air
end

function Movement.initialize(a)
    a.baseHipHeight = a.humanoid.HipHeight
    a.crouching, a.sliding = false, false
    a.slideUntil, a.nextSlide, a.nextCrouch = 0, 0, 0
end

function Movement.applyPosture(a)
    if not a.humanoid then return end
    local base = a.baseHipHeight or a.humanoid.HipHeight
    local lowered = (a.crouching or a.sliding) and Config.CrouchHipDrop or 0
    a.humanoid.HipHeight = math.max(-1, base - lowered)
    a.humanoid.AutoRotate = not a.sliding
end

function Movement.speedMultiplier(a)
    if a.sliding then return Config.SlideSteerMultiplier end
    if a.crouching then return Config.CrouchSpeedMultiplier end
    return 1
end

function Movement.canJump(a)
    return not a.crouching and not a.sliding
end

function Movement.toggleCrouch(a)
    local now = os.clock()
    if not a.alive or a.sliding or now < (a.nextCrouch or 0) or not grounded(a) then return false end
    a.crouching = not a.crouching
    a.nextCrouch = now + Config.CrouchToggleCooldown
    Movement.applyPosture(a)
    return true
end

function Movement.slide(a)
    local now = os.clock()
    if not a.alive or a.sliding or now < (a.nextSlide or 0) or not grounded(a) then return false end
    local velocity = a.root.AssemblyLinearVelocity
    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
    if horizontal.Magnitude < Config.SlideMinSpeed then return false end
    local direction = horizontal.Unit
    local speed = math.max(horizontal.Magnitude, Config.SlideSpeed)
    a.crouching, a.sliding = false, true
    a.slideUntil = now + Config.SlideDuration
    a.nextSlide = now + Config.SlideCooldown
    Movement.applyPosture(a)
    a.root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, velocity.Y, direction.Z * speed)
    return true
end

function Movement.step(a)
    if a.sliding and os.clock() >= (a.slideUntil or 0) then
        a.sliding = false
        Movement.applyPosture(a)
    end
end

return Movement
