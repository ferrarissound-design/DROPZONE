-- Local-only camera visibility. Replicated armor remains visible to observers.
local Visibility = {}
Visibility.__index = Visibility
function Visibility.new()
    return setmetatable({parts={}}, Visibility)
end
function Visibility:clear()
    if self.connection then self.connection:Disconnect() end
    self.connection, self.character = nil, nil
    for part, record in pairs(self.parts) do
        if part.Parent and record.restoreModifier ~= nil then
            part.LocalTransparencyModifier = record.restoreModifier
        end
    end
    self.parts = {}
end
function Visibility:bind(character)
    if self.character == character then return end
    self:clear()
    self.character = character
    if not character then return end
    local function track(item)
        if item:IsA("BasePart") and item:GetAttribute("DropzoneEvolutionAdornment") == true then
            self.parts[item] = {}
        end
    end
    for _, item in ipairs(character:GetDescendants()) do track(item) end
    -- Cosmetics set the marker BEFORE parenting, so newly replicated parts are
    -- hidden during the same AIM even if they arrive after the Snapshot.
    self.connection = character.DescendantAdded:Connect(track)
end
function Visibility:step(aiming)
    for part, record in pairs(self.parts) do
        if not part.Parent then
            self.parts[part] = nil
        elseif aiming then
            -- Capture at AIM entry, not bind time: the camera may already have
            -- hidden this part for first-person since we registered it.
            if record.restoreModifier == nil then
                record.restoreModifier = part.LocalTransparencyModifier
            end
            part.LocalTransparencyModifier = 1
        elseif record.restoreModifier ~= nil then
            -- Restore once, then relinquish ownership. Normal camera updates
            -- must retain their first-person/occlusion transparency each frame.
            part.LocalTransparencyModifier = record.restoreModifier
            record.restoreModifier = nil
        end
    end
end
return Visibility
