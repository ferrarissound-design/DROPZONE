local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("DropzoneShared"):WaitForChild("Rules"))
local Theme = require(ReplicatedStorage:WaitForChild("DropzoneShared"):WaitForChild("VisualTheme"))
local WeaponStats = require(ReplicatedStorage:WaitForChild("DropzoneShared"):WaitForChild("WeaponStats"))
local Hud = {}
Hud.__index = Hud
local white = Theme.Paper
local function escapeRichText(text)
    return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end
local function label(parent, name, position, size, text, textSize)
    local t = Instance.new("TextLabel")
    t.Name, t.Position, t.Size = name, position, size
    t.BackgroundColor3, t.BackgroundTransparency = Theme.Ink, 0.08
    t.BorderSizePixel, t.TextColor3 = 0, white
    t.Text, t.TextSize, t.Font = text, textSize or 16, Enum.Font.GothamBold
    t.TextWrapped, t.Parent = true, parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius, corner.Parent = UDim.new(0, 9), t
    t.Active, t.Selectable = false, false
    return t
end
local function stroke(parent, color, thickness)
    local line = Instance.new("UIStroke")
    line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    line.Color, line.Thickness, line.Parent = color, thickness or 1.5, parent
    return line
end
local function bar(parent, name, x,y,w,h, color)
    local track = Instance.new("Frame")
    track.Name, track.Position, track.Size = name, UDim2.fromOffset(x,y), UDim2.fromOffset(w,h)
    track.BackgroundColor3, track.BorderSizePixel, track.Active, track.Parent = Theme.Slate, 0, false, parent
    local fill = Instance.new("Frame")
    fill.Name, fill.Size, fill.BackgroundColor3 = "Fill", UDim2.fromScale(0,1), color
    fill.BorderSizePixel, fill.Active, fill.Parent = 0, false, track
    for _, frame in ipairs({track,fill}) do
        local c=Instance.new("UICorner"); c.CornerRadius, c.Parent=UDim.new(0,3),frame
    end
    return fill
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
    self.stats.TextYAlignment = Enum.TextYAlignment.Top
    self.stats.TextSize = 15
    self.hpBar = bar(self.stats, "HPBar", 10,27,198,11, Theme.Green)
    self.shieldBar = bar(self.stats, "ShieldBar", 10,43,198,8, Theme.Cyan)
    stroke(self.stats, Theme.Green)
    stroke(self.top, Theme.Cyan, 2)
    self.evo = label(canvas, "Evolution", UDim2.fromOffset(22, 80), UDim2.fromOffset(218, 43), "EVOLUTION 0", 13)
    self.evo.BackgroundColor3, self.evo.TextColor3 = Theme.Paper, Theme.Ink
    self.evo.RichText = true
    self.top.BackgroundColor3, self.top.TextColor3 = Theme.Paper, Theme.Ink
    self.draft = Instance.new("Frame")
    self.draft.Name, self.draft.Position, self.draft.Size = "EvolutionDraft", UDim2.fromOffset(16, 132), UDim2.fromOffset(600, 177)
    self.draft.BackgroundColor3, self.draft.BackgroundTransparency, self.draft.BorderSizePixel = Theme.Ink, 0.04, 0
    self.draft.ZIndex, self.draft.Active, self.draft.Selectable = 20, false, false
    self.draft.Visible, self.draft.Parent = false, canvas
    local draftCorner = Instance.new("UICorner"); draftCorner.CornerRadius, draftCorner.Parent = UDim.new(0, 14), self.draft
    self.draftTitle = label(self.draft, "DraftTitle", UDim2.fromOffset(10, 4), UDim2.fromOffset(440, 28), "EVOLUTION READY · 3つから1つ選べ", 16)
    self.draftTitle.BackgroundTransparency = 1
    self.draftTitle.ZIndex = 21
    self.draftTimer = label(self.draft, "DraftTimer", UDim2.fromOffset(505, 4), UDim2.fromOffset(80, 28), "5秒", 15)
    self.draftTimer.BackgroundTransparency = 1
    self.draftTimer.ZIndex = 21
    self.draftCards, self.cardStrokes = {}, {}
    for i = 1, 3 do
        local card = Instance.new("TextButton")
        card.Name, card.Position, card.Size = "Choice" .. i, UDim2.fromOffset(10 + (i - 1) * 195, 38), UDim2.fromOffset(190, 127)
        card.BackgroundColor3, card.TextColor3, card.TextSize = Theme.Paper, Theme.Ink, 16
        card.BorderSizePixel, card.Font, card.TextWrapped, card.Parent = 0, Enum.Font.GothamBold, true, self.draft
        card.ZIndex, card.AutoButtonColor = 22, true
        local corner = Instance.new("UICorner"); corner.CornerRadius, corner.Parent = UDim.new(0, 11), card
        card.RichText = true
        self.cardStrokes[i] = stroke(card, Theme.Cyan, 2)
        local strip = Instance.new("Frame")
        strip.Name, strip.Position, strip.Size = "CategoryStrip", UDim2.fromOffset(8,4), UDim2.new(1,-16,0,4)
        strip.BorderSizePixel, strip.Active, strip.ZIndex = 0, false, 23
        strip.BackgroundColor3, strip.Parent = Theme.Cyan, card
        card.Activated:Connect(function()
            if self.onEvolutionPick and self.currentDraft and self.submittedDraftId ~= self.currentDraft.id then
                local sent = self.onEvolutionPick(self.currentDraft.id, i)
                if sent then
                    self.submittedDraftId, self.submittedChoice = self.currentDraft.id, i
                    for _, choice in ipairs(self.draftCards) do choice.Active, choice.AutoButtonColor = false, false end
                    self:updateDraftCards()
                    if self.pickTween then self.pickTween:Cancel() end
                    local outline = self.cardStrokes[i]
                    outline.Thickness = 4
                    self.pickTween = TweenService:Create(outline, TweenInfo.new(0.3), {Thickness=2})
                    self.pickTween:Play()
                end
            end
        end)
        self.draftCards[i] = card
    end
    self.ammo = label(canvas, "Ammo", UDim2.fromOffset(328, 371), UDim2.fromOffset(244, 40), "武器を拾おう", 16)
    self.ammo.RichText = true
    stroke(self.ammo, Theme.Gold)
    self.energy = label(canvas, "Energy", UDim2.fromOffset(630, 95), UDim2.fromOffset(242, 30), "BUILD ENERGY 60", 13)
    self.energy.TextYAlignment = Enum.TextYAlignment.Top
    self.energyBar = bar(self.energy, "EnergyBar", 10,22,222,6, Theme.Gold)
    self.energy.TextColor3 = Theme.Gold
    self.notice = label(canvas, "Notice", UDim2.fromOffset(250, 88), UDim2.fromOffset(370, 36), "", 17)
    self.notice.Visible = false
    stroke(self.notice, Theme.Gold)
    self.notice.BackgroundColor3, self.notice.TextColor3 = Theme.Gold, Theme.Ink
    self.crosshair = label(canvas, "Crosshair", UDim2.fromOffset(435, 225), UDim2.fromOffset(30, 30), "+", 28)
    self.crosshair.BackgroundTransparency = 1
    -- Keep the aim anchor unchanged, but never draw the reticle over card text.
    self.crosshair.ZIndex = 10
    self.hitMarker = label(canvas, "HitMarker", UDim2.fromOffset(420, 210), UDim2.fromOffset(60, 60), "×", 42)
    self.hitMarker.BackgroundTransparency, self.hitMarker.Visible, self.hitMarker.ZIndex = 1, false, 11
    self.hitMarker.TextColor3 = Theme.Orange
    self.hitMarker.TextStrokeTransparency = .15
    self.result = label(canvas, "Result", UDim2.fromOffset(265, 150), UDim2.fromOffset(370, 205), "", 22)
    self.result.Visible, self.result.RichText = false, true
    self.resultStroke = stroke(self.result, Theme.Gold, 3)
    self.hint = label(canvas, "Hint", UDim2.fromOffset(260, 340), UDim2.fromOffset(380, 28), "近づくと自動取得 / Eで取得", 13)
    self.mini = Instance.new("Frame")
    self.mini.Name, self.mini.Position, self.mini.Size = "Minimap", UDim2.fromOffset(750, 10), UDim2.fromOffset(122, 78)
    self.mini.BackgroundColor3, self.mini.BorderSizePixel, self.mini.Parent = Theme.Ink, 0, canvas
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
        local category = option and option.category or "Utility"
        local accent = Theme.Category[category] or Theme.Purple
        local status = submitted and (i == self.submittedChoice and "送信中…" or "選択待ち") or "EVOLVE  ›"
        local text = option and string.format('<font size="14">%s</font>\n<font size="20"><b>%s %s</b></font>\n<font size="16">%s</font>\n<font size="14"><b>%s</b></font>',
            string.upper(category), string.upper(option.name), option.rankText, option.description, status) or "—"
        card.Text = text
        card.BackgroundColor3 = submitted and (i == self.submittedChoice and Color3.fromRGB(188,242,199) or Color3.fromRGB(202,211,213)) or Theme.Paper
        card.TextTransparency = submitted and (i == self.submittedChoice and 0 or 0.28) or 0
        if self.cardStrokes then
            self.cardStrokes[i].Color = accent
            card.CategoryStrip.BackgroundColor3 = accent
        end
        card.Active, card.AutoButtonColor = not submitted, not submitted
    end
end
function Hud:button(name, text, x, y, width, height, callback)
    local b = Instance.new("TextButton")
    b.Name, b.Text, b.Position, b.Size = name, text, UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
    b.BackgroundColor3, b.TextColor3, b.TextSize = Theme.Ink, white, 17
    b.TextWrapped = true
    stroke(b, name == "Fire" and Theme.Orange or Theme.Cyan)
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
function Hud:eliminated()
    self:toast("ELIMINATED  ·  撃破して進化")
    self.eliminationUntil = os.clock() + .6
    if self.eliminationTween then self.eliminationTween:Cancel() end
    self.notice.BackgroundColor3 = Theme.Paper
    self.eliminationTween = TweenService:Create(self.notice, TweenInfo.new(.25), {BackgroundColor3=Theme.Gold})
    self.eliminationTween:Play()
end
function Hud:update(s, onEvolutionPick)
    if self.roundId ~= s.roundId then
        self.roundId = s.roundId
        self.submittedDraftId, self.submittedChoice, self.previousMe = nil, nil, nil
        self.guideUntil, self.eliminationUntil, self.reserveGainUntil = nil, nil, nil
        if self.eliminationTween then self.eliminationTween:Cancel(); self.eliminationTween = nil end
        self.notice.BackgroundColor3 = Theme.Gold
        if self.pickTween then self.pickTween:Cancel(); self.pickTween = nil end
        if self.damageTween then self.damageTween:Cancel(); self.damageTween = nil end
        self.stats.BackgroundColor3 = Theme.Ink
        for _, outline in ipairs(self.cardStrokes) do outline.Thickness = 2 end
    end
    local me = s.me
    local active = s.phase == "Active" or s.phase == "FinalZone"
    local playing = active and me and me.alive
    if playing and not self.guideUntil then self.guideUntil = os.clock() + 9 end
    local previous = self.previousMe
    if playing and previous and previous.alive then
        if me.hp + me.shield < previous.hp + previous.shield then
            self.stats.BackgroundColor3 = Color3.fromRGB(145, 45, 42)
            if self.damageTween then self.damageTween:Cancel() end
            self.damageTween = TweenService:Create(self.stats, TweenInfo.new(0.35), {BackgroundColor3=Theme.Ink})
            self.damageTween:Play()
        end
        if me.kills > previous.kills and os.clock() >= (self.eliminationUntil or 0) then self:eliminated()
        elseif me.evolutions > previous.evolutions then self:toast("EVOLVED  ·  EVOLUTION " .. me.evolutions) end
    end
    if not playing or not previous or me.weapon ~= previous.weapon or me.slot ~= previous.slot then
        self.reserveGainUntil = nil
    end
    if playing and previous and me.weapon == previous.weapon and me.slot == previous.slot
        and me.reserve > previous.reserve then
        self.reserveGain, self.reserveGainUntil = me.reserve-previous.reserve, os.clock()+1.5
    end
    self.previousMe = me
    local names = {Waiting = "参加待ち", Intermission = "次の試合まで", Starting = "降下準備中", Active = "生存者", FinalZone = "FINAL ZONE", Results = "RESULTS", Resetting = "リセット中"}
    self.top.Text = (names[s.phase] or s.phase) .. (active and ("  " .. s.alive .. "人   KILL " .. (me and me.kills or 0)) or ("  " .. s.remaining .. "秒"))
    local z = s.zone
    self.zone.Text = active and string.format("ZONE %d  %s %d秒  半径%d → %d", z.phase, z.shrinking and "縮小中" or "縮小まで", z.remaining, math.floor(z.radius), z.nextRadius) or "撃破して進化。最後の1人になれ。"
    self.stats.Text = me and string.format("HP %d/%d   ◇ %d", me.hp, me.maxHp, me.shield) or "DROPZONE\n次のラウンドを待っています"
    self.hpBar.Size = UDim2.fromScale(me and math.clamp(me.hp / math.max(1,me.maxHp),0,1) or 0,1)
    self.shieldBar.Size = UDim2.fromScale(me and math.clamp(me.shield / 100,0,1) or 0,1)
    self.energyBar.Size = UDim2.fromScale(me and math.clamp(me.energy / math.max(1,me.maxEnergy),0,1) or 0,1)
    local build = {}
    for _, ability in ipairs(me and me.evolutionBuild or {}) do
        if #build < 3 then table.insert(build, ability.name .. " " .. ability.rankText) end
    end
    local buildText = table.concat(build, " · ")
    -- One prominent ability on the compact HUD; the result retains the three-item build.
    self.evo.Text = me and string.format('<font size="17"><b>EVOLUTION %d</b></font>\n%s', me.evolutions, build[1] or "撃破で能力獲得") or "EVOLUTION 0"
    self.energy.Text = "BUILD ENERGY " .. (me and me.energy or 0)
    local equippedStats = me and me.weapon and WeaponStats.get(me.weapon, me.rarity or "Common") or nil
    local reserveGain = os.clock() < (self.reserveGainUntil or 0) and (" (+" .. self.reserveGain .. ")") or ""
    self.ammo.Text = equippedStats and string.format('<font size="12">%s%s</font>\n<font size="20"><b>%d / %d</b></font>  <font size="14">予備 %d%s</font>',
        string.upper(me.weapon) .. " · " .. (me.rarity or "Common"), me.reloading and " 装填中" or "",
        me.ammo, equippedStats.magazine, me.reserve, reserveGain) or "光る武器に近づいて拾おう"
    self.ammo.TextColor3 = me and me.weapon and WeaponStats.rarities[me.rarity or "Common"].color or white
    self.crosshair.Visible, self.hint.Visible = not not playing, not not playing
    self.hint.Text = playing and os.clock() < (self.guideUntil or 0)
        and "1 / 2 / 3で武器切替 · 下のSlotをクリック / タップ" or "1 / 2 / 3で武器切替 · 右クリック長押しでAim"
    if playing and z.shrinking then self.hint.Text = "ZONE SHRINKING · 安全地帯へ移動" end
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
        if self.pickTween then self.pickTween:Cancel(); self.pickTween = nil end
        for _, outline in ipairs(self.cardStrokes) do outline.Thickness = 2 end
        for _, card in ipairs(self.draftCards) do card.Active, card.AutoButtonColor, card.TextTransparency = true, true, 0 end
    end
    if self.noticeUntil and os.clock() > self.noticeUntil then self.notice.Visible = false end
    for name, button in pairs(self.buttons) do
        if name == "Spectate" then button.Visible = active and not playing
        else button.Visible = not not playing end
    end
    local crouchButton, sprintButton = self.buttons.Crouch, self.buttons.Sprint
    if crouchButton then
        local cooldown = me and me.slideCooldown or 0
        crouchButton.Text = me and me.sliding and "滑走中" or me and me.crouching and "立つ"
            or me and me.sprinting and (cooldown > 0.05 and string.format("スライド %.1f",cooldown) or "スライド") or "しゃがみ"
        crouchButton.BackgroundColor3 = me and (me.crouching or me.sliding) and Theme.Blue or Theme.Ink
    end
    if sprintButton then
        sprintButton.Text = me and me.sprinting and "走行中" or "走る"
        sprintButton.BackgroundColor3 = me and me.sprinting and Theme.Blue or Theme.Ink
    end
    for i = 1, 3 do
        local b = self.buttons["Slot" .. i]
        if b then
            local rarity = me and me.slotRarities and me.slotRarities[i]
            local tier = WeaponStats.rarities[rarity or "Common"]
            local owned = me and me.slots[i]
            local selected = owned and me.slot == i
            b.TextColor3 = selected and Theme.Paper or owned and tier.color or Theme.Slate
            b.TextSize = 14
            b.Active, b.AutoButtonColor = not not (playing and owned), not not (playing and owned)
            local outline = b:FindFirstChild("UIStroke")
            if outline then outline.Thickness, outline.Color = selected and 3 or 1, selected and Theme.Gold or owned and tier.color or Theme.Slate end
            b.Text = (selected and "▶ " or "") .. tostring(i) .. " " .. (owned and string.upper(owned) or "空") .. (rarity and (" [" .. tier.short .. "]") or "")
            b.BackgroundColor3 = selected and Theme.Blue or Theme.Ink
        end
    end
    self.result.Visible = s.phase == "Results" or (active and me ~= nil and not me.alive)
    if self.result.Visible then
        local title = s.phase == "Results" and (s.winner and me and me.rank == 1 and "#1 VICTORY" or (s.winner and "WINNER: " .. s.winner or "DRAW")) or "ELIMINATED"
        local heading = title == "#1 VICTORY" and '<font size="38"><b>#1  VICTORY</b></font>' or escapeRichText(title)
        self.result.Text = heading .. (me and string.format("\n\n順位 #%d   KILL %d\nDAMAGE %d   生存 %d秒\nEVOLUTION %d", me.rank or s.alive + 1, me.kills, me.damage, me.survival, me.evolutions) or "\n次の試合から参加できます")
        if not active then
            self.result.Text = self.result.Text .. "\n" .. buildText
            self.result.TextColor3 = title == "#1 VICTORY" and Color3.fromRGB(255,220,100) or white
        else self.result.TextColor3 = white end
        -- Compact death card leaves the spectator view clear.
        self.result.Position = active and UDim2.fromOffset(275, 150) or UDim2.fromOffset(265, 150)
        self.result.Size = active and UDim2.fromOffset(350, 115) or UDim2.fromOffset(370, 205)
        self.result.TextSize = active and 15 or 19
    end
    local function mapPosition(p) return UDim2.fromOffset(61 + p.X / 720 * 78, 39 + p.Z / 720 * 78) end
    for _, pair in ipairs({{self.currentCircle, z.center, z.radius}, {self.nextCircle, z.nextCenter, z.nextRadius}}) do
        pair[1].Position = mapPosition(pair[2])
        -- Fixed stud-to-pixel scale keeps circles circular on this rectangular panel.
        pair[1].Size = UDim2.fromOffset(pair[3] / 360 * 78, pair[3] / 360 * 78)
    end
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        self.dot.Position = mapPosition(root.Position)
        local delta = root.Position - z.center
        if playing and math.sqrt(delta.X*delta.X + delta.Z*delta.Z) >= z.radius - 12 then
            self.hint.Text = "危険！ 安全地帯の内側へ移動"
            self.hint.TextColor3 = Color3.fromRGB(255, 180, 90)
        else self.hint.TextColor3 = white end
    end
end
return Hud
