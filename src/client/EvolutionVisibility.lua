-- Local-only camera visibility. Replicated armor remains visible to observers.
local Visibility = {}
Visibility.__index = Visibility
function Visibility.new()
    return setmetatable({parts={}}, Visibility)
end
function Visibility:clear()
    if self.connection then self.connection:Disconnect() end
    self.connection, self.character = nil, nil
    for part, original in pairs(self.parts) do
        if part.Parent then part.LocalTransparencyModifier = original end
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
            self.parts[item] = item.LocalTransparencyModifier
        end
    end
    for _, item in ipairs(character:GetDescendants()) do track(item) end
    -- Cosmetics set the marker BEFORE parenting, so newly replicated parts are
    -- hidden during the same AIM even if they arrive after the Snapshot.
    self.connection = character.DescendantAdded:Connect(track)
end
function Visibility:step(aiming)
    for part, original in pairs(self.parts) do
        if part.Parent then part.LocalTransparencyModifier = aiming and 1 or original
        else self.parts[part] = nil end
    end
end
return Visibility
