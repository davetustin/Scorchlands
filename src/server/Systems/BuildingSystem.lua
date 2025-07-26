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
local DataManager = require(game.ServerScriptService.Server.Core.DataManager)
local GlobalRegistry = require(game.ServerScriptService.Server.Core.GlobalRegistry)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local BuildingSystem = {}
BuildingSystem.__index = BuildingSystem
setmetatable(BuildingSystem, BaseService) -- Inherit from BaseService

-- Private variables
local _structureModels = {} -- Cache of structure models (now generated parts)
local _placedStructures = {} -- Stores references to currently placed structures in workspace
local _structuresFolder = nil -- Reference to the Workspace.Structures folder

-- Structure Health System Variables
local _structureHealthData = {} -- Stores health data for each structure: {structureId = {health, material, lastDamageTime, lastHealthCheck}}
local _healthCheckConnection = nil -- Connection for periodic health checks
local _sunlightCheckConnection = nil -- Connection for periodic sunlight exposure checks
local _lastHealthCheck = 0 -- Last time health check was performed
local _lastSunlightCheck = 0 -- Last time sunlight check was performed
-- Building-specific sunlight damage toggle (separate from player damage)
local _buildingSunlightDamageEnabled = Constants.BUILDING_SUNLIGHT_DAMAGE_ENABLED_DEFAULT
-- Notification cooldown tracking to prevent spam
local _notificationCooldowns = {} -- {structureId = {lastWarningTime, lastCriticalTime}}

--[[
    BuildingSystem:SaveStructureData(playerId)
    Saves all structure data for a player to the DataManager.
    @param playerId number: The UserId of the player.
]]
function BuildingSystem:SaveStructureData(playerId)
    local playerStructures = {}
    
    -- Collect all structures owned by this player
    for structureId, healthData in pairs(_structureHealthData) do
        if healthData.ownerId == playerId then
            local structure = self:GetStructureById(structureId)
            if structure then
                -- Get the structure's CFrame for persistence
                local cframe = structure:GetPrimaryPartCFrame()
                
                -- Convert CFrame to serializable format for DataStore
                local serializedCFrame = {
                    Position = {
                        X = cframe.Position.X,
                        Y = cframe.Position.Y,
                        Z = cframe.Position.Z
                    },
                    -- Store the CFrame components as individual numbers
                    CFrame = {
                        cframe.XVector.X, cframe.XVector.Y, cframe.XVector.Z,
                        cframe.YVector.X, cframe.YVector.Y, cframe.YVector.Z,
                        cframe.ZVector.X, cframe.ZVector.Y, cframe.ZVector.Z,
                        cframe.Position.X, cframe.Position.Y, cframe.Position.Z
                    }
                }
                
                playerStructures[structureId] = {
                    health = healthData.health,
                    material = healthData.material,
                    structureType = healthData.structureType,
                    cframe = serializedCFrame,
                    lastDamageTime = healthData.lastDamageTime,
                    lastHealthCheck = healthData.lastHealthCheck
                }
            end
        end
    end
    
    -- Save to DataManager using the global instance
    local dataManager = GlobalRegistry.Get("DataManager")
    
    -- Debug: Check if DataManager exists and has the required method
    if not dataManager then
        Logger.Error(self:GetServiceName(), "DataManager not found in GlobalRegistry")
        return
    end
    
    if not dataManager.SaveStructureData then
        Logger.Error(self:GetServiceName(), "SaveStructureData method not found on DataManager instance")
        return
    end
    
    dataManager:SaveStructureData(playerId, playerStructures)
    
    -- Count structures properly (since playerStructures uses string keys)
    local structureCount = 0
    for _ in pairs(playerStructures) do
        structureCount = structureCount + 1
    end
    
    Logger.Debug(self:GetServiceName(), "Saved %d structures for player %d", 
        structureCount, playerId)
end

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
    -- Count models properly (since _structureModels uses string keys)
    local modelCount = 0
    for _ in pairs(_structureModels) do
        modelCount = modelCount + 1
    end
    Logger.Debug(self:GetServiceName(), "Finished generating models. Total models in _structureModels: %d", modelCount)
    -- REMOVED: ServerStorage model loading logic is no longer needed

    -- The RemoteFunction is now registered once in init.server.luau
end

function BuildingSystem:Start()
    BaseService.Start(self)
    
    -- Register this service in GlobalRegistry for cross-service communication
    GlobalRegistry.Set("BuildingSystem", self)
    
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

    -- Connect server-side listener for repair requests
    local repairRequestFunction = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_REPAIR)
    if repairRequestFunction then
        repairRequestFunction.OnServerInvoke = function(player, structureId)
            return self:RepairStructure(structureId, player)
        end
    else
        Logger.Error(self:GetServiceName(), "Failed to get ClientRequestRepair RemoteFunction.")
    end

    -- Initialize structure health system
    self:InitializeStructureHealthSystem()

    -- Load existing structures from DataManager (placeholder for now)
    self:LoadAllStructures()
    
    -- Set initial building damage state based on whether players are online
    local Players = game:GetService("Players")
    if #Players:GetPlayers() == 0 then
        -- No players online, disable building damage
        self:SetBuildingSunlightDamageEnabled(false)
        Logger.Info(self:GetServiceName(), "No players online at startup. Building sunlight damage disabled.")
    else
        -- Players are online, enable building damage
        self:SetBuildingSunlightDamageEnabled(true)
        Logger.Info(self:GetServiceName(), "Players online at startup. Building sunlight damage enabled.")
    end
    
    -- Connect player leaving event to save their structures
    local Players = game:GetService("Players")
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
    
    -- Connect player joining event to load their structures
    Players.PlayerAdded:Connect(function(player)
        -- Wait a moment for the player to fully join, then load their structures
        task.wait(1)
        Logger.Info(self:GetServiceName(), "Loading structures for joining player %s (UserId: %d)", player.Name, player.UserId)
        
        -- Re-enable building sunlight damage when player joins
        self:SetBuildingSunlightDamageEnabled(true)
        
        self:LoadPlayerStructures(player.UserId)
    end)
end

function BuildingSystem:Stop()
    BaseService.Stop(self)
    -- Disconnect network event
    local buildRequestFunction = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_BUILD)
    if buildRequestFunction then
        buildRequestFunction.OnServerInvoke = nil
    end
    
    local repairRequestFunction = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_REPAIR)
    if repairRequestFunction then
        repairRequestFunction.OnServerInvoke = nil
    end
    
    -- Clean up health system connections
    if _healthCheckConnection then
        _healthCheckConnection:Disconnect()
        _healthCheckConnection = nil
    end
    if _sunlightCheckConnection then
        _sunlightCheckConnection:Disconnect()
        _sunlightCheckConnection = nil
    end
    
    _structureModels = {}
    _placedStructures = {}
    _structureHealthData = {}
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
    -- 1. Security: Rate limiting check
    if not StateValidator.CheckRateLimit(player, "build_structure") then
        Logger.Warn(self:GetServiceName(), "Rate limit exceeded for %s building %s.", player.Name, structureType)
        return false, "Rate limit exceeded. Please wait before building again."
    end

    -- 2. Basic Validation (server-side)
    if not player then
        Logger.Warn(self:GetServiceName(), "Invalid build request: Player is nil.")
        return false, "Invalid player."
    end
    
    -- 3. Security: Validate structure type
    if not StateValidator.ValidateStructureType(structureType) then
        Logger.Warn(self:GetServiceName(), "Invalid build request from %s: Unknown structure type '%s'.", player.Name, structureType)
        return false, "Invalid structure type."
    end
    
    if not _structureModels[structureType] then
        Logger.Warn(self:GetServiceName(), "Structure model not found for type '%s'.", structureType)
        return false, "Structure type not available."
    end
    
    if typeof(cframe) ~= "CFrame" then
        Logger.Warn(self:GetServiceName(), "Invalid build request from %s: Invalid CFrame provided (type: %s).", player.Name, typeof(cframe))
        return false, "Invalid placement CFrame."
    end

    -- 4. Security: Enhanced placement validation
    if not StateValidator.ValidateStructurePlacement(cframe.Position, cframe) then
        Logger.Warn(self:GetServiceName(), "%s attempted invalid structure placement for %s at %s.", player.Name, structureType, tostring(cframe.Position))
        return false, "Invalid placement location."
    end

    -- 5. Security: Check player structure count limit
    local playerStructureCount = self:GetPlayerStructureCount(player.UserId)
    if playerStructureCount >= Constants.MAX_STRUCTURE_COUNT_PER_PLAYER then
        Logger.Warn(self:GetServiceName(), "%s exceeded structure limit (%d).", player.Name, Constants.MAX_STRUCTURE_COUNT_PER_PLAYER)
        return false, "Structure limit reached."
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

    -- Initialize structure health data
    local structureId = structureModel.Name
    local defaultMaterial = Constants.STRUCTURE_HEALTH.DEFAULT_MATERIAL
    local materialData = Constants.STRUCTURE_HEALTH.MATERIALS[defaultMaterial]
    
    _structureHealthData[structureId] = {
        health = materialData.maxHealth,
        material = defaultMaterial,
        lastDamageTime = 0,
        lastHealthCheck = tick(),
        structureType = structureType,
        ownerId = player.UserId
    }
    
    -- Update the NumberValue to match the material's max health
    structureHealth.Value = materialData.maxHealth

    -- Update visual appearance for new structure
    self:UpdateStructureVisualHealth(structureId, _structureHealthData[structureId])

    table.insert(_placedStructures, structureModel) -- Track placed structures

    -- Save structure data to DataManager
    self:SaveStructureData(player.UserId)

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
]]
function BuildingSystem:LoadAllStructures()
    Logger.Info(self:GetServiceName(), "Loading all saved structures.")
    
    local dataManager = GlobalRegistry.Get("DataManager")
    
    -- Debug: Check if DataManager exists and has the required method
    if not dataManager then
        Logger.Error(self:GetServiceName(), "DataManager not found in GlobalRegistry")
        return
    end
    
    -- Debug: Log the DataManager instance details
    Logger.Debug(self:GetServiceName(), "DataManager instance type: %s", typeof(dataManager))
    Logger.Debug(self:GetServiceName(), "DataManager methods: %s", tostring(dataManager.LoadStructureData))
    
    if not dataManager.LoadStructureData then
        Logger.Error(self:GetServiceName(), "LoadStructureData method not found on DataManager instance")
        Logger.Error(self:GetServiceName(), "Available methods: %s", tostring(dataManager))
        return
    end
    
    -- NOTE: For now, we only load structures for currently online players
    -- In a full implementation, you would want to load ALL saved structures regardless of player online status
    -- This would require the DataManager to provide a method to get all player IDs with saved data
    local Players = game:GetService("Players")
    
    -- Load structures for all online players
    for _, player in ipairs(Players:GetPlayers()) do
        self:LoadPlayerStructures(player.UserId)
    end
    
    Logger.Info(self:GetServiceName(), "Finished loading structures for %d online players", #Players:GetPlayers())
end

--[[
    BuildingSystem:LoadPlayerStructures(playerId)
    Loads and recreates all structures for a specific player.
    @param playerId number: The UserId of the player.
]]
function BuildingSystem:LoadPlayerStructures(playerId)
    local dataManager = GlobalRegistry.Get("DataManager")
    -- Debug: Check if DataManager exists and has the required method
    if not dataManager then
        Logger.Error(self:GetServiceName(), "DataManager not found in GlobalRegistry")
        return
    end
    if not dataManager.LoadStructureData then
        Logger.Error(self:GetServiceName(), "LoadStructureData method not found on DataManager instance")
        return
    end
    local savedStructures = dataManager:LoadStructureData(playerId)
    -- Debug: Log how many structures were loaded
    local structureCount = 0
    for _ in pairs(savedStructures) do
        structureCount = structureCount + 1
    end
    if structureCount > 0 then
        Logger.Info(self:GetServiceName(), "Found %d saved structures for player %d", structureCount, playerId)
    else
        Logger.Debug(self:GetServiceName(), "No saved structures found for player %d", playerId)
    end
    for structureId, structureData in pairs(savedStructures) do
        -- Check if structure model exists
        local structureType = structureData.structureType
        if _structureModels[structureType] then
            -- Recreate the structure
            local structureModel = _structureModels[structureType]:Clone()
            structureModel.Name = structureId -- Use the original ID
            -- Convert serialized CFrame back to proper CFrame
            local cframe
            if structureData.cframe and structureData.cframe.CFrame then
                -- New serialized format
                local cframeData = structureData.cframe.CFrame
                -- Reconstruct CFrame from serialized data (12 components: 9 rotation + 3 position)
                cframe = CFrame.new(
                    cframeData[10], cframeData[11], cframeData[12],  -- Position
                    cframeData[1], cframeData[2], cframeData[3],     -- XVector
                    cframeData[4], cframeData[5], cframeData[6],     -- YVector
                    cframeData[7], cframeData[8], cframeData[9]      -- ZVector
                )
            else
                -- Fallback for old format or invalid data
                cframe = CFrame.new(0, 0, 0)
                Logger.Warn(self:GetServiceName(), "Invalid CFrame data for structure %s, using default position", structureId)
            end
            structureModel:SetPrimaryPartCFrame(cframe)
            structureModel.Parent = _structuresFolder
            -- Restore health data
            local structureHealth = Instance.new("NumberValue")
            structureHealth.Name = "Health"
            structureHealth.Value = structureData.health
            structureHealth.Parent = structureModel
            local ownerId = Instance.new("IntValue")
            ownerId.Name = "OwnerId"
            ownerId.Value = playerId
            ownerId.Parent = structureModel
            -- Restore health data in memory
            _structureHealthData[structureId] = {
                health = structureData.health,
                material = structureData.material,
                structureType = structureData.structureType,
                lastDamageTime = structureData.lastDamageTime or 0,
                lastHealthCheck = structureData.lastHealthCheck or tick(),
                ownerId = playerId
            }
            -- Update visual appearance for loaded structure
            self:UpdateStructureVisualHealth(structureId, _structureHealthData[structureId])
            
            table.insert(_placedStructures, structureModel)
            -- Logger.Debug(self:GetServiceName(), "Loaded structure %s (%s) for player %d with health %f", 
            --     structureId, structureType, playerId, structureData.health)
        else
            Logger.Warn(self:GetServiceName(), "Structure model not found for type '%s'. Skipping structure %s.", 
                structureType, structureId)
        end
    end
    -- Count structures properly (since savedStructures uses string keys)
    local structureCount = 0
    for _ in pairs(savedStructures) do
        structureCount = structureCount + 1
    end
    Logger.Info(self:GetServiceName(), "Loaded %d structures for player %d", 
        structureCount, playerId)
end

-- Example helper for resource checking (will be moved to a dedicated resource system later)
-- function BuildingSystem:HasEnoughResources(playerData, structureType)
--     -- Implement resource check logic here
--     return true
-- end

--[[
    BuildingSystem:GetPlayerStructureCount(playerId)
    Gets the number of structures owned by a player.
    @param playerId number: The UserId of the player.
    @return number: The number of structures owned by the player.
]]
function BuildingSystem:GetPlayerStructureCount(playerId)
    local count = 0
    for _, structure in ipairs(_placedStructures) do
        local ownerId = structure:FindFirstChild("OwnerId")
        if ownerId and ownerId.Value == playerId then
            count = count + 1
        end
    end
    return count
end

-- Example helper for resource deduction (will be moved to a dedicated resource system later)
-- function BuildingSystem:DeductResources(playerData, structureType)
--     -- Implement resource deduction logic here
-- end

--[[
    Structure Health System Functions
]]

--[[
    BuildingSystem:InitializeStructureHealthSystem()
    Initializes the structure health system with periodic checks for health and sunlight exposure.
]]
function BuildingSystem:InitializeStructureHealthSystem()
    Logger.Info(self:GetServiceName(), "Initializing structure health system.")
    
    -- Set up periodic health checks
    _healthCheckConnection = RunService.Heartbeat:Connect(function(deltaTime)
        self:CheckStructureHealth(deltaTime)
    end)
    
    -- Set up periodic sunlight exposure checks
    _sunlightCheckConnection = RunService.Heartbeat:Connect(function(deltaTime)
        self:CheckSunlightExposure(deltaTime)
    end)
    
    Logger.Info(self:GetServiceName(), "Structure health system initialized.")
    Logger.Info(self:GetServiceName(), "Building sunlight damage is currently %s.",
        _buildingSunlightDamageEnabled and "ENABLED" or "DISABLED")
end

--[[
    BuildingSystem:CheckStructureHealth(deltaTime)
    Performs periodic health checks on all structures and handles destruction of critically damaged structures.
    @param deltaTime number: Time since last frame.
]]
function BuildingSystem:CheckStructureHealth(deltaTime)
    local currentTime = tick()
    
    -- Only check at specified intervals
    if currentTime - _lastHealthCheck < Constants.STRUCTURE_HEALTH.HEALTH_CHECK_INTERVAL then
        return
    end
    _lastHealthCheck = currentTime
    
    for structureId, healthData in pairs(_structureHealthData) do
        local structure = self:GetStructureById(structureId)
        if not structure then
            -- Structure no longer exists, clean up data
            _structureHealthData[structureId] = nil
            Logger.Debug(self:GetServiceName(), "Cleaned up health data for non-existent structure: %s", structureId)
        else
            -- Check if structure should be destroyed due to critical health
            if healthData.health <= 0 then
                self:DestroyStructure(structureId, "Critical health damage")
            end
        end
    end
end

--[[
    BuildingSystem:CheckSunlightExposure(deltaTime)
    Checks all structures for sunlight exposure and applies damage accordingly.
    @param deltaTime number: Time since last frame.
]]
function BuildingSystem:CheckSunlightExposure(deltaTime)
    local currentTime = tick()
    
    -- Only check at specified intervals
    if currentTime - _lastSunlightCheck < Constants.STRUCTURE_HEALTH.SUNLIGHT_CHECK_INTERVAL then
        return
    end
    _lastSunlightCheck = currentTime
    
    -- Get sun direction for raycasting
    local sunDirection = Workspace.CurrentCamera.CFrame.LookVector
    local rayDirection = -sunDirection * 1000
    
    -- Use building-specific sunlight damage toggle (separate from player damage)
    for structureId, healthData in pairs(_structureHealthData) do
        local structure = self:GetStructureById(structureId)
        if structure then
            local isExposed = self:IsStructureExposedToSunlight(structure, rayDirection)
            
            if isExposed and _buildingSunlightDamageEnabled then
                self:ApplySunlightDamage(structureId, healthData, deltaTime)
            end
        end
    end
end

--[[
    BuildingSystem:IsStructureExposedToSunlight(structure, rayDirection)
    Determines if a structure is exposed to direct sunlight using raycasting.
    @param structure Model: The structure to check.
    @param rayDirection Vector3: The direction of sunlight rays.
    @return boolean: True if the structure is exposed to sunlight.
]]
function BuildingSystem:IsStructureExposedToSunlight(structure, rayDirection)
    local primaryPart = structure.PrimaryPart
    if not primaryPart then
        return false
    end
    
    local rayOrigin = primaryPart.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {structure}
    rayParams.IgnoreWater = true
    
    local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
    return raycastResult == nil -- No hit means exposed to sunlight
end

--[[
    BuildingSystem:UpdateStructureVisualHealth(structureId, healthData)
    Updates the visual appearance of a structure based on its health.
    @param structureId string: The ID of the structure.
    @param healthData table: The health data for the structure.
]]
function BuildingSystem:UpdateStructureVisualHealth(structureId, healthData)
    local structure = self:GetStructureById(structureId)
    if not structure then
        return
    end
    
    local materialData = Constants.STRUCTURE_HEALTH.MATERIALS[healthData.material]
    if not materialData then
        return
    end
    
    local healthPercentage = (healthData.health / materialData.maxHealth) * 100
    local newColor = nil
    
    -- Determine color based on health thresholds from constants
    if healthData.health <= Constants.STRUCTURE_HEALTH.CRITICAL_HEALTH_THRESHOLD then
        -- Red for critical health
        newColor = Color3.fromRGB(255, 0, 0) -- Red
    elseif healthData.health <= Constants.STRUCTURE_HEALTH.REPAIR_WARNING_THRESHOLD then
        -- Yellow for low health
        newColor = Color3.fromRGB(255, 255, 0) -- Yellow
    else
        -- Default color for healthy structures
        newColor = Color3.fromRGB(255, 255, 255) -- White
    end
    
    -- Apply color to all parts in the structure
    for _, part in pairs(structure:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Color = newColor
            -- Keep existing transparency
            if part.Transparency then
                part.Transparency = part.Transparency
            end
        end
    end
end

--[[
    BuildingSystem:ApplySunlightDamage(structureId, healthData, deltaTime)
    Applies sunlight damage to a structure.
    @param structureId string: The ID of the structure.
    @param healthData table: The health data for the structure.
    @param deltaTime number: Time since last frame.
]]
function BuildingSystem:ApplySunlightDamage(structureId, healthData, deltaTime)
    local materialData = Constants.STRUCTURE_HEALTH.MATERIALS[healthData.material]
    if not materialData then
        Logger.Warn(self:GetServiceName(), "Unknown material for structure %s: %s", structureId, healthData.material)
        return
    end
    
    -- Apply correct per-second damage based on the interval, not deltaTime
    local interval = Constants.STRUCTURE_HEALTH.SUNLIGHT_CHECK_INTERVAL
    local damageAmount = materialData.sunlightDamageRate * interval
    local newHealth = healthData.health - damageAmount
    
    -- Ensure health doesn't go below 0
    if newHealth < 0 then
        newHealth = 0
    end
    
    -- Update health data
    healthData.health = newHealth
    healthData.lastDamageTime = tick()
    
    -- Update the structure's NumberValue
    local structure = self:GetStructureById(structureId)
    if structure then
        local healthValue = structure:FindFirstChild("Health")
        if healthValue then
            healthValue.Value = newHealth
        end
    end
    
    -- Update visual appearance based on new health
    self:UpdateStructureVisualHealth(structureId, healthData)
    
    -- Check for repair notifications
    self:CheckRepairNotifications(structureId, healthData, materialData)
end

--[[
    BuildingSystem:CheckRepairNotifications(structureId, healthData, materialData)
    Checks if repair notifications should be sent to the structure owner.
    @param structureId string: The ID of the structure.
    @param healthData table: The health data for the structure.
    @param materialData table: The material data for the structure.
]]
function BuildingSystem:CheckRepairNotifications(structureId, healthData, materialData)
    local ownerId = healthData.ownerId
    local player = game.Players:GetPlayerByUserId(ownerId)
    
    if not player then
        return -- Player not online
    end
    
    local currentTime = tick()
    local cooldownTime = 5 -- 5 seconds between notifications of the same type
    
    -- Initialize cooldown tracking for this structure if it doesn't exist
    if not _notificationCooldowns[structureId] then
        _notificationCooldowns[structureId] = {lastWarningTime = 0, lastCriticalTime = 0}
    end
    
    local cooldown = _notificationCooldowns[structureId]
    
    -- Check for critical health warning first (highest priority)
    if healthData.health <= Constants.STRUCTURE_HEALTH.CRITICAL_HEALTH_THRESHOLD then
        if currentTime - cooldown.lastCriticalTime >= cooldownTime then
            self:SendRepairNotification(player, structureId, "CRITICAL", healthData.structureType)
            cooldown.lastCriticalTime = currentTime
        end
    -- Check for repair warning only if not critical
    elseif healthData.health <= Constants.STRUCTURE_HEALTH.REPAIR_WARNING_THRESHOLD then
        if currentTime - cooldown.lastWarningTime >= cooldownTime then
            self:SendRepairNotification(player, structureId, "WARNING", healthData.structureType)
            cooldown.lastWarningTime = currentTime
        end
    end
end

--[[
    BuildingSystem:SendRepairNotification(player, structureId, notificationType, structureType)
    Sends a repair notification to a player.
    @param player Player: The player to notify.
    @param structureId string: The ID of the structure.
    @param notificationType string: The type of notification ("WARNING" or "CRITICAL").
    @param structureType string: The type of structure.
]]
function BuildingSystem:SendRepairNotification(player, structureId, notificationType, structureType)
    -- TODO: Implement proper notification system
    -- For now, we'll use a simple print/log approach
    local message = string.format("Structure %s (%s) needs repair! Health: %s", 
        structureType, structureId, notificationType)
    
    if notificationType == "CRITICAL" then
        -- TODO: Send critical notification to player
    else
        -- TODO: Send warning notification to player
    end
end

--[[
    BuildingSystem:DestroyStructure(structureId, reason)
    Destroys a structure and cleans up its data.
    @param structureId string: The ID of the structure.
    @param reason string: The reason for destruction.
]]
function BuildingSystem:DestroyStructure(structureId, reason)
    local structure = self:GetStructureById(structureId)
    if structure then
        Logger.Info(self:GetServiceName(), "Destroying structure %s. Reason: %s", structureId, reason)
        
        -- Remove from workspace
        structure:Destroy()
        
        -- Remove from tracking arrays
        for i, placedStructure in ipairs(_placedStructures) do
            if placedStructure.Name == structureId then
                table.remove(_placedStructures, i)
                break
            end
        end
        
        -- Clean up health data
        local ownerId = _structureHealthData[structureId] and _structureHealthData[structureId].ownerId
        _structureHealthData[structureId] = nil
        
        -- Clean up notification cooldown tracking
        _notificationCooldowns[structureId] = nil
        
        -- Save updated structure data for the owner
        if ownerId then
            self:SaveStructureData(ownerId)
        end
    else
        Logger.Warn(self:GetServiceName(), "Attempted to destroy non-existent structure: %s", structureId)
    end
end

--[[
    BuildingSystem:GetStructureById(structureId)
    Gets a structure by its ID.
    @param structureId string: The ID of the structure.
    @return Model|nil: The structure model or nil if not found.
]]
function BuildingSystem:GetStructureById(structureId)
    for _, structure in ipairs(_placedStructures) do
        if structure.Name == structureId then
            return structure
        end
    end
    return nil
end

--[[
    BuildingSystem:RepairStructure(structureId, player)
    Repairs a structure to full health (placeholder for future material system).
    @param structureId string: The ID of the structure.
    @param player Player: The player attempting to repair.
    @return boolean: True if repair was successful.
]]
function BuildingSystem:RepairStructure(structureId, player)
    local healthData = _structureHealthData[structureId]
    if not healthData then
        Logger.Warn(self:GetServiceName(), "Attempted to repair non-existent structure: %s", structureId)
        return false
    end
    
    -- Check if player owns the structure
    if healthData.ownerId ~= player.UserId then
        Logger.Warn(self:GetServiceName(), "Player %s attempted to repair structure %s they don't own.", 
            player.Name, structureId)
        return false
    end
    
    -- TODO: Check if player has required materials for repair
    
    -- Repair to full health
    local materialData = Constants.STRUCTURE_HEALTH.MATERIALS[healthData.material]
    healthData.health = materialData.maxHealth
    
    -- Update the structure's NumberValue
    local structure = self:GetStructureById(structureId)
    if structure then
        local healthValue = structure:FindFirstChild("Health")
        if healthValue then
            healthValue.Value = materialData.maxHealth
        end
    end
    
    Logger.Info(self:GetServiceName(), "Player %s repaired structure %s to full health.", 
        player.Name, structureId)
    
    -- Save updated structure data
    self:SaveStructureData(player.UserId)
    
    return true
end

--[[
    BuildingSystem:OnPlayerLeaving(player)
    Handles when a player leaves the game. Saves their structure data before they disconnect.
    @param player Player: The player who is leaving.
]]
function BuildingSystem:OnPlayerLeaving(player)
    if not player then
        Logger.Warn(self:GetServiceName(), "OnPlayerLeaving called with nil player")
        return
    end
    
    Logger.Info(self:GetServiceName(), "Player %s (UserId: %d) is leaving. Saving their structures.", 
        player.Name, player.UserId)
    
    -- Save the player's structures before they leave
    self:SaveStructureData(player.UserId)
    
    -- Disable building sunlight damage when player leaves to prevent damage after disconnect
    self:SetBuildingSunlightDamageEnabled(false)
    
    Logger.Info(self:GetServiceName(), "Successfully saved structures for leaving player %s", player.Name)
end

--[[
    BuildingSystem:SetBuildingSunlightDamageEnabled(enabled)
    Sets whether building sunlight damage is enabled or disabled.
    @param enabled boolean: True to enable, false to disable.
]]
function BuildingSystem:SetBuildingSunlightDamageEnabled(enabled)
    if type(enabled) == "boolean" then
        _buildingSunlightDamageEnabled = enabled
        Logger.Info(self:GetServiceName(), "Building sunlight damage has been %s.", enabled and "ENABLED" or "DISABLED")
    else
        Logger.Warn(self:GetServiceName(), "Attempted to set building sunlight damage with invalid value: %s", tostring(enabled))
    end
end

--[[
    BuildingSystem:IsBuildingSunlightDamageEnabled()
    Returns the current status of building sunlight damage.
    @return boolean: True if enabled, false if disabled.
]]
function BuildingSystem:IsBuildingSunlightDamageEnabled()
    return _buildingSunlightDamageEnabled
end

return BuildingSystem
