--!native
--!optimize

--[[
    Core/StateValidator.lua
    Description: Provides utilities for validating game states and data.
    Ensures data integrity and prevents invalid states, crucial for security
    and robustness, especially with networked data.
    This is a generic placeholder.
]]
local StateValidator = {}
local Logger = require(script.Parent.Logger)
-- ADDED: Constants is needed for MAX_HEALTH validation
local Constants = require(game.ReplicatedStorage.Shared.Constants)

--[[
    StateValidator.ValidatePlayerHealth(health)
    Validates if a given health value is within acceptable bounds.
    @param health number: The health value to validate.
    @return boolean: True if valid, false otherwise.
]]
function StateValidator.ValidatePlayerHealth(health)
    -- CORRECTED: Use Constants.MAX_HEALTH for robustness
    if type(health) ~= "number" or health < 0 or health > Constants.MAX_HEALTH then
        Logger.Warn("StateValidator", "Invalid player health value: %s (Expected 0-%d)", tostring(health), Constants.MAX_HEALTH)
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
    if type(resourceType) ~= "string" or type(amount) ~= "number" or amount < 0 then
        Logger.Warn("StateValidator", "Invalid resource amount or type: %s, %s", tostring(resourceType), tostring(amount))
        return false
    end
    -- Add specific validation for resourceType if needed (e.g., check against a list of valid types)
    return true
end

--[[
    StateValidator.ValidateStructurePlacement(position, rotation)
    Placeholder for validating structure placement.
    This would involve checking against game rules (e.g., no overlapping, valid terrain).
    @param position Vector3: The desired position.
    @param rotation CFrame: The desired rotation.
    @return boolean: True if valid, false otherwise.
]]
function StateValidator.ValidateStructurePlacement(position, rotation)
    if not (typeof(position) == "Vector3" and typeof(rotation) == "CFrame") then
        Logger.Warn("StateValidator", "Invalid position or rotation for structure placement.")
        return false
    end
    -- Implement actual game-specific validation logic here
    -- e.g., raycasting to check for obstructions, checking terrain type, etc.
    return true
end

-- Add more validation functions as needed for different game states and data types.

return StateValidator
