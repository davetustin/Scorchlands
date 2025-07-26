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

--[[
    SunlightSystem:ManagePlayerRegen(player, inSunlight)
    Manages health regeneration for a given player's humanoid based on their sunlight state.
    @param player Player: The Roblox Player object.
    @param inSunlight boolean: Whether the player is currently in sunlight.
]]
local function ManagePlayerRegen(player, inSunlight)
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
                
                if shouldEnableRegen then
                    Logger.Debug("SunlightSystem", "Enabled health regeneration for %s (%s).", player.Name, inSunlight and "in sunlight" or "in shadow")
                else
                    Logger.Debug("SunlightSystem", "Disabled health regeneration for %s (%s).", player.Name, inSunlight and "in sunlight" or "in shadow")
                end
            else
                Logger.Warn("SunlightSystem", "Could not find default health script for %s. Regeneration might persist.", player.Name)
            end
        end
    end
end

function SunlightSystem.new(serviceName)
    local self = BaseService.new(serviceName)
    setmetatable(self, SunlightSystem)
    Logger.Debug(self:GetServiceName(), "SunlightSystem instance created.")
    return self
end

function SunlightSystem:Init()
    BaseService.Init(self) -- Call parent Init
    Logger.Info(self:GetServiceName(), "SunlightSystem initialized.")
end

function SunlightSystem:Start()
    BaseService.Start(self) -- Call parent Start
    Logger.Info(self:GetServiceName(), "SunlightSystem started. Sunlight damage is currently %s.",
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
            ManagePlayerRegen(player, false) -- Start in shadow
        end)
        -- Also manage for current character if it exists
        if player.Character then
            ManagePlayerRegen(player, false) -- Start in shadow
        end
        
        -- Clean up when player leaves
        player.AncestryChanged:Connect(function(_, parent)
            if not parent then
                _playerSunlightState[player.UserId] = nil
                _lastDamageTime[player.UserId] = nil
            end
        end)
    end)

    -- NEW: Manage regen for all currently existing players
    for _, player in ipairs(Players:GetPlayers()) do
        -- Initialize player state as in shadow (safe default)
        _playerSunlightState[player.UserId] = false
        
        if player.Character then
            ManagePlayerRegen(player, false) -- Start in shadow
        end
        -- Also connect CharacterAdded for existing players in case they respawn
        player.CharacterAdded:Connect(function(character)
            ManagePlayerRegen(player, false) -- Start in shadow
        end)
    end
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
    -- Disconnect CharacterAdded connections for individual players (more complex to track,
    -- but for a clean shutdown, you'd iterate through players and disconnect their specific connections)
    Logger.Info(self:GetServiceName(), "SunlightSystem stopped.")
end

--[[
    SunlightSystem:CheckSunlightExposure()
    Iterates through all players and checks if they are exposed to direct sunlight.
    Applies damage if exposed and damage is enabled.
]]
function SunlightSystem:CheckSunlightExposure()
    local sunDirection = Workspace.CurrentCamera.CFrame.LookVector -- Simulating sun direction from camera for now, can be replaced by actual sun object later
    -- A more robust sun direction would come from a global light source or a dedicated sun part.
    -- For example: local sunPart = Workspace:FindFirstChild("SunPart")
    -- if sunPart then sunDirection = (sunPart.Position - Vector3.new(0,0,0)).Unit end

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and humanoid.Health > 0 and rootPart then
            local rayOrigin = rootPart.Position
            -- Cast ray slightly above the head to ensure it hits the top of the character
            local rayDirection = -sunDirection * 1000 -- Ray goes from player towards the sun
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {character} -- Exclude the player's own character
            rayParams.IgnoreWater = true

            local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)

            -- If raycastResult is nil, it means the ray went through everything to the sky,
            -- implying direct sunlight. If it hit something, the player is in shadow.
            local inSunlight = raycastResult == nil
            
            -- Check if player's sunlight state has changed
            local previousSunlightState = _playerSunlightState[player.UserId]
            if previousSunlightState ~= inSunlight then
                -- State changed, update regeneration
                ManagePlayerRegen(player, inSunlight)
                _playerSunlightState[player.UserId] = inSunlight
            end

            if inSunlight and _sunlightDamageEnabled then
                local lastDamage = _lastDamageTime[player.UserId] or 0
                local currentTime = tick() -- Use tick() for precise timing instead of os.time()

                if currentTime - lastDamage >= Constants.SUNLIGHT_DAMAGE_INTERVAL then
                    local newHealth = humanoid.Health - Constants.SUNLIGHT_DAMAGE_AMOUNT
                    -- Validate health before applying to prevent invalid states
                    if StateValidator.ValidatePlayerHealth(newHealth) then
                        humanoid.Health = newHealth
                        -- Removed excessive logging for each damage tick
                        _lastDamageTime[player.UserId] = currentTime
                    else
                        -- If validation fails, log a warning but still try to set to 0 if it went below
                        humanoid.Health = math.max(0, newHealth)
                        Logger.Warn(self:GetServiceName(), "Attempted to set invalid health for %s. Clamped to %d. Original: %d",
                            player.Name, humanoid.Health, newHealth)
                        _lastDamageTime[player.UserId] = currentTime
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
