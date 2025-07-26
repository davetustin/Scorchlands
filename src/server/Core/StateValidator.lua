--[[
    Core/StateValidator.lua
    Description: Provides utilities for validating game states and data.
    Ensures data integrity and prevents invalid states, crucial for security
    and robustness, especially with networked data.
]]
local StateValidator = {}
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local Constants = require(game.ReplicatedStorage.Shared.Constants)

-- Security constants
local MAX_POSITION_DISTANCE = 1000 -- Maximum allowed position distance from origin
local MAX_CFRAME_DISTANCE = 2000 -- Maximum allowed CFrame distance
local MIN_HEALTH = 0
local MAX_RESOURCE_AMOUNT = 999999
local MAX_STRUCTURE_COUNT_PER_PLAYER = 100
local MAX_COMMAND_LENGTH = 100

-- Rate limiting for security
local _playerActionTimestamps = {}
local _rateLimitWindow = 1 -- 1 second window
local _maxActionsPerWindow = 10 -- Max actions per second per player

--[[
    StateValidator.ValidatePlayerHealth(health)
    Validates if a given health value is within acceptable bounds.
    @param health number: The health value to validate.
    @return boolean: True if valid, false otherwise.
]]
function StateValidator.ValidatePlayerHealth(health)
    if type(health) ~= "number" or health < MIN_HEALTH or health > Constants.MAX_HEALTH then
        Logger.Warn("StateValidator", "Invalid player health value: %s (Expected %d-%d)", tostring(health), MIN_HEALTH, Constants.MAX_HEALTH)
        return false
    end
    return true
end

--[[
    StateValidator.ValidateResourceAmount(resourceType, amount)
    Validates if a given resource amount is valid for a specific type.
    @param resourceType string: The type of resource (e.g., "Wood", "Stone").
    @param amount number: The amount of the resource.
    @return boolean: True if valid, false otherwise.
]]
function StateValidator.ValidateResourceAmount(resourceType, amount)
    if type(resourceType) ~= "string" or type(amount) ~= "number" or amount < 0 or amount > MAX_RESOURCE_AMOUNT then
        Logger.Warn("StateValidator", "Invalid resource amount or type: %s, %s (Max: %d)", tostring(resourceType), tostring(amount), MAX_RESOURCE_AMOUNT)
        return false
    end
    
    -- Validate resource type against allowed types
    local validResourceTypes = {"Wood", "Stone", "Metal"}
    if not table.find(validResourceTypes, resourceType) then
        Logger.Warn("StateValidator", "Invalid resource type: %s", resourceType)
        return false
    end
    
    return true
end

--[[
    StateValidator.ValidateStructurePlacement(position, cframe)
    Validates structure placement for security and game rules.
    @param position Vector3: The desired position.
    @param cframe CFrame: The desired CFrame.
    @return boolean: True if valid, false otherwise.
]]
function StateValidator.ValidateStructurePlacement(position, cframe)
    if not (typeof(position) == "Vector3" and typeof(cframe) == "CFrame") then
        Logger.Warn("StateValidator", "Invalid position or CFrame type for structure placement.")
        return false
    end
    
    -- Check position bounds
    if position.Magnitude > MAX_POSITION_DISTANCE then
        Logger.Warn("StateValidator", "Structure position too far from origin: %s", tostring(position))
        return false
    end
    
    -- Check CFrame bounds
    local cframePosition = cframe.Position
    if cframePosition.Magnitude > MAX_CFRAME_DISTANCE then
        Logger.Warn("StateValidator", "Structure CFrame too far from origin: %s", tostring(cframePosition))
        return false
    end
    
    -- Check for NaN or infinite values
    if not (math.abs(position.X) < math.huge and math.abs(position.Y) < math.huge and math.abs(position.Z) < math.huge) then
        Logger.Warn("StateValidator", "Invalid position values (NaN/Inf): %s", tostring(position))
        return false
    end
    
    return true
end

--[[
    StateValidator.ValidateStructureType(structureType)
    Validates if a structure type is allowed.
    @param structureType string: The structure type to validate.
    @return boolean: True if valid, false otherwise.
]]
function StateValidator.ValidateStructureType(structureType)
    if type(structureType) ~= "string" then
        Logger.Warn("StateValidator", "Invalid structure type: not a string")
        return false
    end
    
    -- Check against allowed structure types
    for _, validType in pairs(Constants.STRUCTURE_TYPES) do
        if structureType == validType then
            return true
        end
    end
    
    Logger.Warn("StateValidator", "Invalid structure type: %s", structureType)
    return false
end

--[[
    StateValidator.ValidateCommandInput(commandString)
    Validates command input for security.
    @param commandString string: The command string to validate.
    @return boolean: True if valid, false otherwise.
]]
function StateValidator.ValidateCommandInput(commandString)
    if type(commandString) ~= "string" then
        Logger.Warn("StateValidator", "Invalid command: not a string")
        return false
    end
    
    if #commandString > MAX_COMMAND_LENGTH then
        Logger.Warn("StateValidator", "Command too long: %d characters (max: %d)", #commandString, MAX_COMMAND_LENGTH)
        return false
    end
    
    -- Check for potentially dangerous characters or patterns
    local dangerousPatterns = {
        "script", "loadstring", "pcall", "xpcall", "require", "getfenv", "setfenv"
    }
    
    local lowerCommand = commandString:lower()
    for _, pattern in ipairs(dangerousPatterns) do
        if lowerCommand:find(pattern) then
            Logger.Warn("StateValidator", "Command contains dangerous pattern: %s", pattern)
            return false
        end
    end
    
    return true
end

--[[
    StateValidator.CheckRateLimit(player, actionType)
    Implements rate limiting to prevent spam and exploits.
    @param player Player: The player to check.
    @param actionType string: The type of action being performed.
    @return boolean: True if within rate limit, false if rate limited.
]]
function StateValidator.CheckRateLimit(player, actionType)
    local playerId = player.UserId
    local currentTime = tick()
    
    if not _playerActionTimestamps[playerId] then
        _playerActionTimestamps[playerId] = {}
    end
    
    local playerActions = _playerActionTimestamps[playerId]
    
    -- Clean old timestamps
    for i = #playerActions, 1, -1 do
        if currentTime - playerActions[i] > _rateLimitWindow then
            table.remove(playerActions, i)
        end
    end
    
    -- Check if player has exceeded rate limit
    if #playerActions >= _maxActionsPerWindow then
        Logger.Warn("StateValidator", "Rate limit exceeded for player %s (%s)", player.Name, actionType)
        return false
    end
    
    -- Add current action timestamp
    table.insert(playerActions, currentTime)
    return true
end

--[[
    StateValidator.ValidatePlayerOwnership(player, structureData)
    Validates that a player owns a structure they're trying to modify.
    @param player Player: The player attempting the action.
    @param structureData table: The structure data containing owner information.
    @return boolean: True if player owns the structure, false otherwise.
]]
function StateValidator.ValidatePlayerOwnership(player, structureData)
    if not structureData or not structureData.OwnerId then
        Logger.Warn("StateValidator", "Invalid structure data for ownership validation")
        return false
    end
    
    if structureData.OwnerId ~= player.UserId then
        Logger.Warn("StateValidator", "Player %s attempted to modify structure owned by %d", player.Name, structureData.OwnerId)
        return false
    end
    
    return true
end

--[[
    StateValidator.CleanupPlayerData(playerId)
    Cleans up rate limiting data when a player leaves.
    @param playerId number: The UserId of the player who left.
]]
function StateValidator.CleanupPlayerData(playerId)
    _playerActionTimestamps[playerId] = nil
end

return StateValidator
