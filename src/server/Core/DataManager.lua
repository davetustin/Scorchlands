--!native
--!optimize

--[[
    Core/DataManager.lua
    Description: Manages game data persistence (loading and saving).
    This is a placeholder. Actual implementation will involve DataStoreService.
    It will handle player data, base data, and other persistent game states.
    Focuses on secure and robust data handling.
]]
local DataManager = {}
local Logger = require(script.Parent.Logger)
-- CORRECTED: Constants is in ReplicatedStorage.Shared, not script.Parent
local Constants = require(game.ReplicatedStorage.Shared.Constants)

-- Placeholder for DataStoreService
local DataStoreService = game:GetService("DataStoreService")

function DataManager.new()
    local self = setmetatable({}, DataManager)
    Logger.Debug("DataManager", "DataManager instance created.")
    return self
end

--[[
    DataManager:LoadPlayerData(player)
    Loads player data from the DataStore.
    @param player Player: The Roblox Player object.
    @return table: The player's data, or a default table if not found.
]]
function DataManager:LoadPlayerData(player)
    local success, data = pcall(function()
        local playerDataStore = DataStoreService:GetDataStore(Constants.DATA_STORE_KEYS.PLAYER_DATA .. player.UserId)
        return playerDataStore:GetAsync("data")
    end)

    if success then
        if data then
            Logger.Info("DataManager", "Loaded data for player %s.", player.Name)
            return data
        else
            Logger.Info("DataManager", "No existing data for player %s. Returning default.", player.Name)
            -- Return default player data structure
            return {
                lastLogin = os.time(),
                health = Constants.MAX_HEALTH,
                resources = {
                    Wood = 0,
                    Stone = 0,
                    Metal = 0,
                },
                inventory = {},
                unlockedBlueprints = {},
                xp = 0,
                level = 1,
            }
        end
    else
        Logger.Error("DataManager", "Failed to load data for player %s: %s", player.Name, data)
        -- Fallback to default data in case of load failure
        return {
            lastLogin = os.time(),
            health = Constants.MAX_HEALTH,
            resources = {
                Wood = 0,
                Stone = 0,
                Metal = 0,
            },
            inventory = {},
            unlockedBlueprints = {},
            xp = 0,
            level = 1,
        }
    end
end

--[[
    DataManager:SavePlayerData(player, data)
    Saves player data to the DataStore.
    @param player Player: The Roblox Player object.
    @param data table: The data table to save.
    @return boolean: True if save was successful, false otherwise.
]]
function DataManager:SavePlayerData(player, data)
    local success, err = pcall(function()
        local playerDataStore = DataStoreService:GetDataStore(Constants.DATA_STORE_KEYS.PLAYER_DATA .. player.UserId)
        playerDataStore:SetAsync("data", data)
    end)

    if success then
        Logger.Info("DataManager", "Saved data for player %s.", player.Name)
    else
        Logger.Error("DataManager", "Failed to save data for player %s: %s", player.Name, err)
    end
    return success
end

-- Add methods for BaseData, GlobalSettings, etc. as needed.
-- DataManager:LoadBaseData(baseId)
-- DataManager:SaveBaseData(baseId, data)

return DataManager
