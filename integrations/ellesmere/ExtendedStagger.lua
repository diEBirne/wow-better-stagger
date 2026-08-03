-------------------------------------------------------------------------------
-- Extended Stagger (local EllesmereUI Resource Bars integration)
-- Opt-in Brewmaster stagger enhancements hosted on ERB_SecondaryBar.
-- Default OFF. Zero ongoing cost when disabled / not opted in.
--
-- Runtime model (EUI acceptance-oriented):
-- - Visual updates ride the existing Resource Bars secondary update path.
-- - No OnUpdate polling.
-- - Spec events register only while the feature toggle is ON.
-- - Overlay textures are created lazily on first needed draw.
--
-- Model: zoneCount (2-5) evenly divides Scale Maximum.
-- Divider lines = zoneCount - 1. Example: 4 zones at scale 400 -> lines at 100/200/300.
-- Five zone colors are always stored; unused higher zones apply when zoneCount rises.
--
-- SavedVariables keys: extendedStagger / extendedStaggerSettings.
-- Migrates legacy enhancedStagger* keys once.
-- Retail and PTR: uses issecretvalue when present; no IS_121-only aura paths.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local ES = {}
ns.ExtendedStagger = ES

local MAX_DIVIDER_LINES = 4
local MIN_ZONES = 2
local MAX_ZONES = 5
local BREWMASTER_SPEC_ID = 268
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
    zoneCount = 4,
    breakpointsEnabled = true,
    lineColor = { 0, 0, 0, 1 },
    lineThickness = 2,
}

local breakpointScratch = { nil, nil, nil, nil }
local eventFrame = nil
local runtimeEventsActive = false

local function ClampZoneCount(value)
    value = math.floor((tonumber(value) or 4) + 0.5)
    if value < MIN_ZONES then
        return MIN_ZONES
    end
    if value > MAX_ZONES then
        return MAX_ZONES
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
    elseif lineCount > MAX_DIVIDER_LINES then
        lineCount = MAX_DIVIDER_LINES
    end

    local colorIndex = 1
    for index = 1, #legacy do
        if colorIndex <= MAX_ZONES then
            zoneColors[colorIndex] = CopyColor(legacy[index].color, DEFAULT_ZONE_COLORS[colorIndex])
            colorIndex = colorIndex + 1
        end
    end

    settings.zoneCount = lineCount + 1
    settings.breakpointCount = nil
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

    -- Migrate legacy enhanced* keys from earlier local builds.
    if sp.extendedStagger == nil and sp.enhancedStagger ~= nil then
        sp.extendedStagger = sp.enhancedStagger and true or false
    end
    if type(sp.extendedStaggerSettings) ~= "table" and type(sp.enhancedStaggerSettings) == "table" then
        sp.extendedStaggerSettings = sp.enhancedStaggerSettings
    end
    sp.enhancedStagger = nil
    sp.enhancedStaggerSettings = nil

    if sp.extendedStagger == nil then
        sp.extendedStagger = false
    end
    if type(sp.extendedStaggerSettings) ~= "table" then
        sp.extendedStaggerSettings = ES.GetDefaults()
        return sp.extendedStaggerSettings
    end

    local settings = sp.extendedStaggerSettings
    MigrateLegacySettings(settings)

    for key, defaultValue in pairs(DEFAULT_SETTINGS) do
        if settings[key] == nil then
            settings[key] = DeepCopy(defaultValue)
        end
    end

    if settings.zoneCount == nil and settings.breakpointCount ~= nil then
        settings.zoneCount = (tonumber(settings.breakpointCount) or 3) + 1
    end
    settings.zoneCount = ClampZoneCount(settings.zoneCount)
    settings.breakpointCount = nil
    settings.zoneColors = NormalizeZoneColors(settings.zoneColors)
    settings.glowEnabled = nil
    settings.glowThreshold = nil
    settings.rules = nil
    settings.testMode = nil
    settings.testStaggerPercent = nil
    settings.soundEnabled = nil
    settings.soundThreshold = nil
    settings.soundCooldownSeconds = nil
    settings.soundFile = nil

    if type(settings.lineColor) ~= "table" then
        settings.lineColor = { 0, 0, 0, 1 }
    end
    return settings
end

function ES.GetSettings(sp)
    sp = sp or ES.GetSecondary()
    if not sp then
        return nil
    end
    local settings = sp.extendedStaggerSettings
    -- Hot path: settings already present and normalized by EnsureProfile / options.
    if type(settings) == "table" and type(settings.zoneColors) == "table" and settings.zoneCount ~= nil then
        return settings
    end
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

function ES.GetZoneCount(sp)
    local settings = ES.GetSettings(sp)
    return ClampZoneCount(settings and settings.zoneCount)
end

function ES.GetDividerCount(sp)
    return ES.GetZoneCount(sp) - 1
end

-- Evenly spaced absolute Stagger % values for divider lines.
-- Reuses a scratch table to avoid hot-path allocations.
function ES.GetBreakpointValues(sp)
    local scaleMaximum = ES.GetScaleMaximum(sp)
    local zoneCount = ES.GetZoneCount(sp)
    local lineCount = zoneCount - 1
    for index = 1, MAX_DIVIDER_LINES do
        if index <= lineCount then
            breakpointScratch[index] = scaleMaximum * index / zoneCount
        else
            breakpointScratch[index] = nil
        end
    end
    return breakpointScratch, lineCount
end

function ES.GetZoneRangeLabel(zoneIndex, sp)
    local scaleMaximum = ES.GetScaleMaximum(sp)
    local zoneCount = ES.GetZoneCount(sp)
    local lineCount = zoneCount - 1
    zoneIndex = math.max(1, math.min(MAX_ZONES, math.floor(tonumber(zoneIndex) or 1)))

    local function RoundPct(value)
        return math.floor(value + 0.5)
    end

    if zoneIndex == 1 then
        local hi = RoundPct(scaleMaximum / zoneCount)
        return string.format("0%% - %d%%", hi)
    end
    if zoneIndex >= zoneCount then
        local lo = RoundPct(scaleMaximum * lineCount / zoneCount)
        return string.format("%d%%+", lo)
    end
    local lo = RoundPct(scaleMaximum * (zoneIndex - 1) / zoneCount)
    local hi = RoundPct(scaleMaximum * zoneIndex / zoneCount)
    return string.format("%d%% - %d%%", lo, hi)
end

function ES.GetColorForStagger(staggerPercent, sp)
    local settings = ES.GetSettings(sp)
    local scaleMaximum = tonumber(settings and settings.scaleMaximum) or 400
    local zoneCount = ClampZoneCount(settings and settings.zoneCount)
    local lineCount = zoneCount - 1
    local colors = settings and settings.zoneColors
    local zone = 1
    for index = 1, lineCount do
        local threshold = scaleMaximum * index / zoneCount
        if staggerPercent >= threshold then
            zone = index + 1
        end
    end
    local color = (colors and colors[zone]) or DEFAULT_ZONE_COLORS[zone] or DEFAULT_ZONE_COLORS[1]
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
    local colors = settings and settings.zoneColors
    if type(colors) ~= "table" then
        colors = DEFAULT_ZONE_COLORS
    end
    zoneIndex = math.max(1, math.min(MAX_ZONES, math.floor(tonumber(zoneIndex) or 1)))
    local color = colors[zoneIndex] or DEFAULT_ZONE_COLORS[zoneIndex]
    return color[1], color[2], color[3], color[4] or 1
end

function ES.ResetZoneColors()
    local settings = ES.GetSettings()
    if not settings then
        return
    end
    settings.zoneColors = DefaultZoneColors()
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
    for index = 1, MAX_DIVIDER_LINES do
        local line = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
        line:SetColorTexture(0, 0, 0, 1)
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
    for index = 1, MAX_DIVIDER_LINES do
        local line = bar._esOverlay.lines[index]
        if line then
            line:Hide()
        end
    end
end

local function UpdateBreakpointLines(bar, settings, scaleMaximum)
    if not settings.breakpointsEnabled then
        HideOverlay(bar)
        return
    end

    local overlay = EnsureOverlay(bar)
    if not overlay then
        return
    end
    overlay:Show()

    local width = bar:GetWidth() or 0
    local height = bar:GetHeight() or 0
    if width <= 0 or height <= 0 then
        for index = 1, MAX_DIVIDER_LINES do
            overlay.lines[index]:Hide()
        end
        return
    end

    local PP = EllesmereUI and EllesmereUI.PP
    local thickness = math.max(1, math.floor((tonumber(settings.lineThickness) or 2) + 0.5))
    local pxW = PP and (thickness * (PP.mult or 1)) or thickness
    if pxW < 1 then
        pxW = 1
    end

    local lc = settings.lineColor
    local lr, lg, lb, la = 0, 0, 0, 1
    if type(lc) == "table" then
        lr, lg, lb, la = lc[1] or 0, lc[2] or 0, lc[3] or 0, lc[4] or 1
    end

    local values, lineCount = ES.GetBreakpointValues()
    local drawn = 0

    for index = 1, lineCount do
        local value = values[index]
        local ratio = value / scaleMaximum
        if ratio > 0 and ratio <= 1 and drawn < MAX_DIVIDER_LINES then
            drawn = drawn + 1
            local line = overlay.lines[drawn]
            local center = PP and PP.Scale(width * ratio) or (width * ratio)
            local off = center - (pxW * 0.5)
            if off < 0 then
                off = 0
            elseif off > width - pxW then
                off = width - pxW
            end
            line:ClearAllPoints()
            line:SetColorTexture(lr, lg, lb, la)
            line:SetSize(pxW, height)
            line:SetPoint("TOPLEFT", overlay, "TOPLEFT", off, 0)
            line:Show()
        end
    end

    for index = drawn + 1, MAX_DIVIDER_LINES do
        overlay.lines[index]:Hide()
    end
end


local function GetSecondaryBar()
    return _G.ERB_SecondaryBar
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function ReadStagger(cur, maxHealth)
    if cur == nil then
        cur = UnitStagger("player") or 0
    end
    if maxHealth == nil then
        maxHealth = UnitHealthMax("player") or 1
    end

    local curTainted = IsSecret(cur)
    local maxTainted = IsSecret(maxHealth)
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
    if sp.extendedStagger then
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
    return sp and sp.extendedStagger and true or false
end

function ES.IsActive(sp)
    sp = sp or ES.GetSecondary()
    return ES.IsEnabled(sp) and ES.IsBrewmaster()
end

local function SetRuntimeEventsActive(active)
    if active then
        if not eventFrame then
            eventFrame = CreateFrame("Frame")
            eventFrame:SetScript("OnEvent", function(_, event, unit)
                if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
                    return
                end
                ES.SyncCeiling()
                if ES.IsActive() then
                    ES.ApplyVisual(true)
                else
                    HideOverlay(GetSecondaryBar())
                end
            end)
        end
        if not runtimeEventsActive then
            eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
            runtimeEventsActive = true
        end
    elseif eventFrame and runtimeEventsActive then
        eventFrame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        runtimeEventsActive = false
    end
end

function ES.ApplyVisual(force, bar, sp, cur, maxHealth)
    sp = sp or ES.GetSecondary()
    bar = bar or GetSecondaryBar()
    if not bar then
        return
    end

    if not ES.IsActive(sp) then
        HideOverlay(bar)
        return
    end

    local settings = ES.GetSettings(sp)
    local scaleMaximum = tonumber(settings.scaleMaximum) or 400
    if scaleMaximum < 1 then
        scaleMaximum = 1
    end

    local staggerPercent
    cur, maxHealth, staggerPercent = ReadStagger(cur, maxHealth)

    if maxHealth and not IsSecret(maxHealth) and maxHealth > 0 then
        local barMax = maxHealth * scaleMaximum / 100
        if force or bar._esLastMax ~= barMax then
            bar._esLastMax = barMax
            bar._lastMaxC = barMax
            bar:SetMinMaxValues(0, barMax)
        end
        if cur ~= nil and not IsSecret(cur) then
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
    end

    UpdateBreakpointLines(bar, settings, scaleMaximum)
end

-- Called from the Resource Bars secondary update hook (gated on sp.extendedStagger).
function ES.OnSecondaryUpdate(secondaryBar, sp, cur, maxC)
    if not sp or not sp.extendedStagger then
        return
    end
    if not ES.IsBrewmaster() then
        HideOverlay(secondaryBar or GetSecondaryBar())
        return
    end
    ES.ApplyVisual(false, secondaryBar, sp, cur, maxC)
end

function ES.Refresh(rebuildOptions, fullApply)
    local enabled = ES.IsEnabled()
    ES.SyncCeiling()
    SetRuntimeEventsActive(enabled)

    if not enabled then
        HideOverlay(GetSecondaryBar())
    end

    if fullApply and _G._ERB_Apply then
        _G._ERB_Apply()
        C_Timer.After(0, function()
            SetRuntimeEventsActive(ES.IsEnabled())
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
    sp.extendedStagger = not not enabled
    ES.Refresh(true, true)
end

-- One-shot login bootstrap. Unregisters immediately; ongoing events only if enabled.
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    self:SetScript("OnEvent", nil)
    C_Timer.After(0, function()
        local sp = ES.GetSecondary()
        if not sp then
            return
        end
        ES.EnsureProfile(sp)
        if not sp.extendedStagger then
            return
        end
        ES.SyncCeiling(sp)
        SetRuntimeEventsActive(true)
        ES.ApplyVisual(true)
    end)
end)
