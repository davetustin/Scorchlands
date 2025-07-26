--[[
    Client/ResourceClient.lua
    Description: Client-side resource system for Scorchlands.
    Handles resource gathering notifications and UI feedback.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ResourceClient = {}

-- Private variables
local _resourceNotifications = {} -- Track active notifications
local _notificationCounter = 0 -- Counter for unique notification IDs
local _resourceGatheredEvent = nil
local _resourceNodeUpdateEvent = nil

--[[
    ResourceClient:Init()
    Initializes the resource client and sets up network event handlers.
]]
function ResourceClient:Init()
    -- Get RemoteEvents with retry mechanism
    local maxRetries = 10
    local retryCount = 0
    
    while (not _resourceGatheredEvent or not _resourceNodeUpdateEvent) and retryCount < maxRetries do
        if not _resourceGatheredEvent then
            _resourceGatheredEvent = NetworkManager.GetRemoteEvent(Constants.NETWORK_EVENTS.SERVER_NOTIFY_RESOURCE_GATHERED)
        end
        if not _resourceNodeUpdateEvent then
            _resourceNodeUpdateEvent = NetworkManager.GetRemoteEvent(Constants.NETWORK_EVENTS.SERVER_NOTIFY_RESOURCE_NODE_UPDATE)
        end
        
        if not _resourceGatheredEvent or not _resourceNodeUpdateEvent then
            retryCount = retryCount + 1
            Logger.Debug("ResourceClient", "Attempt %d to get RemoteEvents...", retryCount)
            task.wait(0.5) -- Wait 0.5 seconds before retrying
        end
    end
    
    if not _resourceGatheredEvent then
        Logger.Error("ResourceClient", "Failed to get SERVER_NOTIFY_RESOURCE_GATHERED RemoteEvent after %d attempts.", maxRetries)
    else
        Logger.Debug("ResourceClient", "Successfully obtained SERVER_NOTIFY_RESOURCE_GATHERED RemoteEvent.")
        -- Connect to the OnClientEvent
        _resourceGatheredEvent.OnClientEvent:Connect(function(data)
            self:_HandleResourceGathered(data)
        end)
    end
    
    if not _resourceNodeUpdateEvent then
        Logger.Error("ResourceClient", "Failed to get SERVER_NOTIFY_RESOURCE_NODE_UPDATE RemoteEvent after %d attempts.", maxRetries)
    else
        Logger.Debug("ResourceClient", "Successfully obtained SERVER_NOTIFY_RESOURCE_NODE_UPDATE RemoteEvent.")
        -- Connect to the OnClientEvent
        _resourceNodeUpdateEvent.OnClientEvent:Connect(function(data)
            self:_HandleResourceNodeUpdate(data)
        end)
    end
    
    Logger.Info("ResourceClient", "Resource client initialized.")
end

--[[
    ResourceClient:_HandleResourceGathered(data)
    Handles when the server notifies that resources have been gathered.
    @param data table: The resource gathering data
]]
function ResourceClient:_HandleResourceGathered(data)
    local resourceType = data.resourceType
    local resourceName = data.resourceName
    local amount = data.amount
    
    if not resourceType or not resourceName or not amount then
        Logger.Warn("ResourceClient", "Invalid resource gathering data received")
        return
    end
    
    -- Show notification to the player
    self:_ShowResourceNotification(resourceName, amount)
    
    -- Play sound effect (if available)
    self:_PlayResourceSound(resourceType)
    
    Logger.Debug("ResourceClient", "Handled resource gathering: %d %s", amount, resourceName)
end

--[[
    ResourceClient:_HandleResourceNodeUpdate(data)
    Handles when the server notifies about resource node updates.
    @param data table: The resource node update data
]]
function ResourceClient:_HandleResourceNodeUpdate(data)
    local nodeId = data.nodeId
    local isDepleted = data.isDepleted
    local resourceType = data.resourceType
    
    if not nodeId then
        Logger.Warn("ResourceClient", "Invalid resource node update data received")
        return
    end
    
    -- Handle node depletion/restoration visual feedback
    if isDepleted then
        Logger.Debug("ResourceClient", "Resource node %s depleted", nodeId)
    else
        Logger.Debug("ResourceClient", "Resource node %s restored", nodeId)
    end
end

--[[
    ResourceClient:_ShowResourceNotification(resourceName, amount)
    Shows a notification to the player about gathered resources.
    @param resourceName string: The name of the resource
    @param amount number: The amount gathered
]]
function ResourceClient:_ShowResourceNotification(resourceName, amount)
    -- Create a simple notification using StarterGui
    local notificationText = string.format("+%d %s", amount, resourceName)
    
    -- Use StarterGui's notification system for a simple popup
    StarterGui:SetCore("SendNotification", {
        Title = "Resource Gathered",
        Text = notificationText,
        Duration = 3,
        Icon = "rbxasset://textures/ui/notifications/notification_generic.png"
    })
    
    -- Also log to console for debugging
    Logger.Info("ResourceClient", "Gathered: %s", notificationText)
end

--[[
    ResourceClient:_PlayResourceSound(resourceType)
    Plays a sound effect for resource gathering.
    @param resourceType string: The type of resource gathered
]]
function ResourceClient:_PlayResourceSound(resourceType)
    -- For now, we'll just log that a sound would play
    -- In the future, this could load and play actual sound effects
    Logger.Debug("ResourceClient", "Would play sound for resource type: %s", resourceType)
    
    -- Example of how this could work with actual sounds:
    -- local soundId = Constants.RESOURCE_SOUNDS[resourceType]
    -- if soundId then
    --     local sound = Instance.new("Sound")
    --     sound.SoundId = soundId
    --     sound.Volume = 0.5
    --     sound.Parent = LocalPlayer
    --     sound:Play()
    --     sound.Ended:Connect(function()
    --         sound:Destroy()
    --     end)
    -- end
end

--[[
    ResourceClient:ShowResourceInfo(resourceType)
    Shows information about a specific resource type.
    @param resourceType string: The type of resource to show info for
]]
function ResourceClient:ShowResourceInfo(resourceType)
    local resourceData = Constants.RESOURCES[resourceType]
    if not resourceData then
        Logger.Warn("ResourceClient", "Unknown resource type: %s", resourceType)
        return
    end
    
    local infoText = string.format("%s: %s", resourceData.displayName, resourceData.description)
    
    StarterGui:SetCore("SendNotification", {
        Title = resourceData.displayName,
        Text = infoText,
        Duration = 5,
        Icon = "rbxasset://textures/ui/notifications/notification_info.png"
    })
end

--[[
    ResourceClient:GetResourceData(resourceType)
    Gets the configuration data for a specific resource type.
    @param resourceType string: The type of resource
    @return table: The resource configuration data, or nil if not found
]]
function ResourceClient:GetResourceData(resourceType)
    return Constants.RESOURCES[resourceType]
end

--[[
    ResourceClient:GetAllResourceTypes()
    Gets all available resource types.
    @return table: All resource types
]]
function ResourceClient:GetAllResourceTypes()
    local resourceTypes = {}
    for resourceType, _ in pairs(Constants.RESOURCES) do
        table.insert(resourceTypes, resourceType)
    end
    return resourceTypes
end

return ResourceClient 