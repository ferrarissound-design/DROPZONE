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
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("DropzoneRemotes")
local action = remotes:WaitForChild("Action")
local hud, effects = Hud.new(), Effects.new()
local damageFeedback = DamageFeedback.new(effects.folder)
local presentation = Presentation.new(effects.folder, player)
local state, shooting, nextShot, buildType, spectateIndex = nil, false, 0, "Wall", 1
local submittedEvolutionDraft
local touchFire = nil
local nextJumpRequest = 0
local function playing()
    return state and (state.phase == "Active" or state.phase == "FinalZone") and state.me and state.me.alive
end
local function gameplayInput()
    return playing() and not state.me.evolutionDraft
end
local function send(command, argument)
    if playing() and (not state.me.evolutionDraft or command == "Evolve" or (command == "Sprint" and argument == false)) then
        action:FireServer(state.roundId, command, argument)
    end
end
local function cancelAim()
    presentation:cancelAim()
end
local function build()
    if not gameplayInput() then return end
    cancelAim()
    send("Build", buildType)
end
local fire = hud:button("Fire", "射撃", 784, 190, 82, 82)
fire.BackgroundColor3, fire.TextColor3 = Theme.Orange, Theme.Ink
fire.InputBegan:Connect(function(input)
    if not gameplayInput() then return end
    if input.UserInputType == Enum.UserInputType.Touch then
        touchFire, shooting = input, true
        presentation:setCombatAim(true)
        if state and state.me and state.me.sprinting then send("Sprint", false) end
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then shooting = true end
end)
hud:button("Reload", "装填 R", 680, 275, 88, 56, function() send("Reload") end)
hud:button("Build", "建築 Q", 680, 205, 88, 60, build)
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
        buildType = kind
        for _, k in ipairs({"Wall", "Floor", "Ramp"}) do hud.buttons[k].BackgroundColor3 = k == kind and Theme.Blue or Theme.Ink end
    end)
end
hud.buttons.Wall.BackgroundColor3 = Theme.Blue
for i = 1, 3 do hud:button("Slot" .. i, tostring(i), 279 + (i - 1) * 116, 418, 110, 48, function() send("Equip", i) end) end
hud:button("Spectate", "観戦対象を切替", 350, 285, 200, 52, function() spectateIndex = spectateIndex + 1 end)
for name, button in pairs(hud.buttons) do
    if name ~= "Fire" then button.Activated:Connect(function() presentation.audio:play("Button") end) end
end
local function mouseOnEvolutionCard(input)
    if not hud.draft.Visible then return false end
    local position = input.Position
    for _, card in ipairs(hud.draftCards) do
        local origin, size = card.AbsolutePosition, card.AbsoluteSize
        if position.X >= origin.X and position.X <= origin.X + size.X
            and position.Y >= origin.Y and position.Y <= origin.Y + size.Y then return true end
    end
    return false
end
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not gameplayInput() or (input.UserInputType == Enum.UserInputType.MouseButton1 and mouseOnEvolutionCard(input)) then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then shooting = true
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        presentation:setAimHeld(true)
        if state.me.sprinting then send("Sprint", false) end
    end
    local key = input.KeyCode
    if key == Enum.KeyCode.R then send("Reload")
    elseif key == Enum.KeyCode.Q then build()
    elseif key == Enum.KeyCode.E then send("Pickup")
    elseif key == Enum.KeyCode.One then send("Equip", 1)
    elseif key == Enum.KeyCode.Two then send("Equip", 2)
    elseif key == Enum.KeyCode.Three then send("Equip", 3)
    elseif key == Enum.KeyCode.Z then buildType = "Wall"
    elseif key == Enum.KeyCode.X then buildType = "Floor"
    elseif key == Enum.KeyCode.C then buildType = "Ramp"
    elseif key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then posture()
    elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then cancelAim(); send("Sprint", true)
    elseif key == Enum.KeyCode.Tab then spectateIndex = spectateIndex + 1 end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then send("Sprint", false) end
    if input == touchFire then
        shooting, touchFire = false, nil
        presentation:setCombatAim(false)
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then shooting = false end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then presentation:setAimHeld(false) end
end)
UserInputService.WindowFocusReleased:Connect(function()
    shooting, touchFire = false, nil
    cancelAim()
    send("Sprint", false)
end)
UserInputService.JumpRequest:Connect(function()
    -- Do not wait for a posture snapshot before cancelling a just-started slide.
    if gameplayInput() and os.clock() >= nextJumpRequest then
        nextJumpRequest = os.clock() + .15
        send("Jump")
    end
end)
local function aim()
    local camera, character = workspace.CurrentCamera, player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not camera or not root then return nil end
    local center = hud.crosshair.AbsolutePosition + hud.crosshair.AbsoluteSize / 2
    -- Aim uses the camera before cosmetic recoil. Restore the displayed frame immediately.
    local displayFrame = camera.CFrame
    if presentation.camera == camera and presentation.applied then camera.CFrame = displayFrame*presentation.applied:Inverse() end
    local ray = camera:ScreenPointToRay(center.X, center.Y)
    camera.CFrame = displayFrame
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, effects.folder}
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
    local target = hit and hit.Position or ray.Origin + ray.Direction * 300
    local origin = root.Position + Vector3.new(0, 1.4, 0)
    -- Modest mobile assistance only inside the reticle cone and with line of sight.
    if UserInputService.TouchEnabled then
        local best = math.cos(math.rad(5))
        for _, candidate in ipairs(state.targets) do
            local model = candidate.model
            local other = model and model:FindFirstChild("HumanoidRootPart")
            if other and model ~= character then
                local delta = other.Position + Vector3.new(0, 0.8, 0) - ray.Origin
                if delta.Magnitude > 1 and delta.Magnitude < 180 then
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
    return direction.Magnitude > 0.1 and direction.Unit or nil
end
remotes:WaitForChild("Snapshot").OnClientEvent:Connect(function(s)
    if not state or state.roundId ~= s.roundId then
        shooting, touchFire, nextShot, spectateIndex = false, nil, 0, 1
        submittedEvolutionDraft = nil
        nextJumpRequest = 0
        cancelAim()
        damageFeedback:clear()
        hud.shotUntil, hud.hitUntil = 0, 0
        hud.notice.Visible, hud.noticeUntil = false, nil
        buildType = "Wall"
        for _, k in ipairs({"Wall", "Floor", "Ramp"}) do hud.buttons[k].BackgroundColor3 = k == "Wall" and Theme.Blue or Theme.Ink end
    end
    state = s
    presentation:snapshot(s)
    if not gameplayInput() then
        shooting, touchFire = false, nil
        cancelAim()
    end
    if s.phase ~= "Active" and s.phase ~= "FinalZone" then damageFeedback:clear() end
    local draft = s.me and s.me.evolutionDraft
    if not draft or draft.id ~= submittedEvolutionDraft then submittedEvolutionDraft = nil end
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
remotes:WaitForChild("Effects").OnClientEvent:Connect(function(kind, a, b, c, shooterId, roundId)
    if kind == "Notice" and state and a == state.roundId then hud:toast(b)
    elseif kind == "Pickup" and playing() and a == state.roundId then
        presentation.audio:play(b == "Epic" and "EpicPickup" or b == "Rare" and "RarePickup" or "Pickup")
    elseif kind == "SlideSound" and state and a == state.roundId and (state.phase == "Active" or state.phase == "FinalZone") then
        presentation.audio:play("SlideStart", b)
    elseif kind == "ZoneDamage" and playing() and a == state.roundId then
        presentation.audio:play("ZoneDamage")
    elseif kind == "Shot" and state and roundId == state.roundId and (state.phase == "Active" or state.phase == "FinalZone") then
        presentation:shot(a, c, shooterId, state.targets)
        effects:shot(a, b, c)
        if shooterId == player.UserId then hud.shotUntil = os.clock() + .1 end
    elseif kind == "Damage" and state and a == state.roundId and (state.phase == "Active" or state.phase == "FinalZone") then
        -- Only the server can send confirmed damage; never predict a hit locally.
        damageFeedback:show(b, os.clock())
        presentation:damage(b)
        hud.hitUntil = os.clock() + .18
        for _, damage in ipairs(b) do if damage.eliminated then hud:eliminated(); break end end
    end
end)
-- Camera transforms are bracketed around Roblox's camera update, never accumulated.
RunService:BindToRenderStep("DropzonePresentationBefore", Enum.RenderPriority.Camera.Value-1, function() presentation:undoCamera() end)
RunService:BindToRenderStep("DropzonePresentationAfter", Enum.RenderPriority.Camera.Value+1, function(dt) presentation:step(math.min(dt,.1)) end)
script.Destroying:Connect(function()
    RunService:UnbindFromRenderStep("DropzonePresentationBefore")
    RunService:UnbindFromRenderStep("DropzonePresentationAfter")
    presentation:destroy()
end)
local feedbackClock = 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now >= feedbackClock then
        feedbackClock = now + .1
        damageFeedback:step(now)
        local aiming = presentation:isAiming()
        hud.crosshair.TextColor3 = now < (hud.hitUntil or 0) and Theme.Orange or aiming and Theme.Cyan or Theme.Paper
        hud.crosshair.TextSize = now < (hud.shotUntil or 0) and (aiming and 26 or 32) or (aiming and 22 or 28)
    end
    local draftOpen = playing() and state.me.evolutionDraft ~= nil
    if playing() and not draftOpen and not UserInputService.TouchEnabled and not UserInputService:GetFocusedTextBox() then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    else UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
    if shooting and gameplayInput() and os.clock() >= nextShot then
        local spec = Weapons[state.me.weapon]
        if spec then
            nextShot = os.clock() + spec.interval
            local direction = aim()
            if state.me.ammo == 0 and not state.me.reloading then presentation.audio:play("Empty") end
            if direction then send("Fire", direction) end
        end
    end
end)
