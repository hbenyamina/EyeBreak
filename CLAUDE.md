# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EyeBreak is a macOS menu bar app implementing the 20-20-20 rule for eye strain prevention, plus a shift countdown (menu bar and an "End of Shift" desktop widget). Built with SwiftUI and AppKit, styled as frosted glass (Liquid Glass): violet for eyes, clear aqua-blue for water, red only for the dry-eye warning.

Version 3.0 re-implemented the feature set of EyeBreak 2.2.0, whose source no longer exists. Version 3.1 merged in Shift Countdown (formerly `~/Code/ShiftCountdown`, bundle `app.shiftcountdown`): its shift maths, widget, unlock prompt and themes now live here, and its Pomodoro became long breaks on the break timer. Version 3.2 brought back a Pomodoro timer of its own, started from the menu, which takes over the break timer while it runs. It then moved the break and water model onto published evidence: a 30-second look-away-and-blink every 20 minutes, a 5-minute break on your feet about every hour with water inside it, breaks that wait for a pause and hold during calls, and a drinks-only water goal. `docs/FEATURES.md` is the feature spec and the source of truth for behaviour and settings keys; `docs/EVIDENCE.md` is why each number is what it is. The app speaks English and Arabic, and is headed for colleagues at the owner's workplace.

## Build Commands

```bash
# Build the app bundle (with its widget extension) -> Eyebreak.app
./build.sh

# Run the app
open Eyebreak.app

# Build release with DMG
./build.sh --release --dmg

# Test build with its own settings domain, so it can't touch the installed app's prefs or stats
EYEBREAK_BUNDLE_ID=com.eyebreak.app.dev ./build.sh

# Tests (shift maths, shared file, theme contrast, rounds, break routine, water pace and goal, streak)
./Tests/run-tests.sh
```

**Important:** Always use `./build.sh`. It runs `xcodebuild` on `EyeBreak.xcodeproj` (there is no Package.swift any more: SwiftPM can't build the widget extension) and finds Xcode itself when `xcode-select` points at the Command Line Tools. Deployment target is macOS 26.

The project uses file-system-synchronized folders: a new `.swift` file in `Sources/Eyebreak` joins the app, in `Sources/EyeBreakWidget` the widget, and in `Sources/Shared` both. No project edits needed.

**Testing safely:** `CFFIXED_USER_HOME` does not isolate UserDefaults (cfprefsd ignores it). Use `EYEBREAK_BUNDLE_ID` instead. Debug builds take launch arguments for checking UI without clicking: `-openSettingsPane Breaks|Water|Workday|App`, `-expandMoreOptions YES`, `-settingsHeight 2600`, `-openMenu YES`, `-previewShiftPrompt YES`, `-previewBreak YES` (with `-previewLong YES`, `-previewElapsed 22`), `-previewWater YES`, `-startPomodoro YES` (with e.g. `-pomodoroFocusMinutes 2 -pomodoroBreakMinutes 1`), and `-AppleLanguages '(ar)'` for Arabic; any setting can be overridden the same way (`-breakStyle "Floating Window"`). The files in `~/Library/Application Support/EyeBreak/` are shared by every bundle ID: a debug build launched with `open -n --env EYEBREAK_SUPPORT_DIR=/some/folder Eyebreak.app --args …` keeps its `shift.json` and `activity.json` there instead (copy the real `shift.json` in first, or it runs the Shift Countdown migration into it). To check states without opening anything (a full-screen app hides the menu bar), `-snapshotDir /folder -snapshotEvery 15` draws the menu and the break card offscreen into PNGs and logs the menu bar item to `status.txt` (glass surfaces come out blank there); `-snapshotSettings Breaks` adds a page each time, `-silentBreaks YES` keeps breaks off the screen.

## Architecture

### Core

- **EyebreakApp.swift** - SwiftUI app entry point, minimal delegation to AppDelegate
- **AppDelegate.swift** - Coordinator: status item (the eye fills before a break) and popover, break presentation per style with the long break's water prompt, reminder visibility, presence and calls → timer, hotkeys, "Off Shift" prompts
- **AppSettings.swift** - UserDefaults-backed settings plus option enums (break style, rhythm presets, water mode). Key names and raw values match 2.2.0; `moveToRhythmModel` moves old defaults onto the evidence-based model once
- **TimerManager.swift** - Work → (Warning) → Break heartbeat; a running Pomodoro takes it over (`startPomodoro`/`stopPomodoro`, `isFocusing`, `isPomodoroBreak`, `breakIsOnYourFeet`); waits for a pause in typing and holds during calls (`isWaitingForPause`); "5 More Minutes" (`postpone`); honest counting for Window/Notification breaks; the skip note; `PauseReason`; timed "pause all reminders" (`PauseDuration`); long breaks; records stats
- **Habits.swift** - The rules, Foundation only and compiled by the tests: `BreakGuide`/`BreakStep` (look away, then close–squeeze–open blinks), `BreakGoal` (from the shift), `Streak` (work days, one miss a week forgiven)
- **ActivityModel.swift** - Today's events for the rhythm lines and the day's break goal; writes `activity.json` for the widgets with the goals, the glass, today's shift, where a day starts, the app theme and the app's language
- **BreakRound.swift** - Round position (every Nth break is long). Foundation only, compiled by the tests
- **Pomodoro.swift** - The Pomodoro's own count and round: a block counts when its time runs out, an early break doesn't, a break held back by 5 More Minutes isn't counted twice. Foundation only, compiled by the tests
- **ShiftModel.swift** - The shift: hours from the shared file, 1 s clock for countdowns, late start, presets, first-launch migration (Shift Countdown's file, else 2.2.0's `workHoursStart`/`workHoursEnd`/`activeDays`); `TimeZoneCatalog`
- **UnlockPrompt.swift** - "Start your shift from now?" on unlock/launch while a shift is due: notification if allowed, else a glass toast; owns the `UNUserNotificationCenter` delegate
- **StatsStore.swift** - Per-day history in `breakStatistics` (2.2.0 format plus `pomodorosCompleted`/`focusTime`, read as zero where missing; days by shift), work-day streak, plain-fact insights
- **PresenceMonitor.swift** - Idle input, screen lock, calls (`CallDetector`: is a camera or the mic running, no permission needed), and (Smart Schedule on) whether you're on shift; `InputActivity` for typing
- **WaterReminderManager.swift** / **AmbientReminderManager.swift** - Water's own timer (off while it rides with the long break; any logged drink restarts it) and the optional blink reminders; both pause whenever the break timer does
- **FeedbackManager.swift** - Sound effects and user notifications (Notification Only style)

### Windows

- **BlockerWindow.swift** - `OverlayWindowController`: frosted overlay on every display (content on primary); key-capable so ESC works
- **BlockerView.swift** - Full Screen break: countdown ring, the routine (`BreakGuideCard`, shared with the window), the long break's water row, 5 More Minutes, esc hint; `BreakBackdrop`
- **FloatingBreakWindow.swift** - Window break style: a fixed-size card with the same routine
- **WarningWindow.swift** - Optional heads-up toast (5 More Minutes, Skip); also `ToastWindow` (top-right/top-centre, fades, optional key focus)
- **WaterReminderWindow.swift** - Water reminder as floating toast or full-screen frost: I Drank (return), In 10 Minutes (×), esc not now
- **AmbientReminderWindow.swift** - Silent, self-dismissing blink pill
- **MenuBarView.swift** - Popover: date and shift line with the pause menu, glass hero (next break, round dots, waiting states), today's rhythm lanes, the next glass, actions. Right-clicking the status item opens a quick menu (AppDelegate)
- **RhythmLanes.swift** - Today's two lines in the menu; `HabitRhythm` (today and the week for one habit) at the top of Breaks and Water
- **Settings/** - The app window (Dock icon only while open): glass sidebar with live status and five pages, one per need — Breaks, Water (with "Work out my goal"), Pomodoro (today, the week as bars, its lengths; `PomodoroSettingsView.swift`), Workday (with the End of Shift widget's colours), App (theme, language, menu bar, login; colours, keys, data, about). Each shows at most four essentials, the rest under `MoreOptions`. `SettingsComponents.swift` is the page grammar

### Shared (app + widget)

- **ShiftSchedule.swift** - Shift maths: phases (on shift / before / off), night shifts, weekday sets, time zones, one-off adjusted start, widget timeline dates
- **ShiftStore.swift** - `ShiftSettings` (schedule + widget theme) as JSON at `~/Library/Application Support/EyeBreak/shift.json`; also reads Shift Countdown's old file for migration
- **ShiftText.swift** - Countdown strings and state symbols
- **ShiftTheme.swift** / **Contrast.swift** - The End of Shift widget's thirteen solid themes (incl. Greenhouse); secondary inks derived to clear WCAG floors (guarded by the tests)
- **Theme.swift** - `AppTheme` (Violet & Aqua, Garden) and `ThemeColors`; `Theme.*` reads the current one. Never hard-code a colour: add it to `ThemeColors`
- **Activity.swift** - `ActivityLog` / `ActivityStore` (`activity.json`, tolerant of missing keys; days by shift via `dayStartMinutes`) and `Rhythm`: the line maths (each miss catches, then eases back), water pace misses, windows, scores
- **L10n.swift** - `String(shared:)`: shared code's strings, from the app's language even inside the widget; RTL and locale for the widgets
- **Localizable.xcstrings** - Every string, English and Arabic (both targets). New strings: build, then `xcrun xcstringstool sync` with the build's `.stringsdata`, and translate
- **RhythmLine.swift** - `RhythmLine`, `WeekLine`, `WeekLabels`, and how each `Habit` is named and coloured
- **Water.swift** - `WaterUnit`, amount formatting, `WaterSex`, `ExerciseIntensity`, `WaterGoal` (drinks goal from sex, weight, exercise and heat; reminder pace never above 500 ml an hour)

### Widget (`EyeBreakWidget` target, sandboxed)

- **EndOfShiftWidget.swift** - Timeline provider and widget (kind `EndOfShiftWidget`; never rename it, that orphans placed widgets)
- **ShiftWidgetViews.swift** - Small and medium layouts; system material in tinted/clear modes
- **EndOfShiftConfiguration.swift** - The only per-widget setting: its label
- **RhythmWidget.swift** - "Rhythm" (kind `RhythmWidget`): today's eyes and water lines, small/medium/large (large adds the week); wears the app theme from `activity.json`
- Reads the shared file through a read-only sandbox exception (`Config/EyeBreakWidget.entitlements`), not an app group: ad-hoc signing has no team ID to prefix a group with

### Visual Style

- **GlassTheme.swift** - `FrostedBackdrop` (behind-window blur), `glassSurface`, `AccentButtonStyle` / `SoftButtonStyle` (stay coloured in non-key windows, unlike system prominent/glass buttons). The colours themselves live in `Sources/Shared/Theme.swift`
- **ReminderTheme.swift** - Per-surface themes (Default / Random Color / Custom) resolved to a `Palette` and passed via `\.palette`; Default follows the app theme
- **CountdownRing.swift** - Tapered glowing countdown ring; widens toward its head at 12 o'clock

### Utilities

- **ConfigManager.swift** - First-launch defaults from bundled `config.json`
- **HotkeyManager.swift** - ⌥⇧⎋ global skip; plain ESC for focused break/water windows
- **LoginItemManager.swift** - SMAppService for launch-at-login
- **Tools/make-app-icon.swift** - Draws `Resources/AppIcon.png` (the rhythm mark: two solid lines on linen, the eye line catching once). Not compiled into the app; run it with `xcrun swiftc`, then `./build.sh` rebuilds the .icns

## Design Rules

- **Every health number has a source.** Break lengths, the blink routine, water maths, pace limits and the copy's claims come from `docs/EVIDENCE.md`; change one there first. No fear pictures, no claims stronger than the evidence, no quotes.
- **Interrupt little, and never mid-thought.** About three prompts an hour by default; water and blinks ride inside breaks; breaks wait for a pause and hold during calls; "later" is never a skip. One key grammar everywhere: return = the main action, × or a "later" button = defer without penalty, esc = skip / not now.
- **Solid colours only.** No gradients anywhere (icons, buttons, selections, charts, backdrops). One soft solid glow exists, on the thing that moves: the tapered countdown ring. Nothing else glows.
- **Colour means something, per theme.** The theme's eye colour (violet, or leaf green in Garden) = eyes/breaks and app chrome (`Theme.onPage` for symbols on paper, so dark mode clears 3:1); its water colour (aqua, or rain blue) = water; `Theme.alert` is reserved and unused; the End of Shift widget theme's `heroAccent` = the shift. Accent marks actions, selection and state; resting icons are secondary ink. Every colour comes from `ThemeColors`, except text on glass (the popover), which uses the system `.primary` / `.secondary` so it keeps its vibrancy.
- **TickTick/Notion manner, glass as an accent.** Content on opaque paper (`Theme.Page`): a page is a symbol, a large title and one line saying what it's for, then sections set by a heading over a hairline, then flat rows (title and description left, native control right) from `SettingsComponents.swift`. One page per need, at most four essentials, the rest under `MoreOptions`. No boxed grouped forms, stat tiles or card grids. Liquid Glass only where something floats: the sidebar, the popover hero, toasts and break overlays; opaque under Reduce Transparency.
- **Every string is translatable.** SwiftUI literals and `LocalizedStringKey` component titles are looked up automatically; anything built in code uses `String(localized:)` (app) or `String(shared:)` (Shared); already-localized text goes into components as `.verbatim(_:)`. Arabic is Modern Standard Arabic for colleagues across the Arab world: professional, warm but restrained, gender-neutral where natural (verbal nouns, first-person buttons); layouts and the lines run right to left, and timers use the locale's digits (`localizedDigits`).
- **The rhythm line is the signature.** Straight while you keep up, catching at each miss (`Rhythm`; for water, a glass behind pace); the same `RhythmLine` in the menu, Settings and the widget. Don't add other charts where a line says it; the one exception is the "Last 30 days" bars under Breaks → More options, because a line can't carry a month of counts.
- **DESIGN.md holds the tokens** (colours for both themes, type sizes, spacing, the rhythm constants), with `.impeccable/design.json` beside it. Update both when the system changes.
- **Sentence case** for page sections and rows; Title Case only for buttons and menu items.
- **SF Pro, not SF Rounded.** SF Symbols, not emoji (custom ambient reminders may use the user's own emoji).
- **No decorative motion.** Motion only where it conveys state (the ring's tick, a step changing, a section opening), and none under Reduce Motion.

## Key Patterns

1. **Timer States**: Work → (Warning) → due: waits for a pause or a call's end → Break → Work, plus pause reasons (managed in TimerManager). With long breaks on, the break closing each round is long; "5 More Minutes" returns to Work without moving the round. A Pomodoro swaps in its own lengths and round while `isFocusing`; the usual round is left as it was
2. **Multi-Monitor**: OverlayWindowController creates one window per NSScreen
3. **Sleep / Away**: Timer resets on wake, and when you come back from idle or screen lock
4. **Menu Bar**: NSStatusItem + NSPopover hosting MenuBarView
5. **@Published fires on willSet**: Combine sinks that read model state hop to `DispatchQueue.main` first
6. **One shift, one file**: the app writes `shift.json` and calls `WidgetCenter.reloadAllTimelines()` on every edit; the widget only reads it. Hours never live in UserDefaults
7. **Pausing is one switch**: water and blink reminders pause whenever the break timer does (user pause, idle, lock, off shift), so "pause all reminders" is `TimerManager.pause(until:)`
9. **The widget speaks the app's language**: macOS runs an extension in the Mac's language, so the app writes its own into `activity.json` and the widgets call `L10n.follow(language:)`
8. **Themes are read, not stored**: `Theme.current` is set by `AppSettings.appTheme` in the app and from `activity.json` in the widget; `Palette.eyes`/`.water` are computed so a switch applies everywhere

## Configuration

Settings are edited in the Settings window and stored in UserDefaults (`com.eyebreak.app`, shared with 2.2.0), except what the widgets read: the shift hours and End of Shift theme in `~/Library/Application Support/EyeBreak/shift.json`, and the day's events, goals and app theme in `activity.json` beside it (written by the app, never by the widget). `Sources/Eyebreak/Resources/config.json` only seeds first-launch defaults.
