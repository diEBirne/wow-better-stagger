local addonName, addon = ...

local function PrintHelp()
    print("|cff00ff00Better Stagger|r commands:")
    print("  /bs config  - Open settings panel (Esc -> Settings -> AddOns)")
    print("  /bs lock    - Lock bar position")
    print("  /bs unlock  - Unlock bar position")
    print("  /bs reset   - Reset bar position to default")
    print("  /bs test    - Toggle test mode (simulated 237% Stagger)")
    print("  /bs help    - Show this help")
end

local function HandleSlashCommand(message)
    local command, arg = message:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" or command == "help" then
        PrintHelp()
        return
    end

    if command == "config" then
        addon:OpenConfigPanel()
        return
    end

    if command == "lock" then
        addon:SetBarLocked(true)
        print("|cff00ff00Better Stagger:|r Bar locked.")
        return
    end

    if command == "unlock" then
        addon:SetBarLocked(false)
        print("|cff00ff00Better Stagger:|r Bar unlocked. Drag to move.")
        return
    end

    if command == "reset" then
        addon:ResetBarPosition()
        addon:RefreshFromDB()
        print("|cff00ff00Better Stagger:|r Bar position reset.")
        return
    end

    if command == "test" then
        addon:ToggleTestMode()
        return
    end

    print("|cffff0000Better Stagger:|r Unknown command. Type /bs help")
end

function addon:InitSlash()
    SlashCmdList["BETTERSTAGGER"] = HandleSlashCommand
    SLASH_BETTERSTAGGER1 = "/bs"
    SLASH_BETTERSTAGGER2 = "/betterstagger"
end
