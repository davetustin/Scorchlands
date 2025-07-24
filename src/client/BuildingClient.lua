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
local _gridSize = 4 -- Grid size for basic snapping
local _currentRotation = 0 -- 0, 90, 180, 270 degrees

-- REMOVED: Get RemoteFunction here. It will be retrieved in Init()
local ClientRequestBuild = nil

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

    -- For walls, use 2-stud grid for more precise positioning
    if _selectedStructureType == Constants.STRUCTURE_TYPES.WALL then
        local wallGridSize = 2 -- 2-stud grid for walls
        snappedX = math.floor(targetPosition.X / wallGridSize + 0.5) * wallGridSize
        snappedZ = math.floor(targetPosition.Z / wallGridSize + 0.5) * wallGridSize
    end

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
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then -- Right click to rotate
            if _isBuildingMode then
                _currentRotation = (_currentRotation + 90) % 360
                Logger.Debug("BuildingClient", "Rotated preview to %d degrees.", _currentRotation)
            end
        elseif input.KeyCode == Enum.KeyCode.Q then -- Q to disable building mode
            self:DisableBuildingMode()
        end
    end
end

-- Initialize the client-side building system
function BuildingClient.Init()
    -- NEW: Get the RemoteFunction with retry mechanism to handle timing issues
    local maxRetries = 10
    local retryCount = 0
    
    while not ClientRequestBuild and retryCount < maxRetries do
        ClientRequestBuild = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_BUILD)
        if not ClientRequestBuild then
            retryCount = retryCount + 1
            Logger.Debug("BuildingClient", "Attempt %d to get ClientRequestBuild RemoteFunction...", retryCount)
            task.wait(0.5) -- Wait 0.5 seconds before retrying
        end
    end
    
    if not ClientRequestBuild then
        Logger.Error("BuildingClient", "Failed to get ClientRequestBuild RemoteFunction after %d attempts.", maxRetries)
    else
        Logger.Debug("BuildingClient", "Successfully obtained ClientRequestBuild RemoteFunction.")
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
