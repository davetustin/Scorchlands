# Building UI System

## Overview

The Building UI System provides a Fortnite-like building interface for Scorchlands, featuring a bottom toolbar with building buttons, blue glow effects, and part previews.

## Features

### UI Components
- **Bottom Toolbar**: Four buttons positioned along the bottom of the screen
- **Building Buttons**: Wall, Floor, Roof, and Repair buttons with icons
- **Hotkey Support**: Number keys 1-4 for quick selection
- **Visual Feedback**: Blue glow effects and hover animations
- **Part Preview**: 3D preview with blue highlight when building

### Building Controls
- **Left Click**: Place structure (when in building mode)
- **R Key**: Rotate preview 90 degrees
- **Q Key**: Exit building/repair mode
- **E Key**: Toggle repair mode
- **ESC Key**: Deselect all buttons
- **Number Keys 1-4**: Quick select building types

### Structure Types
1. **Wall** (Key 1): Vertical wall structure
2. **Floor** (Key 2): Horizontal floor tile
3. **Roof** (Key 3): Horizontal roof tile
4. **Repair** (Key 4): Repair damaged structures

## Architecture

### Files
- `src/client/Interface/BuildingUI.lua`: Main UI system
- `src/client/BuildingClient.lua`: Building logic and preview system
- `src/shared/BuildingModelBuilder.lua`: Generates building part models
- `src/client/init.client.lua`: Client initialization and integration

### Key Components

#### BuildingUI
- Creates and manages the bottom toolbar
- Handles button interactions and hotkeys
- Provides visual feedback with glow effects
- Integrates with BuildingClient for mode changes

#### BuildingClient
- Manages building mode state
- Creates and updates 3D preview models
- Handles placement and rotation logic
- Provides callback system for UI feedback

#### BuildingModelBuilder
- Generates simple building part models
- Creates models for walls, floors, and roofs
- Places models in ReplicatedStorage.BuildingModels

## Usage

### For Players
1. **Select Building Type**: Click a button or press 1-4
2. **Position Preview**: Move mouse to see blue preview
3. **Rotate**: Press R to rotate preview
4. **Place**: Left click to place structure
5. **Exit**: Press Q or ESC to exit building mode

### For Developers
The system is automatically initialized when the client starts. No additional setup required.

## Technical Details

### UI Constants
```lua
UI_CONSTANTS = {
    BUTTON_SIZE = UDim2.new(0, 80, 0, 80),
    GLOW_COLOR = Color3.fromRGB(0, 150, 255), -- Blue glow
    SELECTED_GLOW_COLOR = Color3.fromRGB(0, 255, 150), -- Green for selected
    -- ... more constants
}
```

### Building Models
Models are automatically generated and stored in `ReplicatedStorage.BuildingModels`:
- `Wall`: 8x8x0.5 studs, concrete material
- `Floor`: 8x0.5x8 studs, concrete material  
- `Roof`: 8x0.5x8 studs, slate material

### Integration
The system integrates with:
- **BuildingSystem**: Server-side structure placement
- **ResourceSystem**: Resource gathering for building materials
- **SunlightSystem**: Structure damage and repair mechanics

## Future Enhancements

- **Material Selection**: Different materials for structures
- **Advanced Shapes**: More complex building parts
- **Building Limits**: Resource-based building restrictions
- **Undo/Redo**: Building history management
- **Blueprint System**: Save and load building designs 