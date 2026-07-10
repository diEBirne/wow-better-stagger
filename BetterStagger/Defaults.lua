local addonName, addon = ...
_G[addonName] = addon

addon.defaults = {
    scale = {
        mode = "fixed",
        fixedMaximum = 400,
        dynamicWindowSeconds = 15,
        dynamicBufferPercent = 25,
        dynamicMinimumMaximum = 100,
        dynamicMaximumMaximum = 600,
        dynamicRoundingStep = 50,
    },

    breakpoints = {
        enabled = true,
        values = { 100, 200, 300 },
        color = { 1, 1, 1, 0.6 },
        thickness = 1,
        labelsEnabled = false,
        labelPosition = "above",
    },

    colors = {
        enabled = true,
        thresholds = {
            { value = 0, color = { 0.1, 0.8, 0.1, 1 } },
            { value = 100, color = { 0.9, 0.9, 0.1, 1 } },
            { value = 200, color = { 1.0, 0.5, 0.0, 1 } },
            { value = 300, color = { 1.0, 0.0, 0.0, 1 } },
        },
    },

    glow = {
        enabled = true,
        threshold = 300,
    },

    sound = {
        enabled = false,
        threshold = 400,
        cooldownSeconds = 10,
        soundFile = "RaidWarning",
    },

    text = {
        enabled = true,
        template = "{current}% / {max}%",
        fontSize = 12,
        color = { 1, 1, 1, 1 },
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },

    visibility = {
        showOnlyBrewmaster = true,
        hideOutOfCombat = false,
        hideIfZero = false,
    },

    appearance = {
        width = 260,
        height = 22,
        x = 0,
        y = -120,
        point = "CENTER",
        relativePoint = "CENTER",
        barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
        barColor = { 0.1, 0.8, 0.1, 1 },
        barAlpha = 1,
        backgroundColor = { 0, 0, 0, 0.5 },
        backgroundAlpha = 0.5,
        borderEnabled = true,
        borderTexture = "Interface\\Tooltips\\UI-Tooltip-Border",
        borderSize = 12,
        borderColor = { 0, 0, 0, 0.8 },
        borderAlpha = 0.8,
        locked = false,
    },

    performance = {
        updateIntervalSeconds = 0.1,
    },
}

local function DeepMerge(defaults, saved)
    if type(defaults) ~= "table" then
        return saved ~= nil and saved or defaults
    end

    local result = {}
    if type(saved) == "table" then
        for key, value in pairs(saved) do
            result[key] = value
        end
    end

    for key, defaultValue in pairs(defaults) do
        if result[key] == nil then
            if type(defaultValue) == "table" then
                result[key] = DeepMerge(defaultValue, nil)
            else
                result[key] = defaultValue
            end
        elseif type(defaultValue) == "table" and type(result[key]) == "table" then
            result[key] = DeepMerge(defaultValue, result[key])
        end
    end

    return result
end

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

local LEGACY_TEXT_FORMATS = {
    none = "",
    current = "{current}%",
    currentMax = "{current}% / {max}%",
    amount = "{amount}",
    amountAndPercent = "{amount} ({current}%)",
}

local function MigrateSavedTextFormat(db, defaults)
    local text = db.text
    if not text then
        return
    end

    if (not text.template or text.template == "") and text.format then
        text.template = LEGACY_TEXT_FORMATS[text.format] or defaults.text.template
    end

    if not text.template then
        text.template = defaults.text.template
    end
end

function addon:InitDB()
    BetterStaggerDB = DeepMerge(self.defaults, BetterStaggerDB or {})
    self.db = BetterStaggerDB
    MigrateSavedTextFormat(self.db, self.defaults)
    return self.db
end

function addon:ResetTextTemplate()
    self.db.text.template = self.defaults.text.template
    self:RefreshFromDB()
end

function addon:ResetAllSettings()
    BetterStaggerDB = DeepCopy(self.defaults)
    self.db = BetterStaggerDB
    if self.ResetDynamicSamples then
        self:ResetDynamicSamples()
    end
    self:RefreshFromDB()
end

addon.DeepMerge = DeepMerge
addon.DeepCopy = DeepCopy
