local addonName, addon = ...

addon.SOUND_OPTIONS = {
    { value = "RAID_WARNING", label = "Raid Warning" },
    { value = "ALARM_CLOCK_WARNING_3", label = "Alarm Clock" },
    { value = "READY_CHECK", label = "Ready Check" },
    { value = "MAP_PING", label = "Map Ping" },
    { value = "IG_PLAYER_INVITE", label = "Invite" },
}

local LEGACY_SOUND_ALIASES = {
    RaidWarning = "RAID_WARNING",
    AlarmClockWarning3 = "ALARM_CLOCK_WARNING_3",
    ReadyCheck = "READY_CHECK",
    MapPing = "MAP_PING",
    IgPlayerInvite = "IG_PLAYER_INVITE",
}

function addon:NormalizeSoundKey(soundKey)
    if not soundKey or soundKey == "" then
        return "RAID_WARNING"
    end

    if LEGACY_SOUND_ALIASES[soundKey] then
        return LEGACY_SOUND_ALIASES[soundKey]
    end

    return soundKey
end

function addon:GetSoundKitID(soundKey)
    local normalized = self:NormalizeSoundKey(soundKey)
    if SOUNDKIT and SOUNDKIT[normalized] then
        return SOUNDKIT[normalized]
    end
    return nil
end

function addon:PlayAlertSound(soundKey)
    local kitID = self:GetSoundKitID(soundKey)
    if not kitID then
        return false
    end

    PlaySound(kitID, "Master")
    return true
end

function addon:PreviewAlertSound(soundKey)
    return self:PlayAlertSound(soundKey)
end

local function FirstUsableFrame(...)
    for index = 1, select("#", ...) do
        local frame = select(index, ...)
        if frame and frame.IsObjectType and frame:IsObjectType("Frame") then
            return frame
        end
    end
    return nil
end

local ATTACH_FRAME_RESOLVERS = {
    PlayerFrame = function()
        return FirstUsableFrame(_G.PlayerFrame)
    end,
    PlayerFrameHealthBar = function()
        return FirstUsableFrame(
            _G.PlayerFrameHealthBar,
            _G.PlayerFrame and _G.PlayerFrame.healthbar,
            _G.PlayerFrame and _G.PlayerFrame.HealthBarContainer,
            _G.PlayerFrame and _G.PlayerFrame.Content and _G.PlayerFrame.Content.MainStatusBar
        )
    end,
    TargetFrame = function()
        return FirstUsableFrame(_G.TargetFrame)
    end,
    TargetFrameHealthBar = function()
        return FirstUsableFrame(
            _G.TargetFrameHealthBar,
            _G.TargetFrame and _G.TargetFrame.healthbar,
            _G.TargetFrame and _G.TargetFrame.HealthBarContainer,
            _G.TargetFrame and _G.TargetFrame.Content and _G.TargetFrame.Content.MainStatusBar
        )
    end,
    FocusFrame = function()
        return FirstUsableFrame(_G.FocusFrame)
    end,
    FocusFrameHealthBar = function()
        return FirstUsableFrame(
            _G.FocusFrameHealthBar,
            _G.FocusFrame and _G.FocusFrame.healthbar,
            _G.FocusFrame and _G.FocusFrame.HealthBarContainer,
            _G.FocusFrame and _G.FocusFrame.Content and _G.FocusFrame.Content.MainStatusBar
        )
    end,
    PetFrame = function()
        return FirstUsableFrame(_G.PetFrame)
    end,
}

function addon:GetAttachFrame(frameName)
    if not frameName or frameName == "" or frameName == "UIParent" then
        return UIParent
    end

    local resolver = ATTACH_FRAME_RESOLVERS[frameName]
    if resolver then
        local frame = resolver()
        if frame and frame.IsObjectType and frame:IsObjectType("Frame") then
            return frame
        end
    end

    local frame = _G[frameName]
    if frame and frame.IsObjectType and frame:IsObjectType("Frame") then
        return frame
    end

    return UIParent
end

function addon:IsInEditMode()
    if self.editModeActive then
        return true
    end

    if not LibStub then
        return false
    end

    local libEditMode = LibStub("LibEditMode", true)
    return libEditMode and libEditMode.IsInEditMode and libEditMode:IsInEditMode()
end

function addon:GetLibEditMode()
    if not LibStub then
        return nil
    end
    return LibStub("LibEditMode", true)
end

function addon:UpdateBarDragState()
    local frame = self.bar
    if not frame then
        return
    end

    local appearance = self.db.appearance
    local locked = appearance.locked
    local attached = (appearance.attachFrame or "UIParent") ~= "UIParent"
    local inEditMode = self:IsInEditMode()
    local allowManualDrag = not locked and not attached and not inEditMode

    frame:SetMovable(allowManualDrag)
    if allowManualDrag then
        frame:RegisterForDrag("LeftButton")
    else
        frame:RegisterForDrag()
    end

    frame:EnableMouse(inEditMode or not locked)
end

function addon:ApplyBarPosition()
    local frame = self.bar
    if not frame then
        return
    end

    local appearance = self.db.appearance
    local attachName = appearance.attachFrame or "UIParent"
    local anchorFrame = self:GetAttachFrame(attachName)
    local point = appearance.point or "CENTER"
    local relativePoint = appearance.relativePoint or point
    local offsetX = appearance.x or 0
    local offsetY = appearance.y or 0

    -- Keep the bar on UIParent and anchor via SetPoint. Parenting to Blizzard
    -- unit frames can produce large unexpected offsets with Edit Mode frames.
    frame:SetParent(UIParent)
    frame:ClearAllPoints()

    if attachName == "UIParent" then
        frame:SetPoint(point, UIParent, relativePoint, offsetX, offsetY)
    else
        frame:SetPoint(point, anchorFrame, relativePoint, offsetX, offsetY)
    end

    self:UpdateBarDragState()
end

function addon:SetBarPosition(x, y, point, relativePoint)
    local appearance = self.db.appearance
    appearance.x = x
    appearance.y = y
    if point then
        appearance.point = point
    end
    if relativePoint then
        appearance.relativePoint = relativePoint
    end
    self:ApplyBarPosition()
end

function addon:NormalizeBreakpointList(values)
    if type(values) ~= "table" then
        return {}
    end

    local seen = {}
    local normalized = {}

    for index = 1, #values do
        local number = tonumber(values[index])
        if number and number > 0 then
            number = math.floor(number + 0.5)
            if not seen[number] then
                seen[number] = true
                normalized[#normalized + 1] = number
            end
        end
    end

    table.sort(normalized)
    return normalized
end

function addon:IsArrayTable(value)
    if type(value) ~= "table" then
        return false
    end

    local length = 0
    for key in pairs(value) do
        if type(key) ~= "number" then
            return false
        end
        length = length + 1
    end

    return length > 0
end

addon.ATTACH_FRAME_OPTIONS = {
    { value = "UIParent", label = "Screen (free position)" },
    { value = "PlayerFrame", label = "Player Frame" },
    { value = "PlayerFrameHealthBar", label = "Player Health Bar" },
    { value = "TargetFrame", label = "Target Frame" },
    { value = "TargetFrameHealthBar", label = "Target Health Bar" },
    { value = "FocusFrame", label = "Focus Frame" },
    { value = "FocusFrameHealthBar", label = "Focus Health Bar" },
    { value = "PetFrame", label = "Pet Frame" },
}

function addon:ResetAttachOffsets()
    local appearance = self.db.appearance
    appearance.x = 0
    appearance.y = 0
    appearance.point = "CENTER"
    appearance.relativePoint = "CENTER"
end

function addon:SetAttachFrame(frameName)
    local appearance = self.db.appearance
    appearance.attachFrame = frameName or "UIParent"

    if appearance.attachFrame ~= "UIParent" then
        self:ResetAttachOffsets()
    end

    self:ApplyBarPosition()
end

addon.ANCHOR_POINT_OPTIONS = {
    { value = "CENTER", label = "Center" },
    { value = "TOP", label = "Top" },
    { value = "BOTTOM", label = "Bottom" },
    { value = "LEFT", label = "Left" },
    { value = "RIGHT", label = "Right" },
    { value = "TOPLEFT", label = "Top Left" },
    { value = "TOPRIGHT", label = "Top Right" },
    { value = "BOTTOMLEFT", label = "Bottom Left" },
    { value = "BOTTOMRIGHT", label = "Bottom Right" },
}

addon.WIDTH_MODE_OPTIONS = {
    { value = "Manual", label = "Manual" },
    { value = "Sync With Essential Cooldowns", label = "Sync With Essential Cooldowns" },
}

function addon:IsManualBarWidth()
    return (self.db.appearance.widthMode or "Manual") == "Manual"
end

function addon:GetEssentialCooldownViewerWidth()
    local viewer = _G.EssentialCooldownViewer
    if viewer and viewer.IsShown and viewer:IsShown() then
        local width = viewer:GetWidth()
        if width and width > 0 then
            return width
        end
    end
    return nil
end

function addon:GetEffectiveBarWidth()
    local appearance = self.db.appearance
    local widthMode = appearance.widthMode or "Manual"

    if widthMode == "Sync With Essential Cooldowns" then
        local syncedWidth = self:GetEssentialCooldownViewerWidth()
        if syncedWidth then
            local minWidth = appearance.minWidth or 0
            if minWidth > 0 then
                syncedWidth = math.max(syncedWidth, minWidth)
            end
            return math.floor(syncedWidth + 0.5)
        end
    end

    return appearance.width or self.defaults.appearance.width
end

function addon:ApplyEffectiveBarSize()
    if not self.bar then
        return
    end

    local width = self:GetEffectiveBarWidth()
    local height = self.db.appearance.height or self.defaults.appearance.height
    self.bar:SetSize(width, height)
end

function addon:InitEssentialCooldownWidthHook()
    if self.essentialCooldownWidthHooked then
        return
    end

    local viewer = _G.EssentialCooldownViewer
    if not viewer then
        return
    end

    local function RefreshSyncedWidth()
        if (addon.db.appearance.widthMode or "Manual") ~= "Sync With Essential Cooldowns" then
            return
        end

        addon:ApplyEffectiveBarSize()
        addon:Update(true)
    end

    hooksecurefunc(viewer, "SetSize", RefreshSyncedWidth)
    hooksecurefunc(viewer, "SetWidth", RefreshSyncedWidth)
    hooksecurefunc(viewer, "Show", RefreshSyncedWidth)
    hooksecurefunc(viewer, "Hide", RefreshSyncedWidth)

    self.essentialCooldownWidthHooked = true
end
