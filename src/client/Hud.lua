local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("DropzoneShared"):WaitForChild("Rules"))
local Hud = {}
Hud.__index = Hud
local white = Color3.fromRGB(237, 246, 255)
local function label(parent, name, position, size, text, textSize)
    local t = Instance.new("TextLabel")
    t.Name, t.Position, t.Size = name, position, size
    t.BackgroundColor3, t.BackgroundTransparency = Color3.fromRGB(17, 27, 44), 0.18
    t.BorderSizePixel, t.TextColor3 = 0, white
    t.Text, t.TextSize, t.Font = text, textSize or 16, Enum.Font.GothamBold
    t.TextWrapped, t.Parent = true, parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius, corner.Parent = UDim.new(0, 9), t
    return t
end
function Hud.new()
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "DropzoneHUD", false, false
    gui.DisplayOrder, gui.ZIndexBehavior = 10, Enum.ZIndexBehavior.Sibling
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local old = playerGui:FindFirstChild(gui.Name)
    if old then old:Destroy() end
    gui.Parent = playerGui
    local canvas = Instance.new("Frame")
    canvas.Name, canvas.AnchorPoint, canvas.Position = "Canvas", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
    canvas.Size, canvas.BackgroundTransparency, canvas.Parent = UDim2.fromOffset(900, 480), 1, gui
    local scale = Instance.new("UIScale")
    scale.Parent = canvas
    local function resize()
        scale.Scale = math.min(gui.AbsoluteSize.X / 900, gui.AbsoluteSize.Y / 480)
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    resize()
    local self = setmetatable({gui = gui, canvas = canvas, buttons = {}}, Hud)
    self.top = label(canvas, "Round", UDim2.fromOffset(270, 8), UDim2.fromOffset(360, 38), "DROPZONE", 18)
    self.zone = label(canvas, "Zone", UDim2.fromOffset(280, 51), UDim2.fromOffset(340, 33), "安全地帯", 15)
    self.stats = label(canvas, "Health", UDim2.fromOffset(22, 16), UDim2.fromOffset(218, 58), "HP —", 17)
    self.evo = label(canvas, "Evolution", UDim2.fromOffset(22, 80), UDim2.fromOffset(218, 43), "EVOLUTION 0", 13)
    self.draft = Instance.new("Frame")
    self.draft.Name, self.draft.Position, self.draft.Size = "EvolutionDraft", UDim2.fromOffset(16, 132), UDim2.fromOffset(600, 177)
    self.draft.BackgroundColor3, self.draft.BackgroundTransparency, self.draft.BorderSizePixel = Color3.fromRGB(12, 21, 34), 0.08, 0
    self.draft.ZIndex, self.draft.Active, self.draft.Selectable = 20, false, false
    self.draft.Visible, self.draft.Parent = false, canvas
    local draftCorner = Instance.new("UICorner"); draftCorner.CornerRadius, draftCorner.Parent = UDim.new(0, 14), self.draft
    self.draftTitle = label(self.draft, "DraftTitle", UDim2.fromOffset(10, 4), UDim2.fromOffset(440, 28), "EVOLUTION DRAFT  ·  選択中も戦闘は続く", 16)
    self.draftTitle.BackgroundTransparency = 1
    self.draftTitle.ZIndex = 21
    self.draftTimer = label(self.draft, "DraftTimer", UDim2.fromOffset(505, 4), UDim2.fromOffset(80, 28), "5秒", 15)
    self.draftTimer.BackgroundTransparency = 1
    self.draftTimer.ZIndex = 21
    self.draftCards = {}
    for i = 1, 3 do
        local card = Instance.new("TextButton")
        card.Name, card.Position, card.Size = "Choice" .. i, UDim2.fromOffset(10 + (i - 1) * 195, 38), UDim2.fromOffset(190, 127)
        card.BackgroundColor3, card.TextColor3, card.TextSize = Color3.fromRGB(34, 69, 91), white, 16
        card.BorderSizePixel, card.Font, card.TextWrapped, card.Parent = 0, Enum.Font.GothamBold, true, self.draft
        card.ZIndex, card.AutoButtonColor = 22, true
        local corner = Instance.new("UICorner"); corner.CornerRadius, corner.Parent = UDim.new(0, 11), card
        local stroke = Instance.new("UIStroke"); stroke.Color, stroke.Thickness, stroke.Parent = Color3.fromRGB(92, 183, 207), 1.5, card
        card.Activated:Connect(function()
            if self.onEvolutionPick and self.currentDraft and self.submittedDraftId ~= self.currentDraft.id then
                local sent = self.onEvolutionPick(self.currentDraft.id, i)
                if sent then
                    self.submittedDraftId, self.submittedChoice = self.currentDraft.id, i
                    for _, choice in ipairs(self.draftCards) do choice.Active, choice.AutoButtonColor = false, false end
                    self:updateDraftCards()
                    card.BackgroundColor3 = Color3.fromRGB(63, 160, 126)
                    TweenService:Create(card, TweenInfo.new(0.16), {BackgroundColor3 = Color3.fromRGB(46, 122, 99)}):Play()
                end
            end
        end)
        self.draftCards[i] = card
    end
    self.ammo = label(canvas, "Ammo", UDim2.fromOffset(328, 375), UDim2.fromOffset(244, 34), "武器を拾おう", 16)
    self.energy = label(canvas, "Energy", UDim2.fromOffset(630, 95), UDim2.fromOffset(242, 30), "BUILD ENERGY 60", 13)
    self.notice = label(canvas, "Notice", UDim2.fromOffset(260, 103), UDim2.fromOffset(380, 43), "", 17)
    self.notice.Visible = false
    self.crosshair = label(canvas, "Crosshair", UDim2.fromOffset(435, 225), UDim2.fromOffset(30, 30), "+", 28)
    self.crosshair.BackgroundTransparency = 1
    self.crosshair.ZIndex = 30
    self.result = label(canvas, "Result", UDim2.fromOffset(265, 150), UDim2.fromOffset(370, 205), "", 22)
    self.result.Visible = false
    self.hint = label(canvas, "Hint", UDim2.fromOffset(260, 340), UDim2.fromOffset(380, 28), "近づくと自動取得 / Eで取得", 13)
    self.mini = Instance.new("Frame")
    self.mini.Name, self.mini.Position, self.mini.Size = "Minimap", UDim2.fromOffset(750, 10), UDim2.fromOffset(122, 78)
    self.mini.BackgroundColor3, self.mini.BorderSizePixel, self.mini.Parent = Color3.fromRGB(20, 39, 49), 0, canvas
    local function circle(color, solid)
        local f = Instance.new("Frame")
        f.AnchorPoint, f.BackgroundColor3 = Vector2.new(0.5, 0.5), color
        f.BackgroundTransparency, f.BorderSizePixel, f.Parent = solid and 0 or 1, 0, self.mini
        local c = Instance.new("UICorner"); c.CornerRadius, c.Parent = UDim.new(1, 0), f
        if not solid then local stroke = Instance.new("UIStroke"); stroke.Color, stroke.Thickness, stroke.Parent = color, 1.5, f end
        return f
    end
    self.currentCircle, self.nextCircle, self.dot = circle(Color3.fromRGB(68, 208, 255)), circle(Color3.fromRGB(240, 240, 240)), circle(Color3.fromRGB(255, 214, 70), true)
    self.dot.Size = UDim2.fromOffset(5, 5)
    return self
end
function Hud:updateDraftCards()
    local draft = self.currentDraft
    local submitted = draft and self.submittedDraftId == draft.id
    for i = 1, 3 do
        local option = draft and draft.options[i]
        local card = self.draftCards[i]
        local text = option and (option.name .. " " .. option.rankText .. "\n" .. option.description .. "\n\n" .. option.category) or "—"
        card.Text = submitted and (i == self.submittedChoice and (text .. "\n送信中…") or text) or text
        card.BackgroundColor3 = submitted and (i == self.submittedChoice and Color3.fromRGB(46, 122, 99) or Color3.fromRGB(31, 43, 56))
        card.TextTransparency = submitted and (i == self.submittedChoice and 0 or 0.28) or 0
        card.Active, card.AutoButtonColor = not submitted, not submitted
    end
end
function Hud:button(name, text, x, y, width, height, callback)
    local b = Instance.new("TextButton")
    b.Name, b.Text, b.Position, b.Size = name, text, UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
    b.BackgroundColor3, b.TextColor3, b.TextSize = Color3.fromRGB(33, 78, 100), white, 17
    b.BorderSizePixel, b.Font, b.Parent = 0, Enum.Font.GothamBold, self.canvas
    local corner = Instance.new("UICorner"); corner.CornerRadius, corner.Parent = UDim.new(0, 12), b
    if callback then b.Activated:Connect(callback) end
    self.buttons[name] = b
    return b
end
function Hud:toast(text)
    self.notice.Text, self.notice.Visible = text, true
    self.noticeUntil = os.clock() + 3
end
function Hud:update(s, onEvolutionPick)
    local me = s.me
    local active = s.phase == "Active" or s.phase == "FinalZone"
    local playing = active and me and me.alive
    local names = {Waiting = "参加待ち", Intermission = "次の試合まで", Starting = "降下準備中", Active = "生存者", FinalZone = "FINAL ZONE", Results = "RESULTS", Resetting = "リセット中"}
    self.top.Text = (names[s.phase] or s.phase) .. (active and ("  " .. s.alive .. "人   KILL " .. (me and me.kills or 0)) or ("  " .. s.remaining .. "秒"))
    local z = s.zone
    self.zone.Text = active and string.format("ZONE %d  %s %d秒  半径%d → %d", z.phase, z.shrinking and "縮小中" or "縮小まで", z.remaining, math.floor(z.radius), z.nextRadius) or "撃破して進化。最後の1人になれ。"
    self.stats.Text = me and string.format("HP %d / %d   SHIELD %d", me.hp, me.maxHp, me.shield) or "DROPZONE\n次のラウンドを待っています"
    local build = {}
    for _, ability in ipairs(me and me.evolutionBuild or {}) do
        if #build < 3 then table.insert(build, ability.name .. " " .. ability.rankText) end
    end
    local buildText = table.concat(build, " · ")
    self.evo.Text = me and ("EVOLUTION " .. me.evolutions .. (buildText ~= "" and ("\n" .. buildText) or "\n撃破で能力獲得")) or "EVOLUTION 0"
    self.energy.Text = "BUILD ENERGY " .. (me and me.energy or 0)
    self.ammo.Text = me and me.weapon and (me.weapon .. "  " .. me.ammo .. " / " .. me.reserve .. (me.reloading and "  装填中" or "")) or "光る武器に近づいて拾おう"
    self.crosshair.Visible, self.hint.Visible = not not playing, not not playing
    local draft = Rules.shouldShowEvolutionDraft(s) and me.evolutionDraft or nil
    self.draft.Visible = draft ~= nil
    self.currentDraft = draft
    self.onEvolutionPick = onEvolutionPick
    if draft then
        self.draftTimer.Text = string.format("%.1f秒", math.max(0, draft.seconds))
        if self.submittedDraftId ~= draft.id then self.submittedDraftId, self.submittedChoice = nil, nil end
        self:updateDraftCards()
    else
        self.submittedDraftId, self.submittedChoice = nil, nil
        for _, card in ipairs(self.draftCards) do card.Active, card.AutoButtonColor, card.TextTransparency = true, true, 0 end
    end
    if self.noticeUntil and os.clock() > self.noticeUntil then self.notice.Visible = false end
    for name, button in pairs(self.buttons) do
        if name == "Spectate" then button.Visible = active and not playing
        else button.Visible = not not playing end
    end
    for i = 1, 3 do
        local b = self.buttons["Slot" .. i]
        if b then b.Text = tostring(i) .. " " .. (me and me.slots[i] or "—"); b.BackgroundColor3 = me and me.slot == i and Color3.fromRGB(48, 143, 157) or Color3.fromRGB(33, 78, 100) end
    end
    self.result.Visible = s.phase == "Results" or (active and me ~= nil and not me.alive)
    if self.result.Visible then
        local title = s.phase == "Results" and (s.winner and me and me.rank == 1 and "#1 VICTORY" or (s.winner and "WINNER: " .. s.winner or "DRAW")) or "ELIMINATED"
        self.result.Text = title .. (me and string.format("\n\n順位 #%d   KILL %d\nDAMAGE %d   生存 %d秒\nEVOLUTION %d", me.rank or s.alive + 1, me.kills, me.damage, me.survival, me.evolutions) or "\n次の試合から参加できます")
        -- Compact death card leaves the spectator view clear.
        self.result.Position = active and UDim2.fromOffset(275, 150) or UDim2.fromOffset(265, 150)
        self.result.Size = active and UDim2.fromOffset(350, 115) or UDim2.fromOffset(370, 205)
        self.result.TextSize = active and 15 or 22
    end
    local function mapPosition(p) return UDim2.fromOffset(61 + p.X / 720 * 78, 39 + p.Z / 720 * 78) end
    for _, pair in ipairs({{self.currentCircle, z.center, z.radius}, {self.nextCircle, z.nextCenter, z.nextRadius}}) do
        pair[1].Position = mapPosition(pair[2])
        -- Fixed stud-to-pixel scale keeps circles circular on this rectangular panel.
        pair[1].Size = UDim2.fromOffset(pair[3] / 360 * 78, pair[3] / 360 * 78)
    end
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then self.dot.Position = mapPosition(root.Position) end
end
return Hud
