-------------------------------------------------------------------------------
-- Brewmaster Monk Extended Stagger Bar options (EllesmereUI Resource Bars)
-- Integrated into CLASS RESOURCE BAR like Ironfur / Ignore Pain (no own section).
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BREWMASTER_SPEC_ID = 268
local MAX_ZONES = 5
local BAR_LABEL = "Brewmaster Monk Extended Stagger Bar"

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
    local ES = ns.BrewmasterExtendedStaggerBar
    if ES and ES.GetSecondary then
        return ES.GetSecondary()
    end
    local db = _G._ERB_AceDB
    return db and db.profile and db.profile.secondary
end

local function Settings()
    local ES = ns.BrewmasterExtendedStaggerBar
    if ES and ES.EnsureProfile then
        return ES.EnsureProfile()
    end
    return nil
end

local function BarOff()
    local sp = Secondary()
    return not (sp and sp.brewmasterExtendedStaggerBar)
end

local function RefreshLive()
    local ES = ns.BrewmasterExtendedStaggerBar
    if ES and ES.ApplyVisual then
        ES.ApplyVisual(true)
    end
end

local function RefreshPage()
    local ES = ns.BrewmasterExtendedStaggerBar
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

-- Rows inside CLASS RESOURCE BAR (same pattern as Ironfur / Ignore Pain).
local function AppendBrewmasterExtendedStaggerBarRows(parent, y)
    local W = EllesmereUI.Widgets
    local ES = ns.BrewmasterExtendedStaggerBar
    if not W or not ES then
        return y
    end
    ES.EnsureProfile()

    local _, h
    local enableRow
    enableRow, h = W:DualRow(parent, y,
        {
            type = "toggle",
            text = BAR_LABEL,
            tooltip = "Adds custom color zones and optional divider lines to the Class Resource stagger bar.",
            getValue = function()
                local sp = Secondary()
                return sp and sp.brewmasterExtendedStaggerBar
            end,
            setValue = EllesmereUI.DependentSetValue(
                function()
                    local sp = Secondary()
                    return sp and sp.brewmasterExtendedStaggerBar
                end,
                function(v)
                    local sp = Secondary()
                    if not sp then
                        return
                    end
                    sp.brewmasterExtendedStaggerBar = v and true or false
                    ES.SyncCeiling(sp)
                    RefreshPage()
                end
            ),
        },
        {
            type = "slider",
            text = "Scale Maximum",
            tooltip = "How much Stagger (as % of max health) fills the bar completely.",
            min = 100,
            max = 500,
            step = 10,
            disabled = BarOff,
            disabledTooltip = BAR_LABEL,
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

    local zonesRow
    zonesRow, h = W:DualRow(parent, y,
        {
            type = "slider",
            text = "Zones",
            tooltip = "How many color ranges the bar is split into.",
            min = 2,
            max = 5,
            step = 1,
            disabled = BarOff,
            disabledTooltip = BAR_LABEL,
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
            tooltip = "Fill colors from lowest Stagger (left) to highest (right).",
            disabled = BarOff,
            disabledTooltip = BAR_LABEL,
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
                            if BarOff() then
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
                    tooltip = "Show lines between the color zones on the bar.",
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
                        return s and s.lineThickness or 1
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
                                return c[1], c[2], c[3], c[4] or 1
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
                EllesmereUI.ShowWidgetTooltip(cogBtn, EllesmereUI.DisabledTooltip(BAR_LABEL))
            end)
            cogDis:SetScript("OnLeave", function()
                EllesmereUI.HideWidgetTooltip()
            end)
            local function UpdateCogDis()
                if BarOff() then
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
    if ns._BrewmasterExtendedStaggerBarOptionsHooked then
        return
    end
    if type(ns.ERB_BuildClassResourceSection) ~= "function" then
        return
    end
    ns._BrewmasterExtendedStaggerBarOptionsHooked = true

    -- Append inside CLASS RESOURCE BAR (end of shared builder), like other
    -- spec bars live in that section. Anchor to Cursor stays after the section.
    local originalClass = ns.ERB_BuildClassResourceSection
    ns.ERB_BuildClassResourceSection = function(parent, y, ctx)
        local newY, hdr, classEnableRow, classColorRow = originalClass(parent, y, ctx)
        if IsBrewmasterContext(ctx) then
            newY = AppendBrewmasterExtendedStaggerBarRows(parent, newY)
        end
        return newY, hdr, classEnableRow, classColorProp
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    C_Timer.After(0, InstallOptionsHook)
    C_Timer.After(0.5, InstallOptionsHook)
end)
