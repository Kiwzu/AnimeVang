-- ==========================================
-- SIMPLE AUTO SELL UNITS SCRIPT
-- ==========================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- CONFIGURATION SETUP
-- ==========================================
-- ให้ผู้ใช้สามารถปรับแต่งได้ง่ายๆ ผ่าน getgenv().Configuration
if not getgenv().Configuration then
    getgenv().Configuration = {
        -- ตั้งชื่อตัวละครที่ต้องการขาย และจำนวนที่ต้องการเก็บไว้
        UNITS_TO_MANAGE = {
            -- เพิ่มตัวละครที่ต้องการจัดการที่นี่
            -- ["ชื่อตัวละคร"] = {keep_count = จำนวนที่เก็บไว้},
        },
        
        -- การตั้งค่าทั่วไป
        SELL_DELAY = 0.3,  -- หน่วงเวลาระหว่างการขาย (วินาที)
    }
end

-- ใช้ Configuration จาก getgenv()
local CONFIG = getgenv().Configuration

-- ==========================================
-- GLOBAL VARIABLES
-- ==========================================
local isAutoSelling = false
local totalSold = 0

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================
local function log(message, ...)
    local timestamp = os.date("[%H:%M:%S]")
    print(string.format("[%s][AUTO-SELL] %s", timestamp, string.format(message, ...)))
end

-- ==========================================
-- CORE FUNCTIONS
-- ==========================================
local function getUnitWindowHandler()
    local success, handler = pcall(function()
        return require(StarterPlayer.Modules.Interface.Loader.Windows.UnitWindowHandler)
    end)
    
    if success and handler then
        return handler
    else
        log("❌ Failed to get UnitWindowHandler")
        return nil
    end
end

local function getAllUnits()
    local handler = getUnitWindowHandler()
    if not handler or not handler._Cache then
        log("⚠️ UnitWindowHandler cache not available")
        return {}
    end
    
    local units = {}
    for uuid, unitData in pairs(handler._Cache) do
        if unitData.UnitData then
            table.insert(units, {
                uuid = uuid,
                name = unitData.UnitData.Name,
                data = unitData.UnitData
            })
        end
    end
    
    return units
end

local function getUnitsToSell()
    local allUnits = getAllUnits()
    local unitsToSell = {}
    
    -- จัดกลุ่มตัวละครตามชื่อ
    local unitsByName = {}
    for _, unit in ipairs(allUnits) do
        if not unitsByName[unit.name] then
            unitsByName[unit.name] = {}
        end
        table.insert(unitsByName[unit.name], unit)
    end
    
    -- ตรวจสอบแต่ละตัวละครใน CONFIG
    for unitName, config in pairs(CONFIG.UNITS_TO_MANAGE) do
        local unitsOfThisName = unitsByName[unitName] or {}
        local keepCount = config.keep_count
        local currentCount = #unitsOfThisName
        
        log("📊 %s: Found %d, Keep %d", unitName, currentCount, keepCount)
        
        if currentCount > keepCount then
            -- ขายส่วนที่เกิน
            local sellCount = currentCount - keepCount
            for i = 1, sellCount do
                table.insert(unitsToSell, unitsOfThisName[i])
            end
            log("💰 Will sell %d %s(s)", sellCount, unitName)
        elseif currentCount == keepCount then
            log("✅ %s count is perfect (%d)", unitName, currentCount)
        else
            log("⚠️ %s count is below target (%d < %d)", unitName, currentCount, keepCount)
        end
    end
    
    log("🎯 Total units to sell: %d", #unitsToSell)
    return unitsToSell
end

local function sellUnit(uuid)
    local success = pcall(function()
        local sellEvent = ReplicatedStorage:WaitForChild("Networking"):WaitForChild("Units"):WaitForChild("SellEvent")
        sellEvent:FireServer({uuid})
    end)
    
    return success
end

local function unequipAllUnits()
    local success = pcall(function()
        local equipEvent = ReplicatedStorage:WaitForChild("Networking"):WaitForChild("Units"):WaitForChild("EquipEvent")
        equipEvent:FireServer("UnequipAll")
    end)
    
    if success then
        log("🔧 Unequipped all units successfully")
    else
        log("❌ Failed to unequip units")
    end
    
    return success
end

-- ==========================================
-- MAIN FUNCTIONS
-- ==========================================
local function startAutoSell()
    if isAutoSelling then
        log("⚠️ Auto sell is already running!")
        return
    end
    
    isAutoSelling = true
    totalSold = 0
    
    log("🚀 Starting auto sell...")
    log("🔧 Unequipping all units first...")
    
    -- Unequip all units ก่อนเริ่มขาย
    if not unequipAllUnits() then
        log("❌ Failed to unequip units, stopping auto sell")
        isAutoSelling = false
        return
    end
    
    task.wait(1) -- รอให้ unequip เสร็จ
    
    log("📋 Checking configured units...")
    
    task.spawn(function()
        while isAutoSelling do
            local unitsToSell = getUnitsToSell()
            
            if #unitsToSell == 0 then
                log("✅ No units need to be sold!")
                break
            end
            
            log("💰 Selling %d units...", #unitsToSell)
            
            for i, unit in ipairs(unitsToSell) do
                if not isAutoSelling then break end
                
                local success = sellUnit(unit.uuid)
                
                if success then
                    totalSold = totalSold + 1
                    log("✅ Sold %s (%d/%d)", unit.name, i, #unitsToSell)
                else
                    log("❌ Failed to sell %s", unit.name)
                end
                
                task.wait(CONFIG.SELL_DELAY)
            end
            
            if isAutoSelling then
                log("🔄 Checking for new units...")
                task.wait(2) -- รอ 2 วินาทีก่อนเช็คใหม่
            end
        end
        
        isAutoSelling = false
        log("🏁 Auto sell completed!")
        log("📈 Total units sold: %d", totalSold)
    end)
end

local function stopAutoSell()
    if not isAutoSelling then
        log("⚠️ Auto sell is not running!")
        return
    end
    
    isAutoSelling = false
    log("🛑 Auto sell stopped!")
    log("📊 Units sold before stop: %d", totalSold)
end

local function sellOnce()
    log("🎯 Performing single sell check...")
    log("🔧 Unequipping all units first...")
    
    -- Unequip all units ก่อนขาย
    if not unequipAllUnits() then
        log("❌ Failed to unequip units, cancelling sell")
        return
    end
    
    task.wait(1) -- รอให้ unequip เสร็จ
    
    local unitsToSell = getUnitsToSell()
    
    if #unitsToSell == 0 then
        log("✅ No units need to be sold!")
        return
    end
    
    log("💰 Selling %d units...", #unitsToSell)
    local soldCount = 0
    
    for _, unit in ipairs(unitsToSell) do
        local success = sellUnit(unit.uuid)
        
        if success then
            soldCount = soldCount + 1
            log("✅ Sold %s", unit.name)
        else
            log("❌ Failed to sell %s", unit.name)
        end
        
        task.wait(CONFIG.SELL_DELAY)
    end
    
    log("🏁 Single sell completed! Sold %d units", soldCount)
end

local function showCurrentStatus()
    log("📊 Current Unit Status:")
    log("==========================================")
    
    local allUnits = getAllUnits()
    local unitsByName = {}
    
    -- จัดกลุ่มตัวละครตามชื่อ
    for _, unit in ipairs(allUnits) do
        if not unitsByName[unit.name] then
            unitsByName[unit.name] = 0
        end
        unitsByName[unit.name] = unitsByName[unit.name] + 1
    end
    
    -- แสดงสถานะตัวละครใน CONFIG
    for unitName, config in pairs(CONFIG.UNITS_TO_MANAGE) do
        local currentCount = unitsByName[unitName] or 0
        local keepCount = config.keep_count
        local status = ""
        
        if currentCount > keepCount then
            status = string.format("🔴 EXCESS (%d to sell)", currentCount - keepCount)
        elseif currentCount == keepCount then
            status = "🟢 PERFECT"
        else
            status = string.format("🟡 BELOW TARGET (%d needed)", keepCount - currentCount)
        end
        
        log("%s: %d/%d %s", unitName, currentCount, keepCount, status)
    end
    
    log("==========================================")
end

-- ==========================================
-- GLOBAL FUNCTIONS
-- ==========================================
_G.startAutoSell = startAutoSell
_G.stopAutoSell = stopAutoSell
_G.sellOnce = sellOnce
_G.showUnitStatus = showCurrentStatus

-- เพิ่มฟังก์ชันจัดการ Configuration
_G.showConfig = function()
    log("📋 Current Configuration:")
    log("==========================================")
    log("SELL_DELAY: %.1f seconds", CONFIG.SELL_DELAY)
    log("UNITS_TO_MANAGE:")
    for unitName, config in pairs(CONFIG.UNITS_TO_MANAGE) do
        log("   • %s: Keep %d", unitName, config.keep_count)
    end
    log("==========================================")
end

_G.addUnit = function(unitName, keepCount)
    if not unitName or not keepCount then
        log("❌ Usage: _G.addUnit('UnitName', keepCount)")
        return
    end
    
    getgenv().Configuration.UNITS_TO_MANAGE[unitName] = {keep_count = keepCount}
    log("✅ Added %s: Keep %d", unitName, keepCount)
end

_G.removeUnit = function(unitName)
    if not unitName then
        log("❌ Usage: _G.removeUnit('UnitName')")
        return
    end
    
    if getgenv().Configuration.UNITS_TO_MANAGE[unitName] then
        getgenv().Configuration.UNITS_TO_MANAGE[unitName] = nil
        log("✅ Removed %s from configuration", unitName)
    else
        log("⚠️ %s not found in configuration", unitName)
    end
end

_G.setDelay = function(delay)
    if not delay or delay < 0 then
        log("❌ Usage: _G.setDelay(0.3) - delay must be >= 0")
        return
    end
    
    getgenv().Configuration.SELL_DELAY = delay
    log("✅ Set sell delay to %.1f seconds", delay)
end

-- ==========================================
-- STARTUP
-- ==========================================
log("🚀 Simple Auto Sell Script Loaded!")
log("📋 Configured units:")
for unitName, config in pairs(CONFIG.UNITS_TO_MANAGE) do
    log("   • %s: Keep %d", unitName, config.keep_count)
end
log("")
log("⚙️ Configuration Commands:")
log("   • _G.showConfig() - Show current configuration")
log("   • _G.addUnit('UnitName', keepCount) - Add unit to sell list")
log("   • _G.removeUnit('UnitName') - Remove unit from sell list")
log("   • _G.setDelay(0.3) - Set delay between sells")
log("   • _G.stopAutoSell() - Stop auto selling")
log("")
log("💡 Example: _G.addUnit('Goku', 3) - Keep 3 Goku, sell the rest")
log("")

-- 🚀 AUTO START SELLING
log("🔥 Auto selling will start in 3 seconds...")
task.wait(3)
startAutoSell()
