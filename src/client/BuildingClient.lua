--[[
    Client/BuildingClient.lua
    Description: Client-side building system for Scorchlands.
    Handles building mode, preview models, and user input for structure placement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local LocalPlayer = Players.LocalPlayer
local PlayerMouse = LocalPlayer:GetMouse()

local BuildingClient = {}

-- Private variables for building state
local _isBuildingMode = false
local _selectedStructureType = nil
local _currentPreviewModel = nil
local _currentPreviewPrimaryPart = nil
local _gridSize = Constants.BUILDING_GRID.GRID_SIZE -- Grid size for all structures
local _currentRotation = 0 -- 0, 90, 180, 270 degrees
local _inputCounter = 0 -- Debug counter for input events
local _lastHotkeyTime = 0 -- Track when hotkeys were pressed to prevent immediate placement

-- Private variables for repair mode
local _isRepairMode = false
local _repairTarget = nil -- The structure being targeted for repair

-- NEW: Callback system for UI feedback
local _onBuildingModeChanged = nil
local _onRepairModeChanged = nil

-- REMOVED: Get RemoteFunction here. It will be retrieved in Init()
local ClientRequestBuild = nil
local ClientRequestRepair = nil

--[[
    BuildingClient:SetCallbacks(onBuildingModeChanged, onRepairModeChanged)
    Sets callback functions for UI feedback.
    @param onBuildingModeChanged function: Called when building mode changes
    @param onRepairModeChanged function: Called when repair mode changes
]]
function BuildingClient:SetCallbacks(onBuildingModeChanged, onRepairModeChanged)
    _onBuildingModeChanged = onBuildingModeChanged
    _onRepairModeChanged = onRepairModeChanged
end

--[[
    BuildingClient:OnHotkeyPressed()
    Called when a hotkey is pressed to prevent immediate placement.
]]
function BuildingClient:OnHotkeyPressed()
    _lastHotkeyTime = tick()
    Logger.Debug("BuildingClient", "Hotkey pressed, setting last hotkey time to: %f", _lastHotkeyTime)
end

--[[
    BuildingClient:EnableBuildingMode(structureType)
    Enables building mode for a specific structure type.
    @param structureType string: The type of structure to build (e.g., "Wall", "Floor").
]]
function BuildingClient:EnableBuildingMode(structureType)
    Logger.Debug("BuildingClient", "EnableBuildingMode called for: %s (current mode: %s)", 
        structureType, _isBuildingMode and _selectedStructureType or "none")
    
    if not Constants.STRUCTURE_TYPES[structureType:upper()] then
        Logger.Warn("BuildingClient", "Invalid structure type provided: %s", structureType)
        return
    end

    -- Disable repair mode if active
    if _isRepairMode then
        Logger.Debug("BuildingClient", "Disabling repair mode before enabling building mode")
        self:DisableRepairMode()
    end

    _isBuildingMode = true
    _selectedStructureType = structureType
    _currentRotation = 0 -- Reset rotation when enabling mode
    
    Logger.Debug("BuildingClient", "Building mode state set - isBuildingMode: %s, selectedStructureType: %s", 
        tostring(_isBuildingMode), _selectedStructureType)

    -- Create and display the preview model
    local modelTemplate = ReplicatedStorage:FindFirstChild("BuildingModels"):FindFirstChild(structureType)
    if modelTemplate and modelTemplate:IsA("Model") then
        -- CRITICAL: Destroy any existing preview model before creating a new one
        if _currentPreviewModel then
            Logger.Debug("BuildingClient", "Destroying existing preview model before creating new one: %s", _currentPreviewModel.Name)
            _currentPreviewModel:Destroy()
            _currentPreviewModel = nil
            _currentPreviewPrimaryPart = nil
        end
        
        _currentPreviewModel = modelTemplate:Clone()
        _currentPreviewModel.Parent = Workspace.CurrentCamera -- Parent to camera for local visibility
        _currentPreviewModel.Archivable = false -- Don't save this temporary model
        _currentPreviewModel.Name = "PreviewModel_" .. structureType -- Give it a clear preview name
        
        Logger.Debug("BuildingClient", "Created preview model for %s - Model: %s, Parent: %s", 
            structureType, tostring(_currentPreviewModel), tostring(_currentPreviewModel.Parent))

        -- Set properties for preview
        for _, part in ipairs(_currentPreviewModel:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0.8 -- More transparent to clearly distinguish from placed structures
                part.CanCollide = false
                part.CanQuery = false -- Ignore raycasts
                part.Anchored = true
                part.Name = "PreviewPart_" .. part.Name -- Give preview parts clear names
                
                -- CRITICAL: Mark this as a preview part to prevent it from being treated as a real structure
                local previewTag = Instance.new("BoolValue")
                previewTag.Name = "IsPreviewPart"
                previewTag.Value = true
                previewTag.Parent = part
                
                -- Add blue glow effect for preview
                local highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.fromRGB(0, 150, 255) -- Blue glow
                highlight.OutlineColor = Color3.fromRGB(0, 100, 200)
                highlight.FillTransparency = 0.1 -- More visible glow
                highlight.OutlineTransparency = 0.2 -- More visible outline
                highlight.Parent = part
                
                Logger.Debug("BuildingClient", "Preview part created: %s, Transparency: %s, CanCollide: %s", 
                    part.Name, tostring(part.Transparency), tostring(part.CanCollide))
                
                -- Add pulsing effect to make it clear this is a preview
                local pulseConnection
                pulseConnection = RunService.Heartbeat:Connect(function()
                    if part.Parent and part:FindFirstChild("IsPreviewPart") then
                        -- Pulse the transparency slightly
                        local pulse = math.sin(tick() * 3) * 0.1 -- Pulse between 0.7 and 0.9 transparency
                        part.Transparency = 0.8 + pulse
                    else
                        -- Clean up connection if part is destroyed or no longer a preview
                        if pulseConnection then
                            pulseConnection:Disconnect()
                            pulseConnection = nil
                        end
                    end
                end)
            end
        end
        _currentPreviewPrimaryPart = _currentPreviewModel.PrimaryPart
    else
        Logger.Warn("BuildingClient", "Could not find model template for %s in ReplicatedStorage.BuildingModels.", structureType)
        self:DisableBuildingMode()
        return
    end

    -- Notify UI of mode change
    if _onBuildingModeChanged then
        _onBuildingModeChanged(true, structureType)
    end

    -- Logger.Debug("BuildingClient", "Building mode ENABLED for %s", structureType)
end

--[[
    BuildingClient:DisableBuildingMode()
    Disables building mode and cleans up the preview model.
]]
function BuildingClient:DisableBuildingMode()
    Logger.Debug("BuildingClient", "DisableBuildingMode called - cleaning up preview model")
    
    _isBuildingMode = false
    _selectedStructureType = nil
    _currentRotation = 0

    if _currentPreviewModel then
        Logger.Debug("BuildingClient", "Destroying preview model: %s", _currentPreviewModel.Name)
        _currentPreviewModel:Destroy()
        _currentPreviewModel = nil
        _currentPreviewPrimaryPart = nil
    else
        Logger.Debug("BuildingClient", "No preview model to destroy")
    end

    -- Notify UI of mode change
    if _onBuildingModeChanged then
        _onBuildingModeChanged(false, nil)
    end

    -- Logger.Debug("BuildingClient", "Building mode DISABLED.")
end

--[[
    BuildingClient:EnableRepairMode()
    Enables repair mode, allowing players to repair their structures.
]]
function BuildingClient:EnableRepairMode()
    if _isBuildingMode then
        self:DisableBuildingMode() -- Disable building mode if active
    end
    
    _isRepairMode = true
    _repairTarget = nil
    
    -- Notify UI of mode change
    if _onRepairModeChanged then
        _onRepairModeChanged(true)
    end
    
    -- Logger.Debug("BuildingClient", "Repair mode ENABLED.")
end

--[[
    BuildingClient:DisableRepairMode()
    Disables repair mode.
]]
function BuildingClient:DisableRepairMode()
    _isRepairMode = false
    _repairTarget = nil
    
    -- Notify UI of mode change
    if _onRepairModeChanged then
        _onRepairModeChanged(false)
    end
    
    -- Logger.Debug("BuildingClient", "Repair mode DISABLED.")
end

--[[
    BuildingClient:ToggleRepairMode()
    Toggles repair mode on/off.
]]
function BuildingClient:ToggleRepairMode()
    if _isRepairMode then
        self:DisableRepairMode()
    else
        self:EnableRepairMode()
    end
end

--[[
    BuildingClient:GetStructureUnderMouse()
    Gets the structure under the mouse cursor for repair targeting.
    @return Model|nil: The structure model or nil if none found.
]]
function BuildingClient:GetStructureUnderMouse()
    local mousePos = PlayerMouse.Hit.Position
    
    local structuresFolder = Workspace:FindFirstChild("Structures")
    if not structuresFolder then
        return nil
    end
    
    -- Find the closest structure to the mouse
    local closestStructure = nil
    local closestDistance = math.huge
    
    for _, structure in ipairs(structuresFolder:GetChildren()) do
        if structure:IsA("Model") then
            local primaryPart = structure.PrimaryPart
            if primaryPart then
                local distance = (primaryPart.Position - mousePos).Magnitude
                if distance < closestDistance and distance < 10 then -- Within 10 studs
                    closestStructure = structure
                    closestDistance = distance
                end
            end
        end
    end
    
    return closestStructure
end

--[[
    BuildingClient:RepairStructure(structureId)
    Sends a repair request to the server for a specific structure.
    @param structureId string: The ID of the structure to repair.
    @return boolean: True if repair request was sent successfully.
]]
function BuildingClient:RepairStructure(structureId)
    if not ClientRequestRepair then
        Logger.Warn("BuildingClient", "ClientRequestRepair RemoteFunction not available.")
        return false
    end
    
    local success, message = ClientRequestRepair:InvokeServer(structureId)
    if success then
        Logger.Debug("BuildingClient", "Successfully sent repair request for structure %s", structureId)
        return true
    else
        Logger.Warn("BuildingClient", "Failed to repair structure %s: %s", structureId, message)
        return false
    end
end

--[[
    BuildingClient:ToggleBuildingMode(structureType)
    Toggles building mode on/off for a specific structure type.
    If already in building mode with the same type, it disables it.
    Otherwise, it enables it for the new type.
    @param structureType string: The type of structure to build.
]]
function BuildingClient:ToggleBuildingMode(structureType)
    if _isBuildingMode and _selectedStructureType == structureType then
        self:DisableBuildingMode()
    else
        self:EnableBuildingMode(structureType)
    end
end

--[[
    BuildingClient:UpdatePreview()
    Updates the position and rotation of the building preview model.
    Called on Heartbeat.
]]
local function UpdatePreview()
    if not _isBuildingMode or not _currentPreviewModel or not _currentPreviewPrimaryPart then 
        return 
    end
    
    -- DEBUG: Log when UpdatePreview is called to see if it's running unexpectedly
    -- Only log occasionally to avoid spam
    if tick() % 1 < 0.1 then -- Log roughly once per second
        Logger.Debug("BuildingClient", "UpdatePreview called - isBuildingMode: %s, hasPreviewModel: %s, hasPrimaryPart: %s", 
            tostring(_isBuildingMode), tostring(_currentPreviewModel ~= nil), tostring(_currentPreviewPrimaryPart ~= nil))
    end

    local mouseHit = PlayerMouse.Hit
    local camera = Workspace.CurrentCamera
    local mousePos = PlayerMouse.Hit.Position
    local cameraPos = camera.CFrame.Position
    local direction = (mousePos - cameraPos).Unit
    
    local raycastResult = Workspace:Raycast(cameraPos, direction * 1000)

    local targetPosition = nil
    local _targetNormal = nil

    if raycastResult then
        targetPosition = raycastResult.Position
        _targetNormal = raycastResult.Normal
    else
        -- Fallback if raycast hits nothing (e.g., pointing at sky)
        targetPosition = mouseHit.Position
        _targetNormal = Vector3.new(0, 1, 0) -- Assume flat ground
    end

    -- Snap to grid
    local snappedX = math.floor(targetPosition.X / _gridSize + 0.5) * _gridSize
    local snappedY = math.floor(targetPosition.Y / _gridSize + 0.5) * _gridSize
    local snappedZ = math.floor(targetPosition.Z / _gridSize + 0.5) * _gridSize

    -- All structures use the same grid size for consistent positioning
    -- Grid snapping is already applied above using _gridSize

    local snappedCFrame = CFrame.new(snappedX, snappedY, snappedZ)

    -- Adjust Y position based on part size and surface normal (for floor/roof)
    -- This is a simplified adjustment. For complex shapes, you'd need more sophisticated logic.
    local halfHeight = _currentPreviewPrimaryPart.Size.Y / 2
    if _selectedStructureType == Constants.STRUCTURE_TYPES.FLOOR then
        -- For floors, place at ground level (Y=0) plus half height
        snappedCFrame = CFrame.new(snappedX, halfHeight, snappedZ)
    elseif _selectedStructureType == Constants.STRUCTURE_TYPES.ROOF then
        -- For roofs, try to snap to the top of nearby walls
        local wallHeight = 8 -- Assuming walls are 8 studs tall
        local roofY = wallHeight + halfHeight -- Default to wall top + half roof height
        
        -- Look for walls near the roof position
        local searchRadius = 4 -- Search within 4 studs
        local nearbyWalls = Workspace:GetPartBoundsInBox(
            CFrame.new(snappedX, wallHeight/2, snappedZ),
            Vector3.new(searchRadius * 2, wallHeight, searchRadius * 2)
        )
        
        -- Find the highest wall in the area
        local highestWallY = 0
        for _, part in ipairs(nearbyWalls) do
            if part.Name:find("Wall") or part.Parent and part.Parent.Name:find("Wall") then
                local wallTop = part.Position.Y + part.Size.Y/2
                if wallTop > highestWallY then
                    highestWallY = wallTop
                end
            end
        end
        
        -- Use the highest wall found, or default to wall height
        if highestWallY > 0 then
            roofY = highestWallY + halfHeight
        end
        
        snappedCFrame = CFrame.new(snappedX, roofY, snappedZ)
    elseif _selectedStructureType == Constants.STRUCTURE_TYPES.WALL then
        -- For walls, snap to the ground plane, adjusting for height
        snappedCFrame = CFrame.new(snappedX, halfHeight, snappedZ)
    end

    -- Apply current rotation
    snappedCFrame = snappedCFrame * CFrame.Angles(0, math.rad(_currentRotation), 0)

    -- Position the preview model at the calculated position
    -- The preview model is parented to the camera, so it will appear in the world
    -- but won't interfere with actual structures since it's marked as a preview
    _currentPreviewModel:SetPrimaryPartCFrame(snappedCFrame)
end

--[[
    BuildingClient:HandleInput(input, gameProcessedEvent)
    Handles user input for building mode (placement and rotation).
    @param input InputObject: The input event.
    @param gameProcessedEvent boolean: True if the game engine has already processed this input.
]]
function BuildingClient:HandleInput(input, gameProcessedEvent)
    _inputCounter = _inputCounter + 1
    Logger.Debug("BuildingClient", "HandleInput called with: %s (gameProcessed: %s) - Counter: %d", 
        input.KeyCode and input.KeyCode.Name or input.UserInputType.Name, 
        tostring(gameProcessedEvent),
        _inputCounter)
    
    if gameProcessedEvent then 
        Logger.Debug("BuildingClient", "Input was game processed, ignoring")
        return 
    end
    
    -- CRITICAL: Safety check for Unknown inputs (but only if they don't have a valid UserInputType)
    if input.KeyCode and input.KeyCode == Enum.KeyCode.Unknown and not input.UserInputType then
        Logger.Debug("BuildingClient", "CRITICAL: Received Unknown input with no UserInputType, ignoring")
        return
    end
    
    -- CRITICAL: Safety check - BuildingClient should NEVER receive hotkeys or UI keys
    -- This is a double-check in case the UI delegation fails
    if input.KeyCode == Enum.KeyCode.One or 
       input.KeyCode == Enum.KeyCode.Two or 
       input.KeyCode == Enum.KeyCode.Three or 
       input.KeyCode == Enum.KeyCode.Four or
       input.KeyCode == Enum.KeyCode.Escape or
       input.KeyCode == Enum.KeyCode.Q then
        Logger.Error("BuildingClient", "CRITICAL: Received hotkey/UI input that should have been filtered: %s", input.KeyCode.Name)
        return -- Don't process hotkeys here
    end
    
    -- ADDITIONAL DEBUG: Log all inputs that reach this point
    Logger.Debug("BuildingClient", "Processing input: %s (KeyCode: %s, UserInputType: %s)", 
        input.KeyCode and input.KeyCode.Name or input.UserInputType.Name,
        input.KeyCode and input.KeyCode.Name or "none",
        input.UserInputType and input.UserInputType.Name or "none")
    
    -- CRITICAL: Additional safety check - log the call stack to see where this is being called from
    Logger.Debug("BuildingClient", "CRITICAL: BuildingClient HandleInput called from: %s", debug.traceback())

    if _isBuildingMode and _currentPreviewModel and _currentPreviewPrimaryPart then
        Logger.Debug("BuildingClient", "In building mode with valid preview, checking input type: %s", 
            input.UserInputType and input.UserInputType.Name or (input.KeyCode and input.KeyCode.Name or "unknown"))
        if input.UserInputType == Enum.UserInputType.MouseButton1 then -- Left click to place
            Logger.Debug("BuildingClient", "CRITICAL: Left click detected - attempting to place structure")
            Logger.Debug("BuildingClient", "Building mode: %s, Preview model: %s, Primary part: %s", 
                tostring(_isBuildingMode), tostring(_currentPreviewModel ~= nil), tostring(_currentPreviewPrimaryPart ~= nil))
            Logger.Debug("BuildingClient", "Current structure type: %s", _selectedStructureType)
            Logger.Debug("BuildingClient", "Mouse position: %s", tostring(PlayerMouse.Hit.Position))
            Logger.Debug("BuildingClient", "Preview model exists: %s", tostring(_currentPreviewModel ~= nil))
            Logger.Debug("BuildingClient", "Preview primary part exists: %s", tostring(_currentPreviewPrimaryPart ~= nil))
            
            -- CRITICAL: Check if a hotkey was recently pressed to prevent accidental placement
            local currentTime = tick()
            Logger.Debug("BuildingClient", "CRITICAL: Current time: %f, last hotkey time: %f, difference: %f", 
                currentTime, _lastHotkeyTime, currentTime - _lastHotkeyTime)
            if currentTime - _lastHotkeyTime < 0.1 then -- 100ms buffer
                Logger.Debug("BuildingClient", "CRITICAL: Mouse click too soon after hotkey press, ignoring to prevent accidental placement")
                return
            end
            
            if not _currentPreviewPrimaryPart then
                Logger.Warn("BuildingClient", "No preview primary part available, cannot place structure")
                return
            end
            
            -- CRITICAL: Check if this is actually a preview part, not a real structure
            if _currentPreviewPrimaryPart:FindFirstChild("IsPreviewPart") then
                Logger.Debug("BuildingClient", "Preview part confirmed - proceeding with placement")
            else
                Logger.Warn("BuildingClient", "CRITICAL: Primary part is not marked as preview, aborting placement")
                return
            end
            
            local cframeToPlace = _currentPreviewPrimaryPart.CFrame
            Logger.Debug("BuildingClient", "Placing structure at CFrame: %s", tostring(cframeToPlace))
            
            -- Send build request to server
            if ClientRequestBuild then -- Ensure RemoteFunction is available
                Logger.Debug("BuildingClient", "CRITICAL: About to send build request for %s at %s", _selectedStructureType, tostring(cframeToPlace))
                local success, message = ClientRequestBuild:InvokeServer(_selectedStructureType, cframeToPlace)
                if success then
                    Logger.Debug("BuildingClient", "Successfully sent build request for %s", _selectedStructureType)
                    -- Optionally, disable building mode after placement or keep it active
                    -- self:DisableBuildingMode()
                else
                    Logger.Warn("BuildingClient", "Failed to place %s: %s", _selectedStructureType, message)
                end
            else
                Logger.Warn("BuildingClient", "ClientRequestBuild RemoteFunction not available.")
            end
        elseif input.KeyCode == Enum.KeyCode.R then -- R key to rotate
            if _isBuildingMode then
                _currentRotation = (_currentRotation + 90) % 360
                Logger.Debug("BuildingClient", "Rotated preview to %d degrees.", _currentRotation)
            end
        else
            Logger.Debug("BuildingClient", "Building mode input not handled: %s", input.KeyCode and input.KeyCode.Name or input.UserInputType.Name)
        -- Q key is handled by the UI, not here
        end
    elseif _isRepairMode then
        if input.UserInputType == Enum.UserInputType.MouseButton1 then -- Left click to repair
            local targetStructure = self:GetStructureUnderMouse()
            if targetStructure then
                self:RepairStructure(targetStructure.Name)
            else
                Logger.Debug("BuildingClient", "No structure found under mouse for repair.")
            end
        -- Q key is handled by the UI, not here
        end
    end
    
    -- Global key bindings
    if input.KeyCode == Enum.KeyCode.E then -- E key to toggle repair mode
        self:ToggleRepairMode()
    end
end

-- Initialize the client-side building system
function BuildingClient.Init()
    -- NEW: Get the RemoteFunctions with retry mechanism to handle timing issues
    local maxRetries = 10
    local retryCount = 0
    
    while (not ClientRequestBuild or not ClientRequestRepair) and retryCount < maxRetries do
        if not ClientRequestBuild then
            ClientRequestBuild = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_BUILD)
        end
        if not ClientRequestRepair then
            ClientRequestRepair = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_REPAIR)
        end
        
        if not ClientRequestBuild or not ClientRequestRepair then
            retryCount = retryCount + 1
            Logger.Debug("BuildingClient", "Attempt %d to get RemoteFunctions...", retryCount)
            task.wait(0.5) -- Wait 0.5 seconds before retrying
        end
    end
    
    if not ClientRequestBuild then
        Logger.Error("BuildingClient", "Failed to get ClientRequestBuild RemoteFunction after %d attempts.", maxRetries)
    else
        Logger.Debug("BuildingClient", "Successfully obtained ClientRequestBuild RemoteFunction.")
    end
    
    if not ClientRequestRepair then
        Logger.Error("BuildingClient", "Failed to get ClientRequestRepair RemoteFunction after %d attempts.", maxRetries)
    else
        Logger.Debug("BuildingClient", "Successfully obtained ClientRequestRepair RemoteFunction.")
    end

    -- Connect Heartbeat to update preview position
    RunService.Heartbeat:Connect(UpdatePreview)

    -- Input handling is now delegated through BuildingUI
    -- UserInputService connection removed to prevent conflicts

    Logger.Debug("BuildingClient", "Client-side building system initialized.")
end

return BuildingClient
