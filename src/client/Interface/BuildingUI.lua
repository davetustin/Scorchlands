--[[
    client/Interface/BuildingUI.lua
    Description: Building UI system for Scorchlands, similar to Fortnite's building system.
    Features:
    - Bottom toolbar with building buttons
    - Blue glow effects for selected parts
    - Part preview with shape visualization
    - Hotkey support (1-4 for quick selection)
    - Visual feedback for building mode
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BuildingUI = {}

-- Private variables
local _buildingFrame = nil
local _buttonContainer = nil
local _buttons = {}
local _buttonData = {} -- NEW: Separate table to store button data
local _selectedButton = nil
local _isVisible = false
local _buildingClient = nil -- Reference to BuildingClient module
local _inputCounter = 0 -- Debug counter for input events

-- UI Constants
local UI_CONSTANTS = {
    BUTTON_SIZE = UDim2.new(0, 80, 0, 80),
    BUTTON_SPACING = 10,
    BOTTOM_MARGIN = 20,
    GLOW_COLOR = Color3.fromRGB(0, 150, 255), -- Blue glow
    GLOW_INTENSITY = 0.8,
    SELECTED_GLOW_COLOR = Color3.fromRGB(0, 255, 150), -- Green for selected
    BUTTON_BACKGROUND_COLOR = Color3.fromRGB(40, 40, 40),
    BUTTON_HOVER_COLOR = Color3.fromRGB(60, 60, 60),
    BUTTON_SELECTED_COLOR = Color3.fromRGB(80, 80, 80),
    TEXT_COLOR = Color3.fromRGB(255, 255, 255),
    TEXT_SIZE = 14,
}

-- Structure button definitions
local STRUCTURE_BUTTONS = {
    {
        name = "Wall",
        displayName = "Wall",
        structureType = Constants.STRUCTURE_TYPES.WALL,
        icon = "⬜", -- Unicode square for wall
        hotkey = Enum.KeyCode.One,
        description = "Build a wall"
    },
    {
        name = "Floor", 
        displayName = "Floor",
        structureType = Constants.STRUCTURE_TYPES.FLOOR,
        icon = "⬛", -- Unicode filled square for floor
        hotkey = Enum.KeyCode.Two,
        description = "Build a floor"
    },
    {
        name = "Roof",
        displayName = "Roof", 
        structureType = Constants.STRUCTURE_TYPES.ROOF,
        icon = "▲", -- Unicode triangle for roof
        hotkey = Enum.KeyCode.Three,
        description = "Build a roof"
    },
    {
        name = "Repair",
        displayName = "Repair",
        structureType = "REPAIR",
        icon = "🔧", -- Unicode wrench for repair
        hotkey = Enum.KeyCode.Four,
        description = "Repair structures"
    }
}

--[[
    BuildingUI:CreateButton(buttonData)
    Creates a building button with the specified data.
    @param buttonData table: Button configuration data
    @return Frame: The created button frame
]]
function BuildingUI:CreateButton(buttonData)
    local button = Instance.new("Frame")
    button.Name = buttonData.name .. "Button"
    button.Size = UI_CONSTANTS.BUTTON_SIZE
    button.BackgroundColor3 = UI_CONSTANTS.BUTTON_BACKGROUND_COLOR
    button.BorderSizePixel = 0
    button.Parent = _buttonContainer
    
    -- Add corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    
    -- Add stroke for border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 100, 100)
    stroke.Thickness = 2
    stroke.Parent = button
    
    -- Icon label
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(1, 0, 0.6, 0)
    iconLabel.Position = UDim2.new(0, 0, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = buttonData.icon
    iconLabel.TextColor3 = UI_CONSTANTS.TEXT_COLOR
    iconLabel.TextScaled = true
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.Parent = button
    
    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = buttonData.displayName
    nameLabel.TextColor3 = UI_CONSTANTS.TEXT_COLOR
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Parent = button
    
    -- Hotkey label
    local hotkeyLabel = Instance.new("TextLabel")
    hotkeyLabel.Name = "Hotkey"
    hotkeyLabel.Size = UDim2.new(0, 20, 0, 20)
    hotkeyLabel.Position = UDim2.new(1, -25, 0, 5)
    hotkeyLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    hotkeyLabel.BorderSizePixel = 0
    
    -- Map hotkey to display number
    local hotkeyNumber = ""
    if buttonData.hotkey == Enum.KeyCode.One then
        hotkeyNumber = "1"
    elseif buttonData.hotkey == Enum.KeyCode.Two then
        hotkeyNumber = "2"
    elseif buttonData.hotkey == Enum.KeyCode.Three then
        hotkeyNumber = "3"
    elseif buttonData.hotkey == Enum.KeyCode.Four then
        hotkeyNumber = "4"
    else
        hotkeyNumber = tostring(buttonData.hotkey.Name):sub(-1) -- Fallback
    end
    
    hotkeyLabel.Text = hotkeyNumber
    hotkeyLabel.TextColor3 = UI_CONSTANTS.TEXT_COLOR
    hotkeyLabel.TextScaled = true
    hotkeyLabel.Font = Enum.Font.GothamBold
    hotkeyLabel.Parent = button
    
    -- Add corner rounding to hotkey
    local hotkeyCorner = Instance.new("UICorner")
    hotkeyCorner.CornerRadius = UDim.new(0, 4)
    hotkeyCorner.Parent = hotkeyLabel
    
    -- Glow effect (initially hidden)
    local glow = Instance.new("Frame")
    glow.Name = "Glow"
    glow.Size = UDim2.new(1.2, 0, 1.2, 0)
    glow.Position = UDim2.new(-0.1, 0, -0.1, 0)
    glow.BackgroundColor3 = UI_CONSTANTS.GLOW_COLOR
    glow.BorderSizePixel = 0
    glow.Transparency = 1 -- Hidden by default
    glow.ZIndex = -1 -- Behind the button
    glow.Parent = button
    
    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0, 12)
    glowCorner.Parent = glow
    
    -- Store button data in separate table (not on Frame)
    _buttonData[button] = buttonData
    
    -- Add click event
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Logger.Debug("BuildingUI", "Button click detected on: %s", buttonData.name)
            self:SelectButton(button)
        end
    end)
    
    -- Add hover effects
    button.MouseEnter:Connect(function()
        if button ~= _selectedButton then
            self:TweenButtonColor(button, UI_CONSTANTS.BUTTON_HOVER_COLOR)
        end
    end)
    
    button.MouseLeave:Connect(function()
        if button ~= _selectedButton then
            self:TweenButtonColor(button, UI_CONSTANTS.BUTTON_BACKGROUND_COLOR)
        end
    end)
    
    return button
end

--[[
    BuildingUI:TweenButtonColor(button, color)
    Smoothly transitions button color.
    @param button Frame: The button to animate
    @param color Color3: Target color
]]
function BuildingUI:TweenButtonColor(button, color)
    local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = color})
    tween:Play()
end

--[[
    BuildingUI:ShowGlow(button, isSelected)
    Shows or hides the glow effect on a button.
    @param button Frame: The button to add glow to
    @param isSelected boolean: Whether this is the selected button
]]
function BuildingUI:ShowGlow(button, isSelected)
    local glow = button:FindFirstChild("Glow")
    if glow then
        local targetColor = isSelected and UI_CONSTANTS.SELECTED_GLOW_COLOR or UI_CONSTANTS.GLOW_COLOR
        local targetTransparency = isSelected and 0.3 or 0.7
        
        local tween = TweenService:Create(glow, TweenInfo.new(0.3), {
            BackgroundColor3 = targetColor,
            Transparency = targetTransparency
        })
        tween:Play()
    end
end

--[[
    BuildingUI:HideGlow(button)
    Hides the glow effect on a button.
    @param button Frame: The button to remove glow from
]]
function BuildingUI:HideGlow(button)
    local glow = button:FindFirstChild("Glow")
    if glow then
        local tween = TweenService:Create(glow, TweenInfo.new(0.3), {Transparency = 1})
        tween:Play()
    end
end

--[[
    BuildingUI:SelectButton(button)
    Selects a building button and enables the corresponding building mode.
    @param button Frame: The button to select
]]
function BuildingUI:SelectButton(button)
    Logger.Debug("BuildingUI", "SelectButton called for button: %s", button.Name)
    
    if not _buildingClient then
        Logger.Warn("BuildingUI", "BuildingClient not available")
        return
    end
    
    -- Deselect previous button
    if _selectedButton then
        Logger.Debug("BuildingUI", "Deselecting previous button: %s", _selectedButton.Name)
        self:TweenButtonColor(_selectedButton, UI_CONSTANTS.BUTTON_BACKGROUND_COLOR)
        self:HideGlow(_selectedButton)
    end
    
    -- Select new button
    _selectedButton = button
    Logger.Debug("BuildingUI", "Selecting new button: %s", button.Name)
    self:TweenButtonColor(button, UI_CONSTANTS.BUTTON_SELECTED_COLOR)
    self:ShowGlow(button, true)
    
    -- Enable building mode (but don't place part yet)
    local buttonData = _buttonData[button]
    if buttonData.structureType == "REPAIR" then
        Logger.Debug("BuildingUI", "Calling EnableRepairMode")
        _buildingClient:EnableRepairMode()
        Logger.Debug("BuildingUI", "Enabled repair mode")
    else
        Logger.Debug("BuildingUI", "Calling EnableBuildingMode for: %s", buttonData.structureType)
        _buildingClient:EnableBuildingMode(buttonData.structureType)
        Logger.Debug("BuildingUI", "Enabled building mode: %s", buttonData.structureType)
    end
end

--[[
    BuildingUI:HandleInput(input, gameProcessedEvent)
    Handles hotkey input for building buttons.
    @param input InputObject: The input event
    @param gameProcessedEvent boolean: Whether the game processed this input
]]
function BuildingUI:HandleInput(input, gameProcessedEvent)
    Logger.Debug("BuildingUI", "HandleInput called with: %s (gameProcessed: %s)", 
        input.KeyCode and input.KeyCode.Name or input.UserInputType.Name, 
        tostring(gameProcessedEvent))
    
    if gameProcessedEvent then 
        Logger.Debug("BuildingUI", "Input was game processed, ignoring")
        return 
    end
    
    -- Filter out Unknown inputs (but only if they don't have a valid UserInputType)
    if input.KeyCode and input.KeyCode == Enum.KeyCode.Unknown and not input.UserInputType then
        Logger.Debug("BuildingUI", "Unknown input detected, ignoring")
        return
    end
    
    -- Check for hotkeys first
    for _, button in pairs(_buttons) do
        local buttonData = _buttonData[button]
        if input.KeyCode == buttonData.hotkey then
            Logger.Debug("BuildingUI", "Processing hotkey: %s for button: %s", input.KeyCode.Name, buttonData.name)
            self:SelectButton(button)
            
            -- Notify BuildingClient that a hotkey was pressed
            if _buildingClient then
                _buildingClient:OnHotkeyPressed()
            end
            
            return -- Consume the input and prevent delegation
        end
    end
    
    -- ESC or Q to deselect
    if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Q then
        self:DeselectAllAndDisableModes()
        return -- Consume the input and prevent delegation
    end
    
    -- Delegate mouse input and specific keyboard keys to BuildingClient
    local shouldDelegate = false
    
    -- Delegate mouse input for placement and interaction
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.MouseButton2 or
       input.UserInputType == Enum.UserInputType.MouseWheel then
        shouldDelegate = true
    end
    
    -- Delegate only specific keyboard keys that BuildingClient should handle
    if input.KeyCode == Enum.KeyCode.R or -- Rotate
       input.KeyCode == Enum.KeyCode.E then -- Toggle repair mode
        shouldDelegate = true
    end
    
    if shouldDelegate and _buildingClient then
        Logger.Debug("BuildingUI", "Delegating input to BuildingClient: %s", input.KeyCode and input.KeyCode.Name or input.UserInputType.Name)
        _buildingClient:HandleInput(input, gameProcessedEvent)
    else
        Logger.Debug("BuildingUI", "Not delegating input: %s", input.KeyCode and input.KeyCode.Name or input.UserInputType.Name)
    end
end

--[[
    BuildingUI:DeselectAll()
    Deselects all buttons (UI only, doesn't change building state).
]]
function BuildingUI:DeselectAll()
    if _selectedButton then
        self:TweenButtonColor(_selectedButton, UI_CONSTANTS.BUTTON_BACKGROUND_COLOR)
        self:HideGlow(_selectedButton)
        _selectedButton = nil
    end
end

--[[
    BuildingUI:DeselectAllAndDisableModes()
    Deselects all buttons and disables building/repair modes.
    Use this when you want to both update UI and change building state.
]]
function BuildingUI:DeselectAllAndDisableModes()
    -- First deselect UI
    self:DeselectAll()
    
    -- Then disable modes (this will trigger callbacks)
    if _buildingClient then
        _buildingClient:DisableBuildingMode()
        _buildingClient:DisableRepairMode()
    end
end

--[[
    BuildingUI:CreateUI()
    Creates the main building UI frame and buttons.
]]
function BuildingUI:CreateUI()
    -- Create ScreenGui first
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BuildingUIScreenGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui
    
    Logger.Debug("BuildingUI", "Created ScreenGui: %s", screenGui.Name)
    
    -- Create main frame
    _buildingFrame = Instance.new("Frame")
    _buildingFrame.Name = "BuildingUI"
    _buildingFrame.Size = UDim2.new(1, 0, 1, 0)
    _buildingFrame.Position = UDim2.new(0, 0, 0, 0)
    _buildingFrame.BackgroundTransparency = 1
    _buildingFrame.Parent = screenGui
    
    Logger.Debug("BuildingUI", "Created main frame: %s", _buildingFrame.Name)
    
    -- Create button container
    _buttonContainer = Instance.new("Frame")
    _buttonContainer.Name = "ButtonContainer"
    _buttonContainer.Size = UDim2.new(0, #STRUCTURE_BUTTONS * (UI_CONSTANTS.BUTTON_SIZE.X.Offset + UI_CONSTANTS.BUTTON_SPACING) - UI_CONSTANTS.BUTTON_SPACING, 0, UI_CONSTANTS.BUTTON_SIZE.Y.Offset)
    _buttonContainer.Position = UDim2.new(0.5, -_buttonContainer.Size.X.Offset / 2, 1, -UI_CONSTANTS.BUTTON_SIZE.Y.Offset - UI_CONSTANTS.BOTTOM_MARGIN)
    _buttonContainer.BackgroundTransparency = 1 -- Fully transparent background
    _buttonContainer.Parent = _buildingFrame
    
    Logger.Debug("BuildingUI", "Created button container")
    
    -- Create buttons
    for i, buttonData in ipairs(STRUCTURE_BUTTONS) do
        local button = self:CreateButton(buttonData)
        button.Position = UDim2.new(0, (i-1) * (UI_CONSTANTS.BUTTON_SIZE.X.Offset + UI_CONSTANTS.BUTTON_SPACING), 0, 0)
        _buttons[i] = button
        Logger.Debug("BuildingUI", "Created button %d: %s", i, buttonData.name)
    end
    
    Logger.Debug("BuildingUI", "Building UI created with %d buttons", #_buttons)
end

--[[
    BuildingUI:Show()
    Shows the building UI.
]]
function BuildingUI:Show()
    if _buildingFrame then
        _buildingFrame.Visible = true
        _isVisible = true
        Logger.Debug("BuildingUI", "Building UI shown")
    end
end

--[[
    BuildingUI:Hide()
    Hides the building UI.
]]
function BuildingUI:Hide()
    if _buildingFrame then
        _buildingFrame.Visible = false
        _isVisible = false
        self:DeselectAll()
        Logger.Debug("BuildingUI", "Building UI hidden")
    end
end

--[[
    BuildingUI:Toggle()
    Toggles the building UI visibility.
]]
function BuildingUI:Toggle()
    if _isVisible then
        self:Hide()
    else
        self:Show()
    end
end

--[[
    BuildingUI:SetBuildingClient(buildingClient)
    Sets the reference to the BuildingClient module.
    @param buildingClient table: The BuildingClient module
]]
function BuildingUI:SetBuildingClient(buildingClient)
    _buildingClient = buildingClient
    Logger.Debug("BuildingUI", "BuildingClient reference set")
end

--[[
    BuildingUI:IsPointInUI(point)
    Checks if a screen point is within the UI bounds.
    @param point Vector2: The screen point to check
    @return boolean: True if the point is within the UI
]]
function BuildingUI:IsPointInUI(point)
    if not _buttonContainer then
        return false
    end
    
    local uiPosition = _buttonContainer.AbsolutePosition
    local uiSize = _buttonContainer.AbsoluteSize
    
    Logger.Debug("BuildingUI", "UI bounds check - Point: %s, UI Position: %s, UI Size: %s", 
        tostring(point), tostring(uiPosition), tostring(uiSize))
    
    -- Check if point is within button container bounds
    local isInUI = point.X >= uiPosition.X and 
                   point.X <= uiPosition.X + uiSize.X and
                   point.Y >= uiPosition.Y and 
                   point.Y <= uiPosition.Y + uiSize.Y
    
    Logger.Debug("BuildingUI", "Is point in UI: %s", tostring(isInUI))
    return isInUI
end

--[[
    BuildingUI:Init()
    Initializes the building UI system.
]]
function BuildingUI:Init()
    -- Create the UI
    self:CreateUI()
    
    -- TEMPORARY TEST: Add a simple test connection to see if mouse clicks are detected
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Logger.Debug("BuildingUI", "TEST: Raw mouse click detected! Input: %s, GameProcessed: %s", 
                tostring(input), tostring(gameProcessedEvent))
        end
    end)
    
    -- Connect input handling
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        _inputCounter = _inputCounter + 1
        
        Logger.Debug("BuildingUI", "Input received: %s (gameProcessed: %s) - Counter: %d", 
            input.KeyCode and input.KeyCode.Name or input.UserInputType.Name, 
            tostring(gameProcessedEvent),
            _inputCounter)
        
        -- CRITICAL: Add detailed logging for mouse input
        if input.UserInputType then
            Logger.Debug("BuildingUI", "CRITICAL: UserInputType detected: %s (Value: %d)", 
                input.UserInputType.Name, input.UserInputType.Value)
            
            -- Special logging for mouse clicks
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                Logger.Debug("BuildingUI", "CRITICAL: MouseButton1 detected! Processing...")
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                Logger.Debug("BuildingUI", "CRITICAL: MouseButton2 detected! Processing...")
            end
        end
        
        -- CRITICAL: Check for mouse clicks BEFORE filtering Unknown inputs
        -- This ensures mouse clicks are processed even if they're marked as "Unknown"
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Logger.Debug("BuildingUI", "MouseButton1 detected!")
            local mousePos = UserInputService:GetMouseLocation()
            local isClickingOnUI = self:IsPointInUI(mousePos)
            Logger.Debug("BuildingUI", "Mouse position: %s, Is clicking on UI: %s", tostring(mousePos), tostring(isClickingOnUI))
            if isClickingOnUI then
                Logger.Debug("BuildingUI", "Mouse click detected on UI, not delegating to BuildingClient")
                return
            else
                Logger.Debug("BuildingUI", "Mouse click detected outside UI, delegating to BuildingClient")
            end
        end
        
        -- Filter out Unknown inputs (but only if they don't have a valid UserInputType)
        if input.KeyCode and input.KeyCode == Enum.KeyCode.Unknown and not input.UserInputType then
            Logger.Debug("BuildingUI", "Filtering out Unknown input with no UserInputType, ignoring")
            return
        end
        
        -- Process the input
        self:HandleInput(input, gameProcessedEvent)
    end)
    
    -- Show UI by default
    self:Show()
    
    Logger.Debug("BuildingUI", "Building UI system initialized")
end

return BuildingUI 