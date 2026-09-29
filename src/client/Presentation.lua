local Config = require(game.ReplicatedStorage.DropzoneShared.PresentationConfig)
local Audio = require(script.Parent.Audio)
local Animations = require(script.Parent.Animations)
local Presentation = {}
Presentation.__index = Presentation
function Presentation.new(folder, player)
    local self = setmetatable({player=player, audio=Audio.new(folder), animations=Animations.new(),
        flashes={}, cursor=0, vertical=0, horizontal=0, kick=0, tilt=0, fov=0, offset=0, aimBlend=0,
        aimHeld=false, combatAimHeld=false, combatAimUntil=0, nextStep=0}, Presentation)
    for _ = 1, Config.FlashPool do
        local p = Instance.new("Part")
        p.Name, p.Shape, p.Material = "MuzzleFlash", Enum.PartType.Ball, Enum.Material.Neon
        p.Color, p.Transparency = Color3.fromRGB(255,227,142), 1
        p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
        p.CastShadow, p.Parent = false, folder
        table.insert(self.flashes, {part=p, untilTime=0})
    end
    local pulse = Instance.new("Highlight")
    pulse.Name, pulse.Enabled, pulse.DepthMode = "EvolutionPulse", false, Enum.HighlightDepthMode.Occluded
    pulse.FillColor, pulse.OutlineColor = Color3.fromRGB(66,220,238), Color3.fromRGB(184,141,244)
    pulse.Parent = folder
    self.pulse = pulse
    return self
end
function Presentation:setAimHeld(enabled)
    self.aimHeld = enabled == true
end
function Presentation:setCombatAim(enabled)
    if enabled then
        self.combatAimHeld = true
        self.combatAimUntil = 0
    else
        if self.combatAimHeld then
            self.combatAimUntil = math.max(self.combatAimUntil or 0, os.clock() + Config.MobileCombatAimHold)
        end
        self.combatAimHeld = false
    end
end
function Presentation:cancelAim()
    self.aimHeld, self.combatAimHeld, self.combatAimUntil, self.aimActive = false, false, 0, false
end
function Presentation:isAiming()
    return self.aimActive == true or (self.aimBlend or 0) > .35
end
function Presentation:undoCamera()
    if self.camera and self.applied then
        -- Remove only our last transform, before Roblox's camera controller runs.
        self.camera.CFrame = self.camera.CFrame * self.applied:Inverse()
    end
    self.applied = nil
end
function Presentation:restoreWeapon()
    if self.joint and self.joint.Parent then self.joint.C0 = self.baseJoint end
    self.joint, self.baseJoint = nil, nil
    self.kick, self.tilt = 0, 0
    self.animations:stop("Reload")
    if self.reloadSound then self.reloadSound:Stop(); self.reloadSound = nil end
end
function Presentation:clear()
    self:undoCamera()
    if self.camera and self.baseFov then self.camera.FieldOfView = self.baseFov end
    if self.humanoid and self.humanoid.Parent and self.baseOffset then self.humanoid.CameraOffset = self.baseOffset end
    self:restoreWeapon()
    self.animations:clear()
    self.animations.movementKey = nil
    self.audio:clear()
    self.camera, self.baseFov, self.humanoid, self.baseOffset, self.character = nil,nil,nil,nil,nil
    self.vertical,self.horizontal,self.fov,self.offset,self.aimBlend = 0,0,0,0,0
    self.aimHeld,self.combatAimHeld,self.combatAimUntil,self.aimActive = false,false,0,false
    self.me, self.previous, self.roundId, self.readyAt, self.slideSound = nil,nil,nil,nil,nil
    self.pulse.Enabled, self.pulse.Adornee = false,nil
    self.nextStep, self.lastShrink = 0,nil
    for _, flash in ipairs(self.flashes) do flash.part.Transparency, flash.untilTime = 1,0 end
end
function Presentation:snapshot(s)
    local me, character = s.me, self.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local active = me and me.alive and (s.phase == "Active" or s.phase == "FinalZone")
    local contextChanged = self.contextRound ~= s.roundId or self.contextPhase ~= s.phase
    self.contextRound, self.contextPhase = s.roundId, s.phase
    if not active or not humanoid or humanoid.Health <= 0 then
        -- Clear on transitions, not every spectator snapshot (which would cut 3D cues).
        if self.me or contextChanged then self:clear() end
        return
    end
    if self.roundId ~= s.roundId or self.character ~= character then self:clear() end
    self.roundId, self.character, self.me = s.roundId, character, me
    if not self.humanoid then
        self.humanoid, self.baseOffset = humanoid, humanoid.CameraOffset
        self.animations:bind(humanoid)
    end
    local previous = self.previous
    local changedWeapon = previous and (previous.weapon ~= me.weapon or previous.rarity ~= me.rarity or previous.slot ~= me.slot)
    if changedWeapon then self:restoreWeapon() end
    if me.reloading and (not previous or not previous.reloading or changedWeapon) then
        self.reloadSound = self.audio:play("Reload")
        self.animations:play("Reload")
    elseif not me.reloading then
        self.animations:stop("Reload")
        if self.reloadSound then self.reloadSound:Stop(); self.reloadSound = nil end
    end
    if me.sliding and (not previous or not previous.sliding) then
        local root = character:FindFirstChild("HumanoidRootPart")
        self.audio:play("SlideStart", root and root.Position)
        self.slideSound = self.audio:play("SlideLoop", root and root.Position, true)
    elseif not me.sliding and previous and previous.sliding then
        if self.slideSound then self.slideSound:Stop(); self.slideSound = nil end
        self.audio:play("SlideEnd")
    end
    local draft = me.evolutionDraft
    if draft and (not previous or not previous.evolutionDraft or previous.evolutionDraft.id ~= draft.id) then
        self.readyAt = os.clock() + .18 -- let elimination confirmation lead the reward cue
    elseif not draft then self.readyAt = nil end
    if previous and me.evolutions > previous.evolutions then
        self.audio:play("EvolutionApplied")
        self.pulse.Adornee = character:FindFirstChild("Mutation") and character or nil
        self.pulse.Enabled, self.pulseUntil = self.pulse.Adornee ~= nil, os.clock()+Config.PulseDuration
    end
    if s.zone and s.zone.shrinking and not self.lastShrink then self.audio:play("ZoneWarning") end
    self.lastShrink = s.zone and s.zone.shrinking
    self.previous = me
end
function Presentation:shot(origin, kind, shooterId, targets)
    local spec = Config.Weapons[kind]
    if not spec then return end
    self.audio:play(kind.."Fire", origin)
    local character
    for _, target in ipairs(targets or {}) do if target.id == shooterId then character = target.model; break end end
    if shooterId == self.player.UserId then character = self.character end
    local held = character and character:FindFirstChild("HeldWeapon")
    local barrel = held and (held:FindFirstChild("Muzzle") or held:FindFirstChild("TwinBarrel") or held:FindFirstChild("Barrel"))
    self.cursor = self.cursor % #self.flashes + 1
    local flash = self.flashes[self.cursor]
    flash.part.Size = Vector3.new(spec.Flash,spec.Flash,spec.Flash*1.5)
    flash.part.CFrame = barrel and barrel.CFrame*CFrame.new(0,0,-barrel.Size.Z/2) or CFrame.new(origin)
    flash.part.Transparency, flash.untilTime = .08, os.clock()+spec.Duration
    if shooterId ~= self.player.UserId or not self.me then return end
    self.vertical = math.min(Config.MaxRecoil, self.vertical+spec.Vertical)
    self.horizontal = math.clamp(self.horizontal+(math.random()*2-1)*spec.Horizontal,-Config.MaxHorizontal,Config.MaxHorizontal)
    self.kick, self.recovery = spec.Kick, spec.Recovery
    self.animations:shot(kind)
end
function Presentation:damage(records)
    local hp, shield, eliminated = false,false,false
    for _, record in ipairs(records) do
        hp, shield, eliminated = hp or record.hp > 0, shield or record.shield > 0, eliminated or record.eliminated
    end
    if shield then self.audio:play("ShieldHit") elseif hp then self.audio:play("HealthHit") end
    if eliminated then self.audio:play("Elimination") end
end
function Presentation:step(dt)
    local now = os.clock()
    for _, flash in ipairs(self.flashes) do if now >= flash.untilTime then flash.part.Transparency = 1 end end
    if not self.me then return end
    if not self.character.Parent or not self.humanoid.Parent or self.humanoid.Health <= 0 then self:clear(); return end
    local camera = workspace.CurrentCamera
    if camera ~= self.camera then
        if self.camera and self.baseFov then self.camera.FieldOfView = self.baseFov end
        self.camera, self.baseFov = camera, camera and camera.FieldOfView
    end
    local alpha = 1-math.exp(-Config.CameraRecovery*dt)
    local aimAlpha = 1-math.exp(-Config.AimRecovery*dt)
    local me = self.me
    local aimIntent = self.aimHeld or self.combatAimHeld or now < (self.combatAimUntil or 0)
    local aimAllowed = not me.sprinting and not me.sliding
    self.aimActive = aimIntent and aimAllowed
    self.aimBlend = self.aimBlend + ((self.aimActive and 1 or 0)-self.aimBlend)*aimAlpha
    local targetFov = self.aimActive and Config.AimFov or me.sliding and Config.SlideFov or me.sprinting and Config.SprintFov or 0
    self.fov = self.fov + (targetFov-self.fov)*alpha
    self.offset = self.offset + ((me.sliding and Config.SlideOffset or me.crouching and Config.CrouchOffset or 0)-self.offset)*alpha
    self.humanoid.CameraOffset = self.baseOffset + Vector3.new(
        Config.AimShoulderX*self.aimBlend,
        self.offset + Config.AimShoulderY*self.aimBlend,
        0
    )
    local decay = math.exp(-(self.recovery or 18)*dt)
    self.vertical,self.horizontal,self.kick = self.vertical*decay,self.horizontal*decay,self.kick*decay
    if camera then
        camera.FieldOfView = self.baseFov+self.fov
        self.applied = CFrame.Angles(math.rad(self.vertical),math.rad(self.horizontal),0)
        camera.CFrame = camera.CFrame*self.applied
    end
    local held = self.character:FindFirstChild("HeldWeapon")
    local joint = held and held:FindFirstChild("PresentationJoint")
    if joint ~= self.joint then
        if self.joint and self.joint.Parent then self.joint.C0 = self.baseJoint end
        self.joint, self.baseJoint = joint,joint and joint.C0
    end
    self.tilt = self.tilt+((me.reloading and Config.ReloadTilt or 0)-self.tilt)*alpha
    if joint then joint.C0 = self.baseJoint*CFrame.new(0,0,self.kick)*CFrame.Angles(0,0,math.rad(self.tilt)) end
    local root = self.character:FindFirstChild("HumanoidRootPart")
    local moving = root and root.AssemblyLinearVelocity.Magnitude > 2
    local grounded = self.humanoid.FloorMaterial ~= Enum.Material.Air
    local movement = grounded and (me.sliding and "Slide" or me.crouching and (moving and "CrouchWalk" or "CrouchIdle") or me.sprinting and moving and "Sprint") or nil
    self.animations:movement(movement)
    if grounded and moving and not me.sliding and now >= self.nextStep then
        self.nextStep = now+(me.sprinting and Config.SprintFootstepInterval or Config.FootstepInterval)
        self.audio:play(me.sprinting and "SprintFootstep" or "Footstep",root.Position)
    end
    if self.slideSound and root then self.slideSound:SetPosition(root.Position) end
    if self.readyAt and now >= self.readyAt then self.readyAt=nil; self.audio:play("EvolutionReady") end
    if self.pulse.Enabled then
        local remaining = math.max(0,(self.pulseUntil-now)/Config.PulseDuration)
        self.pulse.FillTransparency, self.pulse.OutlineTransparency = 1-remaining*.22,1-remaining*.65
        if remaining == 0 then self.pulse.Enabled=false end
    end
end
function Presentation:destroy()
    self:clear()
    self.audio:destroy()
    self.pulse:Destroy()
    for _, flash in ipairs(self.flashes) do flash.part:Destroy() end
end
return Presentation
