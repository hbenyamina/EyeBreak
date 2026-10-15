---
version: 1
slug: "sources-eyebreak"
primary_target: "Sources/Eyebreak"
related_targets: ["Sources/EyeBreakWidget"]
---

# EyeBreak app surfaces: menu popover, app window, widgets

Scope: the menu bar popover, the app window (settings, statistics; opened occasionally, Dock icon only while open), and the desktop widgets (Rhythm, End of Shift). Break overlays, toasts and pills keep their 3.0 look.

Mode: Operate. Audience: one person, long screen days; lives in the menu bar and desktop widgets, opens the window to adjust settings. Job: know at a glance how the day is going and change a setting without hunting. Constraints: solid colours, violet = eyes, aqua = water, red only dry-eye, SF Pro, SF Symbols, no decorative motion; native controls.

Avoid (user): too busy or colourful; too plain and grey.

## Direction contract

THESIS: EyeBreak as a calm Mac productivity app in the TickTick/Notion lineage: content-first pages, a quiet sidebar, type doing the hierarchy, Liquid Glass only where something floats (sidebar, popover hero). It refuses the stat-tile dashboard and glass-on-everything.

OWN-WORLD: Opaque paper-white content (#FFFFFF / #191919 dark) beside a glass sidebar; Notion-like warm ink and hairlines; flat setting rows, title plus one-line description left, native control right; sections set by a 13pt semibold heading over a hairline, no boxed groups. Violet (eyes) and aqua (water) are the only colours, used for state, selection and the lines.

STORY: The user sees whether today is going well before reading a number, adjusts a timing in seconds, and leaves.

FIRST VIEWPORT: Popover: date and shift line on top; a glass hero with the next-break countdown and round dots; the rhythm lanes (eyes violet, water aqua) across today's shift; then countdown rows and plain actions. Window: glass sidebar with live status, a page with a large title and a description, flat rows.

FORM: User-pinned, no concept-seed roll, because the user named the form themselves: "I want this to be styled like TicTic or Notion, but with a glass theme here and there." Seed key: none (pinned). Signature move: the rhythm line, today drawn as one straight line per habit that catches (dips) at each skipped break or missed glass; in the widget, the popover and Statistics.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
