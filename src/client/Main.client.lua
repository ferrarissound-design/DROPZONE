local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage:WaitForChild("DropzoneShared"):WaitForChild("Weapons"))
local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("DropzoneRemotes")
local action = remotes:WaitForChild("Action")
local hud, effects = Hud.new(), Effects.new()
local state, shooting, nextShot, buildType, spectateIndex = nil, false, 0, "Wall", 1
local submittedEvolutionDraft
local touchFire = nil
local function playing()
    return state and (state.phase == "Active" or state.phase == "FinalZone") and state.me and state.me.alive
end
local function send(command, argument)
    if playing() then action:FireServer(state.roundId, command, argument) end
end
local function build() send("Build", buildType) end
local fire = hud:button("Fire", "射撃", 784, 190, 82, 82)
fire.BackgroundColor3 = Color3.fromRGB(191, 93, 48)
fire.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then touchFire, shooting = input, true
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then shooting = true end
end)
hud:button("Reload", "装填 R", 680, 275, 88, 56, function() send("Reload") end)
hud:button("Build", "建築 Q", 680, 205, 88, 60, build)
for i, kind in ipairs({"Wall", "Floor", "Ramp"}) do
    local labels = {"壁", "床", "坂"}
    hud:button(kind, labels[i], 632 + (i - 1) * 82, 137, 76, 52, function()
        buildType = kind
        for _, k in ipairs({"Wall", "Floor", "Ramp"}) do hud.buttons[k].BackgroundColor3 = k == kind and Color3.fromRGB(48, 143, 157) or Color3.fromRGB(33, 78, 100) end
    end)
end
hud.buttons.Wall.BackgroundColor3 = Color3.fromRGB(48, 143, 157)
for i = 1, 3 do hud:button("Slot" .. i, tostring(i), 279 + (i - 1) * 116, 418, 110, 48, function() send("Equip", i) end) end
hud:button("Spectate", "観戦対象を切替", 350, 285, 200, 52, function() spectateIndex = spectateIndex + 1 end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then shooting = true end
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
    elseif key == Enum.KeyCode.Tab then spectateIndex = spectateIndex + 1 end
end)
UserInputService.InputEnded:Connect(function(input)
    if input == touchFire then shooting, touchFire = false, nil end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then shooting = false end
end)
UserInputService.WindowFocusReleased:Connect(function() shooting, touchFire = false, nil end)
local function aim()
    local camera, character = workspace.CurrentCamera, player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not camera or not root then return nil end
    local center = hud.crosshair.AbsolutePosition + hud.crosshair.AbsoluteSize / 2
    local ray = camera:ScreenPointToRay(center.X, center.Y)
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
        hud.notice.Visible, hud.noticeUntil = false, nil
        buildType = "Wall"
        for _, k in ipairs({"Wall", "Floor", "Ramp"}) do hud.buttons[k].BackgroundColor3 = k == "Wall" and Color3.fromRGB(48, 143, 157) or Color3.fromRGB(33, 78, 100) end
    end
    state = s
    if not playing() then shooting = false end
    local draft = s.me and s.me.evolutionDraft
    if not draft or draft.id ~= submittedEvolutionDraft then submittedEvolutionDraft = nil end
    hud:update(s, function(draftId, index)
        if playing() and draftId == submittedEvolutionDraft then return end
        if playing() and draft and draft.id == draftId then
            submittedEvolutionDraft = draftId
            send("Evolve", {draftId = draftId, index = index})
        end
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
remotes:WaitForChild("Effects").OnClientEvent:Connect(function(kind, a, b, c)
    if kind == "Notice" then hud:toast(a)
    elseif kind == "Shot" then effects:shot(a, b, c)
    elseif kind == "Hit" then
        hud.crosshair.TextColor3 = Color3.fromRGB(255, 100, 80)
        task.delay(0.12, function() hud.crosshair.TextColor3 = Color3.new(1, 1, 1) end)
    end
end)
RunService.RenderStepped:Connect(function()
    if playing() and not UserInputService.TouchEnabled and not UserInputService:GetFocusedTextBox() then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    else UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
    if shooting and playing() and os.clock() >= nextShot then
        local spec = Weapons[state.me.weapon]
        if spec then
            nextShot = os.clock() + spec.interval
            local direction = aim()
            if direction then send("Fire", direction) end
        end
    end
end)
