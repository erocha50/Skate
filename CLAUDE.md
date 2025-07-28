# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SKATE** is a Godot 4.4 3D skateboarding game built with GDScript featuring:
- Sonic-style movement mechanics with rail grinding
- QTE (Quick Time Event) system for tricks
- Scoring system with combos and multipliers
- PSX-style graphics and aesthetics

## Project Structure

The game is built as a single Godot project located in `GodotProject/`:

- **Core Scripts**: Located in `codes/` directory
  - `player.gd` - Main player controller with physics, movement, rail grinding, and dash mechanics
  - `camera_controller.gd` - Camera following system

- **Scene Scripts**: Located in `scenes/` directory
  - `qte_system.gd` - Quick Time Event system for rail tricks
  - `score_ui.gd` - Scoring, combo tracking, and UI management
  - `test_world.gd` - Main game world controller

- **Scene Files**: `.tscn` files for game objects
  - `player.tscn` - Player character setup
  - `test_world.tscn` - Main game scene (referenced as main scene in project.godot)
  - `qte_system.tscn` - QTE UI components
  - `score_ui.tscn` - Score display interface

## Key Game Systems

### Player Movement System (`codes/player.gd`)
- **RigidBody3D-based** physics with locked Z-axis (2.5D movement)
- **Rail Grinding**: Automatic speed boost and directional control on objects in "Rail" group
- **Dash System**: Timed dash with cooldown and reduced gravity
- **Freeze Block Mechanic**: Mid-air double jump trigger with game pause effect
- **Signal-based Architecture**: Emits events for scoring system integration

### QTE System (`qte_system.gd`)
- **Scrolling Interface**: WASD letters scroll toward center indicator
- **Timing-based**: Players must hit correct keys when letters reach center
- **Visual Feedback**: Color-coded success/failure with progress bar
- **Configurable**: Sequence length, timing, and scroll speed adjustable

### Scoring System (`score_ui.gd`)
- **Combo System**: Chained tricks increase multiplier
- **Grade Progression**: D→C→B→A→S→U ranking system with thresholds
- **Trick Categories**: Easy/Medium/Hard/Insane difficulty levels
- **Score Decay**: Continuous decay with level-scaled rates
- **Visual Effects**: Screen shake, color changes, animations

## Input Controls

Defined in `project.godot`:
- **WASD**: Movement (W/S: up/down, A/D: left/right)
- **Space**: Jump
- **Shift**: Dash
- **Q**: Trick trigger / QTE input
- **R**: Reset

## Development Workflow

### Running the Game
Open the project in Godot 4.4+ and run the main scene (`test_world.tscn`).

### Testing Changes
- **Player Mechanics**: Test in `test_world.tscn` scene
- **QTE System**: Trigger rail grind to activate QTE sequence
- **Scoring**: Perform tricks to test combo/multiplier system

### Code Architecture Notes
- **Signals**: Extensive use of signals for loose coupling between systems
- **Export Variables**: Most gameplay parameters are `@export` for designer tweaking
- **2.5D Constraints**: Z-axis and rotations locked for side-scrolling gameplay
- **Physics Timing**: Game runs at 240 physics ticks/second with 60 max steps/frame

## Common Modifications

When modifying gameplay:
1. **Player Parameters**: Adjust `@export` variables in `player.gd` for movement tuning
2. **Scoring Balance**: Modify `TRICK_MULTIPLIERS` and `PROGRESS_THRESHOLDS` in `score_ui.gd`
3. **QTE Difficulty**: Change `sequence_length`, `time_per_input` in `qte_system.gd`
4. **New Tricks**: Add signal emissions in `player.gd` and handlers in `score_ui.gd`

## Assets Structure

- **3D Models**: Metro station environment, character models, skateboard
- **Textures**: PSX-style low-res textures for environment and characters
- **Shaders**: Custom shaders for PSX aesthetic (`*.gdshader` files)