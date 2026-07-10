local addonName, addon = ...

local category
local settingsCategoryID = "Better Stagger"

local function OnSettingChanged()
    if addon.RefreshFromDB then
        addon:RefreshFromDB()
    end
end

local function SafeCall(label, func)
    local ok, err = pcall(func)
    if not ok then
        print("|cffff0000Better Stagger:|r Failed to register setting '" .. label .. "': " .. tostring(err))
    end
    return ok
end

local function RegisterCheckbox(parentCategory, variable, variableKey, variableTbl, name, defaultValue, tooltip)
    local setting = Settings.RegisterAddOnSetting(
        parentCategory,
        variable,
        variableKey,
        variableTbl,
        type(defaultValue),
        name,
        defaultValue
    )
    setting:SetValueChangedCallback(OnSettingChanged)
    Settings.CreateCheckbox(parentCategory, setting, tooltip)
    return setting
end

local function RegisterSlider(parentCategory, variable, name, defaultValue, minValue, maxValue, step, getValue, setValue, tooltip)
    local setting = Settings.RegisterProxySetting(
        parentCategory,
        variable,
        type(defaultValue),
        name,
        defaultValue,
        getValue,
        setValue
    )
    setting:SetValueChangedCallback(OnSettingChanged)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(parentCategory, setting, options, tooltip)
    return setting
end

local function RegisterDropdown(parentCategory, variable, name, defaultValue, optionsTable, getValue, setValue, tooltip)
    local setting = Settings.RegisterProxySetting(
        parentCategory,
        variable,
        type(defaultValue),
        name,
        defaultValue,
        getValue,
        setValue
    )
    setting:SetValueChangedCallback(OnSettingChanged)
    local dropdownOptions = Settings.CreateControlTextContainer()
    for _, option in ipairs(optionsTable) do
        dropdownOptions:Set(option.value, option.label)
    end
    Settings.CreateDropdown(parentCategory, setting, dropdownOptions, tooltip)
    return setting
end

local function CreateSectionHeader(parentCategory, title)
    if Settings.CreateSectionHeader then
        Settings.CreateSectionHeader(parentCategory, title)
    end
end

local TEXT_ANCHOR_OPTIONS = {
    { value = "CENTER", label = "Center" },
    { value = "LEFT", label = "Left" },
    { value = "RIGHT", label = "Right" },
    { value = "TOP", label = "Top" },
    { value = "BOTTOM", label = "Bottom" },
}

local LABEL_POSITION_OPTIONS = {
    { value = "above", label = "Above line" },
    { value = "below", label = "Below line" },
    { value = "center", label = "On line (centered)" },
}

local function CreateBreakpointsPanel(parentCategory)
    local panel = CreateFrame("Frame")
    panel.name = "Better Stagger Breakpoints"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Breakpoint Values")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetWidth(400)
    description:SetJustifyH("LEFT")
    description:SetText("Enter Stagger percentages separated by commas (e.g. 100, 200, 300). Positions update relative to the current scale maximum.")

    local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    editBox:SetSize(280, 24)
    editBox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(128)

    local function ApplyBreakpoints()
        local parsed = addon:ParseBreakpointString(editBox:GetText())
        if #parsed == 0 then
            print("|cffff0000Better Stagger:|r Enter at least one positive breakpoint value.")
            editBox:SetText(addon:FormatBreakpointString(addon.db.breakpoints.values))
            return
        end

        addon.db.breakpoints.values = parsed
        editBox:SetText(addon:FormatBreakpointString(parsed))
        addon:RefreshFromDB()
    end

    editBox:SetScript("OnEnterPressed", function(self)
        ApplyBreakpoints()
        self:ClearFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(addon:FormatBreakpointString(addon.db.breakpoints.values))
        self:ClearFocus()
    end)

    local applyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    applyButton:SetSize(100, 24)
    applyButton:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", ApplyBreakpoints)

    panel:SetScript("OnShow", function()
        editBox:SetText(addon:FormatBreakpointString(addon.db.breakpoints.values))
    end)

    if Settings.RegisterCanvasLayoutSubcategory then
        local subcategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, "Breakpoints")
        if subcategory then
            subcategory.ID = settingsCategoryID .. "/Breakpoints"
        end
    end
end

function addon:OpenConfigPanel()
    if not Settings or not Settings.OpenToCategory then
        print("|cffff0000Better Stagger:|r Settings API not available.")
        return
    end

    if category then
        local categoryID = category.ID or (category.GetID and category:GetID())
        if categoryID then
            Settings.OpenToCategory(categoryID)
            return
        end
    end

    Settings.OpenToCategory(settingsCategoryID)
end

function addon:InitConfigPanel()
    if addon.configPanelInitialized then
        return
    end

    if not Settings or not Settings.RegisterVerticalLayoutCategory then
        print("|cffff0000Better Stagger:|r Settings API not available.")
        return
    end

    local db = self.db
    category = Settings.RegisterVerticalLayoutCategory(settingsCategoryID)
    category.ID = settingsCategoryID

    -- Must register the category before adding controls (Settings API requirement).
    Settings.RegisterAddOnCategory(category)
    addon.configPanelInitialized = true

    local appearance = db.appearance
    local scale = db.scale
    local breakpoints = db.breakpoints
    local glow = db.glow
    local sound = db.sound
    local text = db.text
    local visibility = db.visibility
    local performance = db.performance

    CreateSectionHeader(category, "Appearance")

    SafeCall("Bar Width", function()
        RegisterSlider(category, "BS_Appearance_Width", "Bar Width", appearance.width, 100, 600, 1,
            function() return db.appearance.width end,
            function(value) addon:SetBarSize(value, db.appearance.height) end,
            "Width of the stagger bar in pixels.")
    end)

    SafeCall("Bar Height", function()
        RegisterSlider(category, "BS_Appearance_Height", "Bar Height", appearance.height, 10, 60, 1,
            function() return db.appearance.height end,
            function(value) addon:SetBarSize(db.appearance.width, value) end,
            "Height of the stagger bar in pixels.")
    end)

    SafeCall("Bar Alpha", function()
        RegisterSlider(category, "BS_Appearance_BarAlpha", "Bar Alpha", appearance.barAlpha, 0, 1, 0.05,
            function() return db.appearance.barAlpha end,
            function(value) db.appearance.barAlpha = value end,
            "Opacity of the bar fill.")
    end)

    SafeCall("Background Alpha", function()
        RegisterSlider(category, "BS_Appearance_BackgroundAlpha", "Background Alpha", appearance.backgroundAlpha, 0, 1, 0.05,
            function() return db.appearance.backgroundAlpha end,
            function(value) db.appearance.backgroundAlpha = value end,
            "Opacity of the bar background.")
    end)

    SafeCall("Show Border", function()
        RegisterCheckbox(category, "BS_Appearance_Border", "borderEnabled", appearance, "Show Border", appearance.borderEnabled,
            "Draw a border around the bar.")
    end)

    SafeCall("Lock Bar Position", function()
        RegisterCheckbox(category, "BS_Appearance_Locked", "locked", appearance, "Lock Bar Position", appearance.locked,
            "Prevent dragging the bar. Use /bs unlock to move it.")
    end)

    SafeCall("Test Mode", function()
        local settingTestMode = Settings.RegisterProxySetting(
            category,
            "BS_Appearance_TestMode",
            type(false),
            "Test Mode",
            false,
            function() return addon.testMode end,
            function(value)
                if value ~= addon.testMode then
                    addon:ToggleTestMode()
                end
            end
        )
        settingTestMode:SetValueChangedCallback(OnSettingChanged)
        Settings.CreateCheckbox(category, settingTestMode, "Show a simulated 237% Stagger bar for UI testing.")
    end)

    CreateSectionHeader(category, "Scale")

    SafeCall("Scale Mode", function()
        RegisterDropdown(category, "BS_Scale_Mode", "Scale Mode", scale.mode, {
            { value = "fixed", label = "Fixed Linear" },
            { value = "dynamic", label = "Peak-Based Dynamic" },
        },
            function() return db.scale.mode end,
            function(value) db.scale.mode = value end,
            "Fixed uses a set maximum. Dynamic adjusts based on recent peak Stagger.")
    end)

    SafeCall("Fixed Scale Maximum", function()
        RegisterSlider(category, "BS_Scale_FixedMax", "Fixed Scale Maximum (%)", scale.fixedMaximum, 100, 1000, 10,
            function() return db.scale.fixedMaximum end,
            function(value) db.scale.fixedMaximum = value end,
            "Upper end of the bar in fixed mode. 200% Stagger with 400% max fills half the bar.")
    end)

    SafeCall("Dynamic Window", function()
        RegisterSlider(category, "BS_Scale_DynamicWindow", "Dynamic Window (seconds)", scale.dynamicWindowSeconds, 5, 60, 1,
            function() return db.scale.dynamicWindowSeconds end,
            function(value) db.scale.dynamicWindowSeconds = value end,
            "How far back to look for peak Stagger in dynamic mode.")
    end)

    SafeCall("Dynamic Buffer", function()
        RegisterSlider(category, "BS_Scale_DynamicBuffer", "Dynamic Buffer (%)", scale.dynamicBufferPercent, 0, 100, 5,
            function() return db.scale.dynamicBufferPercent end,
            function(value) db.scale.dynamicBufferPercent = value end,
            "Extra headroom above the recent peak in dynamic mode.")
    end)

    SafeCall("Dynamic Minimum Max", function()
        RegisterSlider(category, "BS_Scale_DynamicMin", "Dynamic Minimum Max (%)", scale.dynamicMinimumMaximum, 50, 500, 10,
            function() return db.scale.dynamicMinimumMaximum end,
            function(value) db.scale.dynamicMinimumMaximum = value end,
            "Lowest scale maximum in dynamic mode.")
    end)

    SafeCall("Dynamic Maximum Max", function()
        RegisterSlider(category, "BS_Scale_DynamicMax", "Dynamic Maximum Max (%)", scale.dynamicMaximumMaximum, 100, 1000, 10,
            function() return db.scale.dynamicMaximumMaximum end,
            function(value) db.scale.dynamicMaximumMaximum = value end,
            "Highest scale maximum in dynamic mode.")
    end)

    SafeCall("Dynamic Rounding Step", function()
        RegisterSlider(category, "BS_Scale_DynamicStep", "Dynamic Rounding Step (%)", scale.dynamicRoundingStep, 10, 100, 10,
            function() return db.scale.dynamicRoundingStep end,
            function(value) db.scale.dynamicRoundingStep = value end,
            "Round dynamic maximum up to this step for readability.")
    end)

    CreateSectionHeader(category, "Breakpoints")

    SafeCall("Show Breakpoints", function()
        RegisterCheckbox(category, "BS_Breakpoints_Enabled", "enabled", breakpoints, "Show Breakpoints", breakpoints.enabled,
            "Show vertical lines at configured Stagger percentages.")
    end)

    SafeCall("Breakpoint Thickness", function()
        RegisterSlider(category, "BS_Breakpoints_Thickness", "Breakpoint Thickness", breakpoints.thickness, 1, 5, 1,
            function() return db.breakpoints.thickness end,
            function(value) db.breakpoints.thickness = value end,
            "Line thickness for breakpoint markers.")
    end)

    SafeCall("Show Breakpoint Labels", function()
        RegisterCheckbox(category, "BS_Breakpoints_Labels", "labelsEnabled", breakpoints, "Show Breakpoint Labels", breakpoints.labelsEnabled,
            "Show percentage labels on breakpoint lines.")
    end)

    SafeCall("Breakpoint Label Position", function()
        RegisterDropdown(category, "BS_Breakpoints_LabelPosition", "Breakpoint Label Position", breakpoints.labelPosition or "above", LABEL_POSITION_OPTIONS,
            function() return db.breakpoints.labelPosition or "above" end,
            function(value) db.breakpoints.labelPosition = value end,
            "Where breakpoint labels appear relative to their line.")
    end)

    CreateSectionHeader(category, "Colors and Warnings")

    SafeCall("Enable Glow Warning", function()
        RegisterCheckbox(category, "BS_Glow_Enabled", "enabled", glow, "Enable Glow Warning", glow.enabled,
            "Highlight the bar when Stagger exceeds the glow threshold.")
    end)

    SafeCall("Glow Threshold", function()
        RegisterSlider(category, "BS_Glow_Threshold", "Glow Threshold (%)", glow.threshold, 50, 800, 10,
            function() return db.glow.threshold end,
            function(value) db.glow.threshold = value end,
            "Stagger percentage at which the glow appears.")
    end)

    SafeCall("Enable Sound Warning", function()
        RegisterCheckbox(category, "BS_Sound_Enabled", "enabled", sound, "Enable Sound Warning", sound.enabled,
            "Play a sound when Stagger exceeds the sound threshold.")
    end)

    SafeCall("Sound Threshold", function()
        RegisterSlider(category, "BS_Sound_Threshold", "Sound Threshold (%)", sound.threshold, 50, 1000, 10,
            function() return db.sound.threshold end,
            function(value) db.sound.threshold = value end,
            "Stagger percentage that triggers the sound alert.")
    end)

    SafeCall("Sound Cooldown", function()
        RegisterSlider(category, "BS_Sound_Cooldown", "Sound Cooldown (seconds)", sound.cooldownSeconds, 1, 60, 1,
            function() return db.sound.cooldownSeconds end,
            function(value) db.sound.cooldownSeconds = value end,
            "Minimum time between sound alerts.")
    end)

    CreateSectionHeader(category, "Text")

    SafeCall("Show Bar Text", function()
        RegisterCheckbox(category, "BS_Text_Enabled", "enabled", text, "Show Bar Text", text.enabled,
            "Display Stagger text on the bar. Turn off to hide all bar text.")
    end)

    SafeCall("Text Format", function()
        RegisterDropdown(category, "BS_Text_Format", "Text Format", text.format, {
            { value = "none", label = "Hidden" },
            { value = "current", label = "Current only (237%)" },
            { value = "currentMax", label = "Current / Maximum (237% / 400%)" },
        },
            function() return db.text.format end,
            function(value) db.text.format = value end,
            "What to show on the bar. Hidden removes text even if Show Bar Text is enabled.")
    end)

    SafeCall("Text Anchor", function()
        RegisterDropdown(category, "BS_Text_Anchor", "Text Anchor", text.point or "CENTER", TEXT_ANCHOR_OPTIONS,
            function() return db.text.point or "CENTER" end,
            function(value) db.text.point = value end,
            "Where the text is anchored on the bar.")
    end)

    SafeCall("Text Offset X", function()
        RegisterSlider(category, "BS_Text_OffsetX", "Text Offset X", text.x or 0, -200, 200, 1,
            function() return db.text.x or 0 end,
            function(value) db.text.x = value end,
            "Horizontal text offset in pixels.")
    end)

    SafeCall("Text Offset Y", function()
        RegisterSlider(category, "BS_Text_OffsetY", "Text Offset Y", text.y or 0, -50, 50, 1,
            function() return db.text.y or 0 end,
            function(value) db.text.y = value end,
            "Vertical text offset in pixels.")
    end)

    SafeCall("Text Font Size", function()
        RegisterSlider(category, "BS_Text_FontSize", "Text Font Size", text.fontSize, 8, 24, 1,
            function() return db.text.fontSize end,
            function(value) db.text.fontSize = value end,
            "Font size for bar text.")
    end)

    CreateSectionHeader(category, "Visibility")

    SafeCall("Show Only as Brewmaster", function()
        RegisterCheckbox(category, "BS_Visibility_Brewmaster", "showOnlyBrewmaster", visibility, "Show Only as Brewmaster", visibility.showOnlyBrewmaster,
            "Hide the bar unless you are a Brewmaster Monk.")
    end)

    SafeCall("Hide Out of Combat", function()
        RegisterCheckbox(category, "BS_Visibility_Combat", "hideOutOfCombat", visibility, "Hide Out of Combat", visibility.hideOutOfCombat,
            "Only show the bar while in combat.")
    end)

    SafeCall("Hide When Stagger is 0", function()
        RegisterCheckbox(category, "BS_Visibility_Zero", "hideIfZero", visibility, "Hide When Stagger is 0", visibility.hideIfZero,
            "Hide the bar when you have no Stagger.")
    end)

    CreateSectionHeader(category, "Performance")

    SafeCall("Update Interval", function()
        RegisterSlider(category, "BS_Performance_Interval", "Update Interval (seconds)", performance.updateIntervalSeconds, 0.05, 0.5, 0.05,
            function() return addon:GetUpdateInterval() end,
            function(value) db.performance.updateIntervalSeconds = addon:Clamp(value, 0.05, 0.5) end,
            "How often the bar polls Stagger. Lower = more responsive, higher = lighter on performance. Default: 0.1")
    end)

    SafeCall("Breakpoints panel", function()
        CreateBreakpointsPanel(category)
    end)

    if Settings.CreateButton then
        SafeCall("Reset Bar Position", function()
            Settings.CreateButton(category, "BS_Reset_Position", "Reset Bar Position", "Reset the bar to its default screen position.", function()
                addon:ResetBarPosition()
                addon:RefreshFromDB()
            end)
        end)
    end
end
