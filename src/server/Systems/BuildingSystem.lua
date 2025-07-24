--[[
    Systems/BuildingSystem.lua
    Description: Manages the placement and state of player-built structures.
    This service handles requests from clients to place structures, performs
    server-side validation, and manages the creation of the physical objects.
    Inherits from BaseService.
]]
local BaseService = require(game.ServerScriptService.Server.Core.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local StateValidator = require(game.ServerScriptService.Server.Core.StateValidator)
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BuildingSystem = {}
BuildingSystem.__index = BuildingSystem
setmetatable(BuildingSystem, BaseService) -- Inherit from BaseService

-- Private variables
local _structureModels = {} -- Cache of structure models (now generated parts)
local _placedStructures = {} -- Stores references to currently placed structures in workspace
local _structuresFolder = nil -- Reference to the Workspace.Structures folder

function BuildingSystem.new(serviceName)
    local self = setmetatable({}, BuildingSystem)
    -- CORRECTED: Removed redundant setmetatable(self, BaseService) as it's already done above
    Logger.Debug(self:GetServiceName(), "BuildingSystem instance created.")
    return self
end

function BuildingSystem:Init()
    BaseService.Init(self)
    Logger.Info(self:GetServiceName(), "BuildingSystem initialized.")

    -- Ensure the 'Structures' folder exists in Workspace
    _structuresFolder = Workspace:FindFirstChild("Structures")
    if not _structuresFolder then
        _structuresFolder = Instance.new("Folder")
        _structuresFolder.Name = "Structures"
        _structuresFolder.Parent = Workspace
        Logger.Info(self:GetServiceName(), "Created 'Structures' folder in Workspace.")
    else
        Logger.Debug(self:GetServiceName(), "'Structures' folder already exists in Workspace.")
    end

    -- NEW: Generate basic part models for each structure type
    Logger.Debug(self:GetServiceName(), "Starting to generate models for structure types")
    for key, structureType in pairs(Constants.STRUCTURE_TYPES) do
        Logger.Debug(self:GetServiceName(), "Processing structure type: %s (key: %s)", structureType, key)
        local partProperties = Constants.BUILDING_PART_DEFAULTS[structureType]
        if partProperties then
            Logger.Debug(self:GetServiceName(), "Creating model for %s with properties: %s", structureType, tostring(partProperties.Size))
            local part = Instance.new("Part")
            part.Name = structureType
            part.Size = partProperties.Size
            part.BrickColor = partProperties.Color
            part.Material = partProperties.Material
            part.Anchored = true -- Structures should be anchored
            part.CanCollide = true
            part.Transparency = 0.5 -- Make them slightly transparent for now, easier to see placement
            part.CFrame = CFrame.new(0, -10000, 0) -- Move far away initially

            local model = Instance.new("Model")
            model.Name = structureType
            part.Parent = model
            model.PrimaryPart = part -- Set PrimaryPart for CFrame manipulation
            model.Parent = ReplicatedStorage -- Store in ReplicatedStorage for client previewing and server cloning

            _structureModels[structureType] = model
            Logger.Debug(self:GetServiceName(), "Successfully created and stored model for: %s in ReplicatedStorage", structureType)
        else
            Logger.Warn(self:GetServiceName(), "Missing default properties for structure type: %s", structureType)
        end
    end
    Logger.Debug(self:GetServiceName(), "Finished generating models. Total models in _structureModels: %d", #_structureModels)
    -- REMOVED: ServerStorage model loading logic is no longer needed

    -- The RemoteFunction is now registered once in init.server.luau
end

function BuildingSystem:Start()
    BaseService.Start(self)
    Logger.Info(self:GetServiceName(), "BuildingSystem started.")

    -- Connect server-side listener for build requests
    local buildRequestFunction = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_BUILD)
    if buildRequestFunction then
        buildRequestFunction.OnServerInvoke = function(player, structureType, cframe)
            return self:PlaceStructure(player, structureType, cframe)
        end
    else
        Logger.Error(self:GetServiceName(), "Failed to get ClientRequestBuild RemoteFunction.")
    end

    -- Load existing structures from DataManager (placeholder for now)
    self:LoadAllStructures()
end

function BuildingSystem:Stop()
    BaseService.Stop(self)
    -- Disconnect network event
    local buildRequestFunction = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_BUILD)
    if buildRequestFunction then
        buildRequestFunction.OnServerInvoke = nil
    end
    _structureModels = {}
    _placedStructures = {}
    Logger.Info(self:GetServiceName(), "BuildingSystem stopped.")
end

--[[
    BuildingSystem:PlaceStructure(player, structureType, cframe)
    Handles a request to place a structure. Performs validation and places the structure in the workspace.
    @param player Player: The player requesting the placement.
    @param structureType string: The type of structure to place (e.g., "Wall", "Floor").
    @param cframe CFrame: The desired CFrame for the structure.
    @return boolean: True if placement was successful, false otherwise.
]]
function BuildingSystem:PlaceStructure(player, structureType, cframe)
    -- 1. Basic Validation (server-side)
    if not player then
        Logger.Warn(self:GetServiceName(), "Invalid build request: Player is nil.")
        return false, "Invalid player."
    end
    if not _structureModels[structureType] then
        Logger.Warn(self:GetServiceName(), "Invalid build request from %s: Unknown structure type '%s'.", player.Name, structureType)
        return false, "Invalid structure type."
    end
    if typeof(cframe) ~= "CFrame" then
        Logger.Warn(self:GetServiceName(), "Invalid build request from %s: Invalid CFrame provided (type: %s).", player.Name, typeof(cframe))
        return false, "Invalid placement CFrame."
    end

    -- 2. Resource Check (placeholder)
    -- local playerData = DataManager:LoadPlayerData(player) -- Would load current player resources
    -- if not self:HasEnoughResources(playerData, structureType) then
    --     self:SendFeedback(player, "Not enough resources to build " .. structureType .. ".")
    --     return false, "Not enough resources."
    -- end

    -- 3. Placement Validation (using StateValidator)
    -- This would involve more complex checks like collision, ground alignment, etc.
    if not StateValidator.ValidateStructurePlacement(cframe.Position, cframe) then
        Logger.Warn(self:GetServiceName(), "%s attempted invalid structure placement for %s at %s.", player.Name, structureType, tostring(cframe.Position))
        return false, "Invalid placement location."
    end

    -- 4. Create and Place Structure
    local structureModel = _structureModels[structureType]:Clone()
    structureModel.Name = structureType .. "_" .. player.UserId .. "_" .. os.time() -- Unique name
    structureModel:SetPrimaryPartCFrame(cframe)
    structureModel.Parent = _structuresFolder

    -- Set up initial properties (e.g., health, owner)
    local structureHealth = Instance.new("NumberValue")
    structureHealth.Name = "Health"
    structureHealth.Value = Constants.MAX_STRUCTURE_HEALTH -- Define this in Constants
    structureHealth.Parent = structureModel

    local ownerId = Instance.new("IntValue")
    ownerId.Name = "OwnerId"
    ownerId.Value = player.UserId
    ownerId.Parent = structureModel

    table.insert(_placedStructures, structureModel) -- Track placed structures

    -- 5. Deduct Resources (placeholder)
    -- self:DeductResources(playerData, structureType)
    -- DataManager:SavePlayerData(player, playerData)

    -- 6. Save Structure Data (placeholder for DataManager)
    -- DataManager:SaveBaseData(player.UserId, {
    --     structureType = structureType,
    --     cframe = cframe,
    --     health = structureHealth.Value,
    --     -- etc.
    -- })

    Logger.Info(self:GetServiceName(), "%s successfully placed %s at %s.", player.Name, structureType, tostring(cframe.Position))
    return true, "Structure placed!"
end

--[[
    BuildingSystem:LoadAllStructures()
    Loads all saved structures from the DataManager and places them in the workspace.
    (Placeholder implementation)
]]
function BuildingSystem:LoadAllStructures()
    Logger.Info(self:GetServiceName(), "Loading all saved structures (placeholder).")
    -- In a full implementation, this would fetch data via DataManager
    -- and re-create the structures in the workspace.
end

-- Example helper for resource checking (will be moved to a dedicated resource system later)
-- function BuildingSystem:HasEnoughResources(playerData, structureType)
--     -- Implement resource check logic here
--     return true
-- end

-- Example helper for resource deduction (will be moved to a dedicated resource system later)
-- function BuildingSystem:DeductResources(playerData, structureType)
--     -- Implement resource deduction logic here
-- end

return BuildingSystem
