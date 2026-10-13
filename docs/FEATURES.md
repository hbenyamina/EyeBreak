# EyeBreak 3.0 — Feature Spec

EyeBreak 2.2.0 (the build in `/Applications`) has no surviving source. This spec was rebuilt from
that app's UI text, screen names and saved preferences, and is the checklist for re-implementing it
here with the frosted-glass style (violet for eyes, clear aqua-blue for water, Liquid Glass on macOS 26+, tapered countdown ring).

Both apps use the bundle ID `com.eyebreak.app`, so they share `UserDefaults`. 3.0 reuses 2.2.0's
key names and formats so existing settings and break history carry over.

## 1. Break timer

| Setting | Key | Default |
|---|---|---|
| Work interval (min) | `workIntervalMinutes` | 20 |
| Break duration (s) | `breakDurationSeconds` | 20 |
| Pre-break warning (s, 0 = off) | `preBreakWarningSeconds` | 5 |
| Auto-start timer on launch | `autoStartTimer` | on |
| Sound effects | `soundEffectsEnabled` | on |

- Timing presets: **Default** (20 min / 20 s), **Pomodoro (25/5)** (25 min / 5 min), **Custom**.
- Pre-break warning toast: "Wrap up your work — break starting in N s", with Skip.
- Manual **Take Break Now** from the menu.

## 2. Break styles (`breakStyle`)

| Value | Behaviour |
|---|---|
| `Blur Screen` | Full-screen frosted overlay on every display: countdown ring, quote, skip hint |
| `Floating Window` | Small floating glass card ("Look 20 feet away for 20 seconds"), Close or ESC |
| `Eye Exercise` | Full-screen guided exercise: follow a glowing dot (center, left, right, up, down, 4 diagonals, blink, look around) |
| `Notification Only` | System notification only, no overlay |

- Eye exercise: hold each position `exerciseIntervalSeconds` (default 3); total `eyeExerciseDurationSeconds` (default 30).
- ESC skips a break (plus the global `⌥⇧⎋`). **Preview Break Style** button in Settings.
- **3.0 addition:** the red dry-eye nudge after `skipsBeforeDryEyeNudge` skips in a row (default 2).

## 3. Smart Schedule

| Setting | Key | Default |
|---|---|---|
| Enabled | `smartScheduleEnabled` | off |
| Work hours | `workHoursStart` / `workHoursEnd` (hour 0–23) | 9 / 17 |
| Active days | `activeDays` (JSON `[Int]`, 1 = Sunday … 7 = Saturday) | Mon–Fri |
| Pause on weekends | `pauseOnWeekends` | off |

- Presets: Standard (9 AM – 5 PM), Flexible (8 AM – 6 PM), Early Bird (6 AM – 2 PM), Night Owl (2 PM – 10 PM).
- Outside hours, breaks, water and ambient reminders pause; the menu shows "Paused (Outside work hours)".
- Triggering one by hand outside hours asks: "Outside Work Hours … Take Break Anyway?"

## 4. Away detection

| Setting | Key | Default |
|---|---|---|
| Pause when idle | `idleDetectionEnabled` | on |
| Idle threshold (min) | `idleThresholdMinutes` | 3 |

- Idle → "You seem to be away. Timer paused"; on return the work timer restarts (you already rested).
- Screen lock → "Paused (Screen locked)", same restart on unlock. Sleep/wake also restarts.

## 5. Water reminders

| Setting | Key | Default |
|---|---|---|
| Enabled | `waterReminderEnabled` | on |
| Interval (min) | `waterReminderInterval` | 45 |
| Style | `waterReminderStyle` (`Blur Screen` / `Floating Window`) | `Floating Window` |
| Custom icon/message | `useCustomWaterReminder`, `customWaterReminderIcon`, `customWaterReminderMessage` | off |

- Random title (Time for Water!, Hydration Check, Drink Up! …) and message (8 variants).
- Icon picker: drop, water bottle, drop circle, drop triangle, figure water, cup, mug, leaf, …
- Buttons: **Thanks, I'll drink water now** and, new in 3.0, **I already drank**. Both restart the interval; × snoozes 10 min.
- **Show Water Reminder Now** to test.

## 6. Ambient reminders

| Setting | Key | Default |
|---|---|---|
| Enabled | `ambientRemindersEnabled` | on |
| Interval (min) | `ambientReminderIntervalMinutes` | 10 |
| Display duration (s) | `ambientReminderDurationSeconds` | 6 |
| Custom emoji/message | `useCustomReminder`, `customReminderEmoji`, `customReminderMessage` | off |

- A small glass pill that never takes focus and fades out on its own: "Blink", "Look to the left",
  "Look to the right", "Take a visual break", "Shift your focus", "Change your view", "Rest for a moment" ….
- **Show Reminder Now** to test.

## 7. Themes (Appearance)

Per surface: ambient reminder, break overlay, water reminder.
Keys: `<surface>ThemeType` (`Default` / `Random Color` / `Custom`), `<surface>CustomTheme` (JSON).

- **Default**: violet frosted glass for breaks and ambient reminders, clear aqua-blue for water (translucent, glossy). **Random Color**: a fresh hue every time it appears.
- **Custom**: background colour and opacity, text, secondary text, accent, glass highlight.
  Live preview ("This is how it will look") and Reset to Default.

## 8. Statistics

- Stored in `breakStatistics`: JSON `[{date, breaksCompleted, breaksSkipped, totalBreakTime}]`, one entry per day.
- Today: completed, skipped, total break time, progress toward `dailyBreakGoal` (default 15).
- Week / Month chart, current streak, and insights ("Excellent Progress!", "Room for Improvement", skip rate).
- Reset Statistics.

## 9. Shell

- **Menu bar popover**: one card showing every countdown (break, water, ambient), a pause-reason banner,
  Pause/Resume, Take Break Now, Show Water Reminder, Show Ambient Reminder, Settings…, Launch at Login, Quit.
- **Settings window** (sidebar): General, Breaks, Reminders, Schedule, Appearance, Statistics, About.
- First launch opens Settings with a welcome banner (`hasLaunchedBefore`).
- `launchAtLogin` via `SMAppService`.
