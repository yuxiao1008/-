# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `yx_job`, a FiveM job system resource for QBCore framework servers. It provides an employment center where players can select and change jobs through an interactive menu system using ox-target and ox_lib.

## Architecture

### Core Components
- **fxmanifest.lua**: Resource manifest defining dependencies (qb-core, ox_target, ox_lib)
- **config.lua**: All configurable parameters including job centers, available jobs, and UI settings
- **client.lua**: Client-side logic for UI, targeting, and player interactions
- **server.lua**: Server-side job management and validation

### Framework Dependencies
- **QBCore**: Main framework for player data and job management
- **ox_target**: Interactive targeting system for job center interactions
- **ox_lib**: UI library for context menus and notifications

### Key Data Flow
1. Player approaches job center → ox_target creates interaction zone
2. Player activates target → opens ox_lib context menu with available jobs
3. Player selects job → client sends server event with validation
4. Server validates and updates player job → sends success/error notification

## Development Commands

This is a FiveM Lua resource, so there are no traditional build/test commands. Development workflow:

### Testing Changes
- Place resource in FiveM server's `resources/` directory
- Add `ensure yx_job` to server.cfg
- Restart server or use `restart yx_job` in server console

### Debug Mode
- Set `Config.Debug = true` in config.lua to enable debug commands:
  - `/jobmenu` - Force open job selection menu
  - `/jobhelp [jobname]` - Show help for specific job

## Configuration Structure

### Job Centers (Config.JobCenters)
Each job center contains:
- `coords`: World coordinates for placement
- `blipSprite/blipColor/blipScale`: Map blip appearance
- `targetLabel/targetIcon/targetDistance`: ox-target interaction settings

### Jobs (Config.Jobs)
Each job contains:
- `name`: Unique identifier matching QBCore job names
- `label`: Display name for players
- `description`: Job description shown in menu
- `salary`: Base salary amount
- `helpText`: Array of instruction steps for players

## Code Conventions

### Naming Convention
- Variables and functions: `snake_case`
- Config tables: `PascalCase`
- Event names: `resourcename:scope:action` format

### Event Security
- Server events include player source validation
- Job existence validation against Config.Jobs
- Player employment status checks prevent abuse

### Error Handling
- Check for ox_target and ox_lib availability before use
- Validate player objects before processing
- Provide user-friendly error notifications

## Adding New Jobs

To add a new job:
1. Add entry to `Config.Jobs` with all required fields
2. Ensure QBCore has matching job definition in qb-core/shared/jobs.lua
3. Test job selection and help display

## Extending Functionality

The system is designed for extension:
- Additional job centers: Add to `Config.JobCenters` array
- Custom job validation: Modify server-side `yx_job:server:setJob` handler
- Enhanced UI: Extend ox_lib context menu options
- Job rewards: Uncomment and customize starting bonus logic in server.lua:50

## Development Rules for FiveM/QBCore

- All configurable parameters must be in Config.lua
- Use Config.Debug for development logging
- Event names follow `yx_job:scope:action` pattern
- Client-server communication must include validation
- Functions should be modular and reusable
- Performance: minimize operations in loops and event handlers