--!native
--!optimize

--[[
    Systems/SunlightSystem.lua
    Description: Manages player exposure to sunlight and applies damage.
    This service uses raycasting to detect direct sunlight on players' HumanoidRootPart.
    It also provides a toggle for sunlight damage, useful for testing and admin commands.
    Inherits from BaseService.
]]
-- CORRECTED: Require BaseService, Logger, StateValidator from the Core folder
local BaseService = require(game.ServerScriptService.Core.BaseService)
local Logger = require(game.ServerScriptService.Core.Logger)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local StateValidator = require(game.ServerScriptService.Core.StateValidator) -- For validating health changes
-- CORRECTED: NetworkManager is now in ReplicatedStorage.Shared
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)


local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SunlightSystem = {}
SunlightSystem.__index = SunlightSystem
setmetatable(SunlightSystem, BaseService) -- Inherit from BaseService

-- Private variables for the service
-- UPDATED: Use constant for default player sunlight damage state
local _sunlightDamageEnabled = Constants.PLAYER_SUNLIGHT_DAMAGE_ENABLED_DEFAULT
local _lastDamageTime = {} -- Stores the last time each player took damage

--[[
    SunlightSystem:ManagePlayerRegen(player)
    Manages health regeneration for a given player's humanoid based on Constants.PLAYER_HEALTH_REGEN_ENABLED_DEFAULT.
    @param player Player: The Roblox Player object.
]]
local function ManagePlayerRegen(player)
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local defaultHealthScript = character:FindFirstChild("Health")
            if defaultHealthScript and defaultHealthScript:IsA("Script") then
                -- NEW: Set Disabled state based on Constants.PLAYER_HEALTH_REGEN_ENABLED_DEFAULT
                defaultHealthScript.Disabled = not Constants.PLAYER_HEALTH_REGEN_ENABLED_DEFAULT
                if Constants.PLAYER_HEALTH_REGEN_ENABLED_DEFAULT then
                    Logger.Debug("SunlightSystem", "Enabled default health script for %s.", player.Name)
                else
                    Logger.Debug("SunlightSystem", "Disabled default health script for %s.", player.Name)
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
        player.CharacterAdded:Connect(function(character)
            ManagePlayerRegen(player)
        end)
        -- Also manage for current character if it exists
        if player.Character then
            ManagePlayerRegen(player)
        end
    end)

    -- NEW: Manage regen for all currently existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            ManagePlayerRegen(player)
        end
        -- Also connect CharacterAdded for existing players in case they respawn
        player.CharacterAdded:Connect(function(character)
            ManagePlayerRegen(player)
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

            if inSunlight and _sunlightDamageEnabled then
                local lastDamage = _lastDamageTime[player.UserId] or 0
                local currentTime = os.time()

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
