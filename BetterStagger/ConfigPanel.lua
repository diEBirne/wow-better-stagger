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

local function CreateSectionHeader(parentCategory, title)
    if Settings.CreateSectionHeader then
        Settings.CreateSectionHeader(parentCategory, title)
    end
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

local function RegisterDropdown(parentCategory, variable, name, defaultValue, optionsTable, getValue, setValue, tooltip, onPreview)
    local setting = Settings.RegisterProxySetting(
        parentCategory,
        variable,
        type(defaultValue),
        name,
        defaultValue,
        getValue,
        function(value)
            setValue(value)
            if onPreview then
                onPreview(value)
            end
        end
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

local function HasLibEditMode()
    return addon.GetLibEditMode and addon:GetLibEditMode() ~= nil
end

local RULE_ROW_HEIGHT = 30
local RULE_VALUE_X = 16
local RULE_PERCENT_X = 72
local RULE_COLOR_X = 110
local RULE_REMOVE_X = 200
local PROFILE_BASE_HEIGHT = 300

local function CreateRemoveRuleButton(parent, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(22, 22)
    button:SetText("-")

    local fontString = button:GetFontString()
    if fontString then
        fontString:ClearAllPoints()
        fontString:SetPoint("CENTER", button, "CENTER", 0, 0)
        fontString:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    end

    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove breakpoint", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

local function UpdateColorSwatch(swatch, color)
    color = addon:EnsureColorTable(color)
    swatch.texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

local function CreateColorSwatch(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", -1, 1)
    button.texture = texture

    button:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bar color from this Stagger %", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

local function RebuildProfileRules(widgets)
    local rules = addon:GetBreakpointRules()
    widgets.ruleRows = widgets.ruleRows or {}

    for index, rule in ipairs(rules) do
        local row = widgets.ruleRows[index]
        if not row then
            row = {}
            widgets.ruleRows[index] = row

            row.valueEdit = CreateFrame("EditBox", nil, widgets.content, "InputBoxTemplate")
            row.valueEdit:SetSize(48, 24)
            row.valueEdit:SetAutoFocus(false)
            row.valueEdit:SetMaxLetters(4)

            row.percentLabel = widgets.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.percentLabel:SetText("%")

            row.colorSwatch = CreateColorSwatch(widgets.content)

            row.removeButton = CreateRemoveRuleButton(widgets.content, function()
                if addon:RemoveBreakpointRule(index) then
                    RebuildProfileRules(widgets)
                end
            end)
        end

        local rowOffset = -4 - ((index - 1) * RULE_ROW_HEIGHT)
        row.valueEdit:ClearAllPoints()
        row.valueEdit:SetPoint("TOPLEFT", widgets.valueHeader, "BOTTOMLEFT", 0, rowOffset)
        row.valueEdit:SetText(tostring(rule.value))
        row.valueEdit:SetScript("OnEnterPressed", function(editBox)
            addon:UpdateBreakpointRuleValue(index, editBox:GetText())
            RebuildProfileRules(widgets)
            editBox:ClearFocus()
        end)
        row.valueEdit:SetScript("OnEditFocusLost", function(editBox)
            addon:UpdateBreakpointRuleValue(index, editBox:GetText())
            RebuildProfileRules(widgets)
        end)

        row.percentLabel:ClearAllPoints()
        row.percentLabel:SetPoint("LEFT", row.valueEdit, "RIGHT", 4, 0)

        row.colorSwatch:ClearAllPoints()
        row.colorSwatch:SetPoint("TOPLEFT", widgets.valueHeader, "BOTTOMLEFT", RULE_COLOR_X - 16, rowOffset)
        UpdateColorSwatch(row.colorSwatch, rule.color)
        row.colorSwatch:SetScript("OnClick", function()
            local currentRules = addon:GetBreakpointRules()
            local currentRule = currentRules[index]
            if not currentRule then
                RebuildProfileRules(widgets)
                return
            end

            local color = addon:EnsureColorTable(currentRule.color)
            addon:ShowColorPicker(color[1], color[2], color[3], color[4], function(r, g, b, a)
                addon:UpdateBreakpointRuleColor(index, r, g, b, a)
                RebuildProfileRules(widgets)
            end)
        end)

        row.removeButton:ClearAllPoints()
        row.removeButton:SetPoint("TOPLEFT", widgets.valueHeader, "BOTTOMLEFT", RULE_REMOVE_X - 16, rowOffset + 1)
        row.removeButton:SetScript("OnClick", function()
            if addon:RemoveBreakpointRule(index) then
                RebuildProfileRules(widgets)
            end
        end)

        row.valueEdit:Show()
        row.percentLabel:Show()
        row.colorSwatch:Show()
        row.removeButton:Show()
    end

    for index = #rules + 1, #widgets.ruleRows do
        local row = widgets.ruleRows[index]
        if row then
            row.valueEdit:Hide()
            row.percentLabel:Hide()
            row.colorSwatch:Hide()
            row.removeButton:Hide()
        end
    end

    local rulesBottomOffset = -4 - (#rules * RULE_ROW_HEIGHT) - 8
    widgets.addRuleButton:ClearAllPoints()
    widgets.addRuleButton:SetPoint("TOPLEFT", widgets.valueHeader, "BOTTOMLEFT", 0, rulesBottomOffset)

    widgets.content:SetHeight(PROFILE_BASE_HEIGHT + (#rules * RULE_ROW_HEIGHT))
end

local function CreateProfilePanel(parentCategory)
    if not Settings.RegisterCanvasLayoutSubcategory then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = "Better Stagger Profile"

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(500, PROFILE_BASE_HEIGHT)
    scrollFrame:SetScrollChild(content)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Profile")

    local intro = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    intro:SetWidth(440)
    intro:SetJustifyH("LEFT")
    intro:SetText("Reset options and breakpoint color rules. Position and style are configured in Edit Mode.")

    local resetPosButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetPosButton:SetSize(160, 24)
    resetPosButton:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
    resetPosButton:SetText("Reset Bar Position")
    resetPosButton:SetScript("OnClick", function()
        addon:ResetBarPosition()
        addon:RefreshFromDB()
    end)

    local resetAllButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetAllButton:SetSize(160, 24)
    resetAllButton:SetPoint("LEFT", resetPosButton, "RIGHT", 8, 0)
    resetAllButton:SetText("Reset All Settings")
    resetAllButton:SetScript("OnClick", function()
        addon:ResetAllSettings()
        print("|cff00ff00Better Stagger:|r All settings reset to defaults.")
    end)

    local rulesTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rulesTitle:SetPoint("TOPLEFT", resetPosButton, "BOTTOMLEFT", 0, -24)
    rulesTitle:SetText("Breakpoint Color Rules")

    local rulesHelp = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    rulesHelp:SetPoint("TOPLEFT", rulesTitle, "BOTTOMLEFT", 0, -6)
    rulesHelp:SetWidth(440)
    rulesHelp:SetJustifyH("LEFT")
    rulesHelp:SetText("Each rule sets the bar fill color from that Stagger %. Vertical marker lines appear for rules above 0%.")

    local valueHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    valueHeader:SetPoint("TOPLEFT", rulesHelp, "BOTTOMLEFT", 0, -10)
    valueHeader:SetText("At %")

    local colorHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    colorHeader:SetPoint("TOPLEFT", rulesHelp, "BOTTOMLEFT", RULE_COLOR_X - 16, -10)
    colorHeader:SetText("Bar Color")

    local addRuleButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    addRuleButton:SetSize(120, 24)
    addRuleButton:SetText("Add Rule")
    addRuleButton:SetScript("OnClick", function()
        if addon:AddBreakpointRule() then
            RebuildProfileRules(panel.widgets)
        end
    end)

    panel.widgets = {
        content = content,
        valueHeader = valueHeader,
        ruleRows = {},
        addRuleButton = addRuleButton,
    }

    panel:SetScript("OnShow", function()
        RebuildProfileRules(panel.widgets)
    end)

    RebuildProfileRules(panel.widgets)

    local subcategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, "Profile")
    if subcategory then
        subcategory.ID = settingsCategoryID .. "/Profile"
        Settings.RegisterAddOnCategory(subcategory)
    end
end

local function RegisterFallbackAppearanceSettings(parentCategory, db)
    local appearance = db.appearance

    CreateSectionHeader(parentCategory, "Position and Style (Fallback)")

    SafeCall("Attach To Frame", function()
        RegisterDropdown(parentCategory, "BS_Attach_Frame", "Attach To Frame", appearance.attachFrame or "UIParent", addon.ATTACH_FRAME_OPTIONS,
            function() return db.appearance.attachFrame or "UIParent" end,
            function(value)
                addon:SetAttachFrame(value)
            end,
            "Install LibEditMode for full Edit Mode integration. Anchor the bar to a Blizzard UI frame.")
    end)

    SafeCall("Position X", function()
        RegisterSlider(parentCategory, "BS_Position_X", "Position X", appearance.x or 0, -2000, 2000, 1,
            function() return db.appearance.x or 0 end,
            function(value) db.appearance.x = value end,
            "Horizontal offset in pixels.")
    end)

    SafeCall("Position Y", function()
        RegisterSlider(parentCategory, "BS_Position_Y", "Position Y", appearance.y or 0, -2000, 2000, 1,
            function() return db.appearance.y or 0 end,
            function(value) db.appearance.y = value end,
            "Vertical offset in pixels.")
    end)

    SafeCall("Bar Width", function()
        RegisterSlider(parentCategory, "BS_Appearance_Width", "Bar Width", appearance.width, 100, 600, 1,
            function() return db.appearance.width end,
            function(value) addon:SetBarSize(value, db.appearance.height) end,
            "Width of the stagger bar in pixels.")
    end)
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
    local glow = db.glow
    local sound = db.sound
    local visibility = db.visibility
    local useEditMode = HasLibEditMode()

    category = Settings.RegisterVerticalLayoutCategory(settingsCategoryID)
    category.ID = settingsCategoryID
    Settings.RegisterAddOnCategory(category)
    addon.configPanelInitialized = true

    CreateSectionHeader(category, "General")

    if useEditMode and Settings.CreateButton then
        SafeCall("Open Edit Mode", function()
            Settings.CreateButton(category, "BS_Open_EditMode", "Open Edit Mode", "Configure position, appearance, text, and breakpoint styling.", function()
                addon:OpenEditMode()
            end)
        end)
    elseif Settings.CreateButton then
        SafeCall("Edit Mode Info", function()
            Settings.CreateButton(category, "BS_EditMode_Info", "Edit Mode Unavailable", "LibEditMode could not be loaded. Reinstall Better Stagger or reload the UI.", function()
                print("|cffff0000Better Stagger:|r LibEditMode is missing. Try /reload.")
            end)
        end)
    end

    SafeCall("Lock Bar Position", function()
        RegisterCheckbox(category, "BS_Appearance_Locked", "locked", db.appearance, "Lock Bar Position", db.appearance.locked,
            "Prevent dragging the bar outside Edit Mode.")
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
        Settings.CreateCheckbox(category, settingTestMode, "Animate the bar with a random Stagger value every second (0 to scale max + 100%).")
    end)

    if not useEditMode then
        RegisterFallbackAppearanceSettings(category, db)
    end

    CreateSectionHeader(category, "Scale")

    SafeCall("Scale Maximum", function()
        RegisterSlider(category, "BS_Scale_FixedMax", "Scale Maximum (%)", db.scale.fixedMaximum, 100, 1000, 10,
            function() return db.scale.fixedMaximum end,
            function(value) db.scale.fixedMaximum = value end,
            "Upper end of the bar. 200% Stagger with 400% max fills half the bar.")
    end)

    CreateSectionHeader(category, "Colors and Alerts")

    SafeCall("Use Threshold Colors", function()
        RegisterCheckbox(category, "BS_Colors_Enabled", "enabled", db.colors, "Use Threshold Colors", db.colors.enabled,
            "Color the fill bar using breakpoint rules on the Profile page.")
    end)

    SafeCall("Enable Glow Warning", function()
        RegisterCheckbox(category, "BS_Glow_Enabled", "enabled", glow, "Enable Glow Warning", glow.enabled,
            "Highlight the border when Stagger exceeds the glow threshold.")
    end)

    SafeCall("Glow Threshold", function()
        RegisterSlider(category, "BS_Glow_Threshold", "Glow Threshold (%)", glow.threshold, 50, 800, 10,
            function() return db.glow.threshold end,
            function(value) db.glow.threshold = value end,
            "Stagger percentage at which the border glow appears.")
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

    SafeCall("Preview Sound", function()
        if Settings.CreateButton then
            Settings.CreateButton(category, "BS_Sound_Preview", "Preview Current Sound", "Play the selected alert sound once.", function()
                if not addon:PreviewAlertSound(db.sound.soundFile) then
                    print("|cffff0000Better Stagger:|r Could not play the selected sound.")
                end
            end)
        end
    end)

    SafeCall("Sound File", function()
        RegisterDropdown(category, "BS_Sound_File", "Sound", addon:NormalizeSoundKey(sound.soundFile), addon.SOUND_OPTIONS,
            function() return addon:NormalizeSoundKey(db.sound.soundFile) end,
            function(value) db.sound.soundFile = addon:NormalizeSoundKey(value) end,
            "Blizzard sound played when the sound threshold is exceeded. Selecting a sound plays a preview.",
            function(value)
                addon:PreviewAlertSound(value)
            end)
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
        RegisterSlider(category, "BS_Performance_Interval", "Update Interval (seconds)", db.performance.updateIntervalSeconds, 0.05, 0.5, 0.05,
            function() return addon:GetUpdateInterval() end,
            function(value) db.performance.updateIntervalSeconds = addon:Clamp(value, 0.05, 0.5) end,
            "How often the bar polls Stagger. Lower = more responsive, higher = lighter on performance. Default: 0.1")
    end)

    CreateProfilePanel(category)
end
