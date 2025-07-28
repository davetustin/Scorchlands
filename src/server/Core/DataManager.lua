--[[
    Core/DataManager.lua
    Description: Manages game data persistence (loading and saving).
    This is a placeholder. Actual implementation will involve DataStoreService.
    It will handle player data, base data, and other persistent game states.
    Focuses on secure and robust data handling.
]]
local DataManager = {}
local Logger = require(game.ReplicatedStorage.Shared.Logger)
-- CORRECTED: Constants is in ReplicatedStorage.Shared, not script.Parent
local Constants = require(game.ReplicatedStorage.Shared.Constants)

-- Placeholder for DataStoreService
local DataStoreService = game:GetService("DataStoreService")

function DataManager.new()
    local self = setmetatable({}, DataManager)
    Logger.Debug("DataManager", "DataManager instance created.")
    
    -- Explicitly copy methods to ensure they're available on the instance
    self.LoadPlayerData = DataManager.LoadPlayerData
    self.SavePlayerData = DataManager.SavePlayerData
    self.LoadStructureData = DataManager.LoadStructureData
    self.SaveStructureData = DataManager.SaveStructureData
    
    -- Debug: Verify that methods are properly attached
    Logger.Debug("DataManager", "LoadStructureData method exists: %s", tostring(self.LoadStructureData))
    Logger.Debug("DataManager", "SaveStructureData method exists: %s", tostring(self.SaveStructureData))
    
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
        -- Handle the case where 'data' might be an Instance or other non-string object
        local errorMessage = tostring(data)
        Logger.Error("DataManager", "Failed to load data for player %s: %s", player.Name, errorMessage)
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
        -- Handle the case where 'err' might be an Instance or other non-string object
        local errorMessage = tostring(err)
        Logger.Error("DataManager", "Failed to save data for player %s: %s", player.Name, errorMessage)
    end
    return success
end

-- Add methods for BaseData, GlobalSettings, etc. as needed.
-- DataManager:LoadBaseData(baseId)
-- DataManager:SaveBaseData(baseId, data)

--[[
    DataManager:LoadStructureData(playerId)
    Loads structure data for a player from the DataStore.
    @param playerId number: The UserId of the player.
    @return table: The structure data, or an empty table if not found.
]]
function DataManager:LoadStructureData(playerId)
    local success, data = pcall(function()
        local structureDataStore = DataStoreService:GetDataStore(Constants.DATA_STORE_KEYS.STRUCTURE_DATA .. playerId)
        return structureDataStore:GetAsync("structures")
    end)

    if success then
        if data then
            Logger.Info("DataManager", "Loaded structure data for player %d.", playerId)
            return data
        else
            Logger.Info("DataManager", "No existing structure data for player %d. Returning empty table.", playerId)
            return {}
        end
    else
        -- Handle the case where 'data' might be an Instance or other non-string object
        local errorMessage = tostring(data)
        Logger.Error("DataManager", "Failed to load structure data for player %d: %s", playerId, errorMessage)
        return {}
    end
end

--[[
    DataManager:SaveStructureData(playerId, structureData)
    Saves structure data for a player to the DataStore.
    @param playerId number: The UserId of the player.
    @param structureData table: The structure data to save.
    @return boolean: True if save was successful, false otherwise.
]]
function DataManager:SaveStructureData(playerId, structureData)
    local success, err = pcall(function()
        local structureDataStore = DataStoreService:GetDataStore(Constants.DATA_STORE_KEYS.STRUCTURE_DATA .. playerId)
        structureDataStore:SetAsync("structures", structureData)
    end)

    if success then
        Logger.Info("DataManager", "Saved structure data for player %d.", playerId)
    else
        -- Handle the case where 'err' might be an Instance or other non-string object
        local errorMessage = tostring(err)
        Logger.Error("DataManager", "Failed to save structure data for player %d: %s", playerId, errorMessage)
    end
    return success
end

return DataManager
