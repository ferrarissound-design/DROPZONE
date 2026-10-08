local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage:WaitForChild("DropzoneShared"):WaitForChild("Weapons"))
local Theme = require(ReplicatedStorage:WaitForChild("DropzoneShared"):WaitForChild("VisualTheme"))
local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)
local DamageFeedback = require(script.Parent.DamageFeedback)
local Presentation = require(script.Parent.Presentation)
local FireDrag = require(script.Parent.FireDrag)
local fireDrag = FireDrag.new(require(ReplicatedStorage:WaitForChild("DropzoneShared"):WaitForChild("PresentationConfig")))
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("DropzoneRemotes")
local action = remotes:WaitForChild("Action")
local hud, effects = Hud.new(UserInputService.TouchEnabled), Effects.new()
local damageFeedback = DamageFeedback.new(effects.folder)
local presentation = Presentation.new(effects.folder, player)
local state, shooting, nextShot, buildType, spectateIndex = nil, false, 0, "Wall", 1
local submittedEvolutionDraft
local touchAimToggled = false
local mobileMode = "Combat"
local aimButton
local nextJumpRequest = 0
local playing, send, aim
local function tryShoot()
    if not playing or not playing() or (UserInputService.TouchEnabled and mobileMode == "Build") or os.clock() < nextShot then return end
    local spec = state and state.me and Weapons[state.me.weapon]
    if not spec then return end
    nextShot = os.clock() + spec.interval
    if state.me.ammo == 0 and not state.me.reloading then presentation.audio:play("Empty") end
    local direction = aim and aim()
    if direction then send("Fire", direction) end
end
playing = function()
    return state and (state.phase == "Active" or state.phase == "FinalZone") and state.me and state.me.alive
end
send = function(command, argument)
    if playing() then hud:learn(command) end
    if playing() then action:FireServer(state.roundId, command, argument) end
end
local function cancelAim()
    touchAimToggled = false
    presentation:cancelAim()
    if aimButton then
        aimButton.Text = "AIM"
        aimButton.BackgroundColor3, aimButton.TextColor3 = Theme.Ink, Theme.Paper
    end
end
local function stopFireTouch()
    if fireDrag.input then
        shooting = false
        fireDrag:clear()
    end
end
local function setMobileMode(mode)
    stopFireTouch()
    shooting = false
    cancelAim()
    mobileMode = mode
    hud:setMobileMode(mode)
end
player.CharacterRemoving:Connect(function() setMobileMode("Combat") end)
player.CharacterAdded:Connect(function() setMobileMode("Combat") end)
local function build()
    cancelAim()
    send("Build", buildType)
end
local function mouseOnEvolutionPanel(input)
    if not hud.draft.Visible then return false end
    local position = input.Position
    local origin, size = hud.draft.AbsolutePosition, hud.draft.AbsoluteSize
    return position.X >= origin.X and position.X <= origin.X + size.X
        and position.Y >= origin.Y and position.Y <= origin.Y + size.Y
end
local fire = hud:button("Fire", "FIRE\n射撃", 780, 194, 92, 92)
fire.BackgroundColor3, fire.TextColor3 = Theme.Orange, Theme.Ink
-- Active sinks this touch for Roblox CameraInput, including after it leaves the
-- button. Otherwise the standard camera and FireDrag could both rotate it.
fire.Active = true
fire.InputBegan:Connect(function(input)
    if not playing() or mobileMode == "Build" or mouseOnEvolutionPanel(input) then return end
    if input.UserInputType == Enum.UserInputType.Touch then
        if not fireDrag:begin(input) then return end
        shooting = true
        if state and state.me and state.me.sprinting then send("Sprint", false) end
        tryShoot()
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        shooting = true
        tryShoot()
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input ~= fireDrag.input then return end
    if input.UserInputState == Enum.UserInputState.Cancel then stopFireTouch(); return end
    if not playing() then stopFireTouch(); return end
    -- Intentionally accept processed input: our captured Fire GUI touch is sunk.
    fireDrag:move(input)
end)
aimButton = hud:button("Aim", "AIM", 590, 320, 76, 56)
aimButton.Activated:Connect(function()
    if not playing() or mobileMode == "Build" then return end
    touchAimToggled = not touchAimToggled
    presentation:setAimHeld(touchAimToggled)
    if touchAimToggled and state.me.sprinting then send("Sprint", false) end
    aimButton.Text = touchAimToggled and "AIM\nON" or "AIM"
    aimButton.BackgroundColor3 = touchAimToggled and Theme.Blue or Theme.Ink
    aimButton.TextColor3 = Theme.Paper
end)
hud:button("Reload", "↻\n装填", 680, 275, 88, 56, function() if mobileMode == "Combat" then send("Reload") end end)
hud:button("Build", "▦\n建築", 680, 205, 88, 60, function()
    if playing() then setMobileMode("Build") end
end)
hud:button("Place", "＋\n設置", 0, 0, 64, 64, function()
    if playing() and mobileMode == "Build" then build() end
end)
hud:button("Combat", "↩\n戦闘", 0, 0, 64, 64, function()
    if playing() then setMobileMode("Combat") end
end)
-- Two movement buttons replace the previous Crouch + Slide pair.
hud:button("Sprint", "走る", 784, 285, 82, 48, function()
    local enable = not (state and state.me and state.me.sprinting)
    if enable then cancelAim() end
    send("Sprint", enable)
end)
local function posture() send("Posture") end
hud:button("Crouch", "しゃがみ", 680, 340, 88, 48, posture)
for i, kind in ipairs({"Wall", "Floor", "Ramp"}) do
    local labels = {"壁", "床", "坂"}
    hud:button(kind, labels[i], 632 + (i - 1) * 82, 137, 76, 52, function()
        if not playing() or mobileMode ~= "Build" then return end
        buildType = kind
        for _, k in ipairs({"Wall", "Floor", "Ramp"}) do hud.buttons[k].BackgroundColor3 = k == kind and Theme.Blue or Theme.Ink end
    end)
end
hud.buttons.Wall.BackgroundColor3 = Theme.Blue
for i = 1, 3 do hud:button("Slot" .. i, tostring(i), 279 + (i - 1) * 116, 418, 110, 48, function()
    if playing() then
        if UserInputService.TouchEnabled then setMobileMode("Combat") end
        send("Equip", i)
    end
end) end
hud:button("Spectate", "観戦対象を切替", 350, 285, 200, 52, function() spectateIndex = spectateIndex + 1 end)
for name, button in pairs(hud.buttons) do
    if name ~= "Fire" then button.Activated:Connect(function() presentation.audio:play("Button") end) end
end
hud:setMobileMode("Combat")
UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.Tab then
        if not UserInputService:GetFocusedTextBox() and state
            and (state.phase == "Active" or state.phase == "FinalZone") then
            spectateIndex = spectateIndex + 1
        end
        return
    end
    if processed then return end
    if not playing() or ((input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.MouseButton2) and mouseOnEvolutionPanel(input)) then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        shooting = true
        tryShoot()
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        presentation:setAimHeld(true)
        if state.me.sprinting then send("Sprint", false) end
    end
    local key = input.KeyCode
    if key == Enum.KeyCode.V then hud:toggleDraft()
    elseif key == Enum.KeyCode.R then send("Reload")
    elseif key == Enum.KeyCode.Q then build()
    elseif key == Enum.KeyCode.E then send("Pickup")
    elseif key == Enum.KeyCode.One then send("Equip", 1)
    elseif key == Enum.KeyCode.Two then send("Equip", 2)
    elseif key == Enum.KeyCode.Three then send("Equip", 3)
    elseif key == Enum.KeyCode.Z then buildType = "Wall"; hud.buildUntil = os.clock() + 3
    elseif key == Enum.KeyCode.X then buildType = "Floor"; hud.buildUntil = os.clock() + 3
    elseif key == Enum.KeyCode.C then buildType = "Ramp"; hud.buildUntil = os.clock() + 3
    elseif key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then posture()
    elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then cancelAim(); send("Sprint", true) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then send("Sprint", false) end
    if input == fireDrag.input then stopFireTouch() end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then shooting = false end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then presentation:setAimHeld(false) end
end)
UserInputService.WindowFocusReleased:Connect(function()
    stopFireTouch()
    shooting = false
    setMobileMode("Combat")
    send("Sprint", false)
end)
UserInputService.JumpRequest:Connect(function()
    -- Do not wait for a posture snapshot before cancelling a just-started slide.
    if playing() and os.clock() >= nextJumpRequest then
        nextJumpRequest = os.clock() + .15
        send("Jump")
    end
end)
aim = function()
    local camera, character = workspace.CurrentCamera, player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not camera or not root then return nil end
    local center = hud.crosshair.AbsolutePosition + hud.crosshair.AbsoluteSize / 2
    -- AbsolutePosition is in GUI-inset coordinates, matching ScreenPointToRay.
    -- Use the displayed camera: undoing recoil here aims away from the reticle.
    local ray = camera:ScreenPointToRay(center.X, center.Y)
    local origin = root.Position + Vector3.new(0, 1.4, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, effects.folder}
    -- Skip the camera-to-character segment. A wall behind the shooter must not
    -- become a target that turns the server's root-origin ray backwards.
    -- Cover ahead of the firing origin is still resolved by the server raycast.
    local aimStart = ray.Origin + ray.Direction * math.max(0, (origin - ray.Origin):Dot(ray.Direction))
    local hit = workspace:Raycast(aimStart, ray.Direction * 300, params)
    local target = hit and hit.Position or aimStart + ray.Direction * 300
    -- Modest mobile assistance only inside the reticle cone and with line of sight.
    if UserInputService.TouchEnabled then
        local best = math.cos(math.rad(5))
        for _, candidate in ipairs(state.targets) do
            local model = candidate.model
            local other = model and model:FindFirstChild("HumanoidRootPart")
            if other and model ~= character then
                local delta = other.Position + Vector3.new(0, 0.8, 0) - ray.Origin
                if delta.Magnitude > 1 and delta.Magnitude < 180
                    and (other.Position + Vector3.new(0, 0.8, 0) - origin):Dot(ray.Direction) > 0 then
                    local dot = delta.Unit:Dot(ray.Direction)
                    if dot > best then
                        local block = workspace:Raycast(ray.Origin, delta, params)
                        if not block or block.Instance:IsDescendantOf(model) then best, target = dot, other.Position + Vector3.new(0, 0.8, 0) end
                    end
                end
            end
        end
    end
    local direction = target - origin
    return direction.Magnitude > 0.1 and direction.Unit or nil, target
end
remotes:WaitForChild("Snapshot").OnClientEvent:Connect(function(s)
    if not state or state.roundId ~= s.roundId then
        stopFireTouch()
        shooting, nextShot, spectateIndex = false, 0, 1
        submittedEvolutionDraft = nil
        nextJumpRequest = 0
        setMobileMode("Combat")
        damageFeedback:clear()
        effects:clear()
        hud.shotUntil, hud.hitUntil, hud.hitMarkerUntil = 0, 0, 0
        hud.hitMarker.Visible = false
        hud.notice.Visible, hud.noticeUntil = false, nil
        buildType = "Wall"
        for _, k in ipairs({"Wall", "Floor", "Ramp"}) do hud.buttons[k].BackgroundColor3 = k == "Wall" and Theme.Blue or Theme.Ink end
    end
    state = s
    presentation:snapshot(s)
    if not playing() then
        stopFireTouch()
        shooting = false
        setMobileMode("Combat")
    end
    if s.phase ~= "Active" and s.phase ~= "FinalZone" then
        damageFeedback:clear()
        effects:clear()
        hud.shotUntil, hud.hitUntil, hud.hitMarkerUntil = 0,0,0
        hud.hitMarker.Visible = false
    end
    local draft = s.me and s.me.evolutionDraft
    if not draft or draft.id ~= submittedEvolutionDraft then submittedEvolutionDraft = nil end
    hud.buildType = buildType
    hud:update(s, function(draftId, index)
        if playing() and draftId == submittedEvolutionDraft then return false end
        if playing() and draft and draft.id == draftId then
            submittedEvolutionDraft = draftId
            presentation.audio:play("EvolutionSelect")
            send("Evolve", {draftId = draftId, index = index})
            return true
        end
        return false
    end)
    effects:zone(s.zone, s.phase == "Active" or s.phase == "FinalZone")
    local camera = workspace.CurrentCamera
    if camera then
        if playing() or s.phase == "Intermission" or s.phase == "Waiting" then
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then camera.CameraSubject, camera.CameraType = humanoid, Enum.CameraType.Custom end
        elseif #s.targets > 0 then
            spectateIndex = (spectateIndex - 1) % #s.targets + 1
            local model = s.targets[spectateIndex].model
            local humanoid = model and model:FindFirstChildOfClass("Humanoid")
            if humanoid then camera.CameraSubject, camera.CameraType = humanoid, Enum.CameraType.Custom end
        end
    end
end)
remotes:WaitForChild("Effects").OnClientEvent:Connect(function(kind, a, b, c, shooterId, roundId, impacts)
    if kind == "Notice" and state and a == state.roundId then hud:toast(b)
    elseif kind == "Pickup" and playing() and a == state.roundId then
        presentation.audio:play(b == "Epic" and "EpicPickup" or b == "Rare" and "RarePickup" or "Pickup")
    elseif kind == "SlideSound" and state and a == state.roundId and (state.phase == "Active" or state.phase == "FinalZone") then
        presentation.audio:play("SlideStart", b)
    elseif kind == "ZoneDamage" and playing() and a == state.roundId then
        presentation.audio:play("ZoneDamage")
    elseif kind == "Shot" and state and roundId == state.roundId and (state.phase == "Active" or state.phase == "FinalZone") then
        local localShot = shooterId == player.UserId
        -- Server origin remains the damage ray origin; the barrel tip is display-only.
        local visualOrigin = presentation:shot(a, c, shooterId, state.targets) or a
        effects:shot(visualOrigin, b, c, localShot, impacts)
        if localShot then hud.shotUntil = os.clock() + .14 end
    elseif kind == "Damage" and state and a == state.roundId and (state.phase == "Active" or state.phase == "FinalZone") then
        -- Only the server can send confirmed damage; never predict a hit locally.
        local now = os.clock()
        damageFeedback:show(b, now)
        presentation:damage(b)
        local hp, shield, eliminated = 0,0,false
        for _, damage in ipairs(b) do
            if damage.hp + damage.shield > 0 then
                hp, shield = hp+damage.hp, shield+damage.shield
                eliminated = eliminated or damage.eliminated
                local color = damage.eliminated and Theme.Gold or damage.shield > 0 and Theme.Cyan or Theme.Orange
                effects:impact(damage.position, damage.normal, color, true, now)
            end
        end
        if hp + shield > 0 then
            hud.hitUntil, hud.hitMarkerUntil = now+.18, now+(eliminated and .36 or .24)
            hud.hitMarker.TextColor3 = eliminated and Theme.Gold or shield > 0 and Theme.Cyan or Theme.Orange
            hud.hitMarker.TextSize = eliminated and 52 or 42
            hud.hitMarker.Visible = true
            if eliminated then hud:eliminated() end
        end
    end
end)
-- Camera transforms are bracketed around Roblox's camera update, never accumulated.
RunService:BindToRenderStep("DropzonePresentationBefore", Enum.RenderPriority.Camera.Value-1, function(dt)
    presentation:undoCamera()
    presentation:prepareCamera(dt)
    if fireDrag.input and fireDrag.input.UserInputState == Enum.UserInputState.Cancel then stopFireTouch() end
    if playing() then fireDrag:apply(workspace.CurrentCamera) else stopFireTouch() end
end)
RunService:BindToRenderStep("DropzonePresentationAfter", Enum.RenderPriority.Camera.Value+1, function(dt)
    presentation:step(math.min(dt,.1))
    if playing() and (presentation:isAiming() or (presentation.aimBlend or 0) > .001) then
        local _, target = aim()
        presentation:updateWeaponAim(target)
    end
    if shooting and playing() then tryShoot() end
end)
script.Destroying:Connect(function()
    stopFireTouch()
    RunService:UnbindFromRenderStep("DropzonePresentationBefore")
    RunService:UnbindFromRenderStep("DropzonePresentationAfter")
    presentation:destroy()
    damageFeedback:clear()
    effects:destroy()
end)
local feedbackClock = 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    effects:step(now)
    hud.hitMarker.Visible = playing() and now < (hud.hitMarkerUntil or 0)
    if now >= feedbackClock then
        feedbackClock = now + .1
        damageFeedback:step(now)
        hud:step(now, playing())
        local aiming = presentation:isAiming()
        hud.crosshair.TextColor3 = now < (hud.hitUntil or 0) and Theme.Orange or aiming and Theme.Cyan or Theme.Paper
        hud.crosshair.TextSize = now < (hud.shotUntil or 0) and (aiming and 26 or 32) or (aiming and 22 or 28)
    end
    local draftOpen = hud.draft.Visible
    if playing() and presentation.aimHeld and not draftOpen and not UserInputService.TouchEnabled and not UserInputService:GetFocusedTextBox() then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    else UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
end)
