# EyeBreak

A macOS menu bar app for the working day, styled like TickTick or Notion with Liquid Glass where things float. Every 20 minutes it gives you 30 seconds to look across the room and blink; about every hour, 5 minutes on your feet with a glass of water; and it counts down to the **end of your shift**, in the menu bar and on a desktop widget. Each of those numbers comes from published research: [docs/EVIDENCE.md](docs/EVIDENCE.md). In English and Arabic.

EyeBreak 3.1 is EyeBreak and Shift Countdown merged into one app. Your Shift Countdown hours, days, time zone and widget theme carry over on first launch.

## Features

Frosted glass where things float: violet for everything about your eyes, clear aqua-blue for water. Full spec: [docs/FEATURES.md](docs/FEATURES.md).

**Eyes**
- **A guided routine in every break** - Look across the room, then two slow, full blinks (close, squeeze, open); the long break gets you on your feet
- **Rhythms** - Recommended (30 s every 20 min, 5 min every hour), 20-20-20, Pomodoro, or your own
- **Breaks that wait for you** - A break due mid-sentence waits for a pause in your typing; breaks hold while your camera or microphone is on; **5 More Minutes** never counts as a skip
- **Three styles** - Full screen, a small window, or a notification; a break you type through doesn't count
- **Blink reminders** - Optional, silent, for dry days
- **Away detection** - Pauses when you're idle or the screen is locked

**Water**
- **A drinks goal** in ml or fl oz with your own glass size, and a calculator from sex, weight, exercise and heat
- **Inside the long break** by default, so it's one interruption, not two; never more than 500 ml an hour

**Shift**
- **Shift hours** - Start and end to the minute, any days of the week, night shifts that end the next morning, and an optional time zone of their own
- **End of Shift widget** - Small and medium desktop widgets: time left in the shift, until it starts, or until the next one, in thirteen muted themes
- **Menu bar** - Next break, end of shift, or both beside the eye
- **Running late?** - The first unlock while a shift is due asks whether to start it from now; the end moves with it, for that day only
- **Smart Schedule** - Optionally pause breaks and reminders outside your shift; night shifts count as one day
- **Your region's week** - The default work week follows the Mac's region (Sunday–Thursday in Saudi Arabia)

**How you're doing**
- **Rhythm** - Each habit drawn as a line across your day: straight while you keep up, catching where you skipped a break or fell a glass behind. In the menu, at the top of Breaks and Water, and in the **Rhythm widget**
- **A goal from your shift** and a streak of work days that forgives one missed day a week
- **Pause all reminders** - From the menu or by right-clicking the menu bar item: 30 minutes, an hour, two, until tomorrow, or until you resume

**Everything else**
- **English and Arabic** - Modern Standard Arabic, right to left, widgets included; App → Language
- **App themes** - Violet & Aqua, or Garden (leaf green, rain-water blue, linen and soil)
- **Settings by need** - Breaks, Water, Workday, App: a few essentials each, the rest under More options
- **Multi-monitor**, **launch at login**, **esc / ⌥⇧⎋ to skip**

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26 or later to build (the widget extension can't be built with the Command Line Tools alone)

## Installation

### From DMG

1. Build with `./build.sh --release --dmg` (or download a release)
2. Open `build/EyeBreak-3.1.0.dmg` and drag EyeBreak to Applications
3. Launch EyeBreak from Applications

### Build from Source

```bash
./build.sh            # debug build -> Eyebreak.app
open Eyebreak.app

./build.sh --release --dmg
```

> Always use `./build.sh`. It builds `EyeBreak.xcodeproj` with `xcodebuild`, finding Xcode even when `xcode-select` points at the Command Line Tools.

### Adding the widget

macOS lists the widgets once EyeBreak has run from Applications. Right-click the desktop → **Edit Widgets**, search **EyeBreak**, and drag out **Rhythm** or **End of Shift**. Hours always come from EyeBreak Settings → Workday; right-click the End of Shift widget → **Edit Widget** to change its label.

### Coming from Shift Countdown

On first launch EyeBreak copies `~/Library/Application Support/ShiftCountdown/working-hours.json` (hours, days, time zone, today's late start, theme) and shows both countdowns in the menu bar. After that you can quit Shift Countdown, turn off its login item, remove its widget and delete the app; EyeBreak never touches its files.

## Build Options

```
./build.sh [options]

Options:
  --release    Build in release mode (optimized)
  --dmg        Create a DMG file for distribution
  -h, --help   Show help message

Environment:
  EYEBREAK_BUNDLE_ID   Build under another bundle ID (e.g. com.eyebreak.app.dev),
                       so a test build keeps its own settings and history
```

## Tests

```bash
./Tests/run-tests.sh
```

Shift maths (night shifts, daylight saving, time zones, late starts, widget timelines, the region's work week), the shared files' format and migration, theme contrast, rounds, the break routine, the water goal and pace, the daily goal and the work-day streak.

## Usage

1. **Menu bar** - Click the eye for the next break, the shift, the next glass, today's lines, and actions; right-click to pause. The eye fills in the last minute before a break and crosses out while paused
2. **During a break** - Follow the step on screen; **5 More Minutes** to come back to it, `esc` or `⌥⇧⎋` to skip
3. **Water** - Click **I Drank** whenever you drink, from the menu, a break or a reminder
4. **Settings** - Breaks, Water, Workday, App

## Project Structure

```
EyeBreak.xcodeproj           # Two targets: Eyebreak (app) and EyeBreakWidget (extension)
Sources/
├── Eyebreak/                # The menu bar app (see CLAUDE.md for a file map)
├── Shared/                  # Compiled into both: shift maths, shared file, widget themes
└── EyeBreakWidget/          # The End of Shift widget
Config/                      # Info.plists and the widget's sandbox entitlements
Tests/                       # run-tests.sh + main.swift
docs/FEATURES.md             # Feature spec and settings keys
docs/EVIDENCE.md             # The research behind each break and water number
build.sh
```

## License

MIT License
