local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local Rules = require(game.ReplicatedStorage.DropzoneShared.Rules)
local Movement = {}
local function grounded(a)
    local floor = a.humanoid and a.humanoid.FloorMaterial
    return floor ~= nil and floor ~= Enum.Material.Air
end
local function horizontal(a)
    local v = a.root and a.root.AssemblyLinearVelocity
    if not v or not Rules.finite(v.X) or not Rules.finite(v.Y) or not Rules.finite(v.Z) then return nil end
    return Vector3.new(v.X, 0, v.Z), v
end
local function capVelocity(a, speed)
    local h, v = horizontal(a)
    if h and h.Magnitude > speed then
        local d = h.Unit * speed
        a.root.AssemblyLinearVelocity = Vector3.new(d.X, v.Y, d.Z)
    end
end
function Movement.initialize(a)
    a.baseHipHeight = a.humanoid.HipHeight
    a.crouching, a.sliding, a.sprinting = false, false, false
    a.slideUntil, a.nextSlide, a.nextCrouch, a.nextSprint = 0, 0, 0, 0
end
function Movement.applyPosture(a)
    if not a.humanoid then return end
    local base = a.baseHipHeight or a.humanoid.HipHeight or 0
    a.humanoid.HipHeight = math.max(-1, base - ((a.crouching or a.sliding) and Config.CrouchHipDrop or 0))
    a.humanoid.AutoRotate = not a.sliding
end
function Movement.speedMultiplier(a)
    if a.sliding then return Config.SlideSteerMultiplier end
    if a.crouching then return Config.CrouchSpeedMultiplier end
    if a.sprinting then return Config.SprintMultiplier end
    return 1
end
function Movement.canJump(a) return not a.crouching and not a.sliding end
function Movement.reset(a)
    a.crouching, a.sliding, a.sprinting = false, false, false
    a.slideUntil, a.nextSlide, a.nextCrouch, a.nextSprint = 0, 0, 0, 0
    capVelocity(a, Config.BaseSpeed)
    Movement.applyPosture(a)
end
function Movement.sprint(a, enabled)
    if type(enabled) ~= "boolean" or not a.alive then return false end
    -- Release must always be accepted, even inside the start cooldown.
    if not enabled then a.sprinting = false; return true end
    local now = os.clock()
    if a.sprinting or a.sliding or not grounded(a) or now < (a.nextSprint or 0) then return false end
    a.sprinting, a.crouching, a.nextSprint = true, false, now + Config.SprintCooldown
    Movement.applyPosture(a)
    return true
end
function Movement.toggleCrouch(a)
    local now = os.clock()
    if not a.alive or a.sliding or now < (a.nextCrouch or 0) or not grounded(a) then return false end
    a.crouching, a.sprinting = not a.crouching, false
    a.nextCrouch = now + Config.CrouchToggleCooldown
    Movement.applyPosture(a)
    return true
end
function Movement.slide(a)
    local now = os.clock()
    if not a.alive or not a.sprinting or a.sliding or now < (a.nextSlide or 0) or not grounded(a) then return false end
    local h, velocity = horizontal(a)
    if not h or h.Magnitude < Config.SlideMinSpeed then return false end
    -- Never amplify a client-owned root's untrusted velocity.
    local direction = h.Unit
    a.crouching, a.sliding, a.sprinting = false, true, false
    a.slideUntil, a.nextSlide = now + Config.SlideDuration, now + Config.SlideCooldown
    Movement.applyPosture(a)
    a.root.AssemblyLinearVelocity = Vector3.new(direction.X * Config.SlideSpeed, velocity.Y, direction.Z * Config.SlideSpeed)
    return true
end
function Movement.jump(a)
    if not a.alive or not grounded(a) or not (a.sliding or a.crouching) then return false end
    a.sliding, a.crouching, a.sprinting, a.slideUntil = false, false, false, 0
    capVelocity(a, Config.BaseSpeed)
    Movement.applyPosture(a)
    return true -- caller refreshes Evolution JumpPower before setting Jump
end
function Movement.step(a)
    if not a.alive then Movement.reset(a); return end
    local onGround = grounded(a)
    if not onGround then a.sprinting = false end
    if a.sliding then
        local remaining = (a.slideUntil or 0) - os.clock()
        if remaining <= 0 or not onGround then
            a.sliding, a.crouching = false, onGround
            a.slideUntil = 0
            capVelocity(a, Config.BaseSpeed * (onGround and Config.CrouchSpeedMultiplier or 1))
            Movement.applyPosture(a)
        else
            local alpha = math.max(0, math.min(1, remaining / Config.SlideDuration))
            capVelocity(a, Config.BaseSpeed * Config.CrouchSpeedMultiplier + (Config.SlideSpeed - Config.BaseSpeed * Config.CrouchSpeedMultiplier) * alpha)
        end
    end
end
return Movement
