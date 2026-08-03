-------------------------------------------------------------------------------
-- Enhanced Stagger (local EllesmereUI Resource Bars integration)
-- Opt-in Brewmaster stagger enhancements hosted on ERB_SecondaryBar.
-- Default OFF. Zero cost when disabled / not Brewmaster.
--
-- Model: breakpointCount (1-4) evenly divides Scale Maximum into zones.
-- Example at scale 400 with 3 breakpoints -> lines at 100 / 200 / 300,
-- and 4 fill-color zones. Five zone colors are always stored; unused
-- higher zones apply when the user raises breakpointCount.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local ES = {}
ns.EnhancedStagger = ES

local MAX_BREAKPOINT_LINES = 4
local MAX_ZONES = 5
local BREWMASTER_SPEC_ID = 268
local UPDATE_INTERVAL = 0.1

local DEFAULT_ZONE_COLORS = {
    { 0.1, 0.8, 0.1, 1 },
    { 0.9, 0.9, 0.1, 1 },
    { 1.0, 0.5, 0.0, 1 },
    { 1.0, 0.0, 0.0, 1 },
    { 0.75, 0.0, 0.15, 1 },
}

local function DeepCopy(source)
    if type(source) ~= "table" then
        return source
    end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = DeepCopy(value)
    end
    return copy
end

local function CopyColor(color, fallback)
    color = color or fallback or { 1, 1, 1, 1 }
    return { color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 }
end

local function DefaultZoneColors()
    local colors = {}
    for index = 1, MAX_ZONES do
        colors[index] = CopyColor(DEFAULT_ZONE_COLORS[index])
    end
    return colors
end

local DEFAULT_SETTINGS = {
    scaleMaximum = 400,
    breakpointCount = 3,
    breakpointsEnabled = true,
    lineColor = { 1, 1, 1, 0.6 },
    lineThickness = 1,
    soundEnabled = false,
    soundThreshold = 400,
    soundCooldownSeconds = 10,
    soundFile = "RAID_WARNING",
    testMode = false,
    testStaggerPercent = 200,
}

local SOUND_KEYS = {
    RAID_WARNING = true,
    ALARM_CLOCK_WARNING_3 = true,
    READY_CHECK = true,
    MAP_PING = true,
    IG_PLAYER_INVITE = true,
}

local lastSoundTime = 0
local elapsedSinceUpdate = 0
local tickFrame = nil

local function ClampBreakpointCount(value)
    value = math.floor((tonumber(value) or 3) + 0.5)
    if value < 1 then
        return 1
    end
    if value > MAX_BREAKPOINT_LINES then
        return MAX_BREAKPOINT_LINES
    end
    return value
end

local function NormalizeZoneColors(colors)
    local result = DefaultZoneColors()
    if type(colors) ~= "table" then
        return result
    end
    for index = 1, MAX_ZONES do
        if type(colors[index]) == "table" then
            result[index] = CopyColor(colors[index], DEFAULT_ZONE_COLORS[index])
        end
    end
    return result
end

-- Migrate legacy rule-based settings into zone colors + breakpoint count.
local function MigrateLegacySettings(settings)
    if type(settings) ~= "table" then
        return
    end
    if type(settings.zoneColors) == "table" and #settings.zoneColors > 0 then
        return
    end
    if type(settings.rules) ~= "table" or #settings.rules == 0 then
        settings.zoneColors = DefaultZoneColors()
        settings.rules = nil
        return
    end

    local legacy = {}
    for index = 1, #settings.rules do
        local rule = settings.rules[index]
        if type(rule) == "table" then
            legacy[#legacy + 1] = {
                value = math.max(0, math.floor((tonumber(rule.value) or 0) + 0.5)),
                color = CopyColor(rule.color, DEFAULT_ZONE_COLORS[1]),
            }
        end
    end
    table.sort(legacy, function(a, b)
        return a.value < b.value
    end)

    local zoneColors = DefaultZoneColors()
    local lineCount = 0
    for index = 1, #legacy do
        if legacy[index].value > 0 then
            lineCount = lineCount + 1
        end
    end
    if lineCount < 1 then
        lineCount = 3
    elseif lineCount > MAX_BREAKPOINT_LINES then
        lineCount = MAX_BREAKPOINT_LINES
    end

    -- Map sorted legacy colors onto zones (including the 0% baseline rule).
    local colorIndex = 1
    for index = 1, #legacy do
        if colorIndex <= MAX_ZONES then
            zoneColors[colorIndex] = CopyColor(legacy[index].color, DEFAULT_ZONE_COLORS[colorIndex])
            colorIndex = colorIndex + 1
        end
    end

    settings.breakpointCount = lineCount
    settings.zoneColors = zoneColors
    settings.rules = nil
    settings.glowEnabled = nil
    settings.glowThreshold = nil
end

function ES.GetDefaults()
    local defaults = DeepCopy(DEFAULT_SETTINGS)
    defaults.zoneColors = DefaultZoneColors()
    return defaults
end

function ES.GetSecondary()
    local db = _G._ERB_AceDB
    if not db or not db.profile then
        return nil
    end
    return db.profile.secondary
end

function ES.EnsureProfile(sp)
    sp = sp or ES.GetSecondary()
    if not sp then
        return nil
    end
    if sp.enhancedStagger == nil then
        sp.enhancedStagger = false
    end
    if type(sp.enhancedStaggerSettings) ~= "table" then
        sp.enhancedStaggerSettings = ES.GetDefaults()
        return sp.enhancedStaggerSettings
    end

    local settings = sp.enhancedStaggerSettings
    MigrateLegacySettings(settings)

    for key, defaultValue in pairs(DEFAULT_SETTINGS) do
        if settings[key] == nil then
            settings[key] = DeepCopy(defaultValue)
        end
    end

    settings.breakpointCount = ClampBreakpointCount(settings.breakpointCount)
    settings.zoneColors = NormalizeZoneColors(settings.zoneColors)
    settings.glowEnabled = nil
    settings.glowThreshold = nil
    settings.rules = nil

    if type(settings.lineColor) ~= "table" then
        settings.lineColor = { 1, 1, 1, 0.6 }
    end
    return settings
end

function ES.GetSettings(sp)
    return ES.EnsureProfile(sp)
end

function ES.GetScaleMaximum(sp)
    local settings = ES.GetSettings(sp)
    local maximum = tonumber(settings and settings.scaleMaximum) or 400
    if maximum < 1 then
        maximum = 1
    end
    return maximum
end

function ES.GetBreakpointCount(sp)
    local settings = ES.GetSettings(sp)
    return ClampBreakpointCount(settings and settings.breakpointCount)
end

-- Evenly spaced absolute Stagger % values for the current scale/count.
function ES.GetBreakpointValues(sp)
    local scaleMaximum = ES.GetScaleMaximum(sp)
    local count = ES.GetBreakpointCount(sp)
    local values = {}
    for index = 1, count do
        values[index] = scaleMaximum * index / (count + 1)
    end
    return values
end

function ES.GetZoneCount(sp)
    return ES.GetBreakpointCount(sp) + 1
end

function ES.GetZoneRangeLabel(zoneIndex, sp)
    local scaleMaximum = ES.GetScaleMaximum(sp)
    local count = ES.GetBreakpointCount(sp)
    local zoneCount = count + 1
    zoneIndex = math.max(1, math.min(MAX_ZONES, math.floor(tonumber(zoneIndex) or 1)))

    local function RoundPct(value)
        return math.floor(value + 0.5)
    end

    if zoneIndex == 1 then
        local hi = RoundPct(scaleMaximum / (count + 1))
        return string.format("0%% – %d%%", hi)
    end
    if zoneIndex >= zoneCount then
        local lo = RoundPct(scaleMaximum * count / (count + 1))
        return string.format("%d%%+", lo)
    end
    local lo = RoundPct(scaleMaximum * (zoneIndex - 1) / (count + 1))
    local hi = RoundPct(scaleMaximum * zoneIndex / (count + 1))
    return string.format("%d%% – %d%%", lo, hi)
end

function ES.GetColorForStagger(staggerPercent, sp)
    local settings = ES.GetSettings(sp)
    local scaleMaximum = ES.GetScaleMaximum(sp)
    local count = ES.GetBreakpointCount(sp)
    local colors = NormalizeZoneColors(settings and settings.zoneColors)
    local zone = 1
    for index = 1, count do
        local threshold = scaleMaximum * index / (count + 1)
        if staggerPercent >= threshold then
            zone = index + 1
        end
    end
    local color = colors[zone] or colors[1]
    return color[1], color[2], color[3], color[4] or 1
end

function ES.SetZoneColor(zoneIndex, r, g, b, a)
    local settings = ES.GetSettings()
    if not settings then
        return false
    end
    zoneIndex = math.floor((tonumber(zoneIndex) or 0) + 0.5)
    if zoneIndex < 1 or zoneIndex > MAX_ZONES then
        return false
    end
    settings.zoneColors = NormalizeZoneColors(settings.zoneColors)
    settings.zoneColors[zoneIndex] = { r or 1, g or 1, b or 1, a or 1 }
    return true
end

function ES.GetZoneColor(zoneIndex)
    local settings = ES.GetSettings()
    local colors = NormalizeZoneColors(settings and settings.zoneColors)
    zoneIndex = math.max(1, math.min(MAX_ZONES, math.floor(tonumber(zoneIndex) or 1)))
    local color = colors[zoneIndex]
    return color[1], color[2], color[3], color[4] or 1
end

function ES.ResetZoneColors()
    local settings = ES.GetSettings()
    if not settings then
        return
    end
    settings.zoneColors = DefaultZoneColors()
end

local function PlayAlertSound(soundKey)
    if not soundKey or not SOUNDKIT then
        return false
    end
    if not SOUND_KEYS[soundKey] then
        soundKey = "RAID_WARNING"
    end
    local kitID = SOUNDKIT[soundKey]
    if not kitID then
        return false
    end
    PlaySound(kitID, "Master")
    return true
end

function ES.PreviewSound(soundKey)
    return PlayAlertSound(soundKey)
end

local function EnsureOverlay(bar)
    if not bar then
        return nil
    end
    if bar._esOverlay then
        local inner = bar._sb
        if inner then
            bar._esOverlay:SetFrameLevel(inner:GetFrameLevel() + 2)
        end
        return bar._esOverlay
    end

    local overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints(bar)
    local inner = bar._sb
    overlay:SetFrameLevel(((inner and inner:GetFrameLevel()) or (bar:GetFrameLevel() or 0)) + 2)

    overlay.lines = {}
    for index = 1, MAX_BREAKPOINT_LINES do
        local line = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
        line:SetColorTexture(1, 1, 1, 0.6)
        if line.SetSnapToPixelGrid then
            line:SetSnapToPixelGrid(false)
            line:SetTexelSnappingBias(0)
        end
        line:Hide()
        overlay.lines[index] = line
    end

    bar._esOverlay = overlay
    return overlay
end

local function HideOverlay(bar)
    if not bar or not bar._esOverlay then
        return
    end
    bar._esOverlay:Hide()
    for index = 1, MAX_BREAKPOINT_LINES do
        local line = bar._esOverlay.lines[index]
        if line then
            line:Hide()
        end
    end
end

local function UpdateBreakpointLines(bar, settings, scaleMaximum)
    local overlay = EnsureOverlay(bar)
    if not overlay then
        return
    end
    overlay:Show()

    local width = bar:GetWidth() or 0
    local height = bar:GetHeight() or 0
    if width <= 0 or height <= 0 or not settings.breakpointsEnabled then
        for index = 1, MAX_BREAKPOINT_LINES do
            overlay.lines[index]:Hide()
        end
        return
    end

    local PP = EllesmereUI and EllesmereUI.PP
    local thickness = math.max(1, math.floor((tonumber(settings.lineThickness) or 1) + 0.5))
    local pxW = PP and (thickness * (PP.mult or 1)) or thickness
    if pxW < 1 then
        pxW = 1
    end

    local lineColor = CopyColor(settings.lineColor, { 1, 1, 1, 0.6 })
    local values = ES.GetBreakpointValues()
    local drawn = 0

    for index = 1, #values do
        local value = values[index]
        local ratio = value / scaleMaximum
        if ratio > 0 and ratio <= 1 and drawn < MAX_BREAKPOINT_LINES then
            drawn = drawn + 1
            local line = overlay.lines[drawn]
            local off = PP and PP.Scale(width * ratio) or (width * ratio)
            if off > width - pxW then
                off = width - pxW
            end
            if off < 0 then
                off = 0
            end
            line:ClearAllPoints()
            line:SetColorTexture(lineColor[1], lineColor[2], lineColor[3], lineColor[4] or 0.6)
            line:SetSize(pxW, height)
            line:SetPoint("TOPLEFT", overlay, "TOPLEFT", off, 0)
            line:Show()
        end
    end

    for index = drawn + 1, MAX_BREAKPOINT_LINES do
        overlay.lines[index]:Hide()
    end
end

local function UpdateSound(settings, staggerPercent)
    if not settings.soundEnabled or staggerPercent < (settings.soundThreshold or 400) then
        return
    end
    local now = GetTime()
    local cooldown = settings.soundCooldownSeconds or 10
    if now - lastSoundTime < cooldown then
        return
    end
    if PlayAlertSound(settings.soundFile) then
        lastSoundTime = now
    end
end

local function GetSecondaryBar()
    return _G.ERB_SecondaryBar
end

local function ReadStagger(settings)
    if settings and settings.testMode then
        local percent = tonumber(settings.testStaggerPercent) or 200
        local maxHealth = UnitHealthMax("player") or 1
        if maxHealth <= 0 then
            maxHealth = 1
        end
        return (percent / 100) * maxHealth, maxHealth, percent
    end

    local cur = UnitStagger("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    local curTainted = issecretvalue and issecretvalue(cur)
    local maxTainted = issecretvalue and issecretvalue(maxHealth)
    if maxTainted or not maxHealth or maxHealth <= 0 then
        maxHealth = 1
    end
    if curTainted then
        return cur, maxHealth, nil
    end
    return cur, maxHealth, (cur / maxHealth) * 100
end

function ES.SyncCeiling(sp)
    sp = sp or ES.GetSecondary()
    if not sp then
        return
    end
    ES.EnsureProfile(sp)
    if sp.enhancedStagger then
        if sp._esSavedCeiling == nil then
            sp._esSavedCeiling = sp.staggerCeilingPercent
        end
        sp.staggerCeilingPercent = ES.GetScaleMaximum(sp)
    elseif sp._esSavedCeiling ~= nil then
        sp.staggerCeilingPercent = sp._esSavedCeiling
        sp._esSavedCeiling = nil
    end
end

function ES.IsBrewmaster()
    local _, class = UnitClass("player")
    if class ~= "MONK" then
        return false
    end
    local specIndex = GetSpecialization()
    if not specIndex then
        return false
    end
    local specID = select(1, GetSpecializationInfo(specIndex))
    return specID == BREWMASTER_SPEC_ID
end

function ES.IsEnabled(sp)
    sp = sp or ES.GetSecondary()
    return sp and sp.enhancedStagger and true or false
end

function ES.IsActive(sp)
    sp = sp or ES.GetSecondary()
    if not ES.IsEnabled(sp) then
        return false
    end
    local settings = ES.GetSettings(sp)
    if settings and settings.testMode then
        return true
    end
    return ES.IsBrewmaster()
end

function ES.ApplyVisual(force)
    local sp = ES.GetSecondary()
    local bar = GetSecondaryBar()
    if not bar then
        return
    end

    if not ES.IsActive(sp) then
        HideOverlay(bar)
        return
    end

    local settings = ES.GetSettings(sp)
    local scaleMaximum = ES.GetScaleMaximum(sp)
    local cur, maxHealth, staggerPercent = ReadStagger(settings)

    if maxHealth and not (issecretvalue and issecretvalue(maxHealth)) and maxHealth > 0 then
        local barMax = maxHealth * scaleMaximum / 100
        if force or bar._esLastMax ~= barMax then
            bar._esLastMax = barMax
            bar._lastMaxC = barMax
            bar:SetMinMaxValues(0, barMax)
        end
        if cur ~= nil and not (issecretvalue and issecretvalue(cur)) then
            bar:SetValue(cur)
        end
    end

    if staggerPercent == nil then
        staggerPercent = bar._staggerPctCache
    else
        bar._staggerPctCache = staggerPercent
    end

    if staggerPercent then
        if not sp.darkTheme then
            local r, g, b, a = ES.GetColorForStagger(staggerPercent, sp)
            local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
            if texture and not bar._atlasFill then
                if force or bar._lastStaggerR ~= r or bar._lastStaggerG ~= g or bar._lastStaggerB ~= b then
                    bar._lastStaggerR, bar._lastStaggerG, bar._lastStaggerB = r, g, b
                    texture:SetVertexColor(r, g, b, a or 1)
                end
            end
        end
        if not settings.testMode then
            UpdateSound(settings, staggerPercent)
        end
    end

    UpdateBreakpointLines(bar, settings, scaleMaximum)
end

function ES.OnSecondaryUpdate()
    ES.ApplyVisual(true)
end

local function SetTickerActive(active)
    if active then
        if not tickFrame then
            tickFrame = CreateFrame("Frame")
            tickFrame:SetScript("OnUpdate", function(_, elapsed)
                if not ES.IsActive() then
                    elapsedSinceUpdate = 0
                    HideOverlay(GetSecondaryBar())
                    tickFrame:Hide()
                    return
                end
                elapsedSinceUpdate = elapsedSinceUpdate + elapsed
                if elapsedSinceUpdate >= UPDATE_INTERVAL then
                    elapsedSinceUpdate = 0
                    ES.ApplyVisual(false)
                end
            end)
        end
        tickFrame:Show()
    elseif tickFrame then
        tickFrame:Hide()
        elapsedSinceUpdate = 0
    end
end

function ES.Refresh(rebuildOptions, fullApply)
    ES.SyncCeiling()
    SetTickerActive(ES.IsActive())

    if fullApply and _G._ERB_Apply then
        _G._ERB_Apply()
        C_Timer.After(0, function()
            SetTickerActive(ES.IsActive())
            ES.ApplyVisual(true)
        end)
    else
        ES.ApplyVisual(true)
    end

    if rebuildOptions and EllesmereUI and EllesmereUI.RefreshPage then
        EllesmereUI:RefreshPage(true)
    end
end

function ES.SetEnabled(enabled)
    local sp = ES.GetSecondary()
    if not sp then
        return
    end
    sp.enhancedStagger = not not enabled
    ES.Refresh(true, true)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
boot:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
        return
    end
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        C_Timer.After(0, function()
            local sp = ES.GetSecondary()
            if sp then
                ES.EnsureProfile(sp)
                if sp.enhancedStagger then
                    ES.SyncCeiling(sp)
                end
            end
            SetTickerActive(ES.IsActive())
            ES.ApplyVisual(true)
        end)
        return
    end
    SetTickerActive(ES.IsActive())
    ES.ApplyVisual(true)
end)
