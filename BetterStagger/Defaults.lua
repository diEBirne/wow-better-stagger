local addonName, addon = ...

addon.defaults = {
    scale = {
        fixedMaximum = 400,
    },

    breakpoints = {
        enabled = true,
        rules = {
            { value = 0, color = { 0.1, 0.8, 0.1, 1 } },
            { value = 100, color = { 0.9, 0.9, 0.1, 1 } },
            { value = 200, color = { 1.0, 0.5, 0.0, 1 } },
            { value = 300, color = { 1.0, 0.0, 0.0, 1 } },
        },
        lineColor = { 1, 1, 1, 0.6 },
        thickness = 1,
        labelsEnabled = false,
        labelPosition = "above",
    },

    colors = {
        enabled = true,
    },

    glow = {
        enabled = true,
        threshold = 300,
    },

    sound = {
        enabled = false,
        threshold = 400,
        cooldownSeconds = 10,
        soundFile = "RAID_WARNING",
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
        attachFrame = "UIParent",
        reverseFill = false,
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
        widthMode = "Manual",
        minWidth = 0,
        sectionExpanded = {
            position = true,
            bar = false,
            border = false,
            text = false,
            breakpoints = false,
        },
    },

    performance = {
        updateIntervalSeconds = 0.1,
    },
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

local function DeepMerge(defaults, saved)
    if type(defaults) ~= "table" then
        return saved ~= nil and saved or defaults
    end

    if addon.IsArrayTable(defaults) then
        if type(saved) == "table" then
            return DeepCopy(saved)
        end
        return DeepCopy(defaults)
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

local LEGACY_TEXT_FORMATS = {
    none = "",
    current = "{current}%",
    currentMax = "{current}% / {max}%",
    amount = "{amount}",
    amountAndPercent = "{amount} ({current}%)",
}

local function MigrateSavedSettings(db, defaults)
    local text = db.text
    if text then
        if (not text.template or text.template == "") and text.format then
            text.template = LEGACY_TEXT_FORMATS[text.format] or defaults.text.template
        end
        if not text.template then
            text.template = defaults.text.template
        end
    end

    if db.scale then
        db.scale.mode = nil
        db.scale.dynamicWindowSeconds = nil
        db.scale.dynamicBufferPercent = nil
        db.scale.dynamicMinimumMaximum = nil
        db.scale.dynamicMaximumMaximum = nil
        db.scale.dynamicRoundingStep = nil
        if not db.scale.fixedMaximum then
            db.scale.fixedMaximum = defaults.scale.fixedMaximum
        end
    end

    if db.appearance and not db.appearance.attachFrame then
        db.appearance.attachFrame = defaults.appearance.attachFrame
    end

    if db.appearance and db.appearance.reverseFill == nil then
        db.appearance.reverseFill = defaults.appearance.reverseFill
    end

    if db.appearance then
        if not db.appearance.widthMode then
            db.appearance.widthMode = defaults.appearance.widthMode
        end
        if db.appearance.minWidth == nil then
            db.appearance.minWidth = defaults.appearance.minWidth
        end
        if not db.appearance.sectionExpanded then
            db.appearance.sectionExpanded = DeepCopy(defaults.appearance.sectionExpanded)
        end
    end

    if addon.MigrateBreakpointRules then
        addon:MigrateBreakpointRules(db, defaults)
    end

    if db.colors then
        db.colors.thresholds = nil
    end

    if db.sound and db.sound.soundFile then
        db.sound.soundFile = addon:NormalizeSoundKey(db.sound.soundFile)
    end
end

function addon:InitDB()
    BetterStaggerDB = DeepMerge(self.defaults, BetterStaggerDB or {})
    self.db = BetterStaggerDB
    MigrateSavedSettings(self.db, self.defaults)
    return self.db
end

function addon:ResetTextTemplate()
    self.db.text.template = self.defaults.text.template
    self:RefreshFromDB()
end

function addon:ResetAllSettings()
    BetterStaggerDB = DeepCopy(self.defaults)
    self.db = BetterStaggerDB
    self:RefreshFromDB()
end

addon.DeepMerge = DeepMerge
addon.DeepCopy = DeepCopy
