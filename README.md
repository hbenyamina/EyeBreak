# Eyebreak

A macOS menu bar app that helps you follow the **20-20-20 rule** to prevent digital eye strain. Every 20 minutes, take a 20-second break to look at something 20 feet away.

## Features

Frosted glass throughout (Liquid Glass on macOS 26+): violet for everything about your eyes, clear aqua-blue for water, red only for the dry-eye warning. Full spec: [docs/FEATURES.md](docs/FEATURES.md).

- **Break timer** - 20-20-20 by default, Pomodoro (25/5), or custom intervals, with a pre-break warning
- **Four break styles** - Blur Screen, Floating Window, guided Eye Exercise, or Notification Only
- **Tapered countdown ring** - Glowing violet ring that widens toward its head
- **Dry-eye nudge** - After you skip breaks in a row, a red, dry eye shows what's coming
- **Water reminders** - Floating or full-screen, custom icon and message, "I already drank"
- **Ambient reminders** - Small glass pills that nudge you to blink or look away, then fade
- **Smart Schedule** - Work hours, active days, presets; pauses outside them
- **Away detection** - Pauses when you're idle or the screen is locked
- **Themes** - Default, Random Color, or a custom palette per reminder type
- **Statistics** - Daily goal, streak, week/month chart, insights
- **Multi-monitor**, **launch at login**, **ESC / ⌥⇧⎋ to skip**

## Requirements

- macOS 13.0 or later
- Swift 5.9+

## Installation

### From DMG (Recommended)

1. Download the latest `Eyebreak-1.0.dmg` from releases (or `build/Eyebreak-1.0.dmg` if building locally)
2. Open the DMG and drag Eyebreak to your Applications folder
3. Launch Eyebreak from Applications

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/Eyebreak.git
cd Eyebreak

# Build and run (debug)
./build.sh
open Eyebreak.app

# Build release with DMG
./build.sh --release --dmg
```

> **Note:** Do not use `swift run` directly. This app requires a proper macOS app bundle for notifications and other system features. Always use `./build.sh` followed by `open Eyebreak.app`.

## Build Options

```
./build.sh [options]

Options:
  --release    Build in release mode (optimized)
  --dmg        Create a DMG file for distribution
  -h, --help   Show help message
```

## Usage

1. **Launch** - Click the eye icon in your menu bar to see the dropdown
2. **Timer** - Shows countdown to next break (e.g., "Next break in 19:45")
3. **Pause/Resume** - Click to pause reminders; icon changes to crossed-out eye when paused
4. **Skip Break** - Available in menu during the warning period before a break
5. **During Break** - Screen shows countdown with a random quote; press `⌥⇧⎋` to skip
6. **Quit** - Select "Quit Eyebreak" from the menu

## Configuration

Edit `Sources/Eyebreak/Resources/config.json` to customize timing:

```json
{
    "workDurationMinutes": 20,
    "breakDurationSeconds": 20,
    "warningTimeSeconds": 5
}
```

Then rebuild with `./build.sh`.

## Project Structure

```
Eyebreak/
├── Sources/Eyebreak/
│   ├── EyebreakApp.swift         # Main app entry point
│   ├── AppDelegate.swift         # Menu bar setup and coordination
│   ├── MenuBarView.swift         # Menu bar dropdown UI
│   ├── TimerManager.swift        # Timer logic and sleep/wake handling
│   ├── ConfigManager.swift       # Configuration loader
│   ├── NotificationManager.swift # macOS notifications
│   ├── BlockerWindow.swift       # Full-screen blocker windows
│   ├── BlockerView.swift         # Blocker UI with countdown
│   ├── HotkeyManager.swift       # Global hotkey (⌥⇧⎋)
│   ├── QuoteManager.swift        # Random quotes loader
│   ├── LoginItemManager.swift    # Launch at login
│   └── Resources/
│       ├── config.json           # Timer configuration
│       └── quotes.json           # 30 inspirational quotes
├── Package.swift
├── build.sh
└── README.md
```

## License

MIT License
