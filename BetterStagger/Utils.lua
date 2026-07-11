local addonName, addon = ...

function addon:Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function addon:RoundUpToStep(value, step)
    if not step or step <= 0 then
        return value
    end
    return math.ceil(value / step) * step
end

function addon:RoundPercent(value)
    return math.floor(value + 0.5)
end

function addon:RoundToDecimals(value, decimals)
    decimals = decimals or 2
    local multiplier = 10 ^ decimals
    return math.floor((value or 0) * multiplier + 0.5) / multiplier
end

function addon:FormatSliderLabel(value, step)
    if step and step >= 1 then
        return tostring(math.floor((value or 0) + 0.5))
    end
    return string.format("%.2f", value or 0)
end

function addon:EnsureColorTable(color, fallback)
    if type(color) ~= "table" then
        color = fallback and { fallback[1], fallback[2], fallback[3], fallback[4] } or { 1, 1, 1, 1 }
    end
    color[1] = color[1] or 1
    color[2] = color[2] or 1
    color[3] = color[3] or 1
    color[4] = color[4] or 1
    return color
end

function addon:ColorToHex(color)
    color = self:EnsureColorTable(color)
    local r = math.floor(color[1] * 255 + 0.5)
    local g = math.floor(color[2] * 255 + 0.5)
    local b = math.floor(color[3] * 255 + 0.5)
    local a = math.floor((color[4] or 1) * 255 + 0.5)
    return string.format("#%02X%02X%02X%02X", r, g, b, a)
end

function addon:ParseHexColor(hex, fallbackColor)
    if not hex or hex == "" then
        return nil
    end

    local normalized = string.upper(hex:gsub("#", ""):gsub("%s", ""))
    local r, g, b, a

    if #normalized == 6 then
        r = tonumber(normalized:sub(1, 2), 16)
        g = tonumber(normalized:sub(3, 4), 16)
        b = tonumber(normalized:sub(5, 6), 16)
        a = fallbackColor and fallbackColor[4] or 1
    elseif #normalized == 8 then
        r = tonumber(normalized:sub(1, 2), 16)
        g = tonumber(normalized:sub(3, 4), 16)
        b = tonumber(normalized:sub(5, 6), 16)
        a = tonumber(normalized:sub(7, 8), 16) / 255
    else
        return nil
    end

    if not r or not g or not b then
        return nil
    end

    return {
        r / 255,
        g / 255,
        b / 255,
        a or 1,
    }
end

function addon:ShowColorPicker(r, g, b, a, onChanged)
    local function ApplyColor()
        if not onChanged then
            return
        end

        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        local newA = ColorPickerFrame:GetColorAlpha()
        onChanged(newR, newG, newB, newA)
    end

    local options = {
        swatchFunc = ApplyColor,
        opacityFunc = ApplyColor,
        cancelFunc = function(previousValues)
            if previousValues and onChanged then
                onChanged(previousValues.r, previousValues.g, previousValues.b, previousValues.opacity)
            end
        end,
        hasOpacity = true,
        opacity = a or 1,
        r = r or 1,
        g = g or 1,
        b = b or 1,
    }

    ColorPickerFrame:SetupColorPickerAndShow(options)
end

addon.TEXT_TEMPLATE_PLACEHOLDERS = {
    { token = "{current}", description = "Current Stagger percent (rounded number, no % sign)." },
    { token = "{max}", description = "Current scale maximum percent (rounded number, no % sign)." },
    { token = "{amount}", description = "Current Stagger as absolute health (formatted with commas)." },
    { token = "{fill}", description = "Bar fill level from 0 to 100 (visual fill, not raw Stagger)." },
}

function addon:FormatTextTemplate(template, data)
    if not template or template == "" then
        return ""
    end

    local replacements = {
        ["{current}"] = tostring(data.current or 0),
        ["{max}"] = tostring(data.max or 0),
        ["{amount}"] = data.amount or "0",
        ["{fill}"] = tostring(data.fill or 0),
    }

    local result = template
    for token, value in pairs(replacements) do
        result = result:gsub(token, value)
    end

    return result
end

function addon:IsBrewmaster()
    local _, class = UnitClass("player")
    if class ~= "MONK" then
        return false
    end

    local specIndex = GetSpecialization()
    if not specIndex then
        return false
    end

    local specID = select(1, GetSpecializationInfo(specIndex))
    return specID == 268
end

function addon:GetStaggerData()
    local staggerAmount = UnitStagger("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    if maxHealth <= 0 then
        maxHealth = 1
    end

    local staggerPercent = (staggerAmount / maxHealth) * 100
    return staggerAmount, maxHealth, staggerPercent
end

function addon:ParseBreakpointString(text)
    local values = {}
    if not text or text == "" then
        return values
    end

    local seen = {}
    for part in string.gmatch(text, "[^,]+") do
        local trimmed = part:match("^%s*(.-)%s*$")
        local number = tonumber(trimmed)
        if number and number > 0 then
            number = math.floor(number + 0.5)
            if not seen[number] then
                seen[number] = true
                values[#values + 1] = number
            end
        end
    end

    table.sort(values)
    return values
end

function addon:FormatBreakpointString(values)
    if addon.NormalizeBreakpointList then
        values = addon:NormalizeBreakpointList(values)
    end

    if not values or #values == 0 then
        return ""
    end

    local parts = {}
    for index = 1, #values do
        parts[index] = tostring(math.floor(values[index] + 0.5))
    end
    return table.concat(parts, ", ")
end

function addon:GetColorForStagger(staggerPercent, thresholds)
    if not thresholds or #thresholds == 0 then
        return 0.1, 0.8, 0.1, 1
    end

    local selected = thresholds[1].color
    for index = 1, #thresholds do
        if staggerPercent >= thresholds[index].value then
            selected = thresholds[index].color
        end
    end

    return selected[1], selected[2], selected[3], selected[4] or 1
end

function addon:GetUpdateInterval()
    local interval = self.db and self.db.performance and self.db.performance.updateIntervalSeconds or 0.1
    return self:Clamp(interval, 0.05, 0.5)
end

function addon:FormatStaggerAmount(amount)
    amount = math.floor((amount or 0) + 0.5)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(amount)
    end
    return tostring(amount)
end

function addon:ParseColorThresholdString(text)
    local thresholds = {}
    if not text or text == "" then
        return thresholds
    end

    for entry in string.gmatch(text, "[^;]+") do
        local trimmed = entry:match("^%s*(.-)%s*$")
        local valuePart, r, g, b, a = trimmed:match("^(%d+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)")
        if not a then
            valuePart, r, g, b = trimmed:match("^(%d+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)")
        end
        local percent = tonumber(valuePart)
        r = tonumber(r)
        g = tonumber(g)
        b = tonumber(b)
        a = tonumber(a)
        if percent and r and g and b then
            thresholds[#thresholds + 1] = {
                value = percent,
                color = { r, g, b, a or 1 },
            }
        end
    end

    table.sort(thresholds, function(a, b)
        return a.value < b.value
    end)

    return thresholds
end

function addon:FormatColorThresholdString(thresholds)
    if not thresholds or #thresholds == 0 then
        return ""
    end

    local parts = {}
    for index = 1, #thresholds do
        local threshold = thresholds[index]
        local color = threshold.color or { 1, 1, 1, 1 }
        parts[index] = string.format(
            "%d,%.2f,%.2f,%.2f,%.2f",
            math.floor(threshold.value + 0.5),
            color[1] or 1,
            color[2] or 1,
            color[3] or 1,
            color[4] or 1
        )
    end
    return table.concat(parts, "; ")
end
