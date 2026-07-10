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

    for part in string.gmatch(text, "[^,]+") do
        local trimmed = part:match("^%s*(.-)%s*$")
        local number = tonumber(trimmed)
        if number and number > 0 then
            values[#values + 1] = number
        end
    end

    table.sort(values)
    return values
end

function addon:FormatBreakpointString(values)
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
