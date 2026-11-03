# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

Native macOS (SwiftUI + AppKit), deployment target macOS 26. Not one of the web/iOS/Android values: a menu bar app with a WidgetKit extension.

## Users

The owner, on their own Mac, through long screen days at work (a Sunday–Thursday week plus some Saturdays, 9-to-5 shifts that sometimes start late), and, from 2026-10-15, their colleagues: the owner plans to distribute it at work. Colleagues read English or Arabic and come from across the Arab world, so the Arabic is Modern Standard Arabic, professional and workplace-appropriate, addressing men and women alike. New users need a first run that points them to their working hours; the default work week follows the Mac's region (Sunday–Thursday in Saudi Arabia).

## Product Purpose

Keep the eyes, hydration and working day in check without demanding attention: a short break every 20 minutes to look across the room and blink, a few minutes on your feet every hour with a glass of water, and a countdown to the end of the shift. Every number comes from published evidence (`docs/EVIDENCE.md`). Success is the user taking their breaks, drinking water, and knowing at a glance how much of the day is left, while hardly ever opening a window.

## Positioning

One quiet companion for the working day instead of three apps: the eye-break timer, the water/ambient nudges and the shift countdown share one schedule, so breaks pause when the shift is over and a late start moves everything with it.

## Operating Context

- **Lives in the menu bar and on the desktop.** The menu bar item and its popover are used all day; desktop widgets stay visible next to the user's other desktop widgets.
- **The app window is occasional:** opened to adjust settings, rarely for anything else. The user found seven pages of settings "a bit overwhelming" (2026-10-15) and asked for them organised so "people who would like to answer a specific need would go directly to the right place", so there are pages, one per need (Breaks, Water, Pomodoro, Workday, App; Pomodoro since 2026-11-03, when the user asked for "a tab or something … to see how many pomodoros I've done"), each with at most four essentials and the rest under More options. It opens from the menu; the Dock icon appears only while it's open.
- Break overlays, toasts and reminder pills appear over whatever the user is doing, on every display.

## Capabilities and Constraints

- Break timer (Recommended: 30 s every 20 min and 5 min every hour; 20-20-20; custom), a Pomodoro timer started from the menu that takes over the breaks while it runs (asked for 2026-11-03), three break styles, a guided look-away-and-blink routine in every break, breaks that wait for a pause in typing and hold during calls, "5 More Minutes" that never counts as a skip, optional blink reminders, away detection, history with a goal from the shift and a work-day streak. The user asked (2026-10-15) for "a more scientific approach"; the literature review behind each choice is `docs/EVIDENCE.md`.
- Shift: hours to the minute, days, night shifts, time zones, late start from unlock, Smart Schedule pause off shift.
- Widgets: the user first asked for "widgets for all the functionalities", then, offered a widget per feature, narrowed it in their own words: "I need widgets to give me how well I am doing with eye breaks and water. So it's a line with when I hit it well, so it's just a straight line, but then the line gets caught when I don't drink or something." So the widgets are **Rhythm** (eyes and water, today and this week) and **End of Shift**; no per-feature countdown widgets.
- Water intake is configurable ("not everybody drinks the same amount of water"): a goal in ml or fl oz, the user's own glass size, and a drinks-only calculator from sex, weight, exercise and heat. Water rides inside the hourly break by default; reminders never ask for more than 500 ml an hour.
- The menu bar shows only what the user switches on (2026-11-03: "can I choose what to show on the menu bar? By default … only keep the time shift and the Pomodoro if it's active"): next break, end of shift, a running Pomodoro.
- "Pause all reminders" from the menu bar. Escape always cancels, never snoozes: on water it records "not now", and the water line dips only once the user is a glass behind pace.
- Languages: English and Arabic. The owner first asked for a Saudi dialect that "speaks to him", then, once colleagues were in view, for professional language that "can be said in a work environment" and "standard Arabic because the users are not all Saudis". So: Modern Standard Arabic, warm but restrained, gender-neutral where natural (verbal nouns, first-person buttons). Right to left throughout; widgets follow the app's language.
- App themes: Violet & Aqua and Garden ("inspired from gardens … and health").
- Bundle ID `com.eyebreak.app` and 2.2.0's UserDefaults keys must stay (history depends on them). Shift settings live in `~/Library/Application Support/EyeBreak/shift.json`, shared with the widget extension.
- Ad-hoc signed today: no app groups, notifications may be refused; the widget reads shared state through a sandbox exception. Distributing to colleagues needs a Developer ID signature and notarization, or Gatekeeper blocks the app on their Macs.

## Brand Commitments

- Name: EyeBreak. App icon: the rhythm mark, two lines on linen with the eye line catching once (chosen by the user over three others to replace the "very AI generated" gold eye); drawn by `Tools/make-app-icon.swift`. The icon keeps the Garden colours (leaf green, rain blue) in every app theme, the one place the per-theme colour rule doesn't apply.
- Binding visual constraints from the user: solid colours only, never gradients; violet means eyes/breaks, clear aqua-blue means water, red only for the dry-eye warning; SF Pro (not Rounded); SF Symbols, not emoji; no decorative motion.
- Requested direction (2026-10-15): "styled like TickTick or Notion, but with a glass theme here and there", beautifully designed.

## Evidence on Hand

- `docs/FEATURES.md`: the feature spec and settings keys.
- Real usage data lives in UserDefaults `breakStatistics` on the user's Mac; nothing else to show, and no testimonials or claims exist or are needed.

## Product Principles

1. **Glance, don't visit.** Everything worth knowing during the day is readable from the menu bar, the popover or a widget without opening a window.
2. **Interrupt little, and never mid-thought.** About three prompts an hour; water and blinks ride inside breaks; breaks wait for a pause and hold during calls. Breaks may take the screen; everything else nudges and gets out of the way.
3. **One day, one schedule.** The shift is the backbone; breaks, reminders and widgets follow it.
4. **Settings should feel calm, not technical.** Occasional visits; every option findable and plainly worded.
