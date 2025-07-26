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

-- Private variables for repair mode
local _isRepairMode = false
local _repairTarget = nil -- The structure being targeted for repair

-- REMOVED: Get RemoteFunction here. It will be retrieved in Init()
local ClientRequestBuild = nil
local ClientRequestRepair = nil

--[[
    BuildingClient:EnableBuildingMode(structureType)
    Enables building mode for a specific structure type.
    @param structureType string: The type of structure to build (e.g., "Wall", "Floor").
]]
function BuildingClient:EnableBuildingMode(structureType)
    if not Constants.STRUCTURE_TYPES[structureType:upper()] then
        Logger.Warn("BuildingClient", "Invalid structure type provided: %s", structureType)
        return
    end

    _isBuildingMode = true
    _selectedStructureType = structureType
    _currentRotation = 0 -- Reset rotation when enabling mode

    -- Create and display the preview model
    local modelTemplate = ReplicatedStorage:FindFirstChild(structureType)
    if modelTemplate and modelTemplate:IsA("Model") then
        _currentPreviewModel = modelTemplate:Clone()
        _currentPreviewModel.Parent = Workspace.CurrentCamera -- Parent to camera for local visibility
        _currentPreviewModel.Archivable = false -- Don't save this temporary model

        -- Set properties for preview
        for _, part in ipairs(_currentPreviewModel:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0.7 -- More transparent
                part.CanCollide = false
                part.CanQuery = false -- Ignore raycasts
                part.Anchored = true
            end
        end
        _currentPreviewPrimaryPart = _currentPreviewModel.PrimaryPart
    else
        Logger.Warn("BuildingClient", "Could not find model template for %s in ReplicatedStorage.", structureType)
        self:DisableBuildingMode()
    end

    Logger.Debug("BuildingClient", "Building mode ENABLED for %s", structureType)
end

--[[
    BuildingClient:DisableBuildingMode()
    Disables building mode and cleans up the preview model.
]]
function BuildingClient:DisableBuildingMode()
    _isBuildingMode = false
    _selectedStructureType = nil
    _currentRotation = 0

    if _currentPreviewModel then
        _currentPreviewModel:Destroy()
        _currentPreviewModel = nil
        _currentPreviewPrimaryPart = nil
    end

    Logger.Debug("BuildingClient", "Building mode DISABLED.")
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
    
    Logger.Debug("BuildingClient", "Repair mode ENABLED.")
end

--[[
    BuildingClient:DisableRepairMode()
    Disables repair mode.
]]
function BuildingClient:DisableRepairMode()
    _isRepairMode = false
    _repairTarget = nil
    
    Logger.Debug("BuildingClient", "Repair mode DISABLED.")
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
    if not _isBuildingMode or not _currentPreviewModel or not _currentPreviewPrimaryPart then return end

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

    _currentPreviewModel:SetPrimaryPartCFrame(snappedCFrame)
end

--[[
    BuildingClient:HandleInput(input, gameProcessedEvent)
    Handles user input for building mode (placement and rotation).
    @param input InputObject: The input event.
    @param gameProcessedEvent boolean: True if the game engine has already processed this input.
]]
function BuildingClient:HandleInput(input, gameProcessedEvent)
    if gameProcessedEvent then return end -- Ignore if game engine already handled it

    if _isBuildingMode then
        if input.UserInputType == Enum.UserInputType.MouseButton1 then -- Left click to place
            local cframeToPlace = _currentPreviewPrimaryPart.CFrame
            -- Send build request to server
            if ClientRequestBuild then -- Ensure RemoteFunction is available
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
        elseif input.KeyCode == Enum.KeyCode.Q then -- Q to disable building mode
            self:DisableBuildingMode()
        end
    elseif _isRepairMode then
        if input.UserInputType == Enum.UserInputType.MouseButton1 then -- Left click to repair
            local targetStructure = self:GetStructureUnderMouse()
            if targetStructure then
                self:RepairStructure(targetStructure.Name)
            else
                Logger.Debug("BuildingClient", "No structure found under mouse for repair.")
            end
        elseif input.KeyCode == Enum.KeyCode.Q then -- Q to disable repair mode
            self:DisableRepairMode()
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

    -- Connect UserInputService for placement and rotation
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        BuildingClient:HandleInput(input, gameProcessedEvent)
    end)

    Logger.Debug("BuildingClient", "Client-side building system initialized.")
end

return BuildingClient
