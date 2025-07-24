--[[
    client/BuildingClient.client.luau
    Description: Handles client-side logic for the base building system.
    This includes displaying a building preview, handling input for placement
    and rotation, and sending build requests to the server.
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local NetworkManager = require(ReplicatedStorage.Shared.NetworkManager)

local LocalPlayer = Players.LocalPlayer
local PlayerMouse = LocalPlayer:GetMouse()

local BuildingClient = {}

-- Private variables for building state
local _isBuildingMode = false
local _selectedStructureType = nil
local _currentPreviewModel = nil
local _currentPreviewPrimaryPart = nil
local _gridSize = 4 -- All building parts will snap to a 4x4 grid (adjust based on your part sizes)
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
        warn("BuildingClient: Invalid structure type provided: " .. structureType)
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
                part.Anchored = true
            end
        end
        _currentPreviewPrimaryPart = _currentPreviewModel.PrimaryPart
    else
        warn("BuildingClient: Could not find model template for " .. structureType .. " in ReplicatedStorage.")
        self:DisableBuildingMode()
    end

    print("BuildingClient: Building mode ENABLED for " .. structureType)
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

    print("BuildingClient: Building mode DISABLED.")
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
    local raycastResult = Workspace:Raycast(PlayerMouse.Origin, PlayerMouse.Direction * 1000)

    local targetPosition = nil
    local targetNormal = nil

    if raycastResult then
        targetPosition = raycastResult.Position
        targetNormal = raycastResult.Normal
    else
        -- Fallback if raycast hits nothing (e.g., pointing at sky)
        targetPosition = mouseHit.Position
        targetNormal = Vector3.new(0, 1, 0) -- Assume flat ground
    end

    -- Snap to grid
    local snappedX = math.floor(targetPosition.X / _gridSize + 0.5) * _gridSize
    local snappedY = math.floor(targetPosition.Y / _gridSize + 0.5) * _gridSize
    local snappedZ = math.floor(targetPosition.Z / _gridSize + 0.5) * _gridSize

    local snappedCFrame = CFrame.new(snappedX, snappedY, snappedZ)

    -- Adjust Y position based on part size and surface normal (for floor/roof)
    -- This is a simplified adjustment. For complex shapes, you'd need more sophisticated logic.
    local halfHeight = _currentPreviewPrimaryPart.Size.Y / 2
    if _selectedStructureType == Constants.STRUCTURE_TYPES.FLOOR or _selectedStructureType == Constants.STRUCTURE_TYPES.ROOF then
        -- Snap to the surface, considering the part's half-height
        snappedCFrame = CFrame.new(snappedX, targetPosition.Y + halfHeight, snappedZ)
    elseif _selectedStructureType == Constants.STRUCTURE_TYPES.WALL then
        -- For walls, snap to the ground plane, adjusting for height
        snappedCFrame = CFrame.new(snappedX, snappedY + halfHeight, snappedZ)
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
                    print("BuildingClient: Successfully sent build request for " .. _selectedStructureType)
                    -- Optionally, disable building mode after placement or keep it active
                    -- self:DisableBuildingMode()
                else
                    warn("BuildingClient: Failed to place " .. _selectedStructureType .. ": " .. message)
                end
            else
                warn("BuildingClient: ClientRequestBuild RemoteFunction not available.")
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then -- Right click to rotate
            _currentRotation = (_currentRotation + 90) % 360
            print("BuildingClient: Rotated preview to " .. _currentRotation .. " degrees.")
        elseif input.KeyCode == Enum.KeyCode.Q then -- Q to disable building mode
            self:DisableBuildingMode()
        end
    end
end

-- Initialize the client-side building system
function BuildingClient.Init()
    -- NEW: Get the RemoteFunction here, ensuring NetworkManager is fully loaded
    ClientRequestBuild = NetworkManager.GetRemoteFunction(Constants.NETWORK_EVENTS.CLIENT_REQUEST_BUILD)
    if not ClientRequestBuild then
        error("BuildingClient: Failed to get ClientRequestBuild RemoteFunction during initialization.")
    end

    -- Connect Heartbeat to update preview position
    RunService.Heartbeat:Connect(UpdatePreview)

    -- Connect UserInputService for placement and rotation
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        BuildingClient:HandleInput(input, gameProcessedEvent)
    end)

    print("BuildingClient: Client-side building system initialized.")
end

return BuildingClient
