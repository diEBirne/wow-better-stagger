local addonName, addon = ...

addon.MAX_BREAKPOINT_RULES = 10

local DEFAULT_RULE_COLORS = {
    { 0.1, 0.8, 0.1, 1 },
    { 0.9, 0.9, 0.1, 1 },
    { 1.0, 0.5, 0.0, 1 },
    { 1.0, 0.0, 0.0, 1 },
}

function addon:CopyColor(color, fallback)
    color = self:EnsureColorTable(color, fallback)
    return { color[1], color[2], color[3], color[4] or 1 }
end

function addon:CreateDefaultBreakpointRule(value)
    value = math.max(0, math.floor((value or 0) + 0.5))
    local colorIndex = math.min(#DEFAULT_RULE_COLORS, math.max(1, value > 0 and 2 or 1))
    return {
        value = value,
        color = self:CopyColor(DEFAULT_RULE_COLORS[colorIndex]),
    }
end

function addon:NormalizeBreakpointRules(rules)
    if type(rules) ~= "table" then
        return {}
    end

    local seen = {}
    local normalized = {}

    for index = 1, #rules do
        local rule = rules[index]
        if type(rule) == "table" then
            local value = tonumber(rule.value)
            if value ~= nil and value >= 0 then
                value = math.floor(value + 0.5)
                if not seen[value] then
                    seen[value] = true
                    normalized[#normalized + 1] = {
                        value = value,
                        color = self:CopyColor(rule.color, DEFAULT_RULE_COLORS[1]),
                    }
                end
            end
        end
    end

    table.sort(normalized, function(a, b)
        return a.value < b.value
    end)

    return normalized
end

function addon:GetBreakpointRules()
    local rules = self.db and self.db.breakpoints and self.db.breakpoints.rules
    rules = self:NormalizeBreakpointRules(rules)
    if #rules == 0 then
        return self:NormalizeBreakpointRules(self.defaults.breakpoints.rules)
    end
    return rules
end

function addon:GetBreakpointLineValues()
    local values = {}
    for _, rule in ipairs(self:GetBreakpointRules()) do
        if rule.value > 0 then
            values[#values + 1] = rule.value
        end
    end
    return self:NormalizeBreakpointList(values)
end

function addon:GetBreakpointLineColor()
    local breakpoints = self.db.breakpoints
    return self:EnsureColorTable(breakpoints.lineColor or breakpoints.color, { 1, 1, 1, 0.6 })
end

function addon:SetBreakpointLineColor(color)
    self.db.breakpoints.lineColor = self:CopyColor(color)
    self.db.breakpoints.color = self.db.breakpoints.lineColor
end

function addon:AddBreakpointRule(value)
    local rules = self:GetBreakpointRules()
    if #rules >= self.MAX_BREAKPOINT_RULES then
        print("|cffff0000Better Stagger:|r Maximum of " .. self.MAX_BREAKPOINT_RULES .. " breakpoint rules reached.")
        return false
    end

    local nextValue = 100
    if #rules > 0 then
        nextValue = rules[#rules].value + 100
    end
    if value ~= nil then
        nextValue = math.floor((value or 0) + 0.5)
    end

    rules[#rules + 1] = self:CreateDefaultBreakpointRule(nextValue)
    self.db.breakpoints.rules = self:NormalizeBreakpointRules(rules)
    self:RefreshFromDB()
    return true
end

function addon:RemoveBreakpointRule(index)
    local rules = self:GetBreakpointRules()
    if not rules[index] then
        return false
    end

    if #rules <= 1 then
        print("|cffff0000Better Stagger:|r At least one breakpoint rule is required.")
        return false
    end

    table.remove(rules, index)
    self.db.breakpoints.rules = rules
    self:RefreshFromDB()
    return true
end

function addon:UpdateBreakpointRuleValue(index, value)
    local rules = self:GetBreakpointRules()
    local rule = rules[index]
    if not rule then
        return false
    end

    value = tonumber(value)
    if value == nil or value < 0 then
        print("|cffff0000Better Stagger:|r Enter a valid Stagger percentage (0 or higher).")
        return false
    end

    rule.value = math.floor(value + 0.5)
    self.db.breakpoints.rules = self:NormalizeBreakpointRules(rules)
    self:RefreshFromDB()
    return true
end

function addon:UpdateBreakpointRuleColor(index, r, g, b, a)
    local rules = self:GetBreakpointRules()
    local rule = rules[index]
    if not rule then
        return false
    end

    rule.color = { r, g, b, a or 1 }
    self.db.breakpoints.rules = rules
    self:RefreshFromDB()
    return true
end

function addon:MigrateBreakpointRules(db, defaults)
    local breakpoints = db.breakpoints
    if not breakpoints then
        return
    end

    if breakpoints.lineColor == nil and breakpoints.color then
        breakpoints.lineColor = addon:CopyColor(breakpoints.color)
    end

    if type(breakpoints.rules) == "table" and #breakpoints.rules > 0 then
        breakpoints.rules = addon:NormalizeBreakpointRules(breakpoints.rules)
        return
    end

    local rules = {}
    local defaultRules = defaults.breakpoints.rules

    local function ColorForDefaultValue(value)
        for index = 1, #defaultRules do
            if defaultRules[index].value == value then
                return addon:CopyColor(defaultRules[index].color)
            end
        end
        return addon:CopyColor(defaultRules[1] and defaultRules[1].color)
    end

    if db.colors and type(db.colors.thresholds) == "table" and #db.colors.thresholds > 0 then
        for _, threshold in ipairs(db.colors.thresholds) do
            if type(threshold) == "table" then
                local value = tonumber(threshold.value)
                if value ~= nil and value >= 0 then
                    rules[#rules + 1] = {
                        value = math.floor(value + 0.5),
                        color = addon:CopyColor(threshold.color, ColorForDefaultValue(value)),
                    }
                end
            end
        end
    elseif type(breakpoints.values) == "table" and #breakpoints.values > 0 then
        rules[#rules + 1] = {
            value = 0,
            color = ColorForDefaultValue(0),
        }

        for _, value in ipairs(addon:NormalizeBreakpointList(breakpoints.values)) do
            rules[#rules + 1] = {
                value = value,
                color = ColorForDefaultValue(value),
            }
        end
    end

    if #rules == 0 then
        rules = addon.DeepCopy(defaultRules)
    end

    breakpoints.rules = addon:NormalizeBreakpointRules(rules)
end
