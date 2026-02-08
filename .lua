

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local LocalPlayer = Players.LocalPlayer


if not getgenv().Configuration then
    getgenv().Configuration = {
        UNITS_TO_MANAGE = {
            -- ["UnitName"] = { keep_count = 3 },
        },
        SELL_DELAY = 0.3
    }
end

local CONFIG = getgenv().Configuration


local isAutoSelling = false
local totalSold = 0


local function log(msg, ...)
    local t = os.date("%H:%M:%S")
    print(string.format("[%s][AUTO-SELL] %s", t, string.format(msg, ...)))
end


local function getUnitWindowHandler()
    local ok, handler = pcall(function()
        return require(
            StarterPlayer.Modules.Interface.Loader.Windows.UnitWindowHandler
        )
    end)

    if ok and handler then
        return handler
    end

    log("❌ Cannot access UnitWindowHandler")
    return nil
end


local function getUnitsFromGUI()
    local container = LocalPlayer.PlayerGui
        :WaitForChild("Windows")
        :WaitForChild("GlobalInventory")
        :WaitForChild("Holder")
        :WaitForChild("LeftContainer")
        :WaitForChild("FakeScrollingFrame")
        :WaitForChild("Items")
        :WaitForChild("CacheContainer")

    local units = {}

    for _, guiItem in ipairs(container:GetChildren()) do
        local nameLabel =
            guiItem:FindFirstChild("Name")
            or guiItem:FindFirstChild("Title")
            or guiItem:FindFirstChild("UnitName")

        if nameLabel and nameLabel:IsA("TextLabel") then
            table.insert(units, {
                name = nameLabel.Text,
                gui = guiItem
            })
        end
    end

    return units
end


local function getUUIDByName(unitName, usedUUID)
    local handler = getUnitWindowHandler()
    if not handler or not handler._Cache then
        return nil
    end

    for uuid, data in pairs(handler._Cache) do
        if data.UnitData
            and data.UnitData.Name == unitName
            and not usedUUID[uuid] then

            usedUUID[uuid] = true
            return uuid
        end
    end

    return nil
end


local function getUnitsToSell()
    local guiUnits = getUnitsFromGUI()
    local unitsByName = {}
    local result = {}
    local usedUUID = {}

    -- group by name
    for _, unit in ipairs(guiUnits) do
        unitsByName[unit.name] = unitsByName[unit.name] or {}
        table.insert(unitsByName[unit.name], unit)
    end

    for unitName, cfg in pairs(CONFIG.UNITS_TO_MANAGE) do
        local list = unitsByName[unitName] or {}
        local keep = cfg.keep_count
        local count = #list

        log("📊 %s: GUI=%d | KEEP=%d", unitName, count, keep)

        if count > keep then
            local sellCount = count - keep

            for i = 1, sellCount do
                local uuid = getUUIDByName(unitName, usedUUID)
                if uuid then
                    table.insert(result, {
                        name = unitName,
                        uuid = uuid
                    })
                else
                    log("⚠️ UUID not found for %s", unitName)
                end
            end

            log("💰 Will sell %d %s(s)", sellCount, unitName)
        end
    end

    log("🎯 Total units to sell: %d", #result)
    return result
end

-- ==========================================
-- NETWORK ACTIONS
-- ==========================================
local function unequipAll()
    print("Unequipping all units...")
    return true
end


local function sellUnit(uuid)
    return pcall(function()
        ReplicatedStorage
            :WaitForChild("Networking")
            :WaitForChild("Units")
            :WaitForChild("SellEvent")
            :FireServer({ uuid })
    end)
end

-- ==========================================
-- MAIN LOOP
-- ==========================================
local function startAutoSell()
    if isAutoSelling then
        log("⚠️ Already running")
        return
    end

    isAutoSelling = true
    totalSold = 0

    log("🚀 Auto Sell Started")
    if not unequipAll() then
        isAutoSelling = false
        return
    end

    task.wait(1)

    task.spawn(function()
        while isAutoSelling do
            local list = getUnitsToSell()
            if #list == 0 then
                log("✅ Nothing to sell")
                break
            end

            for i, unit in ipairs(list) do
                if not isAutoSelling then break end

                if sellUnit(unit.uuid) then
                    totalSold += 1
                    log("✅ Sold %s (%d/%d)", unit.name, i, #list)
                else
                    log("❌ Failed to sell %s", unit.name)
                end

                task.wait(CONFIG.SELL_DELAY)
            end

            task.wait(2)
        end

        isAutoSelling = false
        log("🏁 Done | Total sold: %d", totalSold)
    end)
end

local function stopAutoSell()
    isAutoSelling = false
    log("🛑 Stopped | Sold: %d", totalSold)
end

-- ==========================================
-- GLOBAL API
-- ==========================================
_G.startAutoSell = startAutoSell
_G.stopAutoSell = stopAutoSell

_G.addUnit = function(name, keep)
    CONFIG.UNITS_TO_MANAGE[name] = { keep_count = keep }
    log("➕ Added %s | keep %d", name, keep)
end

_G.removeUnit = function(name)
    CONFIG.UNITS_TO_MANAGE[name] = nil
    log("➖ Removed %s", name)
end

_G.setDelay = function(d)
    CONFIG.SELL_DELAY = d
    log("⏱ Delay set to %.2f", d)
end

-- ==========================================
-- STARTUP
-- ==========================================
log("🔥 GUI-Based Auto Sell Loaded")
log("💡 Example: _G.addUnit('Goku', 3)")
log("⏳ Auto start in 3s...")
task.wait(3)
startAutoSell()
