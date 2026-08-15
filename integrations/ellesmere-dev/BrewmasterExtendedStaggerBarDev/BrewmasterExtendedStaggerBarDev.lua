-- Temporary screenshot helper for the local EllesmereUI integration.
-- This addon is intentionally separate from the production integration.
--
-- Resource Bars keeps pushing live stagger values (with easing) between our
-- own draws, which makes a plain timer flicker. The preview therefore repaints
-- every frame and also re-applies right after each Resource Bars update.

local PREFIX = "|cff0cd29fExtended Stagger Dev:|r "
local DEFAULT_PERCENT = 237
local RANDOM_INTERVAL = 1.0
local FAKE_MAX_HEALTH = 100000

local active = false
local testPercent = DEFAULT_PERCENT
local randomMode = false
local nextRandomAt = 0

local previewText = ""
local hookedFontString
local applyingText = false

local wrappedIntegration
local originalOnSecondaryUpdate

local driver = CreateFrame("Frame")
driver:Hide()

local function Print(message)
    print(PREFIX .. message)
end

local function GetIntegration()
    local moduleNS = EllesmereUI and EllesmereUI._ModuleNS
    local resourceBarsNS = moduleNS and moduleNS.EllesmereUIResourceBars
    return resourceBarsNS and resourceBarsNS.BrewmasterExtendedStaggerBar
end

local function GetScaleMaximum(ES, sp)
    local settings = ES.GetSettings and ES.GetSettings(sp)
    return math.max(1, tonumber(settings and settings.scaleMaximum) or 400)
end

-- Resource Bars writes the count text after our runtime hook returns, so the
-- text needs its own guard to stay on the preview value.
local function EnsureTextHook(fontString)
    if not fontString or hookedFontString == fontString then
        return
    end
    hookedFontString = fontString
    hooksecurefunc(fontString, "SetText", function(self)
        if not active or applyingText or previewText == "" then
            return
        end
        applyingText = true
        self:SetText(previewText)
        applyingText = false
    end)
end

local function ApplyPreviewText(sp)
    local frame = _G.ERB_SecondaryFrame
    local fontString = frame and frame._countText
    if not (sp and sp.showText and fontString) then
        previewText = ""
        return
    end

    local suffix = (sp.showPercent == false) and "" or "%"
    previewText = string.format("%d%s", math.floor(testPercent + 0.5), suffix)

    EnsureTextHook(fontString)
    applyingText = true
    fontString:SetText(previewText)
    applyingText = false
end

local function Render()
    local ES = GetIntegration()
    local bar = _G.ERB_SecondaryBar
    local sp = ES and ES.GetSecondary and ES.GetSecondary()
    if not (ES and ES.ApplyVisual and bar and sp) then
        return
    end

    if randomMode and GetTime() >= nextRandomAt then
        local upperBound = math.floor(GetScaleMaximum(ES, sp) + 100)
        testPercent = math.random(0, math.max(1, upperBound))
        nextRandomAt = GetTime() + RANDOM_INTERVAL
    end

    local fakeStagger = FAKE_MAX_HEALTH * testPercent / 100
    ES.ApplyVisual(true, bar, sp, fakeStagger, FAKE_MAX_HEALTH)
    ApplyPreviewText(sp)
end

driver:SetScript("OnUpdate", function()
    if active then
        Render()
    end
end)

-- Repaint inside the same update in which Resource Bars pushed a live value,
-- so a real stagger value is never visible on screen.
local function InstallUpdateWrapper()
    local ES = GetIntegration()
    if not ES or wrappedIntegration == ES then
        return
    end

    wrappedIntegration = ES
    originalOnSecondaryUpdate = ES.OnSecondaryUpdate
    ES.OnSecondaryUpdate = function(secondaryBar, sp, cur, maxC)
        if not active then
            return originalOnSecondaryUpdate(secondaryBar, sp, cur, maxC)
        end
        local fakeStagger = FAKE_MAX_HEALTH * testPercent / 100
        originalOnSecondaryUpdate(secondaryBar, sp, fakeStagger, FAKE_MAX_HEALTH)
        ApplyPreviewText(sp)
    end
end

local function RemoveUpdateWrapper()
    if wrappedIntegration and originalOnSecondaryUpdate then
        wrappedIntegration.OnSecondaryUpdate = originalOnSecondaryUpdate
    end
    wrappedIntegration = nil
    originalOnSecondaryUpdate = nil
end

local function Stop()
    if not active then
        Print("test mode is already off.")
        return
    end

    active = false
    randomMode = false
    previewText = ""
    driver:Hide()
    RemoveUpdateWrapper()

    if _G._ERB_Apply then
        _G._ERB_Apply()
    end
    Print("test mode off.")
end

local function Start(percent, useRandom)
    local ES = GetIntegration()
    if not ES then
        Print("integration not found. Deploy the Ellesmere integration first.")
        return
    end

    local sp = ES.GetSecondary and ES.GetSecondary()
    if not sp then
        Print("Resource Bars profile is not available.")
        return
    end
    if not (ES.IsBrewmaster and ES.IsBrewmaster()) then
        Print("test mode requires an active Brewmaster Monk.")
        return
    end
    if not sp.brewmasterExtendedStaggerBar then
        Print("enable Brewmaster Monk Extended Stagger Bar in Resource Bars first.")
        return
    end
    if not _G.ERB_SecondaryBar then
        Print("Class Resource bar is not available. Enable Show Class Resource.")
        return
    end

    testPercent = percent or DEFAULT_PERCENT
    randomMode = useRandom and true or false
    nextRandomAt = 0
    active = true

    InstallUpdateWrapper()
    driver:Show()
    Render()

    if randomMode then
        Print("random test mode on (new value every second).")
    else
        Print(string.format("test mode on at %d%%.", math.floor(testPercent + 0.5)))
    end
end

local function Help()
    Print("commands:")
    print("  /bestest              - toggle a fixed 237% preview")
    print("  /bestest <percent>    - show a fixed preview value")
    print("  /bestest random       - animate random values")
    print("  /bestest off          - stop and restore the live bar")
end

local function HandleCommand(input)
    local command = strtrim(input or ""):lower()
    if command == "" then
        if active then
            Stop()
        else
            Start(DEFAULT_PERCENT, false)
        end
        return
    end
    if command == "off" or command == "stop" then
        Stop()
        return
    end
    if command == "random" then
        Start(DEFAULT_PERCENT, true)
        return
    end
    if command == "help" then
        Help()
        return
    end

    local percent = tonumber(command)
    if percent and percent >= 0 then
        Start(percent, false)
        return
    end
    Help()
end

SLASH_BREWMASTEREXTENDEDSTAGGERBARDEV1 = "/bestest"
SLASH_BREWMASTEREXTENDEDSTAGGERBARDEV2 = "/esbtest"
SlashCmdList.BREWMASTEREXTENDEDSTAGGERBARDEV = HandleCommand

Print("loaded. Use /bestest or /bestest help.")
