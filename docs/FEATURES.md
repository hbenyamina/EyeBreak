# EyeBreak 3.1 — Feature Spec

EyeBreak 2.2.0 (the build in `/Applications`) has no surviving source. 3.0 rebuilt its features here; 3.1 merged in
Shift Countdown and then moved the break and water model onto the evidence in [EVIDENCE.md](EVIDENCE.md). This file is
the source of truth for behaviour and settings keys.

All builds use the bundle ID `com.eyebreak.app`, so they share `UserDefaults`; 2.2.0's key names and formats are kept
so settings and break history carry over. Settings that changed meaning are moved once, on the first launch of the
evidence-based model (`rhythmModel` = 1), and only when they still hold the old default.

## 1. Breaks

| Setting | Key | Default |
|---|---|---|
| Work between breaks (min) | `workIntervalMinutes` | 20 |
| Break length (s) | `breakDurationSeconds` | 30 |
| Long break every Nth break (0 = never) | `longBreakEvery` | 3 (about hourly) |
| Long break length (min) | `longBreakMinutes` | 5 |
| Heads-up toast before a break (s, 0 = menu bar only) | `preBreakWarningSeconds` | 0 |
| Wait for a pause in typing | `waitForPause` | on |
| Hold breaks during calls | `holdDuringCalls` | on |
| Auto-start timer on launch | `autoStartTimer` | on |
| Sound effects | `soundEffectsEnabled` | on |

- **Rhythm presets:** **Recommended** (20 min / 30 s, a 5-minute long break every 3rd), **20-20-20** (20 min / 20 s, no
  long break), **Pomodoro** (25 min / 5 min, 15 min every 4th), **Custom**. Moving onto this model, the old default
  (20/20, no long breaks) becomes Recommended, a 5 s heads-up becomes 0, and the 10-minute nudges switch off.
- **Every break is a routine** (`BreakGuide`): look across the room (3 m or more) until the last 10 s, then two
  complete blinks: close 2 s, squeeze 2 s, open 1 s. A long break starts with "Stand up and move: refill your water and
  look out of a window" and ends with the same blinks. A break under 20 s has one blink; under 10 s, none.
- **Breaks wait for you:** due mid-sentence (a key press or drag in the last 3 s), a break waits for a pause, up to
  2 minutes. While a camera or the microphone is in use (`CallDetector`, no permission needed) it holds until the call
  ends. Water and blink reminders hold too.
- **5 More Minutes:** on the warning, the break, the menu and the right-click menu. Twice per break at most; never a
  skip, and the round doesn't move on, so a long break stays long.
- **The heads-up is the menu bar:** the eye fills for the last minute and while a break waits. The toast is optional.
- **Honest counting:** a Window or Notification break you type through for more than half of it is a skip.
- ESC skips a break (counted), as does ⌥⇧⎋ from any app, also before a break starts or while it waits.
- **Skip note:** after `skipsBeforeDryEyeNudge` (2) skips in a row, the next break opens with one plain line ("2
  breaks skipped in a row. Screens cut blinking by about two thirds; this one takes 30 seconds."), at most once a
  day. No picture, no red. (2.2.0's dry-eye picture and 3.0's quotes are gone.)

## 2. Break styles (`breakStyle`)

| Value | Shown as | Behaviour |
|---|---|---|
| `Blur Screen` | Full Screen | Frosted overlay on every display; the countdown ring and the routine on the primary one, esc hint, 5 More Minutes |
| `Floating Window` | Window | A fixed-size glass card at the top centre: ring, routine, 5 More Minutes, Skip (esc) |
| `Notification Only` | Notification | A notification with the routine; Settings warns when notifications are off |
| `Eye Exercise` | — | 2.2.0's follow-the-dot exercise; a stored value reads as Blur Screen |

## 3. Shift (merged from Shift Countdown)

The hours live in `~/Library/Application Support/EyeBreak/shift.json` (`{schedule, themeID}`), written by the app and
read by the widget — not in UserDefaults.

| Setting | Where | Default |
|---|---|---|
| Start / end, to the minute (end ≤ start = night shift) | `schedule.startHour/Minute`, `endHour/Minute` | 9:00 / 17:00 |
| Days (1 = Sunday … 7 = Saturday; the day a night shift *starts*); at least one | `schedule.weekdays` | Mon–Fri |
| Time zone (nil follows this Mac) | `schedule.timeZoneIdentifier` | nil |
| Today's late/early start (one day only) | `schedule.adjustedStart` | nil |
| Widget theme | `themeID` | `slate` |
| Pause everything outside these hours | UserDefaults `smartScheduleEnabled` (2.2.0 key) | off |
| Ask on unlock | UserDefaults `askOnUnlock` | on |
| "No" mutes the question until | UserDefaults `shiftStartPromptMutedUntil` | — |

- Presets: Standard (9 AM – 5 PM), Flexible (8 AM – 6 PM), Early Bird (6 AM – 2 PM), Night Owl (2 PM – 10 PM).
- **Start from now:** the first unlock (or launch) while a shift is due or running asks "Start your shift from now?".
  Yes keeps the shift's length, so the end moves; No mutes until the scheduled start (before it) or the end (after it).
  A notification when macOS allows one, otherwise a glass toast at the top right. Also in the menu ("Start Shift from
  Now" on work days, "Undo Late Start" after) and Settings → Workday.
- **Migration, first launch only** (no `shift.json` yet): copy Shift Countdown's
  `~/Library/Application Support/ShiftCountdown/working-hours.json` and set the menu bar to show both countdowns; else
  build the shift from 2.2.0's `workHoursStart` / `workHoursEnd` / `activeDays`.
- **Days follow the shift:** for a night shift the day starts in the middle of the time off
  (`ShiftSchedule.dayStartMinutes`), so a shift past midnight stays one day in the lines, counts and history.
- **End of Shift widget** (small, medium): time left with a progress bar, "Your shift starts in … at 9:00", or time
  until the next one; thirteen solid themes; system material in tinted/clear modes. Its only own setting is its label.

## 4. Away detection

| Setting | Key | Default |
|---|---|---|
| Pause when away | `idleDetectionEnabled` | on |
| Away after (min) | `idleThresholdMinutes` | 3 |

- Idle or screen lock pauses; on return the work timer restarts (you already rested). Sleep/wake also restarts.

## 5. Water

| Setting | Key | Default |
|---|---|---|
| Remind me to drink | `waterReminderEnabled` | on |
| Ask me (`withBreaks` / `ownTimer`) | `waterReminderMode` | `withBreaks` |
| Interval on its own timer (min) | `waterReminderInterval` | 60, never under `WaterGoal.minimumInterval` |
| Daily goal (ml) | `waterGoalML` | 2000 |
| My glass (ml, at most 500) | `glassSizeML` | 250 |
| Units | `waterUnit` (`milliliters` / `fluidOunces`) | from the region |
| Reminder look | `waterReminderStyle` (`Blur Screen` / `Floating Window`) | `Floating Window` |
| Custom icon/message | `useCustomWaterReminder`, `customWaterReminderIcon`, `customWaterReminderMessage` | off |

- **With the long break** (default): the long break carries "Drink a glass while you're up" with **I Drank**; no
  separate reminder. Falls back to its own timer when long breaks are off.
- **On its own timer:** a toast or full-screen reminder: **I Drank** (return), **In 10 Minutes** (×, not a miss), esc
  for "not now" (recorded). Any drink logged anywhere (menu, right-click menu, a break) restarts the interval.
- **Never faster than the kidneys clear it:** reminders at least `glass ÷ 500 ml × 60` minutes apart (30 min for 250 ml).
- **Goal calculator** (`bodyWeightKg`, `waterSex`, `activeMinutesPerDay`, `exerciseIntensity`, `hotClimate`): a drinks
  goal of 1.6 L (women, 60 kg), 2.0 L (men, 70 kg) or 1.8 L (rather not say, 65 kg), plus 10 ml per kg above that
  weight, 200 / 400 ml per half hour of moderate / vigorous exercise, 500 ml in heat without air conditioning; rounded
  to 50 ml, within 1.2–4 L. Tea and coffee count.

## 6. Blink reminders (2.2.0's ambient reminders)

| Setting | Key | Default |
|---|---|---|
| Enabled | `ambientRemindersEnabled` | off |
| Interval (min) | `ambientReminderIntervalMinutes` | 10 |
| Display duration (s) | `ambientReminderDurationSeconds` | 6 |

- A small, silent glass pill that never takes focus and fades on its own, alternating "Two slow blinks" and "Look
  across the room". Every break already ends with two blinks; these are for dry days.

## 7. Colours

- `appTheme`: **Violet & Aqua** (`classic`) or **Garden** (`garden`). Recolours the window, menu, break screens,
  reminders and the Rhythm widget; choosing Garden moves the End of Shift widget to Greenhouse and back.
- Per surface (break screen, water reminder): `<surface>ThemeType` (`Default` / `Random Color` / `Custom`) and
  `<surface>CustomTheme` (JSON), under App → More options. The blink pill wears the break screen's colours.

## 8. History and goals

- `breakStatistics` (2.2.0 format): `[{date, breaksCompleted, breaksSkipped, totalBreakTime}]`, one entry per day.
- **Daily goal:** `breakGoalFollowsShift` (on): three quarters of the breaks today's shift holds (16 of 21 in 8 hours
  at the Recommended rhythm); off: `dailyBreakGoal`.
- **Streak:** work days in a row with a break; days off don't count, today doesn't break it, one missed work day in
  seven is forgiven.
- **Insights:** plain facts (goal met on N of M days, skips this week, work days in a row). Reset history clears the
  break history and today's lines together.

## 9. Shell

- **Menu bar:** the eye (filled in the last minute before a break, crossed out while paused), and beside it the next
  break, the shift, both or nothing (`menuBarCountdown`). VoiceOver reads the pause state.
- **Popover:** date and shift line with the pause menu; the glass hero (next break, round dots, "Break when you pause
  typing" / "Break after your call"); today's lines; the next glass with I Drank; 5 More Minutes and Skip This Break
  while a break is due; Take a Break Now; Start Shift from Now / Undo Late Start; Settings (⌘,) and Quit (⌘Q).
- **Right-click menu:** pause for 30 min / 1 h / 2 h / until tomorrow / until resumed, or Resume; 5 More Minutes; Take a
  Break Now; I Drank a Glass of Water; Settings (⌘,); Quit (⌘Q).
- **App window** (Dock icon only while open), one page per need, each with at most four essentials and **More options**:
  - **Breaks:** your rhythm (today's line, the week); Rhythm, Break screen, Wait for a pause, Hold during calls. More:
    timing, daily goal, blink reminders, away detection, the last 30 days, what the week says, preview.
  - **Water:** your rhythm; Remind me, Drink each day, My glass, Ask me. "Work out my goal" opens the calculator. More:
    units, the reminder's look, preview.
  - **Workday:** today; Starts, Ends, Days, Pause everything outside these hours. More: presets and time zone, the
    unlock question, the End of Shift widget's colours.
  - **App:** theme; Language, Menu bar shows, Open at login. More: sounds, auto-start, reminder colours, keys, reset
    history, about.
- First launch opens Breaks with a short "How EyeBreak works" callout (`hasLaunchedBefore`).

## 10. Rhythm

- Every break taken or skipped and every glass drunk or declined is logged (with its amount) in
  `~/Library/Application Support/EyeBreak/activity.json`, kept 8 days, with the goals, the glass, today's shift, where a
  day starts, the app theme and the app's language.
- **The line:** one per habit across today's shift (8 AM–8 PM without one). Straight while you keep up; at a miss it
  drops by 0.42 of its height within ~1% of the span and eases back over ~9%. Eyes miss at each skipped break. Water
  misses come from pace, not from esc: the goal spread over the shift, a catch at a glass and a half behind and one per
  glass after, cleared by catching up (`Rhythm.paceMisses`).
- **Week line:** each day's score: breaks taken out of breaks recorded; water drunk against the goal (today, against
  the share due so far).
- In the menu, at the top of Breaks and Water, and in the **Rhythm widget** (small, medium; large adds the week).

## 11. Pause all reminders

- The pause button at the top of the menu, or right-clicking the menu bar item. Breaks, water and blink reminders all
  stop; the menu shows "All reminders paused until …" with Resume. A timed pause ends by itself. Pausing during a break
  ends it without counting a skip.

## 12. Language

- English and Arabic (`Sources/Shared/Localizable.xcstrings`). The Arabic is Modern Standard Arabic, professional and
  gender-neutral where natural, for colleagues from any Arab country.
- App → Language: Same as This Mac / English / العربية, stored as the app's `AppleLanguages` (plus `AppleTextDirection`
  and `NSForceRightToLeftWritingDirection` for Arabic, since macOS mirrors a single app only when asked) and applied
  with a restart. Right to left in Arabic, the rhythm lines and day labels included. Dates, digits (timers too,
  `localizedDigits`) and the calendar follow the Mac's region.
- The default work week follows the region's weekend (`ShiftSchedule.regionWorkweek`): Sunday–Thursday in Saudi Arabia.
- The widgets follow the app's language through `activity.json` (`L10n`), since macOS gives an extension the Mac's.

## 13. Accessibility

- Reduce Transparency: every glass surface turns opaque. Reduce Motion: no step cross-fades or chevron turns.
- Page symbols use the theme's accent in dark mode (`Theme.onPage`), clearing 3:1. Close buttons have 30 pt targets.
- Each break step is announced to VoiceOver, since the blinks are done with eyes closed.
