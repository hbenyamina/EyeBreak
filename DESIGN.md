---
name: EyeBreak
description: A quiet companion for the working day; paper pages, two habit lines, glass only where something floats.
colors:
  eyes-light: "#E6D9FF"
  eyes-bright: "#BA99FF"
  eyes-accent: "#8C5CF7"
  eyes-deep: "#6B36E0"
  eyes-dark: "#2E1470"
  water-light: "#E8FCFF"
  water-bright: "#5FE0FF"
  water-accent: "#14B8FF"
  water-deep: "#0490F5"
  water-dark: "#0A62D6"
  water-ink: "#06355E"
  alert: "#EB1F4D"
  paper: "#FFFFFF"
  paper-dark: "#191919"
  ink: "#2F2E2B"
  ink-dark: "#E6E5E3"
  secondary-ink: "#73726E"
  secondary-ink-dark: "#9B9A97"
  hairline: "#EBEAE8"
  hairline-dark: "#2D2D2C"
  wash: "#F2F1EE"
  wash-dark: "#262625"
  eyes-backdrop: "rgba(8, 3, 20, 0.45)"
  water-backdrop: "rgba(0, 18, 38, 0.30)"
  garden-eyes-light: "#E2F0DC"
  garden-eyes-bright: "#9DD196"
  garden-eyes-accent: "#3E9A57"
  garden-eyes-deep: "#2C7A43"
  garden-eyes-dark: "#163D22"
  garden-water-light: "#E3F3FA"
  garden-water-bright: "#86D3EF"
  garden-water-accent: "#2F9FD3"
  garden-water-deep: "#1C7DB4"
  garden-water-dark: "#0F4B6E"
  garden-water-ink: "#0B3550"
  garden-alert: "#D9452C"
  garden-paper: "#FAF9F4"
  garden-paper-dark: "#151A15"
  garden-ink: "#24301F"
  garden-ink-dark: "#E3E8DE"
  garden-secondary-ink: "#66705F"
  garden-secondary-ink-dark: "#9BA595"
  garden-hairline: "#E6E4D8"
  garden-hairline-dark: "#263025"
  garden-wash: "#F0EEE3"
  garden-wash-dark: "#1F261E"
  garden-eyes-backdrop: "rgba(5, 18, 8, 0.45)"
  garden-water-backdrop: "rgba(0, 20, 28, 0.30)"
typography:
  display-widget:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "44px"
    fontWeight: 700
    lineHeight: 1
    fontFeature: "tnum"
  headline:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "26px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.3px"
  title-hero:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "26px"
    fontWeight: 600
    lineHeight: 1.1
    fontFeature: "tnum"
  title-popover:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.25
  title-section:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.3
  body-small:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.35
  value:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.3
    fontFeature: "tnum"
  button:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.2
  label:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.3
  label-strong:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: 1.3
rounded:
  menu-row: "6px"
  selection: "7px"
  inline: "8px"
  callout: "10px"
  swatch: "12px"
  hero: "16px"
  toast: "22px"
  overlay: "28px"
  capsule: "9999px"
spacing:
  xxs: "2px"
  xs: "4px"
  sm: "6px"
  row-y: "9px"
  md: "12px"
  popover: "14px"
  row-gap: "20px"
  section: "30px"
  page-top: "34px"
  page-x: "44px"
  page-bottom: "56px"
components:
  page:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    padding: "34px 44px 56px"
    width: "640px"
  page-title:
    textColor: "{colors.ink}"
    typography: "{typography.headline}"
  section-heading:
    textColor: "{colors.ink}"
    typography: "{typography.title-section}"
    padding: "0 0 7px"
  setting-row:
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    padding: "9px 0"
    height: "40px"
  setting-row-detail:
    textColor: "{colors.secondary-ink}"
    typography: "{typography.body-small}"
  sidebar-row:
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.selection}"
    padding: "6px 8px"
  callout:
    backgroundColor: "{colors.wash}"
    textColor: "{colors.ink}"
    rounded: "{rounded.callout}"
    padding: "14px"
  button-accent:
    backgroundColor: "{colors.eyes-deep}"
    textColor: "{colors.paper}"
    typography: "{typography.button}"
    rounded: "{rounded.capsule}"
    padding: "4px 11px"
  button-accent-large:
    backgroundColor: "{colors.eyes-deep}"
    textColor: "{colors.paper}"
    rounded: "{rounded.capsule}"
    padding: "8px 18px"
  button-accent-water:
    backgroundColor: "{colors.water-bright}"
    textColor: "{colors.water-ink}"
    typography: "{typography.button}"
    rounded: "{rounded.capsule}"
    padding: "4px 11px"
  menu-row-hover:
    backgroundColor: "{colors.eyes-deep}"
    textColor: "{colors.paper}"
    typography: "{typography.body}"
    rounded: "{rounded.menu-row}"
    padding: "5px 8px"
  popover:
    width: "300px"
    padding: "14px"
  popover-hero:
    rounded: "{rounded.hero}"
    padding: "12px"
    typography: "{typography.title-hero}"
---

# Design System: EyeBreak

## Overview

**Creative North Star: "The Quiet Notebook"**

EyeBreak is a calm Mac productivity app in the TickTick/Notion lineage. Content sits on opaque paper: a page is an SF Symbol, a large bold title and one line of description, then sections set by a semibold heading over a hairline, then flat rows with a title and one line of detail on the left and a native control on the right. Type and spacing do the grouping. There are no boxed grouped forms, stat tiles or card grids. The window has four pages, one per need (Breaks, Water, Workday, App); each shows at most four essentials and folds the rest under "More options".

Liquid Glass is the accent, not the ground. It appears only where something floats over the user's work or desktop: the window's sidebar, the popover's hero card holding the next-break countdown, toasts, and break overlays. Everything else is solid. Colour belongs to the habits. The theme's eye colour (violet, or leaf green in Garden) marks breaks and the app's own chrome. Its water colour (aqua, or rain blue) marks water. One red (`Theme.alert`) is held in reserve for a warning; nothing draws in it today. Neutrals are warm ink on paper with hairlines.

The signature is the rhythm line. Each habit draws one line across today's shift. It stays straight while the user keeps up and catches, dipping and easing back, at each skipped break or missed glass. The same view draws it in the popover, at the top of the Breaks and Water pages and in the Rhythm widget, and the app icon is that line drawn large.

EyeBreak speaks English and Arabic (Modern Standard Arabic). In Arabic the whole interface mirrors right to left, the rhythm lines and day labels included, and times are set in the locale's digits. The voice is calm and factual in both languages.

**Key Characteristics:**
- Opaque paper pages, warm ink, 1px hairlines; flat rows, never boxed groups.
- Glass only where something floats: the sidebar, the popover hero, toasts, break overlays.
- Two habit colours per theme, plus one red held in reserve; accents mark action, selection and state, never decoration.
- Solid colours only. No gradients anywhere.
- SF Pro (never Rounded), SF Symbols, monospaced digits for every live number.
- The rhythm line as the one chart idiom: straight while on track, catching at each miss.
- English and Arabic, mirrored right to left down to the lines; no hard-coded strings.

## Colors

Two themes share one set of colour jobs. Violet & Aqua (the default) is listed first in the tokens; Garden carries the same jobs with a `garden-` prefix. Neutrals have light and dark (`-dark`) values that follow the system appearance.

### Primary
- **Eye Violet** (eyes-accent; Garden: **Leaf Green**, garden-eyes-accent): the eye habit. Rhythm lines, the countdown ring, round dots, pause-line icons, the break guide's step symbol, and the tint for glass that belongs to breaks (8–10% over glass). In dark mode it is also the page tint (see Deep Violet).
- **Deep Violet** (eyes-deep; Garden: **Herb Green**, garden-eyes-deep): solid fills that carry white text (accent buttons, hovered menu rows; white reads at 6.5:1 and 5.2:1). In light mode it is also the page tint (`Theme.onPage`) for every Settings page except Water: the page symbol, the selected sidebar icon, the selection wash at 12%, the callout symbol and native control tint. In dark mode `Theme.onPage` switches to Eye Violet, because Deep Violet falls under 3:1 on the dark page.
- **Lavender Mist / New Leaf** (eyes-light), **Bright Violet / Bright Leaf** (eyes-bright), **Night Violet / Ivy** (eyes-dark): the rest of the eye ramp, used by break overlays, reminder themes and the custom reminder-theme starting values.

### Secondary
- **Aqua** (water-bright; Garden: **Rain**, garden-water-bright): solid fill for water actions ("I drank"), always with **Water Ink** (water-ink) text, never white.
- **Clear Blue** (water-deep; Garden: **Watering-can Blue**, garden-water-deep): the water rhythm line and the Water page tint.
- **Vivid Sky** (water-accent): water icons in the popover's countdown rows, and water glass tint at 14%.
- **Water Mist** (water-light) and **Deep Water** (water-dark): the rest of the water ramp, for water reminder surfaces.

### Tertiary
- **Alert Red** (alert; Garden: **Geranium**, garden-alert): reserved for a warning. The dry-eye card that used it is gone, and the skipped-breaks note on a break is one neutral line in secondary text, so nothing draws in red today. Nothing else may be red.

### Neutral
- **Paper** (paper / paper-dark; Garden: **Linen / Night Garden**): the opaque ground of every Settings page, the Rhythm widget's background, and the fill behind open week-line rings.
- **Ink** (ink / ink-dark): page titles, section headings, row titles, values.
- **Secondary Ink** (secondary-ink / secondary-ink-dark; Garden: **Sage**): descriptions, row detail, footers, slider read-outs, resting sidebar icons. It holds 4.7:1 or better on paper in every theme and appearance.
- **Hairline** (hairline / hairline-dark): the 1px rule under every section heading, the unfinished part of a rhythm line, and week-line tracks.
- **Wash** (wash / wash-dark): the callout block, and the only tinted panel on a page.
- **Backdrops** (eyes-backdrop, water-backdrop): laid over the full-screen frost behind a break or a full-screen water reminder.

### End of Shift widget themes

The End of Shift widget has its own family of 13 solid themes (`ShiftTheme`). They split into six **Tones** (Slate, the default; Clay, Sage, Ochre, Plum, Graphite) and seven **Workplaces** (Ward, Warehouse, Night Desk, Workshop, Line, Control, Greenhouse). Each theme has three surfaces, one per shift state (working / ahead / off), a headline ink, a signal `tint` that has to carry white text, and a `heroAccent` (light and dark) for the shift countdown inside the app. All surfaces sit at OKLCH chroma 0.004–0.056. A state is told apart by lightness, never by moving round the hue wheel. Ward and Warehouse use the pale register with dark ink; the rest use deep surfaces with near-white ink at 8–13:1. Greenhouse is the one to pair with the Garden app theme. The full values live in `.impeccable/design.json` under `extensions.widgetThemes`.

Secondary text levels are derived from each surface, not picked by hand. `inkSoft` is the most muted mix of ink toward the surface that still clears 6.0:1 (7.6:1 for light-on-dark). `inkFaint` clears 4.7:1 (6.5:1 for light-on-dark). The light-on-dark floors are raised because macOS rasterises light text at about 0.72 of its nominal contrast. The progress track is ink at 28%.

### Named Rules
**The Colour Has a Job Rule.** Eye colour means eyes, breaks and app chrome. Water colour means water. Alert red is reserved for a warning and unused today. A widget theme's heroAccent means the shift. Resting icons are secondary ink. If a colour can't name its job, it doesn't ship.

**The Solid Only Rule.** Every fill is one flat colour: icons, buttons, selections, charts, backdrops. Gradients are prohibited, with no exceptions.

**The Garden Icon Rule.** The app icon is drawn in Garden's linen (garden-paper), herb green (garden-eyes-deep) and watering-can blue (garden-water-deep) whichever theme is active. It is the one place the per-theme colour rule doesn't apply.

## Typography

**Display Font:** SF Pro (system), never SF Rounded
**Body Font:** SF Pro (system)
**Label/Mono Font:** SF Pro with monospaced digits for every live number (countdowns, values, read-outs)

**Character:** A single native family. Hierarchy comes from size and weight steps (bold, semibold, medium, regular) and from ink versus secondary ink, never from a second typeface or letter-spaced capitals.

### Hierarchy
- **Display** (700, 32px small / 44px medium, tabular digits): the End of Shift widget's countdown. The break overlay's countdown is light weight, sized to its 300px ring (0.25 of the diameter; 0.19 for long breaks), on a glass disc.
- **Headline** (700, 26px, -0.3px tracking): the Settings page title, under a 26px regular page symbol.
- **Title, hero** (600, 26px, tabular digits): the popover's next-break time. It drops to 16px for "Not running".
- **Title, popover** (600, 15px): the popover's date line.
- **Break guide** (500, 30px step title over a 16px secondary line, 24px step symbol; in the window card 600 15px over 12px, 15px symbol): the one thing to do now on every break.
- **Title, section** (600, 13px): section headings, the sidebar's selected row, callout titles, the sidebar's "EyeBreak". The Rhythm widget uses the same size for its titles.
- **Body** (400, 13px): row titles, page descriptions, sidebar rows, menu rows, read-only values. The "More options" disclosure is 13px medium in secondary ink.
- **Body small** (400, 12px): row detail, section footers, slider and stepper read-outs (tabular), the popover's shift line.
- **Value** (500, 12–13px, tabular digits): lane counts ("4 of 15") and countdown-row values.
- **Button** (500, 12px; large 14px): accent and soft capsules.
- **Label** (400–600, 10–11px): sidebar status lines, popover captions, hour and day labels under lines, and widget headers (11 semibold, with a 10 semibold symbol).

### Named Rules
**The Sentence Case Rule.** Page sections, rows, descriptions and widget headers are in sentence case. Title Case is only for buttons and menu items ("Take a Break Now", "Every 4th Break").

**The Ticking Digits Rule.** Any number that changes while you watch is set in monospaced digits so it doesn't jitter, in the locale's own digits (`localizedDigits`; Arabic-Indic where the locale uses them). The break countdowns keep their digits in left-to-right order in every language.

## Layout

The window is a native split view. The sidebar is 190–240px (ideal 210) and the detail column is a scrolling paper page. The window opens at 880 × 660 and can't go below 780 × 560. The page content column is capped at 640px and left-aligned. It has 44px side padding, 34px at the top and 56px at the bottom. The page header stacks the symbol (34px frame), title and description with 6px gaps. Each section begins 30px below the previous one. Its heading sits 7px above a 1px hairline, and rows start 4px below the rule. A row is at least 40px tall with 9px vertical padding and a 20px gap between text and control. Title and detail are 2px apart. Sliders are 170px wide, with an 84px right-aligned read-out. Footers sit 6px under the last row.

A page shows at most four essentials. Everything else waits under "More options" 26px below the last section, a plain 13px medium line in secondary ink with a 10px chevron that turns 90° when open (it then reads "Fewer options"). The Water page's goal calculator uses the same disclosure ("Work out my goal"). Breaks and Water open with the habit's rhythm under a "Your rhythm" heading: today's line (34px tall) with the shift's start and end hours under it, then the week line and its day labels, between a 76px label column and a 96px value column. Breaks keeps its 30-day bars and plain-fact insights under More options.

The popover is a fixed 300px column with 14px padding, ordered top to bottom: the date and shift line, an optional pause line, the glass hero, "Today" with the two compact rhythm lanes (24px tall, 1.75px lines), the countdown rows (min 28px), a hairline, the actions, a hairline, then Settings and Quit. Inner content is inset 4px from the column edges so text lines up with row highlights.

The full-screen break stacks the 300px ring, the guide card (at most 640px wide, 40 × 26px padding) and the actions 48px from the bottom. The Window style is a fixed 440px glass card: a 64px ring beside the compact guide and its buttons. Its height is set once per break, so the steps change without the window resizing.

In Arabic everything mirrors: the sidebar sits on the right, rows read right to left, and rhythm lines, week lines and day labels flip (`flipsForRightToLeftLayoutDirection`) so the day runs right to left. Widgets follow the app's language, not the Mac's.

Widgets follow WidgetKit families. Rhythm comes in small, medium and large on Paper. End of Shift comes in small and medium on its theme's surface. In the medium size, a hairline column divider separates the countdown from the times.

### Named Rules
**The No Box Rule.** Group with a heading over a hairline and with spacing. Never wrap settings in boxed forms, group boxes, stat tiles or card grids. The wash callout is the one tinted block, for the one thing on a page worth reading first.

## Elevation & Depth

The system is flat on paper, with glass for floating layers. Pages, rows and widgets have no shadows. Depth comes from the system's Liquid Glass material on surfaces that float above the user's work. That glass is tinted by the habit it belongs to: eye colour at 8–10%, water at 14%. Small floating panels over an arbitrary desktop (toasts, the unlock prompt, the warning toast, the blink pill, the floating break card) add a behind-window blur under the glass for legibility. Under Reduce Transparency every glass surface turns opaque: the window background colour with its tint and a 1px rim at 15% primary.

### Shadow Vocabulary
- **Ring glow** (the countdown ring's own arc in the habit's accent, blurred 16px for the hero ring and 12px for the compact hero ring, at 45% opacity): the single soft glow in the app, on the full-screen break's ring only. The 64px ring in the floating break card and the 48px popover ring have none.
- **Icon template shadow** (`0 10px 18px rgba(0,0,0,0.22)`): under the app icon's squircle, as Apple's icon template expects.

### Named Rules
**The Glass Floats Rule.** Glass only where something floats: the sidebar, the popover hero, toasts, break overlays. A page, a row or a widget is never glass.

**The One Glow Rule.** The tapered countdown ring on the full-screen break gets one soft solid glow. Nothing else glows.

## Shapes

Corners are continuous (squircle) curves throughout. Radii grow with how far a surface floats. Menu-row highlights are 6px. Sidebar and list selections are 7px. The pause line is 8px. The callout and theme previews are 10px, and swatches are 12px. The popover hero is 16px. Toasts and prompts are 22px (the floating break card is 24px). The break guide card is 28px, and the full-screen water card is 36px. Buttons and the blink pill are full capsules, key caps are 6px, and the close button is a 24px circle in a 30px hit target. Rules are 1px hairlines. Lines have round caps and joins, and every rhythm line ends in a solid dot.

## Components

### Buttons
- **Shape:** full capsule (rounded.capsule).
- **Accent:** the surface's main action. It is a solid habit fill drawn by the app itself, because system prominent styles turn grey in windows that never become key. The eye version is Deep Violet with white text. The water version is Aqua with Water Ink. Small is 12px medium with 4 × 11px padding; large is 14px with 8 × 18px.
- **Pressed:** the fill drops to 80% opacity. There is no hover animation.
- **Soft:** the secondary action on toasts and overlays. It uses primary text over a 9% primary-colour fill (16% when pressed), at the same sizes.
- **Native:** everything inside Settings pages uses system controls at small size (switches, sliders, pop-ups, steppers, small bordered buttons for "Preview" and "Show now"), tinted by the page's colour.
- **Close:** a 24px circle with a bold 10px xmark in secondary ink over an 8% primary-colour fill, inside a 30px hit target.

### Rows (Settings)
- **Anatomy:** a 13px ink title, an optional 12px secondary-ink detail beneath it, and the control trailing. Rows are flat, with no separators between them; the hairline belongs to the section heading only.
- **Variants:** toggle (small switch), slider (170px plus read-out), picker (fixed-size pop-up), stepper (value text to its left), action (small button), and value (13px secondary-ink tabular text).

### More options
- **Style:** a plain button line, not a box: 13px medium secondary ink, a 10px semibold chevron.forward that turns 90° when open, 6px vertical padding, 26px above. "More options" closed, "Fewer options" open; VoiceOver hears Shown or Hidden. `DisclosureRow` is the same line with its own title, for one tool most visits don't need ("Work out my goal").

### Callout
- **Style:** a wash fill with 10px corners and 14px padding. It holds a 15px medium symbol in the tint, a 13px semibold title and a 12px secondary message, with an optional trailing accessory. There is at most one per page, 24px above what follows (today, the first-run "How EyeBreak works" on Breaks, with a "Got It" accent button).

### Navigation (sidebar)
- **Style:** the system sidebar list (Liquid Glass). At the top is the app icon (30px) beside "EyeBreak" in 13px semibold and one or two 11px tabular status lines. Below that is one group of four: Breaks (eye), Water (drop), Workday (hourglass), App (gearshape).
- **Row:** an 18px-wide 13px symbol and a 13px title, padded 6 × 8px, with 7px corners.
- **States:** at rest, the icon is secondary ink. On hover, the row gets a 5% primary-colour wash. When selected, the row takes a 12% wash of the page tint, the icon turns to the tint and the title goes semibold. It never uses the system accent highlight.

### Menu bar item
- **Style:** the `eye` symbol, with the countdown beside it when enabled. It fills (`eye.fill`) for the last minute before a break and while a break waits for a pause, and turns to `eye.slash` while paused or stopped.

### Popover menu rows
- **Style:** a 12px symbol in secondary colour, a 13px title, and an optional 11px shortcut, padded 5 × 8px.
- **Hover:** a solid fill in the habit's colour with 6px corners, like a native menu selection. Text and icon switch to the on-fill colour. Disabled rows drop to 45%.

### Popover hero
- **Style:** a glass card with 16px corners, tinted with the eye accent at 10%, and 12px padding. It holds a 48px compact countdown ring with the eye symbol at its centre, an 11px medium caption, and the 26px semibold tabular time. A row of 6px round dots (filled in eye accent, empty in quaternary) shows the Pomodoro round. When paused, the ring desaturates to half opacity. While a break is due, "5 More Minutes" and "Skip This Break" join the actions above "Take a Break Now".

### Rhythm line (signature)
- **Behaviour:** the line is drawn up to now, in the habit's colour (eye accent; water deep). Ahead of now it is a 1px hairline at the line's resting height. A solid dot 2.5× the line width marks now. Each miss pulls the line down by 0.42 of its height. The drop takes about 1% of the window (at least 1 minute) and the recovery eases back over about 9% (at least 10 minutes), so on an 8-hour shift that is 5 minutes down and 45 back. The line never goes below 0.06 of its height.
- **Sizes:** in the popover, 24px tall with a 1.75px stroke and a 12% primary track. On the Breaks and Water pages, 34px tall with a 2px stroke and a hairline track; in widgets 26–34px.
- **Week line:** one point per day at that day's score. A day with no record is an open ring on the track, filled with paper. Day labels sit underneath in 11px secondary ink.
- **Lanes:** eyes over water, each with its filled symbol (eye.fill, drop.fill) in the habit colour and a trailing tabular count.
- **Right to left:** the line, the week line and the day labels mirror, so now and today sit on the left in Arabic.

### Break guide card
- **Style:** a symbol in the palette accent, the step title and one secondary line: look across the room, then close, squeeze and open for two slow blinks; a long break starts with standing up and moving. On a long break with water due it adds a water row (drop.fill in water accent, a line, and an "I Drank" water accent button). The step cross-fades as the break runs and is announced to VoiceOver. After a run of skipped breaks, one neutral secondary line above it says how many and how short this one is; no red, no picture.
- **Full screen:** 28px glass card under the ring, "5 More Minutes" (soft, large) and an esc Skip hint (glass capsule with a key cap) at the bottom. **Window:** the compact guide in the 440px card, with "5 More Minutes" and "Skip esc" as soft buttons. The warning toast before a break is the same 440px, 22px-corner glass with "5 More Minutes" and "Skip".

### Water reminder
- **Toast:** a 400px glass card (22px corners): a 40px water-tinted (14%) icon disc, a 14px semibold title over a 12px line, and the close button (later). One primary "I Drank" (water accent, return) and a soft "In 10 Minutes". **Full screen:** a 104px glass icon disc, a 30px semibold title, the same two buttons large on a 36px-corner card, and an esc "Not now" hint at the bottom. Escape always means not now.

### Blink pill
- **Style:** a silent, self-dismissing glass capsule at the top centre in the break-screen palette: a 34px icon disc (accent at 14%), a 13px semibold title over an 11px line. It alternates two prompts (two slow blinks; look across the room). Click to dismiss.

### Widgets
- **Rhythm:** on paper (clear in accented/tinted rendering modes). Small, medium and large sizes show today's and the week's lines, with 11–13px semibold headers.
- **End of Shift:** a solid theme surface for the current shift state. It has a header symbol and an 11px semibold label, a bold tabular countdown (32px small, 44px medium), a 28% ink progress track, and a footer in derived soft and faint inks. The medium size adds a times column (24px bold) behind a hairline divider.

## Do's and Don'ts

### Do:
- **Do** take every colour from `ThemeColors` by its job. Reach for the token (paper, ink, secondary-ink, hairline, wash, the eye and water ramps), not a literal.
- **Do** build Settings pages from the page grammar: symbol, 26px bold title, one-line description, then sections of a 13px semibold heading over a 1px hairline, then flat 40px-minimum rows. Keep a page to four essentials and put the rest under More options.
- **Do** put text on solid fills only in its paired colour: white on eyes-deep, water-ink on water-bright.
- **Do** use monospaced digits for every countdown and live value.
- **Do** say it with a rhythm line when showing how the day or week is going.
- **Do** take every user-facing string from the string catalog (`Localizable.xcstrings`, `String(localized:)`; shared code via `String(shared:)`). Never hard-code one.
- **Do** mirror anything time-based in right to left (lines, week lines, day labels) and set times in the locale's digits; keep break countdown digits left to right.
- **Do** write copy calm and factual in both languages: no exclamation marks, no health claim beyond `docs/EVIDENCE.md`.
- **Do** derive secondary text on widget surfaces from the surface (`Contrast.muted`), with floors of 6.0 / 4.7 (7.6 / 6.5 light-on-dark).

### Don't:
- **Don't** use gradients anywhere: icons, buttons, selections, charts, backdrops.
- **Don't** put glass on pages, rows or widgets. Glass is for the sidebar, the popover hero, toasts and break overlays.
- **Don't** box settings into grouped forms, stat tiles or card grids.
- **Don't** use red. `Theme.alert` is reserved for a warning, and nothing draws in it today; a skipped-breaks note is neutral.
- **Don't** put anything on a break beyond the countdown, the guide card and its actions: no quotes, no pictures of damage.
- **Don't** use SF Rounded, a second typeface, or emoji in the app's own UI. Custom ambient reminders may carry the user's own emoji.
- **Don't** add decorative motion. Motion only conveys state: the ring ticking down, the break step cross-fading, a disclosure chevron turning (0.2s ease-out), and toasts fading in and out. All of it stops under Reduce Motion: the ring steps once a second and toasts simply appear.
- **Don't** add a glow or shadow beyond the countdown ring's glow and the icon's template shadow.
