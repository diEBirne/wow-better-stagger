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

function addon:CreateBar()
    if self.bar then
        return self.bar
    end

    local db = self.db
    local appearance = db.appearance

    local frame = CreateFrame("Frame", "BetterStaggerBar", UIParent, "BackdropTemplate")
    frame:SetSize(appearance.width, appearance.height)
    frame:SetPoint(appearance.point, UIParent, appearance.relativePoint, appearance.x, appearance.y)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(not appearance.locked)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(barFrame)
        if not addon.db.appearance.locked then
            barFrame:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(barFrame)
        barFrame:StopMovingOrSizing()
        SavePosition(barFrame, addon.db.appearance)
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

    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.2, 0.1, 0.8)
    glow:Hide()
    frame.glow = glow

    frame.breakpointLines = {}
    frame.breakpointLabels = {}
    for index = 1, MAX_BREAKPOINT_LINES do
        local line = frame:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 1, 1, 0.6)
        line:Hide()
        frame.breakpointLines[index] = line

        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:Hide()
        frame.breakpointLabels[index] = label
    end

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text = text

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

    frame:SetSize(appearance.width, appearance.height)
    frame:ClearAllPoints()
    frame:SetPoint(appearance.point, UIParent, appearance.relativePoint, appearance.x, appearance.y)
    frame:EnableMouse(not appearance.locked)

    local bg = appearance.backgroundColor
    frame.background:SetColorTexture(bg[1], bg[2], bg[3], appearance.backgroundAlpha or bg[4] or 0.5)

    frame.statusBar:SetStatusBarTexture(appearance.barTexture)
    frame.statusBar:SetAlpha(appearance.barAlpha or 1)

    if appearance.borderEnabled then
        frame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame:SetBackdropBorderColor(0, 0, 0, 0.8)
    else
        frame:SetBackdrop(nil)
    end

    local textColor = textConfig.color or { 1, 1, 1, 1 }
    frame.text:SetFont(STANDARD_TEXT_FONT, textConfig.fontSize or 12, "OUTLINE")
    frame.text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)

    frame.text:ClearAllPoints()
    frame.text:SetPoint(
        textConfig.point or "CENTER",
        frame,
        textConfig.relativePoint or textConfig.point or "CENTER",
        textConfig.x or 0,
        textConfig.y or 0
    )
end

function addon:SetBarFill(fill)
    if self.bar and self.bar.statusBar then
        self.bar.statusBar:SetValue(fill)
    end
end

function addon:UpdateBarColor(staggerPercent)
    if not self.bar or not self.db.colors.enabled then
        return
    end

    local r, g, b, a = self:GetColorForStagger(staggerPercent, self.db.colors.thresholds)
    self.bar.statusBar:SetStatusBarColor(r, g, b, a)
end

function addon:UpdateText(staggerPercent, scaleMaximum)
    local frame = self.bar
    if not frame then
        return
    end

    if not self.db.text.enabled then
        frame.text:SetText("")
        return
    end

    local format = self.db.text.format or "current"
    if format == "none" then
        frame.text:SetText("")
        return
    end

    local rounded = self:RoundPercent(staggerPercent)
    local maxRounded = self:RoundPercent(scaleMaximum)

    if format == "current" then
        frame.text:SetText(string.format("%d%%", rounded))
    elseif self.db.scale.mode == "dynamic" then
        frame.text:SetText(string.format("%d%% / dyn %d%%", rounded, maxRounded))
    else
        frame.text:SetText(string.format("%d%% / %d%%", rounded, maxRounded))
    end
end

function addon:UpdateBreakpoints(scaleMaximum)
    local frame = self.bar
    if not frame then
        return
    end

    local config = self.db.breakpoints
    local barWidth = self.db.appearance.width
    local barHeight = self.db.appearance.height
    local thickness = config.thickness or 1
    local color = config.color or { 1, 1, 1, 0.6 }

    for index = 1, MAX_BREAKPOINT_LINES do
        local line = frame.breakpointLines[index]
        local label = frame.breakpointLabels[index]
        line:Hide()
        label:Hide()
    end

    if not config.enabled or not config.values then
        return
    end

    local lineIndex = 0
    for _, breakpoint in ipairs(config.values) do
        local position = breakpoint / scaleMaximum
        if position > 0 and position < 1 then
            lineIndex = lineIndex + 1
            if lineIndex > MAX_BREAKPOINT_LINES then
                break
            end

            local line = frame.breakpointLines[lineIndex]
            local xOffset = (barWidth * position) - (thickness / 2)
            line:ClearAllPoints()
            line:SetPoint("LEFT", frame, "LEFT", xOffset, 0)
            line:SetSize(thickness, barHeight)
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
    if glowConfig.enabled and staggerPercent >= glowConfig.threshold then
        self.bar.glow:Show()
    else
        self.bar.glow:Hide()
    end
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

    if self.bar then
        self.bar:ClearAllPoints()
        self.bar:SetPoint(appearance.point, UIParent, appearance.relativePoint, appearance.x, appearance.y)
    end
end

function addon:SetBarSize(width, height)
    self.db.appearance.width = width
    self.db.appearance.height = height
    if self.bar then
        self.bar:SetSize(width, height)
    end
end
