-------------------------------------------------------------------------------
-- Extended Stagger options (EllesmereUI Resource Bars)
-- Evenly spaced breakpoints from Scale Maximum + per-zone fill colors.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BREWMASTER_SPEC_ID = 268
local MAX_ZONES = 5

local function IsBrewmasterContext(ctx)
    if ctx and ctx.advanced then
        return ctx.specID == BREWMASTER_SPEC_ID
    end
    local _, classFile = UnitClass("player")
    if classFile ~= "MONK" then
        return false
    end
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    return specID == BREWMASTER_SPEC_ID
end

local function Secondary()
    local ES = ns.EnhancedStagger
    if ES and ES.GetSecondary then
        return ES.GetSecondary()
    end
    local db = _G._ERB_AceDB
    return db and db.profile and db.profile.secondary
end

local function Settings()
    local ES = ns.EnhancedStagger
    if ES and ES.EnsureProfile then
        return ES.EnsureProfile()
    end
    return nil
end

local function EnhancedOff()
    local sp = Secondary()
    return not (sp and sp.enhancedStagger)
end

local function RefreshLive()
    local ES = ns.EnhancedStagger
    if ES and ES.ApplyVisual then
        ES.ApplyVisual(true)
    end
end

local function RefreshPage()
    local ES = ns.EnhancedStagger
    if ES and ES.Refresh then
        ES.Refresh(true, true)
    elseif EllesmereUI and EllesmereUI.RefreshPage then
        EllesmereUI:RefreshPage(true)
    end
end

local function MakeInlineCog(rgn, showFn)
    if not rgn or not showFn then
        return nil
    end
    local cogBtn = CreateFrame("Button", nil, rgn)
    cogBtn:SetSize(26, 26)
    cogBtn:SetPoint("RIGHT", rgn._lastInline or rgn._control, "LEFT", -8, 0)
    rgn._lastInline = cogBtn
    cogBtn:SetFrameLevel(rgn:GetFrameLevel() + 5)
    cogBtn:SetAlpha(0.4)
    local cogTex = cogBtn:CreateTexture(nil, "OVERLAY")
    cogTex:SetAllPoints()
    cogTex:SetTexture(EllesmereUI.COGS_ICON)
    cogBtn:SetScript("OnEnter", function(self)
        self:SetAlpha(0.7)
    end)
    cogBtn:SetScript("OnLeave", function(self)
        self:SetAlpha(0.4)
    end)
    cogBtn:SetScript("OnClick", function(self)
        showFn(self)
    end)
    return cogBtn
end

local function BuildEnhancedSection(parent, y)
    local W = EllesmereUI.Widgets
    local ES = ns.EnhancedStagger
    if not W or not ES then
        return y
    end

    local _, h
    _, h = W:SectionHeader(parent, "Extended Stagger", y)
    y = y - h

    local enableRow
    enableRow, h = W:DualRow(parent, y,
        {
            type = "toggle",
            text = "Extended Stagger",
            tooltip = "Replaces default Brewmaster stagger coloring and ceiling with color zones and optional divider lines on the Class Resource bar.",
            getValue = function()
                local sp = Secondary()
                return sp and sp.enhancedStagger
            end,
            setValue = EllesmereUI.DependentSetValue(
                function()
                    local sp = Secondary()
                    return sp and sp.enhancedStagger
                end,
                function(v)
                    local sp = Secondary()
                    if not sp then
                        return
                    end
                    sp.enhancedStagger = v and true or false
                    ES.SyncCeiling(sp)
                    RefreshPage()
                end
            ),
        },
        {
            type = "slider",
            text = "Scale Maximum",
            tooltip = "Stagger percent required to fully fill the bar. Zone divider lines are spaced evenly across this scale.",
            min = 100,
            max = 500,
            step = 10,
            disabled = EnhancedOff,
            disabledTooltip = "Extended Stagger",
            getValue = function()
                local s = Settings()
                return s and s.scaleMaximum or 400
            end,
            setValue = function(v)
                local s = Settings()
                local sp = Secondary()
                if not s or not sp then
                    return
                end
                s.scaleMaximum = v
                ES.SyncCeiling(sp)
                if ES.Refresh then
                    ES.Refresh(false, true)
                else
                    RefreshLive()
                end
            end,
        }
    )
    y = y - h

    do
        local rgn = enableRow._leftRegion
        local _, cogShow = EllesmereUI.BuildCogPopup({
            title = "Extended Stagger",
            minWidth = 280,
            captureRegion = rgn,
            rows = {
                {
                    type = "toggle",
                    label = "Sound Warning",
                    get = function()
                        local s = Settings()
                        return s and s.soundEnabled
                    end,
                    set = function(v)
                        local s = Settings()
                        if s then
                            s.soundEnabled = v and true or false
                            RefreshLive()
                        end
                    end,
                },
                {
                    type = "slider",
                    label = "Sound At %",
                    min = 50,
                    max = 500,
                    step = 10,
                    get = function()
                        local s = Settings()
                        return s and s.soundThreshold or 400
                    end,
                    set = function(v)
                        local s = Settings()
                        if s then
                            s.soundThreshold = v
                            RefreshLive()
                        end
                    end,
                },
                {
                    type = "dropdown",
                    label = "Sound",
                    values = {
                        RAID_WARNING = "Raid Warning",
                        ALARM_CLOCK_WARNING_3 = "Alarm Clock",
                        READY_CHECK = "Ready Check",
                        MAP_PING = "Map Ping",
                        IG_PLAYER_INVITE = "Invite",
                    },
                    order = {
                        "RAID_WARNING",
                        "ALARM_CLOCK_WARNING_3",
                        "READY_CHECK",
                        "MAP_PING",
                        "IG_PLAYER_INVITE",
                    },
                    get = function()
                        local s = Settings()
                        return (s and s.soundFile) or "RAID_WARNING"
                    end,
                    set = function(v)
                        local s = Settings()
                        if s then
                            s.soundFile = v
                            if ES.PreviewSound then
                                ES.PreviewSound(v)
                            end
                            RefreshLive()
                        end
                    end,
                },
                {
                    type = "button",
                    label = "Reset Zone Colors",
                    action = function()
                        ES.ResetZoneColors()
                        RefreshLive()
                        if EllesmereUI.RefreshPage then
                            EllesmereUI:RefreshPage()
                        end
                    end,
                },
            },
        })
        local cogBtn = MakeInlineCog(rgn, cogShow)
        if cogBtn then
            local cogDis = CreateFrame("Frame", nil, rgn)
            cogDis:SetAllPoints(cogBtn)
            cogDis:SetFrameLevel(cogBtn:GetFrameLevel() + 5)
            cogDis:EnableMouse(true)
            cogDis:SetScript("OnEnter", function()
                EllesmereUI.ShowWidgetTooltip(cogBtn, EllesmereUI.DisabledTooltip("Extended Stagger"))
            end)
            cogDis:SetScript("OnLeave", function()
                EllesmereUI.HideWidgetTooltip()
            end)
            local function UpdateCogDis()
                if EnhancedOff() then
                    cogDis:Show()
                    cogBtn:SetAlpha(0.15)
                else
                    cogDis:Hide()
                    cogBtn:SetAlpha(0.4)
                end
            end
            cogBtn:HookScript("OnShow", UpdateCogDis)
            if EllesmereUI.RegisterWidgetRefresh then
                EllesmereUI.RegisterWidgetRefresh(UpdateCogDis)
            end
            UpdateCogDis()
        end
    end

    local zonesRow
    zonesRow, h = W:DualRow(parent, y,
        {
            type = "slider",
            text = "Zones",
            tooltip = "Number of color zones across Scale Maximum. Divider lines are placed between zones (Zones - 1). Example: 4 zones at 400% -> lines at 100 / 200 / 300.",
            min = 2,
            max = 5,
            step = 1,
            disabled = EnhancedOff,
            disabledTooltip = "Extended Stagger",
            getValue = function()
                return ES.GetZoneCount()
            end,
            setValue = function(v)
                local s = Settings()
                if not s then
                    return
                end
                s.zoneCount = v
                RefreshLive()
                if not EllesmereUI._sliderDragging and EllesmereUI.RefreshPage then
                    EllesmereUI:RefreshPage()
                end
            end,
        },
        {
            type = "multiSwatch",
            text = "Zone Colors",
            tooltip = "Fill colors from lowest Stagger (left) to highest (right). Only the first N swatches are active for the current Zones value; the rest are saved for later.",
            disabled = EnhancedOff,
            disabledTooltip = "Extended Stagger",
            swatches = (function()
                local swatches = {}
                local labels = {
                    "Zone 1 (lowest Stagger)",
                    "Zone 2",
                    "Zone 3",
                    "Zone 4",
                    "Zone 5 (highest Stagger)",
                }
                for zoneIndex = 1, MAX_ZONES do
                    local index = zoneIndex
                    swatches[index] = {
                        tooltip = labels[index],
                        hasAlpha = true,
                        getValue = function()
                            return ES.GetZoneColor(index)
                        end,
                        setValue = function(r, g, b, a)
                            ES.SetZoneColor(index, r, g, b, a)
                            RefreshLive()
                        end,
                        refreshAlpha = function()
                            if EnhancedOff() then
                                return 0.3
                            end
                            local activeZones = ES.GetZoneCount()
                            return index <= activeZones and 1 or 0.35
                        end,
                    }
                end
                return swatches
            end)(),
        }
    )
    y = y - h

    -- Divider-line appearance lives on the Zones row cog.
    do
        local rgn = zonesRow._leftRegion
        local _, cogShow = EllesmereUI.BuildCogPopup({
            title = "Zone Dividers",
            minWidth = 280,
            captureRegion = rgn,
            rows = {
                {
                    type = "toggle",
                    label = "Show Divider Lines",
                    tooltip = "Draw vertical divider lines between color zones on the bar.",
                    get = function()
                        local s = Settings()
                        return not s or s.breakpointsEnabled ~= false
                    end,
                    set = function(v)
                        local s = Settings()
                        if s then
                            s.breakpointsEnabled = v and true or false
                            RefreshLive()
                        end
                    end,
                },
                {
                    type = "slider",
                    label = "Line Thickness",
                    min = 1,
                    max = 4,
                    step = 1,
                    get = function()
                        local s = Settings()
                        return s and s.lineThickness or 2
                    end,
                    set = function(v)
                        local s = Settings()
                        if s then
                            s.lineThickness = v
                            RefreshLive()
                        end
                    end,
                },
                {
                    type = "multiswatch",
                    label = "Line Color",
                    swatches = {
                        {
                            tooltip = "Divider Line Color",
                            hasAlpha = true,
                            getValue = function()
                                local s = Settings()
                                local c = s and s.lineColor or { 0, 0, 0, 1 }
                                return c[1], c[2], c[3], c[4] or 0.6
                            end,
                            setValue = function(r, g, b, a)
                                local s = Settings()
                                if s then
                                    s.lineColor = { r, g, b, a or 1 }
                                    RefreshLive()
                                end
                            end,
                        },
                    },
                },
            },
        })
        local cogBtn = MakeInlineCog(rgn, cogShow)
        if cogBtn then
            local cogDis = CreateFrame("Frame", nil, rgn)
            cogDis:SetAllPoints(cogBtn)
            cogDis:SetFrameLevel(cogBtn:GetFrameLevel() + 5)
            cogDis:EnableMouse(true)
            cogDis:SetScript("OnEnter", function()
                EllesmereUI.ShowWidgetTooltip(cogBtn, EllesmereUI.DisabledTooltip("Extended Stagger"))
            end)
            cogDis:SetScript("OnLeave", function()
                EllesmereUI.HideWidgetTooltip()
            end)
            local function UpdateCogDis()
                if EnhancedOff() then
                    cogDis:Show()
                    cogBtn:SetAlpha(0.15)
                else
                    cogDis:Hide()
                    cogBtn:SetAlpha(0.4)
                end
            end
            cogBtn:HookScript("OnShow", UpdateCogDis)
            if EllesmereUI.RegisterWidgetRefresh then
                EllesmereUI.RegisterWidgetRefresh(UpdateCogDis)
            end
            UpdateCogDis()
        end
    end

    return y
end

local function InstallOptionsHook()
    if ns._EnhancedStaggerOptionsHooked then
        return
    end
    if type(ns.ERB_BuildClassResourceSection) ~= "function" then
        return
    end
    ns._EnhancedStaggerOptionsHooked = true

    local original = ns.ERB_BuildClassResourceSection
    ns.ERB_BuildClassResourceSection = function(parent, y, ctx)
        local newY, hdr, classEnableRow, classColorRow = original(parent, y, ctx)
        if IsBrewmasterContext(ctx) then
            newY = BuildEnhancedSection(parent, newY)
        end
        return newY, hdr, classEnableRow, classColorRow
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    C_Timer.After(0, InstallOptionsHook)
    C_Timer.After(0.5, InstallOptionsHook)
end)
