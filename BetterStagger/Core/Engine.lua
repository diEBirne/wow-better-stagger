local addonName, addon = ...

addon.testMode = false
addon.testStaggerPercent = 237

local elapsedSinceUpdate = 0
local testModeElapsed = 0
local TEST_MODE_INTERVAL = 1.0
local lastSoundTime = 0
local onUpdateActive = true

local lastState = {
    staggerRounded = -1,
    scaleMaximum = -1,
    fill = -1,
    visible = nil,
    glowActive = nil,
}

function addon:RandomizeTestStagger()
    local scaleMaximum = self:GetCurrentScaleMaximum()
    local upperBound = math.max(1, math.floor(scaleMaximum + 100))
    self.testStaggerPercent = math.random(0, upperBound)
end

function addon:GetCurrentScaleMaximum()
    return self.db.scale.fixedMaximum or 400
end

function addon:ShouldShowBar(staggerAmount)
    if self:IsInEditMode() then
        return true
    end

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

    if self:PlayAlertSound(soundConfig.soundFile) then
        lastSoundTime = now
    end
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
    elseif self:IsInEditMode() then
        staggerPercent = 55
        local healthMax = UnitHealthMax("player") or 1
        staggerAmount = (staggerPercent / 100) * healthMax
    else
        staggerAmount, _, staggerPercent = self:GetStaggerData()
    end

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

function addon:RunEngineOnUpdate(elapsed)
    if not onUpdateActive then
        return
    end

    if self.testMode then
        testModeElapsed = testModeElapsed + elapsed
        if testModeElapsed >= TEST_MODE_INTERVAL then
            testModeElapsed = 0
            self:RandomizeTestStagger()
            self:Update(true)
            return
        end
    end

    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate >= self:GetUpdateInterval() then
        elapsedSinceUpdate = 0
        self:Update(false)
    end
end
