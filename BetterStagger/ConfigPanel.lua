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

local function RegisterSubcategory(parentCategory, name)
    local subcategory = Settings.RegisterVerticalLayoutSubcategory(parentCategory, name)
    if subcategory then
        subcategory.ID = settingsCategoryID .. "/" .. name:gsub("[^%w]", "")
        Settings.RegisterAddOnCategory(subcategory)
    end
    return subcategory
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
    local decimals = step >= 1 and 0 or 2

    local setting = Settings.RegisterProxySetting(
        parentCategory,
        variable,
        type(defaultValue),
        name,
        defaultValue,
        function()
            return addon:RoundToDecimals(getValue(), decimals)
        end,
        function(value)
            setValue(addon:RoundToDecimals(value, decimals))
        end
    )
    setting:SetValueChangedCallback(OnSettingChanged)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return addon:FormatSliderLabel(value, step)
    end)
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
    Settings.CreateDropdown(parentCategory, setting, function()
        local dropdownOptions = Settings.CreateControlTextContainer()
        for _, option in ipairs(optionsTable) do
            dropdownOptions:Add(option.value, option.label)
        end
        return dropdownOptions:GetData()
    end, tooltip)
    return setting
end

local function RegisterColorPicker(parentCategory, variable, name, getColorFn, tooltip)
    if not Settings.CreateButton then
        return
    end

    SafeCall(name, function()
        Settings.CreateButton(parentCategory, variable, name, tooltip, function()
            local color = addon:EnsureColorTable(getColorFn())
            addon:ShowColorPicker(color[1], color[2], color[3], color[4], function(r, g, b, a)
                color[1] = r
                color[2] = g
                color[3] = b
                color[4] = a
                OnSettingChanged()
            end)
        end)
    end)
end

local BAR_TEXTURE_OPTIONS = {
    { value = "Interface\\TargetingFrame\\UI-StatusBar", label = "Status Bar (default)" },
    { value = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill", label = "Raid HP Fill" },
    { value = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar", label = "Skills Bar" },
    { value = "Interface\\Buttons\\WHITE8X8", label = "Flat Solid" },
    { value = "Interface\\ChatFrame\\ChatFrameBackground", label = "Flat Soft" },
}

local BORDER_TEXTURE_OPTIONS = {
    { value = "Interface\\Tooltips\\UI-Tooltip-Border", label = "Tooltip Border" },
    { value = "Interface\\DialogFrame\\UI-DialogBox-Border", label = "Dialog Border" },
    { value = "Interface\\Buttons\\WHITE8X8", label = "Flat Line" },
}

local SOUND_OPTIONS = {
    { value = "RaidWarning", label = "Raid Warning" },
    { value = "AlarmClockWarning3", label = "Alarm Clock" },
    { value = "ReadyCheck", label = "Ready Check" },
    { value = "MapPing", label = "Map Ping" },
    { value = "IgPlayerInvite", label = "Invite" },
}

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

local function CreateCanvasSubcategory(parentCategory, panel, name, idSuffix)
    if not Settings.RegisterCanvasLayoutSubcategory then
        return
    end

    local subcategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, name)
    if subcategory then
        subcategory.ID = settingsCategoryID .. "/" .. idSuffix
        Settings.RegisterAddOnCategory(subcategory)
    end
end

local function CreateColorHexPanel(parentCategory, panelTitle, colorEntries, idSuffix)
    local panel = CreateFrame("Frame")
    panel.name = "Better Stagger " .. panelTitle

    local yOffset = -16
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, yOffset)
    title:SetText(panelTitle)

    yOffset = yOffset - 28
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", 16, yOffset)
    description:SetWidth(420)
    description:SetJustifyH("LEFT")
    description:SetText("Enter hex color codes (#RRGGBB or #RRGGBBAA). Use the color picker buttons on the main page, or edit codes here directly.")

    local editBoxes = {}

    for index, entry in ipairs(colorEntries) do
        yOffset = yOffset - 36

        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", 16, yOffset)
        label:SetWidth(140)
        label:SetJustifyH("LEFT")
        label:SetText(entry.label)

        local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        editBox:SetSize(180, 24)
        editBox:SetPoint("TOPLEFT", 160, yOffset + 4)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(16)
        editBoxes[index] = editBox

        local function ApplyEntry()
            local parsed = addon:ParseHexColor(editBox:GetText(), entry.getColor())
            if not parsed then
                print("|cffff0000Better Stagger:|r Invalid hex color for " .. entry.label .. ". Use #RRGGBB or #RRGGBBAA.")
                editBox:SetText(addon:ColorToHex(entry.getColor()))
                return
            end

            local color = entry.getColor()
            color[1] = parsed[1]
            color[2] = parsed[2]
            color[3] = parsed[3]
            color[4] = parsed[4]
            editBox:SetText(addon:ColorToHex(color))
            addon:RefreshFromDB()
        end

        editBox:SetScript("OnEnterPressed", function(self)
            ApplyEntry()
            self:ClearFocus()
        end)

        editBox:SetScript("OnEscapePressed", function(self)
            self:SetText(addon:ColorToHex(entry.getColor()))
            self:ClearFocus()
        end)

        local applyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        applyButton:SetSize(70, 24)
        applyButton:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
        applyButton:SetText("Apply")
        applyButton:SetScript("OnClick", ApplyEntry)
    end

    panel:SetScript("OnShow", function()
        for index, entry in ipairs(colorEntries) do
            editBoxes[index]:SetText(addon:ColorToHex(entry.getColor()))
        end
    end)

    CreateCanvasSubcategory(parentCategory, panel, panelTitle, idSuffix)
end

local function CreateTextFormatPanel(parentCategory)
    local panel = CreateFrame("Frame")
    panel.name = "Better Stagger Text Format"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Custom Text Format")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetWidth(440)
    description:SetJustifyH("LEFT")
    description:SetText("Build the bar text with placeholders and any literal characters (% signs, separators, labels). Example: {current}% / {max}%")

    local helpTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    helpTitle:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
    helpTitle:SetText("Available placeholders")

    local helpLines = {}
    local previous = helpTitle
    for index, placeholder in ipairs(addon.TEXT_TEMPLATE_PLACEHOLDERS) do
        local line = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, index == 1 and -6 or -2)
        line:SetWidth(440)
        line:SetJustifyH("LEFT")
        line:SetText(placeholder.token .. " - " .. placeholder.description)
        helpLines[index] = line
        previous = line
    end

    local editLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    editLabel:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -16)
    editLabel:SetText("Text template")

    local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    editBox:SetSize(360, 24)
    editBox:SetPoint("TOPLEFT", editLabel, "BOTTOMLEFT", 0, -6)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(128)

    local function ApplyTemplate()
        addon.db.text.template = editBox:GetText() or ""
        addon:RefreshFromDB()
    end

    editBox:SetScript("OnEnterPressed", function(self)
        ApplyTemplate()
        self:ClearFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(addon.db.text.template or "")
        self:ClearFocus()
    end)

    local applyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    applyButton:SetSize(80, 24)
    applyButton:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", ApplyTemplate)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(120, 24)
    resetButton:SetPoint("LEFT", applyButton, "RIGHT", 8, 0)
    resetButton:SetText("Reset Default")
    resetButton:SetScript("OnClick", function()
        addon:ResetTextTemplate()
        editBox:SetText(addon.db.text.template or "")
    end)

    panel:SetScript("OnShow", function()
        editBox:SetText(addon.db.text.template or "")
    end)

    CreateCanvasSubcategory(parentCategory, panel, "Text Format", "TextFormat")
end

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

    CreateCanvasSubcategory(parentCategory, panel, "Breakpoint Values", "BreakpointValues")
end

local function CreateColorThresholdsPanel(parentCategory)
    local panel = CreateFrame("Frame")
    panel.name = "Better Stagger Color Thresholds"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Color Thresholds")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetWidth(420)
    description:SetJustifyH("LEFT")
    description:SetText("Enter thresholds as percent,r,g,b,a pairs separated by semicolons. Example: 0,0.1,0.8,0.1,1; 100,0.9,0.9,0.1,1; 200,1,0.5,0,1")

    local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    editBox:SetSize(360, 24)
    editBox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(512)

    local function ApplyThresholds()
        local parsed = addon:ParseColorThresholdString(editBox:GetText())
        if #parsed == 0 then
            print("|cffff0000Better Stagger:|r Enter at least one valid threshold entry.")
            editBox:SetText(addon:FormatColorThresholdString(addon.db.colors.thresholds))
            return
        end

        addon.db.colors.thresholds = parsed
        editBox:SetText(addon:FormatColorThresholdString(parsed))
        addon:RefreshFromDB()
    end

    editBox:SetScript("OnEnterPressed", function(self)
        ApplyThresholds()
        self:ClearFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(addon:FormatColorThresholdString(addon.db.colors.thresholds))
        self:ClearFocus()
    end)

    local applyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    applyButton:SetSize(100, 24)
    applyButton:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", ApplyThresholds)

    panel:SetScript("OnShow", function()
        editBox:SetText(addon:FormatColorThresholdString(addon.db.colors.thresholds))
    end)

    CreateCanvasSubcategory(parentCategory, panel, "Color Thresholds", "ColorThresholds")
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

local function RegisterGeneralSettings(parentCategory, db)
    SafeCall("Lock Bar Position", function()
        RegisterCheckbox(parentCategory, "BS_Appearance_Locked", "locked", db.appearance, "Lock Bar Position", db.appearance.locked,
            "Prevent dragging the bar. Use /bs unlock to move it.")
    end)

    SafeCall("Test Mode", function()
        local settingTestMode = Settings.RegisterProxySetting(
            parentCategory,
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
        Settings.CreateCheckbox(parentCategory, settingTestMode, "Animate the bar with a random Stagger value every second (0 to scale max + 100%).")
    end)

    if Settings.CreateButton then
        SafeCall("Reset Bar Position", function()
            Settings.CreateButton(parentCategory, "BS_Reset_Position", "Reset Bar Position", "Reset the bar to its default screen position.", function()
                addon:ResetBarPosition()
                addon:RefreshFromDB()
            end)
        end)

        SafeCall("Reset All Settings", function()
            Settings.CreateButton(parentCategory, "BS_Reset_All", "Reset All Settings", "Restore all Better Stagger settings to defaults.", function()
                addon:ResetAllSettings()
                print("|cff00ff00Better Stagger:|r All settings reset to defaults.")
            end)
        end)
    end
end

local function RegisterAppearanceSettings(parentCategory, db)
    local appearance = db.appearance

    SafeCall("Bar Width", function()
        RegisterSlider(parentCategory, "BS_Appearance_Width", "Bar Width", appearance.width, 100, 600, 1,
            function() return db.appearance.width end,
            function(value) addon:SetBarSize(value, db.appearance.height) end,
            "Width of the stagger bar in pixels.")
    end)

    SafeCall("Bar Height", function()
        RegisterSlider(parentCategory, "BS_Appearance_Height", "Bar Height", appearance.height, 10, 60, 1,
            function() return db.appearance.height end,
            function(value) addon:SetBarSize(db.appearance.width, value) end,
            "Height of the stagger bar in pixels.")
    end)

    SafeCall("Bar Alpha", function()
        RegisterSlider(parentCategory, "BS_Appearance_BarAlpha", "Bar Alpha", appearance.barAlpha, 0, 1, 0.05,
            function() return db.appearance.barAlpha end,
            function(value) db.appearance.barAlpha = value end,
            "Opacity of the bar fill.")
    end)

    SafeCall("Background Alpha", function()
        RegisterSlider(parentCategory, "BS_Appearance_BackgroundAlpha", "Background Alpha", appearance.backgroundAlpha, 0, 1, 0.05,
            function() return db.appearance.backgroundAlpha end,
            function(value) db.appearance.backgroundAlpha = value end,
            "Opacity of the bar background.")
    end)

    RegisterColorPicker(parentCategory, "BS_Appearance_BackgroundPick", "Choose Background Color", function()
        db.appearance.backgroundColor = addon:EnsureColorTable(db.appearance.backgroundColor, { 0, 0, 0, 0.5 })
        return db.appearance.backgroundColor
    end, "Open the color picker for the bar background.")

    SafeCall("Bar Texture", function()
        RegisterDropdown(parentCategory, "BS_Appearance_BarTexture", "Bar Fill Texture", appearance.barTexture, BAR_TEXTURE_OPTIONS,
            function() return db.appearance.barTexture end,
            function(value) db.appearance.barTexture = value end,
            "Texture used for the stagger fill bar.")
    end)

    RegisterColorPicker(parentCategory, "BS_Appearance_BarColorPick", "Choose Bar Fill Color", function()
        db.appearance.barColor = addon:EnsureColorTable(db.appearance.barColor, { 0.1, 0.8, 0.1, 1 })
        return db.appearance.barColor
    end, "Static fill color when threshold colors are disabled.")

    SafeCall("Show Border", function()
        RegisterCheckbox(parentCategory, "BS_Appearance_Border", "borderEnabled", appearance, "Show Border", appearance.borderEnabled,
            "Draw a border around the bar.")
    end)

    SafeCall("Border Texture", function()
        RegisterDropdown(parentCategory, "BS_Appearance_BorderTexture", "Border Texture", appearance.borderTexture or "Interface\\Tooltips\\UI-Tooltip-Border", BORDER_TEXTURE_OPTIONS,
            function() return db.appearance.borderTexture end,
            function(value) db.appearance.borderTexture = value end,
            "Edge texture for the bar border.")
    end)

    SafeCall("Border Size", function()
        RegisterSlider(parentCategory, "BS_Appearance_BorderSize", "Border Size", appearance.borderSize or 12, 1, 32, 1,
            function() return db.appearance.borderSize or 12 end,
            function(value) db.appearance.borderSize = value end,
            "Thickness of the border edge texture.")
    end)

    RegisterColorPicker(parentCategory, "BS_Appearance_BorderPick", "Choose Border Color", function()
        db.appearance.borderColor = addon:EnsureColorTable(db.appearance.borderColor, { 0, 0, 0, 0.8 })
        return db.appearance.borderColor
    end, "Open the color picker for the bar border.")

    SafeCall("Border Alpha", function()
        RegisterSlider(parentCategory, "BS_Appearance_BorderAlpha", "Border Alpha", appearance.borderAlpha or 0.8, 0, 1, 0.05,
            function() return db.appearance.borderAlpha or 0.8 end,
            function(value) db.appearance.borderAlpha = value end,
            "Opacity of the border edge.")
    end)

    CreateColorHexPanel(parentCategory, "Color Hex Codes", {
        {
            label = "Background",
            getColor = function()
                db.appearance.backgroundColor = addon:EnsureColorTable(db.appearance.backgroundColor, { 0, 0, 0, 0.5 })
                return db.appearance.backgroundColor
            end,
        },
        {
            label = "Bar Fill",
            getColor = function()
                db.appearance.barColor = addon:EnsureColorTable(db.appearance.barColor, { 0.1, 0.8, 0.1, 1 })
                return db.appearance.barColor
            end,
        },
        {
            label = "Border",
            getColor = function()
                db.appearance.borderColor = addon:EnsureColorTable(db.appearance.borderColor, { 0, 0, 0, 0.8 })
                return db.appearance.borderColor
            end,
        },
    }, "AppearanceColors")
end

local function RegisterScaleSettings(parentCategory, db)
    local scale = db.scale

    SafeCall("Scale Mode", function()
        RegisterDropdown(parentCategory, "BS_Scale_Mode", "Scale Mode", scale.mode, {
            { value = "fixed", label = "Fixed Linear" },
            { value = "dynamic", label = "Peak-Based Dynamic" },
        },
            function() return db.scale.mode end,
            function(value) db.scale.mode = value end,
            "Fixed uses a set maximum. Dynamic adjusts based on recent peak Stagger.")
    end)

    SafeCall("Fixed Scale Maximum", function()
        RegisterSlider(parentCategory, "BS_Scale_FixedMax", "Fixed Scale Maximum (%)", scale.fixedMaximum, 100, 1000, 10,
            function() return db.scale.fixedMaximum end,
            function(value) db.scale.fixedMaximum = value end,
            "Upper end of the bar in fixed mode. 200% Stagger with 400% max fills half the bar.")
    end)

    SafeCall("Dynamic Window", function()
        RegisterSlider(parentCategory, "BS_Scale_DynamicWindow", "Dynamic Window (seconds)", scale.dynamicWindowSeconds, 5, 60, 1,
            function() return db.scale.dynamicWindowSeconds end,
            function(value) db.scale.dynamicWindowSeconds = value end,
            "How far back to look for peak Stagger in dynamic mode.")
    end)

    SafeCall("Dynamic Buffer", function()
        RegisterSlider(parentCategory, "BS_Scale_DynamicBuffer", "Dynamic Buffer (%)", scale.dynamicBufferPercent, 0, 100, 5,
            function() return db.scale.dynamicBufferPercent end,
            function(value) db.scale.dynamicBufferPercent = value end,
            "Extra headroom above the recent peak in dynamic mode.")
    end)

    SafeCall("Dynamic Minimum Max", function()
        RegisterSlider(parentCategory, "BS_Scale_DynamicMin", "Dynamic Minimum Max (%)", scale.dynamicMinimumMaximum, 50, 500, 10,
            function() return db.scale.dynamicMinimumMaximum end,
            function(value) db.scale.dynamicMinimumMaximum = value end,
            "Lowest scale maximum in dynamic mode.")
    end)

    SafeCall("Dynamic Maximum Max", function()
        RegisterSlider(parentCategory, "BS_Scale_DynamicMax", "Dynamic Maximum Max (%)", scale.dynamicMaximumMaximum, 100, 1000, 10,
            function() return db.scale.dynamicMaximumMaximum end,
            function(value) db.scale.dynamicMaximumMaximum = value end,
            "Highest scale maximum in dynamic mode.")
    end)

    SafeCall("Dynamic Rounding Step", function()
        RegisterSlider(parentCategory, "BS_Scale_DynamicStep", "Dynamic Rounding Step (%)", scale.dynamicRoundingStep, 10, 100, 10,
            function() return db.scale.dynamicRoundingStep end,
            function(value) db.scale.dynamicRoundingStep = value end,
            "Round dynamic maximum up to this step for readability.")
    end)
end

local function RegisterBreakpointSettings(parentCategory, db)
    local breakpoints = db.breakpoints

    SafeCall("Show Breakpoints", function()
        RegisterCheckbox(parentCategory, "BS_Breakpoints_Enabled", "enabled", breakpoints, "Show Breakpoints", breakpoints.enabled,
            "Show vertical lines at configured Stagger percentages.")
    end)

    SafeCall("Breakpoint Thickness", function()
        RegisterSlider(parentCategory, "BS_Breakpoints_Thickness", "Breakpoint Thickness", breakpoints.thickness, 1, 5, 1,
            function() return db.breakpoints.thickness end,
            function(value) db.breakpoints.thickness = value end,
            "Line thickness for breakpoint markers.")
    end)

    SafeCall("Show Breakpoint Labels", function()
        RegisterCheckbox(parentCategory, "BS_Breakpoints_Labels", "labelsEnabled", breakpoints, "Show Breakpoint Labels", breakpoints.labelsEnabled,
            "Show percentage labels on breakpoint lines.")
    end)

    SafeCall("Breakpoint Label Position", function()
        RegisterDropdown(parentCategory, "BS_Breakpoints_LabelPosition", "Breakpoint Label Position", breakpoints.labelPosition or "above", LABEL_POSITION_OPTIONS,
            function() return db.breakpoints.labelPosition or "above" end,
            function(value) db.breakpoints.labelPosition = value end,
            "Where breakpoint labels appear relative to their line.")
    end)

    RegisterColorPicker(parentCategory, "BS_Breakpoints_ColorPick", "Choose Breakpoint Line Color", function()
        db.breakpoints.color = addon:EnsureColorTable(db.breakpoints.color, { 1, 1, 1, 0.6 })
        return db.breakpoints.color
    end, "Open the color picker for breakpoint marker lines.")

    CreateColorHexPanel(parentCategory, "Breakpoint Color Hex", {
        {
            label = "Breakpoint Line",
            getColor = function()
                db.breakpoints.color = addon:EnsureColorTable(db.breakpoints.color, { 1, 1, 1, 0.6 })
                return db.breakpoints.color
            end,
        },
    }, "BreakpointColors")

    CreateBreakpointsPanel(parentCategory)
end

local function RegisterColorsAndAlertsSettings(parentCategory, db)
    local glow = db.glow
    local sound = db.sound

    SafeCall("Use Threshold Colors", function()
        RegisterCheckbox(parentCategory, "BS_Colors_Enabled", "enabled", db.colors, "Use Threshold Colors", db.colors.enabled,
            "Color the fill bar by Stagger thresholds. Turn off to use the static Bar Fill Color.")
    end)

    SafeCall("Enable Glow Warning", function()
        RegisterCheckbox(parentCategory, "BS_Glow_Enabled", "enabled", glow, "Enable Glow Warning", glow.enabled,
            "Highlight the bar when Stagger exceeds the glow threshold.")
    end)

    SafeCall("Glow Threshold", function()
        RegisterSlider(parentCategory, "BS_Glow_Threshold", "Glow Threshold (%)", glow.threshold, 50, 800, 10,
            function() return db.glow.threshold end,
            function(value) db.glow.threshold = value end,
            "Stagger percentage at which the glow appears.")
    end)

    SafeCall("Enable Sound Warning", function()
        RegisterCheckbox(parentCategory, "BS_Sound_Enabled", "enabled", sound, "Enable Sound Warning", sound.enabled,
            "Play a sound when Stagger exceeds the sound threshold.")
    end)

    SafeCall("Sound Threshold", function()
        RegisterSlider(parentCategory, "BS_Sound_Threshold", "Sound Threshold (%)", sound.threshold, 50, 1000, 10,
            function() return db.sound.threshold end,
            function(value) db.sound.threshold = value end,
            "Stagger percentage that triggers the sound alert.")
    end)

    SafeCall("Sound Cooldown", function()
        RegisterSlider(parentCategory, "BS_Sound_Cooldown", "Sound Cooldown (seconds)", sound.cooldownSeconds, 1, 60, 1,
            function() return db.sound.cooldownSeconds end,
            function(value) db.sound.cooldownSeconds = value end,
            "Minimum time between sound alerts.")
    end)

    SafeCall("Sound File", function()
        RegisterDropdown(parentCategory, "BS_Sound_File", "Sound", sound.soundFile or "RaidWarning", SOUND_OPTIONS,
            function() return db.sound.soundFile or "RaidWarning" end,
            function(value) db.sound.soundFile = value end,
            "Blizzard sound played when the sound threshold is exceeded.")
    end)

    CreateColorThresholdsPanel(parentCategory)
end

local function RegisterTextSettings(parentCategory, db)
    local text = db.text

    SafeCall("Show Bar Text", function()
        RegisterCheckbox(parentCategory, "BS_Text_Enabled", "enabled", text, "Show Bar Text", text.enabled,
            "Display Stagger text on the bar. Turn off to hide all bar text.")
    end)

    SafeCall("Text Anchor", function()
        RegisterDropdown(parentCategory, "BS_Text_Anchor", "Text Anchor", text.point or "CENTER", TEXT_ANCHOR_OPTIONS,
            function() return db.text.point or "CENTER" end,
            function(value) db.text.point = value end,
            "Where the text is anchored on the bar.")
    end)

    SafeCall("Text Offset X", function()
        RegisterSlider(parentCategory, "BS_Text_OffsetX", "Text Offset X", text.x or 0, -200, 200, 1,
            function() return db.text.x or 0 end,
            function(value) db.text.x = value end,
            "Horizontal text offset in pixels.")
    end)

    SafeCall("Text Offset Y", function()
        RegisterSlider(parentCategory, "BS_Text_OffsetY", "Text Offset Y", text.y or 0, -50, 50, 1,
            function() return db.text.y or 0 end,
            function(value) db.text.y = value end,
            "Vertical text offset in pixels.")
    end)

    SafeCall("Text Font Size", function()
        RegisterSlider(parentCategory, "BS_Text_FontSize", "Text Font Size", text.fontSize, 8, 24, 1,
            function() return db.text.fontSize end,
            function(value) db.text.fontSize = value end,
            "Font size for bar text.")
    end)

    RegisterColorPicker(parentCategory, "BS_Text_ColorPick", "Choose Text Color", function()
        db.text.color = addon:EnsureColorTable(db.text.color, { 1, 1, 1, 1 })
        return db.text.color
    end, "Open the color picker for bar text.")

    CreateColorHexPanel(parentCategory, "Text Color Hex", {
        {
            label = "Text",
            getColor = function()
                db.text.color = addon:EnsureColorTable(db.text.color, { 1, 1, 1, 1 })
                return db.text.color
            end,
        },
    }, "TextColors")

    CreateTextFormatPanel(parentCategory)
end

local function RegisterVisibilitySettings(parentCategory, db)
    local visibility = db.visibility

    SafeCall("Show Only as Brewmaster", function()
        RegisterCheckbox(parentCategory, "BS_Visibility_Brewmaster", "showOnlyBrewmaster", visibility, "Show Only as Brewmaster", visibility.showOnlyBrewmaster,
            "Hide the bar unless you are a Brewmaster Monk.")
    end)

    SafeCall("Hide Out of Combat", function()
        RegisterCheckbox(parentCategory, "BS_Visibility_Combat", "hideOutOfCombat", visibility, "Hide Out of Combat", visibility.hideOutOfCombat,
            "Only show the bar while in combat.")
    end)

    SafeCall("Hide When Stagger is 0", function()
        RegisterCheckbox(parentCategory, "BS_Visibility_Zero", "hideIfZero", visibility, "Hide When Stagger is 0", visibility.hideIfZero,
            "Hide the bar when you have no Stagger.")
    end)
end

local function RegisterPerformanceSettings(parentCategory, db)
    SafeCall("Update Interval", function()
        RegisterSlider(parentCategory, "BS_Performance_Interval", "Update Interval (seconds)", db.performance.updateIntervalSeconds, 0.05, 0.5, 0.05,
            function() return addon:GetUpdateInterval() end,
            function(value) db.performance.updateIntervalSeconds = addon:Clamp(value, 0.05, 0.5) end,
            "How often the bar polls Stagger. Lower = more responsive, higher = lighter on performance. Default: 0.1")
    end)
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
    Settings.RegisterAddOnCategory(category)
    addon.configPanelInitialized = true

    local generalCategory = RegisterSubcategory(category, "General")
    local appearanceCategory = RegisterSubcategory(category, "Appearance")
    local scaleCategory = RegisterSubcategory(category, "Scale")
    local breakpointsCategory = RegisterSubcategory(category, "Breakpoints")
    local colorsCategory = RegisterSubcategory(category, "Colors and Alerts")
    local textCategory = RegisterSubcategory(category, "Text")
    local visibilityCategory = RegisterSubcategory(category, "Visibility")
    local performanceCategory = RegisterSubcategory(category, "Performance")

    if generalCategory then
        RegisterGeneralSettings(generalCategory, db)
    end
    if appearanceCategory then
        RegisterAppearanceSettings(appearanceCategory, db)
    end
    if scaleCategory then
        RegisterScaleSettings(scaleCategory, db)
    end
    if breakpointsCategory then
        RegisterBreakpointSettings(breakpointsCategory, db)
    end
    if colorsCategory then
        RegisterColorsAndAlertsSettings(colorsCategory, db)
    end
    if textCategory then
        RegisterTextSettings(textCategory, db)
    end
    if visibilityCategory then
        RegisterVisibilitySettings(visibilityCategory, db)
    end
    if performanceCategory then
        RegisterPerformanceSettings(performanceCategory, db)
    end
end
