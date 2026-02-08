-- ==============================
-- CONFIG
-- ==============================

-- ==============================
-- SERVICES
-- ==============================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local CONFIG = getgenv().Configuration

-- ==============================
-- INVENTORY (PATH ของจริง)
-- ==============================
local unitsFolder = player.PlayerGui
    :WaitForChild("Windows")
    :WaitForChild("GlobalInventory")
    :WaitForChild("Holder")
    :WaitForChild("LeftContainer")
    :WaitForChild("FakeScrollingFrame")
    :WaitForChild("Items")
    :WaitForChild("CacheContainer")

-- ==============================
-- SELL EVENT
-- ==============================
local SellEvent = ReplicatedStorage
    :WaitForChild("Networking")
    :WaitForChild("Units")
    :WaitForChild("SellEvent")

-- ==============================
-- NORMALIZE NAME
-- ==============================
local function normalizeName(str)
    return str
        :gsub("<.->", "")
        :gsub("%b[]", "")
        :gsub("%b()", "")
        :gsub("★", "")
        :gsub("%s+", "")
        :lower()
end

-- ==============================
-- BUILD SELL LIST (FIX จุดตาย)
-- ==============================
local function buildSellList()
    local unitsByName = {}

    for _, guiItem in ipairs(unitsFolder:GetChildren()) do
        local unitNameLabel =
            guiItem:FindFirstChild("Container")
            and guiItem.Container:FindFirstChild("Holder")
            and guiItem.Container.Holder:FindFirstChild("Main")
            and guiItem.Container.Holder.Main:FindFirstChild("UnitName")

        if unitNameLabel and unitNameLabel:IsA("TextLabel") then
            local cleanName = normalizeName(unitNameLabel.Text)
            unitsByName[cleanName] = unitsByName[cleanName] or {}
            table.insert(unitsByName[cleanName], guiItem.Name) -- UUID
        end
    end

    local sellList = {}

    for unitName, cfg in pairs(CONFIG.UNITS_TO_MANAGE) do
        local list = unitsByName[unitName] or {}
        local keep = cfg.keep_count or 0

        if #list > keep then
            for i = keep + 1, #list do
                table.insert(sellList, {
                    name = unitName,
                    uuid = list[i]
                })
            end
        end
    end

    print("[AUTO-SELL] FOUND", #sellList, "units")
    return sellList
end

-- ==============================
-- SELL
-- ==============================
local function sell(uuid)
    return pcall(function()
        SellEvent:FireServer({ uuid })
    end)
end


-- ==============================
-- START
-- ==============================
task.wait(1)

local list = buildSellList()

for i, unit in ipairs(list) do
    if sell(unit.uuid) then
        print("[AUTO-SELL] SOLD", unit.name, unit.uuid)
    else
        print("[AUTO-SELL] FAIL", unit.name)
    end
    task.wait(CONFIG.SELL_DELAY)
end

print("[AUTO-SELL] DONE")
