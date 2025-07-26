--[[
    Systems/SunlightSystem.lua
    Description: Manages player exposure to sunlight and applies damage.
    This service uses raycasting to detect direct sunlight on players' HumanoidRootPart.
    It also provides a toggle for sunlight damage, useful for testing and admin commands.
    Inherits from BaseService.
]]
-- CORRECTED: Require BaseService, Logger, StateValidator from the Core folder
local BaseService = require(game.ServerScriptService.Server.Core.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local StateValidator = require(game.ServerScriptService.Server.Core.StateValidator) -- For validating health changes

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SunlightSystem = {}
SunlightSystem.__index = SunlightSystem
setmetatable(SunlightSystem, BaseService) -- Inherit from BaseService

-- Private variables for the service
-- UPDATED: Use constant for default player sunlight damage state
local _sunlightDamageEnabled = Constants.PLAYER_SUNLIGHT_DAMAGE_ENABLED_DEFAULT
local _lastDamageTime = {} -- Stores the last time each player took damage (using tick() for precision)
local _playerSunlightState = {} -- Tracks whether each player is currently in sunlight
local _sunIcons = {} -- Tracks sun icon instances for each player

-- Performance optimization variables
local _playerCache = {} -- Cache player data to avoid repeated lookups
local _lastCacheCleanup = tick()
local _cacheCleanupInterval = 10 -- Clean cache every 10 seconds
local _maxCacheAge = 30 -- Remove cache entries older than 30 seconds
local _isInitialized = false -- Track if system is fully initialized

--[[
    SunlightSystem:CreateSunIcon(player)
    Creates a sun icon above the player's head.
    @param player Player: The Roblox Player object.
    @return BillboardGui: The sun icon BillboardGui.
]]
function SunlightSystem:CreateSunIcon(player)
    local character = player.Character
    if not character then return nil end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    -- Create BillboardGui for the sun icon
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "SunIcon"
    billboardGui.Size = UDim2.new(0, 20, 0, 20) -- Smaller size
    billboardGui.StudsOffset = Vector3.new(0, 4.5, 0) -- Higher above head
    billboardGui.Adornee = humanoidRootPart
    billboardGui.AlwaysOnTop = true
    billboardGui.LightInfluence = 0 -- Don't be affected by lighting
    billboardGui.MaxDistance = 100 -- Optional: hide at extreme distance
    billboardGui.ClipsDescendants = false
    billboardGui.ResetOnSpawn = false
    billboardGui.Parent = humanoidRootPart
    
    -- Create the sun icon (using a simple circle for now)
    local sunIcon = Instance.new("Frame")
    sunIcon.Name = "Icon"
    sunIcon.Size = UDim2.new(1, 0, 1, 0)
    sunIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
    sunIcon.BorderSizePixel = 0
    sunIcon.Parent = billboardGui
    
    -- Make it circular
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = sunIcon
    
    -- Add a subtle glow effect
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 100) -- Light yellow
    stroke.Thickness = 2
    stroke.Parent = sunIcon
    
    return billboardGui
end

--[[
    SunlightSystem:ShowSunIcon(player)
    Shows the sun icon above the player's head.
    @param player Player: The Roblox Player object.
]]
function SunlightSystem:ShowSunIcon(player)
    local playerId = player.UserId
    
    -- Remove existing sun icon if it exists
    self:HideSunIcon(player)
    
    -- Create and show new sun icon
    local sunIcon = self:CreateSunIcon(player)
    if sunIcon then
        _sunIcons[playerId] = sunIcon
    end
end

--[[
    SunlightSystem:HideSunIcon(player)
    Hides the sun icon above the player's head.
    @param player Player: The Roblox Player object.
]]
function SunlightSystem:HideSunIcon(player)
    local playerId = player.UserId
    local existingIcon = _sunIcons[playerId]
    
    if existingIcon then
        existingIcon:Destroy()
        _sunIcons[playerId] = nil
    end
end

--[[
    SunlightSystem:ManagePlayerRegen(player, inSunlight)
    Manages health regeneration for a given player's humanoid based on their sunlight state.
    @param player Player: The Roblox Player object.
    @param inSunlight boolean: Whether the player is currently in sunlight.
]]
function SunlightSystem:ManagePlayerRegen(player, inSunlight)
    if not self._isInitialized then return end
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local defaultHealthScript = character:FindFirstChild("Health")
            if defaultHealthScript and defaultHealthScript:IsA("Script") then
                -- Determine regeneration state based on sunlight state and constants
                local shouldEnableRegen
                if inSunlight then
                    shouldEnableRegen = Constants.PLAYER_HEALTH_REGEN.ENABLED_IN_SUNLIGHT
                else
                    shouldEnableRegen = Constants.PLAYER_HEALTH_REGEN.ENABLED_IN_SHADOW
                end
                
                defaultHealthScript.Disabled = not shouldEnableRegen
                -- Removed debug logs for enabling/disabling health regeneration
            else
                Logger.Warn("SunlightSystem", "Could not find default health script for %s. Regeneration might persist.", player.Name)
            end
        end
    end
end

function SunlightSystem.new(serviceName)
    local self = BaseService.new(serviceName)
    setmetatable(self, SunlightSystem)
    self._isInitialized = false
    Logger.Debug(self:GetServiceName(), "SunlightSystem instance created.")
    return self
end

function SunlightSystem:Init()
    BaseService.Init(self) -- Call parent Init
    Logger.Info(self:GetServiceName(), "SunlightSystem initialized.")
end

function SunlightSystem:Start()
    BaseService.Start(self) -- Call parent Start
    
    -- Register this service in GlobalRegistry for cross-service communication
    local GlobalRegistry = require(game.ServerScriptService.Server.Core.GlobalRegistry)
    GlobalRegistry.Set("SunlightSystem", self)
    
    Logger.Info(self:GetServiceName(), "SunlightSystem started. Player sunlight damage is currently %s.",
        _sunlightDamageEnabled and "ENABLED" or "DISABLED")

    -- Connect to Heartbeat for continuous sunlight checks
    self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
        self:CheckSunlightExposure()
    end)

    -- NEW: Manage regen for players who join after the system starts
    self._playerAddedConnection = Players.PlayerAdded:Connect(function(player)
        -- Initialize player state as in shadow (safe default)
        _playerSunlightState[player.UserId] = false
        
        player.CharacterAdded:Connect(function(character)
            self:ManagePlayerRegen(player, false) -- Start in shadow
        end)
        -- Also manage for current character if it exists
        if player.Character then
            self:ManagePlayerRegen(player, false) -- Start in shadow
        end
        
        -- Clean up when player leaves
        player.AncestryChanged:Connect(function(_, parent)
            if not parent then
                _playerSunlightState[player.UserId] = nil
                _lastDamageTime[player.UserId] = nil
                self:HideSunIcon(player) -- Clean up sun icon
            end
        end)
    end)

    -- NEW: Manage regen for all currently existing players
    for _, player in ipairs(Players:GetPlayers()) do
        -- Initialize player state as in shadow (safe default)
        _playerSunlightState[player.UserId] = false
        
        if player.Character then
            self:ManagePlayerRegen(player, false) -- Start in shadow
        end
        -- Also connect CharacterAdded for existing players in case they respawn
        player.CharacterAdded:Connect(function(character)
            self:ManagePlayerRegen(player, false) -- Start in shadow
        end)
    end
    
    -- Mark system as initialized after startup is complete
    self._isInitialized = true
    Logger.FlushBuffer()
end

function SunlightSystem:Stop()
    BaseService.Stop(self) -- Call parent Stop
    if self._heartbeatConnection then
        self._heartbeatConnection:Disconnect()
        self._heartbeatConnection = nil
    end
    if self._playerAddedConnection then
        self._playerAddedConnection:Disconnect()
        self._playerAddedConnection = nil
    end
    
    -- Clean up all sun icons
    for playerId, sunIcon in pairs(_sunIcons) do
        if sunIcon then
            sunIcon:Destroy()
        end
    end
    _sunIcons = {}
    
    -- Disconnect CharacterAdded connections for individual players (more complex to track,
    -- but for a clean shutdown, you'd iterate through players and disconnect their specific connections)
    Logger.Info(self:GetServiceName(), "SunlightSystem stopped.")
end

--[[
    SunlightSystem:CheckSunlightExposure()
    Iterates through all players and checks if they are exposed to direct sunlight.
    Applies damage if exposed and damage is enabled.
]]
--[[
    SunlightSystem:CleanupPlayerCache()
    Cleans up old player cache entries to prevent memory leaks.
]]
local function CleanupPlayerCache()
    local currentTime = tick()
    for playerId, cacheData in pairs(_playerCache) do
        if currentTime - cacheData.lastAccess > _maxCacheAge then
            _playerCache[playerId] = nil
        end
    end
end

function SunlightSystem:CheckSunlightExposure()
    local currentTime = tick()
    
    -- Periodic cache cleanup
    if currentTime - _lastCacheCleanup > _cacheCleanupInterval then
        CleanupPlayerCache()
        _lastCacheCleanup = currentTime
    end

    -- Use a fixed sun direction (pointing downward at an angle)
    -- This simulates sunlight coming from above at roughly 45 degrees
    local sunDirection = Vector3.new(0.7, -0.7, 0.7).Unit -- Normalized direction
    local rayDirection = -sunDirection * 1000

    for _, player in ipairs(Players:GetPlayers()) do
        local playerId = player.UserId
        
        -- Use cached player data if available
        local cachedData = _playerCache[playerId]
        local character, humanoid, rootPart
        
        if cachedData and cachedData.lastAccess > currentTime - 0.1 then -- Cache valid for 0.1 seconds
            character = cachedData.character
            humanoid = cachedData.humanoid
            rootPart = cachedData.rootPart
        else
            -- Update cache
            character = player.Character
            humanoid = character and character:FindFirstChildOfClass("Humanoid")
            rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            _playerCache[playerId] = {
                character = character,
                humanoid = humanoid,
                rootPart = rootPart,
                lastAccess = currentTime
            }
        end

        if humanoid and humanoid.Health > 0 and rootPart then
            local rayOrigin = rootPart.Position
            
            -- Optimize raycast parameters (reuse where possible)
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {character}
            rayParams.IgnoreWater = true

            local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
            local inSunlight = raycastResult == nil
            
            -- Check if player's sunlight state has changed
            local previousSunlightState = _playerSunlightState[playerId]
            if previousSunlightState ~= inSunlight then
                self:ManagePlayerRegen(player, inSunlight)
                _playerSunlightState[playerId] = inSunlight
                
                -- Show/hide sun icon based on sunlight state
                if inSunlight then
                    self:ShowSunIcon(player)
                else
                    self:HideSunIcon(player)
                end
            end

            if inSunlight and _sunlightDamageEnabled then
                local lastDamage = _lastDamageTime[playerId] or 0

                if currentTime - lastDamage >= Constants.SUNLIGHT_DAMAGE_INTERVAL then
                    local newHealth = humanoid.Health - Constants.SUNLIGHT_DAMAGE_AMOUNT
                    
                    if StateValidator.ValidatePlayerHealth(newHealth) then
                        humanoid.Health = newHealth
                        _lastDamageTime[playerId] = currentTime
                    else
                        humanoid.Health = math.max(0, newHealth)
                        Logger.Warn(self:GetServiceName(), "Attempted to set invalid health for %s. Clamped to %d. Original: %d",
                            player.Name, humanoid.Health, newHealth)
                        _lastDamageTime[playerId] = currentTime
                    end
                end
            end
        end
    end
end

--[[
    SunlightSystem:SetSunlightDamageEnabled(enabled)
    Sets whether sunlight damage is enabled or disabled.
    @param enabled boolean: True to enable, false to disable.
]]
function SunlightSystem:SetSunlightDamageEnabled(enabled)
    if type(enabled) == "boolean" then
        _sunlightDamageEnabled = enabled
        Logger.Info(self:GetServiceName(), "Sunlight damage has been %s.", enabled and "ENABLED" or "DISABLED")
    else
        Logger.Warn(self:GetServiceName(), "Attempted to set sunlight damage with invalid value: %s", tostring(enabled))
    end
end

--[[
    SunlightSystem:IsSunlightDamageEnabled()
    Returns the current status of sunlight damage.
    @return boolean: True if enabled, false if disabled.
]]
function SunlightSystem:IsSunlightDamageEnabled()
    return _sunlightDamageEnabled
end
-- CORRECTED: Changed 'END' to 'end' and ensured correct return
return SunlightSystem
