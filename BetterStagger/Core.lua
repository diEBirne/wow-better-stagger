local addonName, addon = ...

addon.testMode = false
addon.testStaggerPercent = 237

local elapsedSinceUpdate = 0
local testModeElapsed = 0
local TEST_MODE_INTERVAL = 1.0
local lastSoundTime = 0
local dynamicSamples = {}
local onUpdateActive = true

local lastState = {
    staggerRounded = -1,
    scaleMaximum = -1,
    fill = -1,
    visible = nil,
    glowActive = nil,
}

local eventFrame = CreateFrame("Frame")

function addon:ResetDynamicSamples()
    dynamicSamples = {}
end

function addon:RandomizeTestStagger()
    local scaleMaximum = self:GetCurrentScaleMaximum()
    local upperBound = math.max(1, math.floor(scaleMaximum + 100))
    self.testStaggerPercent = math.random(0, upperBound)
end

function addon:UpdateDynamicPeak(staggerPercent)
    if self.db.scale.mode ~= "dynamic" then
        return
    end

    local now = GetTime()
    dynamicSamples[#dynamicSamples + 1] = { time = now, percent = staggerPercent }

    local window = self.db.scale.dynamicWindowSeconds or 15
    local cutoff = now - window
    local writeIndex = 1

    for index = 1, #dynamicSamples do
        local sample = dynamicSamples[index]
        if sample.time >= cutoff then
            dynamicSamples[writeIndex] = sample
            writeIndex = writeIndex + 1
        end
    end

    for index = writeIndex, #dynamicSamples do
        dynamicSamples[index] = nil
    end
end

function addon:GetCurrentScaleMaximum()
    local scale = self.db.scale

    if scale.mode == "dynamic" then
        local peak = 0
        for index = 1, #dynamicSamples do
            local percent = dynamicSamples[index].percent
            if percent > peak then
                peak = percent
            end
        end

        if peak <= 0 then
            return scale.dynamicMinimumMaximum or 100
        end

        local rawDynamicMax = peak * (1 + (scale.dynamicBufferPercent or 25) / 100)
        local rounded = self:RoundUpToStep(rawDynamicMax, scale.dynamicRoundingStep or 50)
        return self:Clamp(
            rounded,
            scale.dynamicMinimumMaximum or 100,
            scale.dynamicMaximumMaximum or 600
        )
    end

    return scale.fixedMaximum or 400
end

function addon:ShouldShowBar(staggerAmount)
    if self.testMode then
        return true
    end

    local visibility = self.db.visibility

    if visibility.showOnlyBrewmaster and not self:IsBrewmaster() then
        return false
    end

    if visibility.hideOutOfCombat and not InCombatLockdown() then
        return false
    end

    if visibility.hideIfZero and staggerAmount <= 0 then
        return false
    end

    return true
end

function addon:UpdateVisibility(staggerAmount, shouldForce)
    local frame = self.bar
    if not frame then
        return false
    end

    local shouldShow = self:ShouldShowBar(staggerAmount)
    if shouldShow then
        frame:Show()
    else
        frame:Hide()
    end

    onUpdateActive = shouldShow or self.testMode

    if shouldForce or lastState.visible ~= shouldShow then
        lastState.visible = shouldShow
        return true
    end

    return false
end

function addon:UpdateSound(staggerPercent)
    local soundConfig = self.db.sound
    if not soundConfig.enabled or staggerPercent < soundConfig.threshold then
        return
    end

    local now = GetTime()
    local cooldown = soundConfig.cooldownSeconds or 10
    if now - lastSoundTime < cooldown then
        return
    end

    local soundFile = soundConfig.soundFile or "RaidWarning"
    if SOUNDKIT and SOUNDKIT[soundFile] then
        PlaySound(SOUNDKIT[soundFile])
    else
        PlaySound(soundFile)
    end

    lastSoundTime = now
end

function addon:Update(force)
    if not self.db or not self.bar then
        return
    end

    local staggerAmount, _, staggerPercent
    if self.testMode then
        local healthMax = UnitHealthMax("player") or 1
        staggerAmount = (self.testStaggerPercent / 100) * healthMax
        staggerPercent = self.testStaggerPercent
    else
        staggerAmount, _, staggerPercent = self:GetStaggerData()
    end

    self:UpdateDynamicPeak(staggerPercent)

    local scaleMaximum = self:GetCurrentScaleMaximum()
    if scaleMaximum <= 0 then
        scaleMaximum = 1
    end

    local fill = self:Clamp(staggerPercent / scaleMaximum, 0, 1)
    local staggerRounded = self:RoundPercent(staggerPercent)
    local scaleRounded = self:RoundPercent(scaleMaximum)
    local fillRounded = math.floor(fill * 1000 + 0.5) / 1000

    local visibilityChanged = self:UpdateVisibility(staggerAmount, force)

    local glowActive = self.db.glow.enabled and staggerPercent >= self.db.glow.threshold
    local dirty = force
        or visibilityChanged
        or lastState.staggerRounded ~= staggerRounded
        or lastState.scaleMaximum ~= scaleRounded
        or lastState.fill ~= fillRounded
        or lastState.glowActive ~= glowActive

    if not dirty then
        if lastState.visible or self.testMode then
            self:UpdateSound(staggerPercent)
        end
        return
    end

    lastState.staggerRounded = staggerRounded
    lastState.scaleMaximum = scaleRounded
    lastState.fill = fillRounded
    lastState.glowActive = glowActive

    self:SetBarFill(fill)
    self:UpdateBarColor(staggerPercent)
    self:UpdateText(staggerPercent, scaleMaximum, staggerAmount, fill)
    self:UpdateBreakpoints(scaleMaximum)
    self:UpdateGlow(staggerPercent)
    self:UpdateSound(staggerPercent)
end

function addon:RefreshFromDB()
    self:ApplyAppearance()
    self:Update(true)
end

function addon:ToggleTestMode()
    self.testMode = not self.testMode
    testModeElapsed = 0
    onUpdateActive = true

    if self.testMode then
        self:RandomizeTestStagger()
        self:Update(true)
        print("|cff00ff00Better Stagger:|r Test mode enabled (random 0-" .. math.floor(self:GetCurrentScaleMaximum() + 100) .. "%, updates every second).")
    else
        self:Update(true)
        print("|cff00ff00Better Stagger:|r Test mode disabled.")
    end

    return self.testMode
end

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
            if addon.InitSlash then
                addon:InitSlash()
            end
            addon:Update(true)
            return
        end

        OnEvent(self, event, ...)
    end)

    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        if not onUpdateActive then
            return
        end

        if addon.testMode then
            testModeElapsed = testModeElapsed + elapsed
            if testModeElapsed >= TEST_MODE_INTERVAL then
                testModeElapsed = 0
                addon:RandomizeTestStagger()
                addon:Update(true)
                return
            end
        end

        elapsedSinceUpdate = elapsedSinceUpdate + elapsed
        if elapsedSinceUpdate >= addon:GetUpdateInterval() then
            elapsedSinceUpdate = 0
            addon:Update(false)
        end
    end)
end

addon:InitCore()
