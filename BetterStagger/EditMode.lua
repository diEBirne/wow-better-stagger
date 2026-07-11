local addonName, addon = ...

local BAR_TEXTURE_OPTIONS = {
    { text = "Status Bar (default)", value = "Interface\\TargetingFrame\\UI-StatusBar" },
    { text = "Raid HP Fill", value = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { text = "Skills Bar", value = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    { text = "Flat Solid", value = "Interface\\Buttons\\WHITE8X8" },
    { text = "Flat Soft", value = "Interface\\ChatFrame\\ChatFrameBackground" },
}

local BORDER_TEXTURE_OPTIONS = {
    { text = "Tooltip Border", value = "Interface\\Tooltips\\UI-Tooltip-Border" },
    { text = "Dialog Border", value = "Interface\\DialogFrame\\UI-DialogBox-Border" },
    { text = "Flat Line", value = "Interface\\Buttons\\WHITE8X8" },
}

local TEXT_ANCHOR_OPTIONS = {
    { text = "Center", value = "CENTER" },
    { text = "Left", value = "LEFT" },
    { text = "Right", value = "RIGHT" },
    { text = "Top", value = "TOP" },
    { text = "Bottom", value = "BOTTOM" },
}

local LABEL_POSITION_OPTIONS = {
    { text = "Above line", value = "above" },
    { text = "Below line", value = "below" },
    { text = "On line (centered)", value = "center" },
}

local WIDTH_MODE_OPTIONS = {
    { text = "Manual", value = "Manual" },
    { text = "Sync With Essential Cooldowns", value = "Sync With Essential Cooldowns" },
}

local function BuildWidthModeOptions()
    local options = {}
    for _, entry in ipairs(addon.WIDTH_MODE_OPTIONS or WIDTH_MODE_OPTIONS) do
        options[#options + 1] = { text = entry.label or entry.text, value = entry.value }
    end
    return options
end

local function IsSectionExpanded(sectionKey)
    local sections = addon.db.appearance.sectionExpanded
    if not sections or sections[sectionKey] == nil then
        return sectionKey == "position"
    end
    return sections[sectionKey] == true
end

local function SetSectionExpanded(sectionKey, expanded)
    addon.db.appearance.sectionExpanded = addon.db.appearance.sectionExpanded or {}
    addon.db.appearance.sectionExpanded[sectionKey] = expanded
end

local function ExpanderKind()
    local lib = addon:GetLibEditMode()
    if lib and lib.SettingType and lib.SettingType.Expander then
        return lib.SettingType.Expander
    end
    return "expander"
end

local function ExpanderSetting(sectionKey, title, defaultExpanded)
    return {
        kind = ExpanderKind(),
        name = title,
        default = defaultExpanded,
        get = function(_layoutName)
            return IsSectionExpanded(sectionKey)
        end,
        set = function(_layoutName, value)
            SetSectionExpanded(sectionKey, value)
        end,
    }
end

local function WithSection(sectionKey, setting)
    local originalHidden = setting.hidden
    setting.hidden = function(_layoutName)
        if not IsSectionExpanded(sectionKey) then
            return true
        end
        if type(originalHidden) == "function" then
            return originalHidden(_layoutName)
        end
        return originalHidden or false
    end
    return setting
end

local function AppendSection(target, sectionKey, title, defaultExpanded, settings)
    target[#target + 1] = ExpanderSetting(sectionKey, title, defaultExpanded)
    for _, setting in ipairs(settings) do
        target[#target + 1] = WithSection(sectionKey, setting)
    end
end

local function IsManualWidthMode()
    return (addon.db.appearance.widthMode or "Manual") == "Manual"
end

local function IsSyncedWidthMode()
    return (addon.db.appearance.widthMode or "Manual") == "Sync With Essential Cooldowns"
end

local function ToColorMixin(color)
    color = addon:EnsureColorTable(color)
    return CreateColor(color[1], color[2], color[3], color[4] or 1)
end

local function FromColorMixin(colorMixin, fallback)
    if not colorMixin then
        return fallback
    end
    return { colorMixin.r, colorMixin.g, colorMixin.b, colorMixin.a }
end

local function DropdownSetting(name, desc, default, values, getter, setter, options)
    options = options or {}
    local setting = {
        kind = Enum.EditModeSettingDisplayType.Dropdown,
        name = name,
        desc = desc,
        default = default,
        values = values,
        get = function(_layoutName)
            return getter()
        end,
        set = function(_layoutName, value)
            setter(value)
            addon:RefreshFromDB()
        end,
    }
    if options.disabled then
        setting.disabled = options.disabled
    end
    if options.hidden then
        setting.hidden = options.hidden
    end
    return setting
end

local function SliderSetting(name, desc, default, minValue, maxValue, step, getter, setter, formatter, options)
    options = options or {}
    local decimals = step >= 1 and 0 or 2
    local setting = {
        kind = Enum.EditModeSettingDisplayType.Slider,
        name = name,
        desc = desc,
        default = default,
        minValue = minValue,
        maxValue = maxValue,
        valueStep = step,
        formatter = formatter,
        get = function(_layoutName)
            return getter()
        end,
        set = function(_layoutName, value)
            setter(value)
            addon:RefreshFromDB()
        end,
    }
    if options.disabled then
        setting.disabled = options.disabled
    end
    if options.hidden then
        setting.hidden = options.hidden
    end
    return setting
end

local function CheckboxSetting(name, desc, default, getter, setter, options)
    options = options or {}
    local setting = {
        kind = Enum.EditModeSettingDisplayType.Checkbox,
        name = name,
        desc = desc,
        default = default,
        get = function(_layoutName)
            return getter()
        end,
        set = function(_layoutName, value)
            setter(value)
            addon:RefreshFromDB()
        end,
    }
    if options.disabled then
        setting.disabled = options.disabled
    end
    if options.hidden then
        setting.hidden = options.hidden
    end
    return setting
end

local function ColorSetting(name, desc, defaultColor, getter, setter, options)
    options = options or {}
    local setting = {
        kind = 10,
        name = name,
        desc = desc,
        default = ToColorMixin(defaultColor),
        hasOpacity = true,
        get = function(_layoutName)
            return ToColorMixin(getter())
        end,
        set = function(_layoutName, value)
            setter(FromColorMixin(value, getter()))
            addon:RefreshFromDB()
        end,
    }
    if options.disabled then
        setting.disabled = options.disabled
    end
    if options.hidden then
        setting.hidden = options.hidden
    end
    return setting
end

local function BuildAttachFrameOptions()
    local options = {}
    for _, entry in ipairs(addon.ATTACH_FRAME_OPTIONS) do
        options[#options + 1] = { text = entry.label, value = entry.value }
    end
    return options
end

local function BuildAnchorOptions(source)
    local options = {}
    for _, entry in ipairs(source) do
        options[#options + 1] = { text = entry.label or entry.text, value = entry.value }
    end
    return options
end

function addon:BuildEditModeSettings()
    local db = self.db
    local appearance = db.appearance
    local text = db.text
    local breakpoints = db.breakpoints
    local settings = {}

    AppendSection(settings, "position", "Position and Size", true, {
        DropdownSetting(
            "Attach To Frame",
            "Anchor the bar to a Blizzard frame or the free screen position.",
            appearance.attachFrame or "UIParent",
            BuildAttachFrameOptions(),
            function() return db.appearance.attachFrame or "UIParent" end,
            function(value)
                addon:SetAttachFrame(value)
            end
        ),
        DropdownSetting(
            "Anchor Point",
            "Which point on the bar is anchored.",
            appearance.point or "CENTER",
            BuildAnchorOptions(addon.ANCHOR_POINT_OPTIONS),
            function() return db.appearance.point or "CENTER" end,
            function(value) db.appearance.point = value end
        ),
        DropdownSetting(
            "Relative Anchor",
            "Which point on the parent frame to attach to.",
            appearance.relativePoint or "CENTER",
            BuildAnchorOptions(addon.ANCHOR_POINT_OPTIONS),
            function() return db.appearance.relativePoint or "CENTER" end,
            function(value) db.appearance.relativePoint = value end
        ),
        SliderSetting(
            "Offset X",
            "Horizontal offset from the anchor point.",
            appearance.x or 0,
            -2000,
            2000,
            1,
            function() return math.floor((db.appearance.x or 0) + 0.5) end,
            function(value) db.appearance.x = math.floor(value + 0.5) end,
            function(value) return tostring(math.floor(value + 0.5)) end
        ),
        SliderSetting(
            "Offset Y",
            "Vertical offset from the anchor point.",
            appearance.y or 0,
            -2000,
            2000,
            1,
            function() return math.floor((db.appearance.y or 0) + 0.5) end,
            function(value) db.appearance.y = math.floor(value + 0.5) end,
            function(value) return tostring(math.floor(value + 0.5)) end
        ),
        DropdownSetting(
            "Width Mode",
            "Match the bar width to another UI element or set it manually.",
            appearance.widthMode or "Manual",
            BuildWidthModeOptions(),
            function() return db.appearance.widthMode or "Manual" end,
            function(value)
                db.appearance.widthMode = value
                addon:ApplyEffectiveBarSize()
            end
        ),
        SliderSetting(
            "Bar Width",
            "Width of the stagger bar in pixels.",
            appearance.width,
            100,
            600,
            1,
            function() return db.appearance.width end,
            function(value) addon:SetBarSize(value, db.appearance.height) end,
            nil,
            {
                disabled = function()
                    return not IsManualWidthMode()
                end,
            }
        ),
        SliderSetting(
            "Minimum Width",
            "Lower bound when syncing width to Essential Cooldowns.",
            appearance.minWidth or 0,
            0,
            600,
            1,
            function() return db.appearance.minWidth or 0 end,
            function(value)
                db.appearance.minWidth = math.floor(value + 0.5)
                addon:ApplyEffectiveBarSize()
            end,
            nil,
            {
                disabled = function()
                    return not IsSyncedWidthMode()
                end,
            }
        ),
        SliderSetting(
            "Bar Height",
            "Height of the stagger bar in pixels.",
            appearance.height,
            10,
            60,
            1,
            function() return db.appearance.height end,
            function(value) addon:SetBarSize(db.appearance.width, value) end
        ),
    })

    AppendSection(settings, "bar", "Bar Style", false, {
        CheckboxSetting(
            "Reverse Fill",
            "Fill the bar from right to left.",
            appearance.reverseFill,
            function() return db.appearance.reverseFill end,
            function(value) db.appearance.reverseFill = value end
        ),
        SliderSetting(
            "Bar Alpha",
            "Opacity of the bar fill.",
            appearance.barAlpha,
            0,
            1,
            0.05,
            function() return db.appearance.barAlpha end,
            function(value) db.appearance.barAlpha = value end,
            function(value) return addon:FormatSliderLabel(value, 0.05) end
        ),
        SliderSetting(
            "Background Alpha",
            "Opacity of the bar background.",
            appearance.backgroundAlpha,
            0,
            1,
            0.05,
            function() return db.appearance.backgroundAlpha end,
            function(value) db.appearance.backgroundAlpha = value end,
            function(value) return addon:FormatSliderLabel(value, 0.05) end
        ),
        DropdownSetting(
            "Bar Texture",
            "Texture used for the stagger fill bar.",
            appearance.barTexture,
            BAR_TEXTURE_OPTIONS,
            function() return db.appearance.barTexture end,
            function(value) db.appearance.barTexture = value end
        ),
        ColorSetting(
            "Background Color",
            "Background fill color.",
            appearance.backgroundColor,
            function() return db.appearance.backgroundColor end,
            function(value) db.appearance.backgroundColor = value end
        ),
        ColorSetting(
            "Bar Fill Color",
            "Static fill color when threshold colors are disabled.",
            appearance.barColor,
            function() return db.appearance.barColor end,
            function(value) db.appearance.barColor = value end
        ),
    })

    AppendSection(settings, "border", "Border", false, {
        CheckboxSetting(
            "Show Border",
            "Draw a border around the bar.",
            appearance.borderEnabled,
            function() return db.appearance.borderEnabled end,
            function(value) db.appearance.borderEnabled = value end
        ),
        DropdownSetting(
            "Border Texture",
            "Edge texture for the bar border.",
            appearance.borderTexture,
            BORDER_TEXTURE_OPTIONS,
            function() return db.appearance.borderTexture end,
            function(value) db.appearance.borderTexture = value end
        ),
        SliderSetting(
            "Border Size",
            "Thickness of the border edge texture.",
            appearance.borderSize or 12,
            1,
            32,
            1,
            function() return db.appearance.borderSize or 12 end,
            function(value) db.appearance.borderSize = value end
        ),
        ColorSetting(
            "Border Color",
            "Border edge color.",
            appearance.borderColor,
            function() return db.appearance.borderColor end,
            function(value) db.appearance.borderColor = value end
        ),
        SliderSetting(
            "Border Alpha",
            "Opacity of the border edge.",
            appearance.borderAlpha or 0.8,
            0,
            1,
            0.05,
            function() return db.appearance.borderAlpha or 0.8 end,
            function(value) db.appearance.borderAlpha = value end,
            function(value) return addon:FormatSliderLabel(value, 0.05) end
        ),
    })

    AppendSection(settings, "text", "Text", false, {
        CheckboxSetting(
            "Show Bar Text",
            "Display Stagger text on the bar.",
            text.enabled,
            function() return db.text.enabled end,
            function(value) db.text.enabled = value end
        ),
        DropdownSetting(
            "Text Anchor",
            "Where the text is anchored on the bar.",
            text.point or "CENTER",
            TEXT_ANCHOR_OPTIONS,
            function() return db.text.point or "CENTER" end,
            function(value) db.text.point = value end
        ),
        SliderSetting(
            "Text Offset X",
            "Horizontal text offset in pixels.",
            text.x or 0,
            -200,
            200,
            1,
            function() return db.text.x or 0 end,
            function(value) db.text.x = value end
        ),
        SliderSetting(
            "Text Offset Y",
            "Vertical text offset in pixels.",
            text.y or 0,
            -50,
            50,
            1,
            function() return db.text.y or 0 end,
            function(value) db.text.y = value end
        ),
        SliderSetting(
            "Text Font Size",
            "Font size for bar text.",
            text.fontSize,
            8,
            24,
            1,
            function() return db.text.fontSize end,
            function(value) db.text.fontSize = value end
        ),
        ColorSetting(
            "Text Color",
            "Bar text color.",
            text.color,
            function() return db.text.color end,
            function(value) db.text.color = value end
        ),
    })

    AppendSection(settings, "breakpoints", "Breakpoints", false, {
        CheckboxSetting(
            "Show Breakpoints",
            "Show vertical lines at configured Stagger percentages.",
            breakpoints.enabled,
            function() return db.breakpoints.enabled end,
            function(value) db.breakpoints.enabled = value end
        ),
        SliderSetting(
            "Breakpoint Thickness",
            "Line thickness for breakpoint markers.",
            breakpoints.thickness,
            1,
            5,
            1,
            function() return db.breakpoints.thickness end,
            function(value) db.breakpoints.thickness = value end
        ),
        CheckboxSetting(
            "Show Breakpoint Labels",
            "Show percentage labels on breakpoint lines.",
            breakpoints.labelsEnabled,
            function() return db.breakpoints.labelsEnabled end,
            function(value) db.breakpoints.labelsEnabled = value end
        ),
        DropdownSetting(
            "Breakpoint Label Position",
            "Where breakpoint labels appear relative to their line.",
            breakpoints.labelPosition or "above",
            LABEL_POSITION_OPTIONS,
            function() return db.breakpoints.labelPosition or "above" end,
            function(value) db.breakpoints.labelPosition = value end
        ),
        ColorSetting(
            "Breakpoint Line Color",
            "Breakpoint marker line color.",
            breakpoints.lineColor or breakpoints.color,
            function() return addon:GetBreakpointLineColor() end,
            function(value) addon:SetBreakpointLineColor(value) end
        ),
    })

    return settings
end

function addon:InitEditMode()
    if self.editModeInitialized then
        return true
    end

    if not self.bar then
        return false
    end

    local libEditMode = self:GetLibEditMode()
    if not libEditMode then
        self.editModeAvailable = false
        return false
    end

    local appearance = self.db.appearance
    local bar = self.bar
    bar.editModeName = "Better Stagger"

    local function OnEditModePositionChanged(_frame, _layoutName, point, x, y)
        appearance.point = point
        appearance.relativePoint = point
        appearance.x = math.floor(x + 0.5)
        appearance.y = math.floor(y + 0.5)
        appearance.attachFrame = "UIParent"
        addon:ApplyBarPosition()
    end

    libEditMode:AddFrame(bar, OnEditModePositionChanged, {
        point = appearance.point or "CENTER",
        x = appearance.x or 0,
        y = appearance.y or 0,
    }, "Better Stagger")

    libEditMode:AddFrameSettings(bar, self:BuildEditModeSettings())

    libEditMode:AddFrameSettingsButtons(bar, {
        {
            text = "Edit Text Format",
            click = function()
                addon:OpenTextFormatDialog()
            end,
        },
    })

    libEditMode:RegisterCallback("enter", function()
        addon.editModeActive = true
        addon:InitEssentialCooldownWidthHook()
        if addon.bar then
            addon.bar:Show()
            addon:ApplyBarPosition()
            addon:ApplyEffectiveBarSize()
            addon:Update(true)
        end
    end)

    libEditMode:RegisterCallback("exit", function()
        addon.editModeActive = false
        addon:ApplyBarPosition()
        addon:Update(true)
    end)

    libEditMode:RegisterCallback("layout", function()
        addon:ApplyBarPosition()
        addon:Update(true)
    end)

    self.editModeAvailable = true
    self.editModeInitialized = true
    self:ApplyBarPosition()
    return true
end

function addon:OpenTextFormatDialog()
    if not StaticPopupDialogs then
        return
    end

    StaticPopupDialogs["BETTERSTAGGER_TEXT_TEMPLATE"] = StaticPopupDialogs["BETTERSTAGGER_TEXT_TEMPLATE"] or {
        text = "Text template (%s = placeholders like {current}, {max}, {amount}, {fill}):",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 128,
        editBoxWidth = 260,
        OnShow = function(dialog)
            dialog.editBox:SetText(addon.db.text.template or "")
        end,
        OnAccept = function(dialog)
            addon.db.text.template = dialog.editBox:GetText() or ""
            addon:RefreshFromDB()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("BETTERSTAGGER_TEXT_TEMPLATE", "{current}, {max}, {amount}, {fill}")
end

function addon:OpenEditMode()
    if EditModeManagerFrame and EditModeManagerFrame.EnterEditMode then
        ShowUIPanel(EditModeManagerFrame)
        EditModeManagerFrame:EnterEditMode()
        return
    end

    if Settings and Settings.OpenToCategory then
        self:OpenConfigPanel()
    end
end
