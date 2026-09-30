local Theme = require(game.ReplicatedStorage.DropzoneShared.VisualTheme)
local DamageFeedback = {}
DamageFeedback.__index = DamageFeedback
DamageFeedback.limit = 8
function DamageFeedback.new(parent)
    local self = setmetatable({slots={}, cursor=0}, DamageFeedback)
    for i=1,DamageFeedback.limit do
        local anchor = Instance.new("Part")
        anchor.Name, anchor.Size, anchor.Transparency = "DamageAnchor", Vector3.new(.1,.1,.1), 1
        anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
        anchor.CastShadow, anchor.Parent = false, parent
        local gui = Instance.new("BillboardGui")
        gui.Size, gui.MaxDistance, gui.Enabled, gui.Parent = UDim2.fromOffset(155,52), 280, false, anchor
        -- These are short, server-confirmed numbers, not persistent enemy tracking.
        gui.AlwaysOnTop, gui.LightInfluence = true, 0
        local function line(y, color)
            local label = Instance.new("TextLabel")
            label.Position, label.Size = UDim2.fromOffset(0,y), UDim2.fromOffset(155,25)
            label.BackgroundTransparency, label.TextColor3, label.TextStrokeTransparency = 1, color, .2
            label.TextSize, label.Font, label.Parent = 21, Enum.Font.GothamBold, gui
            return label
        end
        self.slots[i] = {anchor=anchor, gui=gui, hp=line(25,Theme.Gold), shield=line(0,Theme.Cyan), expires=0}
    end
    return self
end
function DamageFeedback:show(records, now)
    for _, damage in ipairs(records) do
        if damage.hp + damage.shield > 0 then
            self.cursor = self.cursor % DamageFeedback.limit + 1
            local slot = self.slots[self.cursor]
            slot.anchor.Position = damage.position
            slot.hp.Text = damage.hp > 0 and ("HP −" .. math.ceil(damage.hp)) or ""
            slot.shield.Text = damage.shield > 0 and ("◇ −" .. math.ceil(damage.shield)) or ""
            slot.hp.TextTransparency, slot.shield.TextTransparency = 0, 0
            slot.offset = (self.cursor%3-1)*.35
            slot.gui.StudsOffsetWorldSpace = Vector3.new(slot.offset,3.8,0)
            slot.gui.Enabled, slot.expires = true, now + .65
        end
    end
end
function DamageFeedback:step(now)
    for _, slot in ipairs(self.slots) do
        if slot.gui.Enabled then
            local remaining = slot.expires - now
            if remaining <= 0 then slot.gui.Enabled = false
            else
                local alpha = 1 - remaining/.65
                slot.hp.TextTransparency, slot.shield.TextTransparency = alpha*.8, alpha*.8
                slot.gui.StudsOffsetWorldSpace = Vector3.new(slot.offset,3.8+alpha,0)
            end
        end
    end
end
function DamageFeedback:clear()
    self.cursor = 0
    for _, slot in ipairs(self.slots) do slot.gui.Enabled, slot.expires = false, 0 end
end
return DamageFeedback
