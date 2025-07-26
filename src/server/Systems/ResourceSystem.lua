--[[
    Systems/ResourceSystem.lua
    Description: Manages resource nodes and gathering functionality.
    This service handles the creation, spawning, and interaction with resource nodes
    such as wood, stone, and other materials that players can gather.
    Inherits from BaseService.
]]
local BaseService = require(game.ServerScriptService.Server.Core.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local StateValidator = require(game.ServerScriptService.Server.Core.StateValidator)
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)
local GlobalRegistry = require(game.ServerScriptService.Server.Core.GlobalRegistry)
local ResourceNodeBuilder = require(game.ReplicatedStorage.Shared.ResourceNodeBuilder)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ResourceSystem = {}
ResourceSystem.__index = ResourceSystem
setmetatable(ResourceSystem, BaseService) -- Inherit from BaseService

-- Add a constructor function
function ResourceSystem.new(serviceName)
    local self = BaseService.new(serviceName)
    setmetatable(self, ResourceSystem)
    Logger.Debug(self:GetServiceName(), "ResourceSystem instance created.")
    return self
end

-- Private variables
local _resourceNodes = {} -- Stores all active resource nodes: {nodeId = {model, resourceType, quantity, lastGathered, respawnTime}}
local _resourceNodesFolder = nil -- Reference to the Workspace.ResourceNodes folder
local _nodeCounter = 0 -- Counter for generating unique node IDs
local _spawnPoints = {} -- Stores spawn points for resource spawning
local _resourceModels = {} -- Cache of resource node models from ReplicatedStorage

--[[
    ResourceSystem:Init()
    Initializes the resource system.
]]
function ResourceSystem:Init()
    if self._isInitialized then
        Logger.Warn(self:GetServiceName(), "ResourceSystem already initialized.")
        return
    end
    
    Logger.Info(self:GetServiceName(), "Starting ResourceSystem initialization...")
    
    -- Call parent init
    BaseService.Init(self)
    Logger.Info(self:GetServiceName(), "BaseService.Init completed")
    
    -- Create resource nodes folder
    _resourceNodesFolder = Instance.new("Folder")
    _resourceNodesFolder.Name = "ResourceNodes"
    _resourceNodesFolder.Parent = Workspace
    Logger.Info(self:GetServiceName(), "ResourceNodes folder created")
    
    -- Load resource models from ReplicatedStorage
    local success, err = pcall(function()
        self:_LoadResourceModels()
    end)
    if not success then
        Logger.Error(self:GetServiceName(), "Failed to load resource models: %s", tostring(err))
    else
        Logger.Info(self:GetServiceName(), "Resource models loaded successfully")
    end
    
    -- Set up spawn points (for now, use a default spawn point)
    success, err = pcall(function()
        self:_SetupSpawnPoints()
    end)
    if not success then
        Logger.Error(self:GetServiceName(), "Failed to setup spawn points: %s", tostring(err))
    else
        Logger.Info(self:GetServiceName(), "Spawn points setup completed")
    end
    
    Logger.Info(self:GetServiceName(), "ResourceSystem initialization completed successfully.")
end

--[[
    ResourceSystem:Start()
    Starts the resource system and begins spawning resource nodes.
]]
function ResourceSystem:Start()
    print("ResourceSystem Start() method called - DEBUG") -- Very early debug print
    Logger.Info(self:GetServiceName(), "ResourceSystem Start() method called")
    
    if not self._isInitialized then
        Logger.Warn(self:GetServiceName(), "ResourceSystem not initialized before starting.")
        self:Init()
    end
    
    if self._isStarted then
        Logger.Warn(self:GetServiceName(), "ResourceSystem already started.")
        return
    end
    
    Logger.Info(self:GetServiceName(), "Calling BaseService.Start...")
    -- Call parent start
    BaseService.Start(self)
    Logger.Info(self:GetServiceName(), "BaseService.Start completed")
    
    Logger.Info(self:GetServiceName(), "Registering in GlobalRegistry...")
    -- Register this service in GlobalRegistry for cross-service communication
    GlobalRegistry.Set("ResourceSystem", self)
    Logger.Info(self:GetServiceName(), "ResourceSystem registered in GlobalRegistry")
    
    -- Spawn initial resource nodes with error handling
    local success, err = pcall(function()
        self:_SpawnInitialResourceNodes()
    end)
    if not success then
        Logger.Error(self:GetServiceName(), "Failed to spawn initial resource nodes: %s", tostring(err))
    end
    
    -- Set up periodic respawn checks with error handling
    success, err = pcall(function()
        self:_StartRespawnChecks()
    end)
    if not success then
        Logger.Error(self:GetServiceName(), "Failed to start respawn checks: %s", tostring(err))
    end
    
    Logger.Info(self:GetServiceName(), "ResourceSystem started successfully.")
end

--[[
    ResourceSystem:_LoadResourceModels()
    Loads resource node models from ReplicatedStorage into cache.
]]
function ResourceSystem:_LoadResourceModels()
    for resourceType, resourceData in pairs(Constants.RESOURCES) do
        local modelName = resourceData.modelName
        local model = ReplicatedStorage:FindFirstChild(modelName)
        
        if model and model:IsA("Model") then
            _resourceModels[resourceType] = model
            Logger.Debug(self:GetServiceName(), "Loaded resource model: %s", modelName)
        else
            -- Create a fallback model using ResourceNodeBuilder
            Logger.Warn(self:GetServiceName(), "Resource model not found: %s, creating fallback", modelName)
            local fallbackModel = ResourceNodeBuilder:CreateResourceNode(resourceType)
            if fallbackModel then
                _resourceModels[resourceType] = fallbackModel
                Logger.Debug(self:GetServiceName(), "Created fallback resource model for: %s", resourceType)
            else
                Logger.Error(self:GetServiceName(), "Failed to create fallback model for: %s", resourceType)
            end
        end
    end
end

--[[
    ResourceSystem:_SetupSpawnPoints()
    Sets up spawn points for resource nodes.
]]
function ResourceSystem:_SetupSpawnPoints()
    -- For now, use a default spawn point at origin
    -- In the future, this could be loaded from a configuration or map data
    _spawnPoints = {
        Vector3.new(0, 0, 0), -- Origin
        Vector3.new(50, 0, 50), -- Offset from origin
        Vector3.new(-50, 0, -50), -- Negative offset
    }
    
    Logger.Debug(self:GetServiceName(), "Set up %d spawn points", #_spawnPoints)
end

--[[
    ResourceSystem:_SpawnInitialResourceNodes()
    Spawns the initial set of resource nodes in the world.
]]
function ResourceSystem:_SpawnInitialResourceNodes()
    -- Spawn wood nodes (the default starting resource)
    local woodResource = Constants.RESOURCES.WOOD
    local maxNodes = Constants.RESOURCE_NODES.MAX_NODES_PER_RESOURCE_TYPE
    
    for i = 1, maxNodes do
        self:_SpawnResourceNode("WOOD")
    end
    
    Logger.Info(self:GetServiceName(), "Spawned %d initial resource nodes", maxNodes)
end

--[[
    ResourceSystem:_SpawnResourceNode(resourceType)
    Spawns a single resource node of the specified type.
    @param resourceType string: The type of resource to spawn (e.g., "WOOD")
]]
function ResourceSystem:_SpawnResourceNode(resourceType)
    local resourceData = Constants.RESOURCES[resourceType]
    if not resourceData then
        Logger.Error(self:GetServiceName(), "Invalid resource type: %s", resourceType)
        return nil
    end
    
    local modelTemplate = _resourceModels[resourceType]
    if not modelTemplate then
        Logger.Error(self:GetServiceName(), "Resource model not found for type: %s", resourceType)
        return nil
    end
    
    -- Find a valid spawn position
    local spawnPosition = self:_FindValidSpawnPosition()
    if not spawnPosition then
        Logger.Warn(self:GetServiceName(), "Could not find valid spawn position for resource node")
        return nil
    end
    
    -- Create the resource node
    local nodeModel = modelTemplate:Clone()
    nodeModel.Parent = _resourceNodesFolder
    nodeModel:PivotTo(CFrame.new(spawnPosition))
    
    -- Generate unique node ID
    _nodeCounter = _nodeCounter + 1
    local nodeId = "node_" .. _nodeCounter
    
    -- Set up the resource node data
    local nodeData = {
        model = nodeModel,
        resourceType = resourceType,
        quantity = resourceData.maxQuantity,
        lastGathered = 0,
        respawnTime = resourceData.respawnTime,
        health = Constants.RESOURCE_NODES.NODE_HEALTH,
        isDepleted = false
    }
    
    _resourceNodes[nodeId] = nodeData
    
    -- Add ProximityPrompt for interaction
    self:_AddProximityPrompt(nodeModel, nodeId, resourceData)
    
    Logger.Debug(self:GetServiceName(), "Spawned %s resource node at %s", resourceType, tostring(spawnPosition))
    return nodeId
end

--[[
    ResourceSystem:_FindValidSpawnPosition()
    Finds a valid position to spawn a resource node.
    @return Vector3: The spawn position, or nil if no valid position found
]]
function ResourceSystem:_FindValidSpawnPosition()
    local spawnRadius = Constants.RESOURCE_NODES.DEFAULT_SPAWN_RADIUS
    local minDistance = Constants.RESOURCE_NODES.MIN_DISTANCE_BETWEEN_NODES
    local maxAttempts = 50
    
    for attempt = 1, maxAttempts do
        -- Pick a random spawn point as base
        local baseSpawn = _spawnPoints[math.random(1, #_spawnPoints)]
        
        -- Add random offset within spawn radius
        local offset = Vector3.new(
            (math.random() - 0.5) * spawnRadius * 2,
            0, -- Keep on ground level
            (math.random() - 0.5) * spawnRadius * 2
        )
        
        local candidatePosition = baseSpawn + offset
        
        -- Check if position is far enough from existing nodes
        local isValid = true
        for nodeId, nodeData in pairs(_resourceNodes) do
            local distance = (candidatePosition - nodeData.model:GetPivot().Position).Magnitude
            if distance < minDistance then
                isValid = false
                break
            end
        end
        
        if isValid then
            return candidatePosition
        end
    end
    
    return nil
end

--[[
    ResourceSystem:_AddProximityPrompt(model, nodeId, resourceData)
    Adds a ProximityPrompt to a resource node for player interaction.
    @param model Model: The resource node model
    @param nodeId string: The unique node ID
    @param resourceData table: The resource configuration data
]]
function ResourceSystem:_AddProximityPrompt(model, nodeId, resourceData)
    local primaryPart = model.PrimaryPart or model:FindFirstChild("Main")
    if not primaryPart then
        Logger.Warn(self:GetServiceName(), "No primary part found for resource node %s", nodeId)
        return
    end
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Gather " .. resourceData.displayName
    prompt.ObjectText = resourceData.displayName .. " Node"
    prompt.HoldDuration = resourceData.gatherTime
    prompt.MaxActivationDistance = 8
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Default
    prompt.Parent = primaryPart
    
    -- Connect the prompt trigger event
    prompt.Triggered:Connect(function(player)
        self:_HandleResourceGathering(player, nodeId)
    end)
    
    Logger.Debug(self:GetServiceName(), "Added ProximityPrompt to resource node %s", nodeId)
end

--[[
    ResourceSystem:_HandleResourceGathering(player, nodeId)
    Handles when a player attempts to gather resources from a node.
    @param player Player: The player attempting to gather
    @param nodeId string: The ID of the resource node
]]
function ResourceSystem:_HandleResourceGathering(player, nodeId)
    local nodeData = _resourceNodes[nodeId]
    if not nodeData then
        Logger.Warn(self:GetServiceName(), "Resource node not found: %s", nodeId)
        return
    end
    
    if nodeData.isDepleted then
        Logger.Debug(self:GetServiceName(), "Player %s attempted to gather from depleted node %s", player.Name, nodeId)
        return
    end
    
    local resourceData = Constants.RESOURCES[nodeData.resourceType]
    if not resourceData then
        Logger.Error(self:GetServiceName(), "Resource data not found for type: %s", nodeData.resourceType)
        return
    end
    
    -- Check if enough time has passed since last gathering
    local currentTime = tick()
    if currentTime - nodeData.lastGathered < resourceData.respawnTime then
        Logger.Debug(self:GetServiceName(), "Resource node %s not ready for gathering yet", nodeId)
        return
    end
    
    -- Gather the resource
    local gatheredAmount = math.min(nodeData.quantity, resourceData.maxQuantity)
    nodeData.quantity = nodeData.quantity - gatheredAmount
    nodeData.lastGathered = currentTime
    
    -- Check if node is depleted
    if nodeData.quantity <= 0 then
        nodeData.isDepleted = true
        self:_DepleteResourceNode(nodeId)
    end
    
    -- Notify the player
    self:_NotifyPlayerGathered(player, nodeData.resourceType, gatheredAmount)
    
    Logger.Info(self:GetServiceName(), "Player %s gathered %d %s from node %s", 
        player.Name, gatheredAmount, resourceData.displayName, nodeId)
end

--[[
    ResourceSystem:_DepleteResourceNode(nodeId)
    Handles the visual and functional depletion of a resource node.
    @param nodeId string: The ID of the resource node
]]
function ResourceSystem:_DepleteResourceNode(nodeId)
    local nodeData = _resourceNodes[nodeId]
    if not nodeData then
        return
    end
    
    -- Make the node visually appear depleted
    local model = nodeData.model
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 0.8
            part.Color = Color3.fromRGB(100, 100, 100) -- Gray out
        end
    end
    
    -- Disable the ProximityPrompt
    local primaryPart = model.PrimaryPart or model:FindFirstChild("Main")
    if primaryPart then
        local prompt = primaryPart:FindFirstChild("ProximityPrompt")
        if prompt then
            prompt.Enabled = false
        end
    end
    
    Logger.Debug(self:GetServiceName(), "Resource node %s depleted", nodeId)
end

--[[
    ResourceSystem:_NotifyPlayerGathered(player, resourceType, amount)
    Notifies a player that they have gathered resources.
    @param player Player: The player who gathered
    @param resourceType string: The type of resource gathered
    @param amount number: The amount gathered
]]
function ResourceSystem:_NotifyPlayerGathered(player, resourceType, amount)
    local resourceData = Constants.RESOURCES[resourceType]
    if not resourceData then
        return
    end
    
    -- Send notification to the client
    NetworkManager.FireClient(player, Constants.NETWORK_EVENTS.SERVER_NOTIFY_RESOURCE_GATHERED, {
        resourceType = resourceType,
        resourceName = resourceData.displayName,
        amount = amount
    })
end

--[[
    ResourceSystem:_StartRespawnChecks()
    Starts the periodic checks for resource node respawning.
]]
function ResourceSystem:_StartRespawnChecks()
    local lastCheckTime = 0
    local checkInterval = 5 -- Check every 5 seconds
    
    local function checkRespawns()
        local currentTime = tick()
        
        -- Only check every 5 seconds, not every frame
        if currentTime - lastCheckTime < checkInterval then
            return
        end
        lastCheckTime = currentTime
        
        for nodeId, nodeData in pairs(_resourceNodes) do
            if nodeData.isDepleted then
                local resourceData = Constants.RESOURCES[nodeData.resourceType]
                if resourceData and (currentTime - nodeData.lastGathered) >= resourceData.respawnTime then
                    self:_RespawnResourceNode(nodeId)
                end
            end
        end
    end
    
    -- Check every frame but only process every 5 seconds
    RunService.Heartbeat:Connect(function()
        checkRespawns()
    end)
    
    Logger.Debug(self:GetServiceName(), "Started respawn checks (every %d seconds)", checkInterval)
end

--[[
    ResourceSystem:_RespawnResourceNode(nodeId)
    Respawns a depleted resource node.
    @param nodeId string: The ID of the resource node
]]
function ResourceSystem:_RespawnResourceNode(nodeId)
    local nodeData = _resourceNodes[nodeId]
    if not nodeData then
        return
    end
    
    local resourceData = Constants.RESOURCES[nodeData.resourceType]
    if not resourceData then
        return
    end
    
    -- Reset the node
    nodeData.quantity = resourceData.maxQuantity
    nodeData.isDepleted = false
    
    -- Restore visual appearance
    local model = nodeData.model
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 0
            -- Restore original colors based on part names
            if part.Name == "Leaves" then
                part.Color = Color3.fromRGB(34, 139, 34) -- Forest green for leaves
            elseif part.Name == "Main" or part.Name:find("Branch") then
                part.Color = Color3.fromRGB(139, 69, 19) -- Brown for trunk and branches
            else
                -- For other parts, use the resource's default color
                part.Color = resourceData.color.Color
            end
        end
    end
    
    -- Re-enable the ProximityPrompt
    local primaryPart = model.PrimaryPart or model:FindFirstChild("Main")
    if primaryPart then
        local prompt = primaryPart:FindFirstChild("ProximityPrompt")
        if prompt then
            prompt.Enabled = true
        end
    end
    
    Logger.Debug(self:GetServiceName(), "Resource node %s respawned", nodeId)
end

--[[
    ResourceSystem:GetResourceNodeById(nodeId)
    Gets a resource node by its ID.
    @param nodeId string: The ID of the resource node
    @return table: The node data, or nil if not found
]]
function ResourceSystem:GetResourceNodeById(nodeId)
    return _resourceNodes[nodeId]
end

--[[
    ResourceSystem:GetAllResourceNodes()
    Gets all active resource nodes.
    @return table: All resource nodes
]]
function ResourceSystem:GetAllResourceNodes()
    return _resourceNodes
end

--[[
    ResourceSystem:ForceSpawnResourceNode(resourceType, position)
    Forces the spawning of a resource node at a specific position.
    @param resourceType string: The type of resource to spawn
    @param position Vector3: The position to spawn at
    @return string: The node ID, or nil if failed
]]
function ResourceSystem:ForceSpawnResourceNode(resourceType, position)
    local resourceData = Constants.RESOURCES[resourceType]
    if not resourceData then
        Logger.Error(self:GetServiceName(), "Invalid resource type: %s", resourceType)
        return nil
    end
    
    local modelTemplate = _resourceModels[resourceType]
    if not modelTemplate then
        Logger.Error(self:GetServiceName(), "Resource model not found for type: %s", resourceType)
        return nil
    end
    
    -- Create the resource node
    local nodeModel = modelTemplate:Clone()
    nodeModel.Parent = _resourceNodesFolder
    nodeModel:PivotTo(CFrame.new(position))
    
    -- Generate unique node ID
    _nodeCounter = _nodeCounter + 1
    local nodeId = "node_" .. _nodeCounter
    
    -- Set up the resource node data
    local nodeData = {
        model = nodeModel,
        resourceType = resourceType,
        quantity = resourceData.maxQuantity,
        lastGathered = 0,
        respawnTime = resourceData.respawnTime,
        health = Constants.RESOURCE_NODES.NODE_HEALTH,
        isDepleted = false
    }
    
    _resourceNodes[nodeId] = nodeData
    
    -- Add ProximityPrompt for interaction
    self:_AddProximityPrompt(nodeModel, nodeId, resourceData)
    
    Logger.Info(self:GetServiceName(), "Force spawned %s resource node at %s", resourceType, tostring(position))
    return nodeId
end

--[[
    ResourceSystem:HandleGatherRequest(player, nodeId)
    Handles a client request to gather resources from a node.
    @param player Player: The player requesting to gather
    @param nodeId string: The ID of the resource node
    @return boolean: True if gathering was successful, false otherwise
]]
function ResourceSystem:HandleGatherRequest(player, nodeId)
    if not player or not nodeId then
        Logger.Warn(self:GetServiceName(), "Invalid gather request: player=%s, nodeId=%s", 
            tostring(player), tostring(nodeId))
        return false
    end
    
    -- Call the existing gathering logic
    self:_HandleResourceGathering(player, nodeId)
    
    -- Return true to indicate the request was processed
    return true
end

return ResourceSystem 