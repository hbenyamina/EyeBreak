# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EyeBreak is a macOS menu bar app implementing the 20-20-20 rule for eye strain prevention. Built with SwiftUI and AppKit, styled as frosted glass (Liquid Glass on macOS 26+): violet for eyes, clear aqua-blue for water, red only for the dry-eye warning.

Version 3.0 re-implements the feature set of the installed EyeBreak 2.2.0, whose source no longer exists. `docs/FEATURES.md` is the feature spec and the source of truth for behaviour and settings keys.

## Build Commands

```bash
# Build and create app bundle (required - do not use swift run)
./build.sh

# Run the app
open Eyebreak.app

# Build release with DMG
./build.sh --release --dmg
```

**Important:** Always use `./build.sh` instead of `swift run`. The app requires a proper macOS app bundle for notifications, menu bar integration, and system features.

## Architecture

### Core

- **EyebreakApp.swift** - SwiftUI app entry point, minimal delegation to AppDelegate
- **AppDelegate.swift** - Coordinator: status item and popover, break presentation per style, reminder visibility, presence → pause wiring, hotkeys, "Outside Work Hours" prompts
- **AppSettings.swift** - UserDefaults-backed settings plus option enums (break style, presets). Key names and raw values match 2.2.0
- **TimerManager.swift** - Work → Warning → Break heartbeat; `PauseReason` (user, idle, screen locked, outside work hours); skip streak; records stats
- **StatsStore.swift** - Per-day history in `breakStatistics` (2.2.0 format), streak, insights
- **PresenceMonitor.swift** - Idle input, screen lock, Smart Schedule hours
- **WaterReminderManager.swift** / **AmbientReminderManager.swift** - Reminder countdowns; pause whenever the break timer is paused
- **FeedbackManager.swift** - Sound effects and user notifications (Notification Only style)

### Windows

- **BlockerWindow.swift** - `OverlayWindowController`: frosted overlay on every display (content on primary); key-capable so ESC works
- **BlockerView.swift** - Blur Screen break: countdown ring, quote or dry-eye card, ESC hint; `BreakBackdrop`
- **EyeExerciseView.swift** - Eye Exercise break: glowing orb walks through 11 positions
- **FloatingBreakWindow.swift** - Floating Window break style
- **WarningWindow.swift** - Pre-break toast; also `ToastWindow` (top-right/top-centre, fades, optional key focus)
- **WaterReminderWindow.swift** - Water reminder as floating toast or full-screen frost; "Thanks, I'll drink water now", "I already drank", × snooze
- **AmbientReminderWindow.swift** - Self-dismissing glass pill
- **MenuBarView.swift** - Popover: all countdowns, pause banner, today's progress, actions
- **Settings/** - Sidebar Settings window: General, Breaks, Reminders, Schedule, Appearance, Statistics, About

### Visual Style

- **GlassTheme.swift** - Violet (eyes) and clear aqua-blue (`Theme.Water`) ramps plus `Theme.alert` red, `FrostedBackdrop` (behind-window blur), `glassSurface`, `AccentButtonStyle` / `SoftButtonStyle` (stay coloured in non-key windows, unlike system prominent/glass buttons)
- **ReminderTheme.swift** - Per-surface themes (Default / Random Color / Custom) resolved to a `Palette` and passed via `\.palette`
- **CountdownRing.swift** - Tapered glowing countdown ring; widens toward its head at 12 o'clock
- **DryEyeView.swift** - Bloodshot-eye nudge shown after `skipsBeforeDryEyeNudge` consecutive skipped breaks

### Utilities

- **ConfigManager.swift** - First-launch defaults from bundled `config.json`
- **QuoteManager.swift** - Random quote selection from bundled JSON
- **HotkeyManager.swift** - ⌥⇧⎋ global skip; plain ESC for focused break/water windows
- **LoginItemManager.swift** - SMAppService for launch-at-login

## Design Rules

- **Solid colours only.** No gradients anywhere (icons, buttons, selections, charts, backdrops). The tapered ring gets one soft solid glow; that's the only glow.
- **Colour means something.** Violet = eyes/breaks and app chrome, aqua = water, red (`Theme.alert`) = dry-eye warning only. Accent marks actions, selection and state; resting icons are `.secondary`.
- **Native first in Settings.** Grouped `Form` sections with header/footer text, standard `Picker` / `Stepper` / `Toggle` / `Slider`. No icon-tile cards, option-card grids or stat tiles.
- **SF Pro, not SF Rounded.** SF Symbols, not emoji (custom ambient reminders may use the user's own emoji).
- **No decorative motion.** Motion only where it is the content (the exercise dot) or conveys state.

## Key Patterns

1. **Timer States**: Work → Warning → Break → Work, plus pause reasons (managed in TimerManager)
2. **Multi-Monitor**: OverlayWindowController creates one window per NSScreen
3. **Sleep / Away**: Timer resets on wake, and when you come back from idle or screen lock
4. **Menu Bar**: NSStatusItem + NSPopover hosting MenuBarView
5. **@Published fires on willSet**: Combine sinks that read model state hop to `DispatchQueue.main` first

## Configuration

Settings are edited in the Settings window and stored in UserDefaults (`com.eyebreak.app`, shared with 2.2.0). `Sources/Eyebreak/Resources/config.json` only seeds first-launch defaults.
