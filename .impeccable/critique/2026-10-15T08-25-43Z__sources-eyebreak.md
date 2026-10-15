---
target: EyeBreak app surfaces (Sources/Eyebreak)
total_score: 23
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 4
target_identity: "file:/Users/hamzabenyamina/Code/EyeBreak/.claude/worktrees/merge-product-endofshift-2fbcca/Sources/Eyebreak"
timestamp: 2026-10-15T08-25-43Z
slug: sources-eyebreak
---
Method: dual-agent (A: design review · B: detector scan). Impeccable 4.5.2 critique, plus the taste skill's published platform-agnostic rules and designer-skills (focus-attention-design, data-visualization) as lenses. impeccable detect scanned 0 of 52 Swift files (web-only rules); B substituted a grep scan for the CLAUDE.md design rules.

## Design Health Score

| # | Heuristic | Score | Key issue |
|---|---|---|---|
| 1 | Visibility of System Status | 3 | Status item's VoiceOver label never says "paused"; Notification Only breaks count as taken unseen |
| 2 | Match System / Real World | 3 | "Back to Scheduled Hours", "signed ad hoc", "Glass rim", "Next to the eye" |
| 3 | User Control and Freedom | 2 | No "later" for a break; only a counted skip or pausing everything |
| 4 | Consistency and Standards | 2 | Esc / × / Close differ per surface; four countdown formats; red in Insights |
| 5 | Error Prevention | 2 | Notification Only with notifications off; no contrast guard on custom themes; all day chips off |
| 6 | Recognition Rather Than Recall | 2 | Esc and × meaning only in a footer and tooltips |
| 7 | Flexibility and Efficiency | 2 | No Return defaults, no postpone hotkey; ⌥⇧⎋ only during a break |
| 8 | Aesthetic and Minimalist Design | 2 | ~70 controls across 7 pages (owner reports overload); test actions in the popover; empty 30-day chart |
| 9 | Error Recovery | 2 | No undo for an accidental Esc or skip; Reset clears one of two stores |
| 10 | Help and Documentation | 3 | Good subtitles and footers, often four-sentence walls |
| **Total** | | **23/40** | **Acceptable** |

## Design Specificity Verdict
About 60% authored. The rhythm line (icon, popover, Statistics, widget, theme swatches; a miss shown by shape) and the End of Shift widget are ownable. The interruptions (ring over frost, random poster quotes, "Time for Water!", a fear image) are category-generic. Deterministic: detector 0 files; grep scan 0 gradients, 0 rounded fonts, 0 stray system colours; 5 palette bypasses (BlockerView.swift:128,142-150; WaterReminderWindow.swift:169; ShiftSettingsView.swift:210); no Reduce Transparency anywhere; 122 fixed font sizes. No overlay (native app).

## Priority Issues
1. [P1] Settings organised by feature, not need: ~70 controls on 7 pages; Reminders ~22; goals and widget settings split across pages; calculator always open. Cognitive load 5/8 fail. Fix: four need-based pages (Breaks, Water, Workday, App), ≤4 essentials each, "More options" disclosure, Statistics folded into each habit page, retire settings the evidence removes. Command: /impeccable distill, then /impeccable layout.
2. [P1] ~13 prompts an hour and none can wait: 3 breaks, 3 warnings, ~1.3 water, 6 nudges with "Pop"; water toast fires as a break ends (AppDelegate.swift:411). Fix: ≤3 an hour, blink and water inside breaks, warning as a menu-bar cue, "5 more minutes" ×2 not a skip, wait for a typing pause. Command: /impeccable quieter.
3. [P1] Inconsistent exits: × on warning = break still comes; floating "Close (or press ESC)" = counted skip (AppDelegate.swift:343); water × = snooze, Esc = miss only after a click; no Return default. Fix: Return = primary, × / Later = defer without penalty, Esc = skip / not now, key hints shown. Command: /impeccable clarify.
4. [P1] The rhythm line can be untrue: Notification Only counted as taken (TimerManager.swift:233); calendar-day grouping splits night shifts (Activity.swift:70); two stores, Reset clears one (StatsView.swift:31); streak resets every weekend (StatsStore.swift:91). Fix: group by shift, one store, work-day streak, unconfirmed Notification Only. Command: /impeccable harden.
5. [P2] Shame and unsupported claims: "Your eyes will be like this." (BlockerView.swift:99, WarningWindow.swift:153), permanent in a settings row; red in Insights (StatsView.swift:139); health-claim quotes; exclamation copy. Fix: action-first card, instruction instead of quote, neutral copy. Command: /impeccable clarify.

## Persona Red Flags
- Alex: ⌥⇧⎋ ignored until a break shows; 5 s warning not keyboard-dismissable; water toast needs a click before Esc; 118-step break slider; test actions in the daily menu.
- Sam: paused status reads only "EyeBreak"; no Reduce Transparency fallback; exercise orb springs under Reduce Motion (EyeExerciseView.swift:97); Theme.deep #6B36E0 on #191919 = 2.7:1; 22 px close targets.
- Owner at 3 pm: 5 s "Wrap up your work"; skip (counted, leads to red eye) or × (break comes anyway); every 4th Pomodoro break is 15 min on every display; water toast then a Pop nudge right after.

## Minor Observations
"Back to Scheduled Hours" → "Undo Late Start" (MenuBarView.swift:50); two water buttons with one outcome; goal min 500 ml vs calculator 1000 ml; empty 30-day chart; three identical theme previews; "Random Colour" has no job; Rhythm widget dead space; "Shift starts in … to go"; 9–10 pt text in 6 widget spots; 8–9 glass sizes and 13 widget themes exceed four options.

## Questions to Consider
1. If a snooze is never a miss and a pause never a skip, does a straight line track your eyes or your clicks?
2. What would a second skip look like as an invitation rather than a picture of damage?
3. The day has a countdown but no ending. What should 5 PM look like?
4. If you could keep one interruption an hour, which would it be?
