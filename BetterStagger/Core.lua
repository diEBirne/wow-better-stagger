local addonName, addon = ...

-- Standalone bootstrap shell. Engine update logic lives in Core/Engine.lua.

local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, unit)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if unit and unit ~= "player" then
            return
        end
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local target = unit
        if target and target ~= "player" then
            return
        end
    end

    addon:Update(true)
end

function addon:InitCore()
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_LOGIN" then
            addon:InitDB()
            addon:CreateBar()
            if addon.InitConfigPanel then
                addon:InitConfigPanel()
            end
            if addon.InitEditMode then
                addon:InitEditMode()
            end
            if addon.InitEssentialCooldownWidthHook then
                addon:InitEssentialCooldownWidthHook()
            end
            if addon.InitSlash then
                addon:InitSlash()
            end
            addon:ApplyBarPosition()
            addon:Update(true)
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0, function()
                addon:ApplyBarPosition()
            end)
        end

        OnEvent(self, event, ...)
    end)

    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        addon:RunEngineOnUpdate(elapsed)
    end)
end

addon:InitCore()
