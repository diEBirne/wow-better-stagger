local addonName, addon = ...

local MAX_BREAKPOINT_LINES = 10

addon.bar = nil

local function SavePosition(frame, appearance)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        return
    end

    appearance.point = point
    appearance.relativePoint = relativePoint
    appearance.x = x
    appearance.y = y
end

local function RefreshFrameLevels(frame)
    if not frame or not frame.statusBar then
        return
    end

    local baseLevel = frame.statusBar:GetFrameLevel()

    if frame.markersOverlay then
        frame.markersOverlay:SetFrameLevel(baseLevel + 1)
    end

    if frame.textOverlay then
        frame.textOverlay:SetFrameLevel(baseLevel + 2)
    end

    if frame.borderFrame then
        frame.borderFrame:SetFrameLevel(baseLevel + 5)
    end
end

function addon:CreateBar()
    if self.bar then
        return self.bar
    end

    local db = self.db
    local appearance = db.appearance

    local frame = CreateFrame("Frame", "BetterStaggerBar", UIParent)
    frame:SetSize(self:GetEffectiveBarWidth(), appearance.height)
    frame:SetClampedToScreen(true)

    frame:SetScript("OnDragStart", function(barFrame)
        if not addon.db.appearance.locked then
            barFrame:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(barFrame)
        barFrame:StopMovingOrSizing()
        SavePosition(barFrame, addon.db.appearance)
        addon.db.appearance.attachFrame = "UIParent"
        addon:ApplyBarPosition()
    end)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    frame.background = background

    local statusBar = CreateFrame("StatusBar", nil, frame)
    statusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)
    frame.statusBar = statusBar

    local markersOverlay = CreateFrame("Frame", nil, frame)
    markersOverlay:SetAllPoints(frame)
    frame.markersOverlay = markersOverlay

    frame.breakpointLines = {}
    frame.breakpointLabels = {}
    for index = 1, MAX_BREAKPOINT_LINES do
        local line = markersOverlay:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 0.6)
        line:Hide()
        frame.breakpointLines[index] = line

        local label = markersOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:Hide()
        frame.breakpointLabels[index] = label
    end

    local textOverlay = CreateFrame("Frame", nil, frame)
    textOverlay:SetAllPoints(frame)
    frame.textOverlay = textOverlay

    local text = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", textOverlay, "CENTER", 0, 0)
    frame.text = text

    local borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    borderFrame:SetAllPoints(frame)
    borderFrame:EnableMouse(false)
    frame.borderFrame = borderFrame

    RefreshFrameLevels(frame)

    self.bar = frame
    self:ApplyAppearance()
    return frame
end

function addon:ApplyAppearance()
    local frame = self.bar
    if not frame then
        return
    end

    local appearance = self.db.appearance
    local textConfig = self.db.text

    frame:SetSize(self:GetEffectiveBarWidth(), appearance.height)

    self:ApplyBarPosition()

    local bg = appearance.backgroundColor or { 0, 0, 0, 0.5 }
    frame.background:SetColorTexture(bg[1], bg[2], bg[3], appearance.backgroundAlpha or bg[4] or 0.5)

    frame.statusBar:SetStatusBarTexture(appearance.barTexture or "Interface\\TargetingFrame\\UI-StatusBar")
    frame.statusBar:SetAlpha(appearance.barAlpha or 1)

    if frame.statusBar.SetReverseFill then
        frame.statusBar:SetReverseFill(appearance.reverseFill == true)
    end

    local borderFrame = frame.borderFrame
    if appearance.borderEnabled then
        self:ApplyBorderColor(false)
        borderFrame:Show()
    else
        borderFrame:SetBackdrop(nil)
        borderFrame:Hide()
    end

    local textColor = textConfig.color or { 1, 1, 1, 1 }
    frame.text:SetFont(STANDARD_TEXT_FONT, textConfig.fontSize or 12, "OUTLINE")
    frame.text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)

    frame.text:ClearAllPoints()
    frame.text:SetPoint(
        textConfig.point or "CENTER",
        frame.textOverlay,
        textConfig.relativePoint or textConfig.point or "CENTER",
        textConfig.x or 0,
        textConfig.y or 0
    )

    RefreshFrameLevels(frame)
end

function addon:ApplyBorderColor(glowActive)
    local frame = self.bar
    if not frame or not frame.borderFrame then
        return
    end

    local appearance = self.db.appearance
    if not appearance.borderEnabled then
        return
    end

    local borderColor = appearance.borderColor or { 0, 0, 0, 0.8 }
    local borderAlpha = appearance.borderAlpha
    if borderAlpha == nil then
        borderAlpha = borderColor[4] or 0.8
    end

    local r, g, b, a = borderColor[1], borderColor[2], borderColor[3], borderAlpha
    if glowActive then
        r, g, b, a = 1, 0.25, 0.05, math.min(1, borderAlpha + 0.2)
    end

    frame.borderFrame:SetBackdrop({
        edgeFile = appearance.borderTexture or "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = appearance.borderSize or 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame.borderFrame:SetBackdropBorderColor(r, g, b, a)
end

function addon:SetBarFill(fill)
    if self.bar and self.bar.statusBar then
        self.bar.statusBar:SetValue(fill)
    end
end

function addon:UpdateBarColor(staggerPercent)
    if not self.bar then
        return
    end

    if self.db.colors.enabled then
        local r, g, b, a = self:GetColorForStagger(staggerPercent, self:GetBreakpointRules())
        self.bar.statusBar:SetStatusBarColor(r, g, b, a)
        return
    end

    local barColor = self.db.appearance.barColor or { 0.1, 0.8, 0.1, 1 }
    self.bar.statusBar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
end

function addon:UpdateText(staggerPercent, scaleMaximum, staggerAmount, fill)
    local frame = self.bar
    if not frame then
        return
    end

    if not self.db.text.enabled then
        frame.text:SetText("")
        return
    end

    local template = self.db.text.template
    if not template or template == "" then
        frame.text:SetText("")
        return
    end

    local fillPercent = self:RoundPercent((fill or 0) * 100)
    local text = self:FormatTextTemplate(template, {
        current = self:RoundPercent(staggerPercent),
        max = self:RoundPercent(scaleMaximum),
        amount = self:FormatStaggerAmount(staggerAmount),
        fill = fillPercent,
    })

    frame.text:SetText(text)
end

function addon:UpdateBreakpoints(scaleMaximum)
    local frame = self.bar
    if not frame then
        return
    end

    local config = self.db.breakpoints
    local barWidth = frame.markersOverlay and frame.markersOverlay:GetWidth() or self.db.appearance.width
    local barHeight = self.db.appearance.height
    local thickness = math.max(1, math.floor((config.thickness or 1) + 0.5))
    local color = self:GetBreakpointLineColor()
    local insetX = 1
    local insetY = 2
    local drawableWidth = math.max(1, barWidth - (insetX * 2))
    local lineHeight = math.max(1, math.floor(barHeight - (insetY * 2) + 0.5))
    local values = self:GetBreakpointLineValues()

    for index = 1, MAX_BREAKPOINT_LINES do
        local line = frame.breakpointLines[index]
        local label = frame.breakpointLabels[index]
        line:Hide()
        label:Hide()
    end

    if not config.enabled or #values == 0 then
        return
    end

    local lineIndex = 0
    for _, breakpoint in ipairs(values) do
        local position = breakpoint / scaleMaximum
        if position > 0 and position <= 1 then
            lineIndex = lineIndex + 1
            if lineIndex > MAX_BREAKPOINT_LINES then
                break
            end

            local line = frame.breakpointLines[lineIndex]
            local xCenter = insetX + (drawableWidth * position)
            local xOffset = math.floor(xCenter - (thickness / 2) + 0.5)
            xOffset = math.max(insetX, math.min(barWidth - insetX - thickness, xOffset))

            line:ClearAllPoints()
            line:SetPoint("LEFT", frame.markersOverlay, "LEFT", xOffset, 0)
            line:SetSize(thickness, lineHeight)
            line:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
            line:Show()

            if config.labelsEnabled then
                local label = frame.breakpointLabels[lineIndex]
                local labelPosition = config.labelPosition or "above"
                label:ClearAllPoints()
                if labelPosition == "below" then
                    label:SetPoint("TOP", line, "BOTTOM", 0, -2)
                elseif labelPosition == "center" then
                    label:SetPoint("CENTER", line, "CENTER", 0, 0)
                else
                    label:SetPoint("BOTTOM", line, "TOP", 0, 2)
                end
                label:SetText(string.format("%d%%", self:RoundPercent(breakpoint)))
                label:Show()
            end
        end
    end
end

function addon:UpdateGlow(staggerPercent)
    if not self.bar then
        return
    end

    local glowConfig = self.db.glow
    local glowActive = glowConfig.enabled and staggerPercent >= glowConfig.threshold
    self:ApplyBorderColor(glowActive)
end

function addon:SetBarLocked(locked)
    self.db.appearance.locked = locked
    if self.bar then
        self.bar:EnableMouse(not locked)
    end
end

function addon:ResetBarPosition()
    local defaults = self.defaults.appearance
    local appearance = self.db.appearance

    appearance.point = defaults.point
    appearance.relativePoint = defaults.relativePoint
    appearance.x = defaults.x
    appearance.y = defaults.y
    appearance.attachFrame = defaults.attachFrame

    self:ApplyBarPosition()
end

function addon:SetBarSize(width, height)
    if width then
        self.db.appearance.width = width
    end
    if height then
        self.db.appearance.height = height
    end
    self:ApplyEffectiveBarSize()
end
