import Foundation
import SwiftUI

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "Europe/Paris")!
cal.locale = Locale(identifier: "en_US")

func date(_ s: String) -> Date {
    let f = DateFormatter()
    f.calendar = cal; f.timeZone = cal.timeZone; f.locale = cal.locale
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}
func show(_ d: Date) -> String {
    let f = DateFormatter()
    f.calendar = cal; f.timeZone = cal.timeZone; f.locale = cal.locale
    f.dateFormat = "EEE yyyy-MM-dd HH:mm"
    return f.string(from: d)
}
var failures = 0
func menuText(_ schedule: ShiftSchedule, at date: Date) -> String {
    ShiftText.short(for: schedule.status(at: date), now: date)
}
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    print((ok ? "PASS  " : "FAIL  ") + label + (detail.isEmpty ? "" : "   [\(detail)]"))
    if !ok { failures += 1 }
}

// 09:00-17:00 Mon-Fri
let day = ShiftSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, weekdays: [2,3,4,5,6])

// Tue 2026-09-08 is a Tuesday
let midShift = date("2026-09-08 14:30")
if let s = day.status(at: midShift, calendar: cal) {
    check("mid-shift is onShift", s.phase == .onShift)
    check("targets today 17:00", s.target == date("2026-09-08 17:00"), show(s.target))
} else { check("mid-shift status exists", false) }

if let s = day.status(at: date("2026-09-08 07:00"), calendar: cal) {
    check("early morning is beforeShift", s.phase == .beforeShift)
    check("targets today 09:00", s.target == date("2026-09-08 09:00"), show(s.target))
}
if let s = day.status(at: date("2026-09-08 19:00"), calendar: cal) {
    check("after work is offDuty", s.phase == .offDuty)
    check("targets Wed 09:00", s.target == date("2026-09-09 09:00"), show(s.target))
}
if let s = day.status(at: date("2026-09-12 12:00"), calendar: cal) {   // Saturday
    check("saturday is offDuty", s.phase == .offDuty)
    check("targets Mon 09:00", s.target == date("2026-09-14 09:00"), show(s.target))
}
if let s = day.status(at: date("2026-09-08 17:00"), calendar: cal) {
    check("exactly at end -> offDuty", s.phase == .offDuty, show(s.target))
}
if let s = day.status(at: date("2026-09-08 09:00"), calendar: cal) {
    check("exactly at start -> onShift", s.phase == .onShift, show(s.target))
}

// Night shift 22:00 -> 06:00, Mon-Fri starts
let night = ShiftSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0, weekdays: [2,3,4,5,6])
check("night shift duration 8h", night.durationMinutes == 480, "\(night.durationMinutes)")
if let s = night.status(at: date("2026-09-09 02:00"), calendar: cal) {
    check("2am is still on the night shift", s.phase == .onShift)
    check("night target Wed 06:00", s.target == date("2026-09-09 06:00"), show(s.target))
}
if let s = night.status(at: date("2026-09-09 07:00"), calendar: cal) {
    check("after night shift -> beforeShift today 22:00", s.phase == .beforeShift && s.target == date("2026-09-09 22:00"), show(s.target))
}
// Friday night shift runs into Saturday even though Sat isn't selected
if let s = night.status(at: date("2026-09-12 03:00"), calendar: cal) {
    check("fri-night shift still on at Sat 03:00", s.phase == .onShift, show(s.target))
}

// 24h edge: same start and end
let full = ShiftSchedule(startHour: 9, startMinute: 0, endHour: 9, endMinute: 0, weekdays: [2])
check("equal start/end = 24h", full.durationMinutes == 1440, "\(full.durationMinutes)")

// DST: Europe/Paris falls back Sun 2026-10-25 03:00 -> 02:00
let dst = ShiftSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, weekdays: [1,2,3,4,5,6,7])
if let w = dst.window(startingOn: date("2026-10-25 12:00"), calendar: cal) {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.locale = cal.locale; f.dateFormat = "HH:mm"
    check("DST day still starts at 09:00 wall clock", f.string(from: w.start) == "09:00", f.string(from: w.start))
    // Paris falls back at 03:00, before this shift, so the day itself is a normal 8 hours.
    check("DST day is 8 real hours long", w.end.timeIntervalSince(w.start) == 8*3600, "\(w.end.timeIntervalSince(w.start)/3600)h")
}
// A night shift that actually crosses the fall-back: 22:00 Sat -> 06:00 Sun, one extra real hour.
let dstNight = ShiftSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0, weekdays: [1,2,3,4,5,6,7])
if let w = dstNight.window(startingOn: date("2026-10-24 23:00"), calendar: cal) {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.locale = cal.locale; f.dateFormat = "EEE HH:mm"
    check("night shift over DST still ends 06:00 on the clock", f.string(from: w.end) == "Sun 06:00", f.string(from: w.end))
    check("night shift over DST is 9 real hours", w.end.timeIntervalSince(w.start) == 9*3600, "\(w.end.timeIntervalSince(w.start)/3600)h")
    check("still counted as on shift at 02:30 during the repeated hour", w.contains(date("2026-10-25 02:30")))
}

// timeline entry dates: ordered, future-only, and covering the state changes
let ts = day.timelineDates(from: midShift, calendar: cal)
check("entry dates all now-or-future", ts.allSatisfy { $0 >= midShift })
check("entry dates sorted", ts == ts.sorted())
check("entry dates deduped", Set(ts).count == ts.count)
check("first entry is now", ts.first == midShift, ts.first.map(show) ?? "nil")
check("includes today's shift end", ts.contains(date("2026-09-08 17:00")))
check("includes tomorrow's shift start", ts.contains(date("2026-09-09 09:00")))
check("includes a mid-shift tick", ts.contains(date("2026-09-08 15:00")))
check("respects the entry cap", ts.count <= 120, "\(ts.count)")
check("covers more than a day ahead", (ts.last?.timeIntervalSince(midShift) ?? 0) > 86_400,
      "\((ts.last?.timeIntervalSince(midShift) ?? 0) / 3600)h")

// progress through the shift
if let s = day.status(at: date("2026-09-08 13:00"), calendar: cal) {
    check("half way through an 09-17 shift", abs(s.progress(at: date("2026-09-08 13:00")) - 0.5) < 0.001,
          "\(s.progress(at: date("2026-09-08 13:00")))")
    check("progress clamps at the ends",
          s.progress(at: date("2026-09-08 06:00")) == 0 && s.progress(at: date("2026-09-08 23:00")) == 1)
}

// the shared store's codable shape survives a round trip
let encoded = try! JSONEncoder().encode(night)
check("schedule round-trips through JSON", try! JSONDecoder().decode(ShiftSchedule.self, from: encoded) == night)

// empty weekdays
let none = ShiftSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, weekdays: [])
check("no weekdays -> nil status", none.status(at: midShift, calendar: cal) == nil)

// display strings
check("daysText Mon-Fri run", day.daysText(calendar: cal) == "Mon–Fri", day.daysText(calendar: cal))
check("daysText every day", dst.daysText(calendar: cal) == "Every day", dst.daysText(calendar: cal))
var us = cal; us.firstWeekday = 1
let weekend = ShiftSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, weekdays: [1,7])
check("weekend list", weekend.daysText(calendar: us) == "Sun, Sat", weekend.daysText(calendar: us))
let sunThu = ShiftSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, weekdays: [1,2,3,4,5])
check("Sun-Thu run in US week order", sunThu.daysText(calendar: us) == "Sun–Thu", sunThu.daysText(calendar: us))
check("durationText 7h30", ShiftSchedule(startHour: 9, startMinute: 0, endHour: 16, endMinute: 30, weekdays: [2]).durationMinutes == 450)


// MARK: Time zones

// Hours pinned to Riyadh (GMT+3) while the Mac sits in Paris (GMT+2 in September).
let riyadh = ShiftSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0,
                           weekdays: [1, 2, 3, 4, 5], timeZoneIdentifier: "Asia/Riyadh")
check("pinned zone resolves", riyadh.timeZone.identifier == "Asia/Riyadh", riyadh.timeZone.identifier)
check("pinned zone is not following the Mac", !riyadh.followsSystemTimeZone)
check("default schedule does follow the Mac", ShiftSchedule.standard.followsSystemTimeZone)
if let s = riyadh.status(at: date("2026-09-08 14:00")) {
    // 17:00 in Riyadh is 16:00 on a Paris clock.
    check("Riyadh 17:00 lands at 16:00 Paris", s.target == date("2026-09-08 16:00"), show(s.target))
    check("Riyadh shift is running at 14:00 Paris", s.phase == .onShift)
}
if let s = riyadh.status(at: date("2026-09-08 16:30")) {
    check("past the Riyadh end we are off duty", s.phase == .offDuty, show(s.target))
}
check("zone city for display", riyadh.timeZoneText == "Riyadh", riyadh.timeZoneText ?? "nil")
check("underscores become spaces",
      ShiftSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, weekdays: [2],
                    timeZoneIdentifier: "America/New_York").timeZoneText == "New York")
check("no city when following the Mac", ShiftSchedule.standard.timeZoneText == nil)
check("differs from the Mac clock", riyadh.differsFromSystemClock(at: date("2026-09-08 14:00")))

// The stored file gained a key over time, so files saved before it must still decode.
let legacy = Data(#"{"startHour":8,"startMinute":30,"endHour":16,"endMinute":30,"weekdays":[2,3]}"#.utf8)
if let decoded = try? JSONDecoder().decode(ShiftSchedule.self, from: legacy) {
    check("a file saved before time zones still decodes", decoded.followsSystemTimeZone && decoded.startHour == 8)
} else {
    check("a file saved before time zones still decodes", false)
}
let zoned = try! JSONEncoder().encode(riyadh)
check("zone survives a JSON round trip", try! JSONDecoder().decode(ShiftSchedule.self, from: zoned) == riyadh)

// Menu bar text
check("menu bar text under an hour", menuText(riyadh, at: date("2026-09-08 15:35")) == "25m",
      menuText(riyadh, at: date("2026-09-08 15:35")))
check("menu bar text over an hour", menuText(riyadh, at: date("2026-09-08 13:00")) == "3:00",
      menuText(riyadh, at: date("2026-09-08 13:00")))
check("menu bar text on a weekend is short", menuText(day, at: date("2026-09-12 12:00")) == "Off",
      menuText(day, at: date("2026-09-12 12:00")))


// MARK: Starting from an unlock

// Late on Tue 2026-09-08: unlocked at 09:40 for a 09:00 shift.
var late = day
late.adjustedStart = date("2026-09-08 09:40")
if let s = late.status(at: date("2026-09-08 10:00"), calendar: cal) {
    check("late start: on shift", s.phase == .onShift)
    check("late start: keeps the 8h, so ends 17:40", s.target == date("2026-09-08 17:40"), show(s.target))
    check("late start: window begins at the unlock", s.window.start == date("2026-09-08 09:40"), show(s.window.start))
}
if let s = late.status(at: date("2026-09-08 09:20"), calendar: cal) {
    check("late start: before it, waiting for 09:40 not 09:00", s.phase == .beforeShift && s.target == date("2026-09-08 09:40"), show(s.target))
}
if let s = late.status(at: date("2026-09-08 17:20"), calendar: cal) {
    check("late start: 17:20 still on shift", s.phase == .onShift, show(s.target))
}
if let s = late.status(at: date("2026-09-09 14:30"), calendar: cal) {
    check("late start: next day runs on the scheduled hours", s.target == date("2026-09-09 17:00"), show(s.target))
}
if let s = late.status(at: date("2026-09-07 14:30"), calendar: cal) {
    check("late start: the day before is untouched", s.target == date("2026-09-07 17:00"), show(s.target))
}
check("late start: exactly one shift on that day",
      late.windows(around: date("2026-09-08 12:00"), calendar: cal).filter { cal.isDate($0.start, inSameDayAs: date("2026-09-08 12:00")) }.count == 1)
check("late start: timeline holds the adjusted end",
      late.timelineDates(from: date("2026-09-08 10:00"), calendar: cal).contains(date("2026-09-08 17:40")))
check("late start: timeline drops the scheduled end",
      !late.timelineDates(from: date("2026-09-08 10:00"), calendar: cal).contains(date("2026-09-08 17:00")))

// Early: unlocked at 08:30, before anything was running.
var early = day
early.adjustedStart = date("2026-09-08 08:30")
if let s = early.status(at: date("2026-09-08 08:45"), calendar: cal) {
    check("early start: on shift from 08:30", s.phase == .onShift && s.target == date("2026-09-08 16:30"), show(s.target))
}

// A Saturday: started from now adds a shift on a day off.
var weekendWork = day
weekendWork.adjustedStart = date("2026-09-12 10:00")
if let s = weekendWork.status(at: date("2026-09-12 12:00"), calendar: cal) {
    check("day off: an adjusted start adds a shift", s.phase == .onShift && s.target == date("2026-09-12 18:00"), show(s.target))
}

// Night shift, late after midnight: Tue's 22:00 shift, sat down at Wed 00:30.
var lateNight = night
lateNight.adjustedStart = date("2026-09-09 00:30")
if let s = lateNight.status(at: date("2026-09-09 01:00"), calendar: cal) {
    check("night late: on shift until 08:30", s.phase == .onShift && s.target == date("2026-09-09 08:30"), show(s.target))
}
if let s = lateNight.status(at: date("2026-09-09 12:00"), calendar: cal) {
    check("night late: Wed's own 22:00 shift survives", s.phase == .beforeShift && s.target == date("2026-09-09 22:00"), show(s.target))
}
check("night late: Tue 22:00 window was replaced, not doubled",
      !lateNight.windows(around: date("2026-09-09 01:00"), calendar: cal).contains { $0.start == date("2026-09-08 22:00") })

// A stale start from last week changes nothing this week.
var stale = day
stale.adjustedStart = date("2026-09-01 11:00")
if let s = stale.status(at: midShift, calendar: cal) {
    check("stale start: ignored", s.target == date("2026-09-08 17:00"), show(s.target))
}

check("adjusted start survives a JSON round trip",
      try! JSONDecoder().decode(ShiftSchedule.self, from: try! JSONEncoder().encode(late)) == late)
check("a file without an adjusted start decodes to none",
      (try? JSONDecoder().decode(ShiftSchedule.self, from: legacy))?.adjustedStart == nil)
// Foundation puts a narrow no-break space before AM/PM; compare on plain spaces.
let clock = late.clockText(for: date("2026-09-08 09:40"), locale: Locale(identifier: "en_US"))
    .replacingOccurrences(of: "\u{202F}", with: " ")
check("clock text for a moment", clock == "9:40 AM", clock)
check("menu bar text on a late day counts to the adjusted end",
      menuText(late, at: date("2026-09-08 16:40")) == "1:00",
      menuText(late, at: date("2026-09-08 16:40")))


// MARK: Settings file

// A file from before themes existed: the schedule's keys at the top level.
let legacyFile = Data(#"{"startHour":7,"startMinute":0,"endHour":15,"endMinute":0,"weekdays":[2,3,4,5,6]}"#.utf8)
if let settings = try? JSONDecoder().decode(ShiftSettings.self, from: legacyFile) {
    check("legacy file still loads its hours", settings.schedule.startHour == 7 && settings.schedule.endHour == 15)
    check("legacy file gets the default theme", settings.themeID == ShiftTheme.defaultID, settings.themeID)
} else {
    check("legacy file still loads", false)
}
let chosen = ShiftSettings(schedule: riyadh, themeID: "forest")
let saved = try! JSONEncoder().encode(chosen)
check("settings round-trip keeps hours and theme", try! JSONDecoder().decode(ShiftSettings.self, from: saved) == chosen)
check("saved file uses the new shape", String(data: saved, encoding: .utf8)!.contains("\"schedule\""))


// MARK: Theme contrast
//
// Guards the whole palette: every ink level on every solid surface. Adding a theme with
// weak secondary text fails here.

for theme in ShiftTheme.all {
    for (name, surface) in [("working", theme.working), ("ahead", theme.ahead), ("off", theme.off)] {
        let points = Contrast.samples(across: [surface.color])
        var worstRole = ""
        var worstRatio = Double.greatestFiniteMagnitude
        for (role, color) in [("ink", surface.ink), ("soft", surface.inkSoft), ("faint", surface.inkFaint)] {
            let parts = Contrast.components(of: color)
            let value = points.map { Contrast.ratio(parts, $0) }.min() ?? 0
            if value < worstRatio {
                worstRatio = value
                worstRole = role
            }
        }
        check("\(theme.name) \(name): every ink clears AA",
              worstRatio >= Contrast.smallText,
              String(format: "worst %@ %.2f", worstRole, worstRatio))
    }
    // Light-on-dark surfaces carry extra nominal headroom for font smoothing.
    for (name, surface) in [("working", theme.working), ("ahead", theme.ahead), ("off", theme.off)]
    where Contrast.inkIsLighterThanSurface(surface.ink, [surface.color]) {
        let points = Contrast.samples(across: [surface.color])
        let faint = Contrast.components(of: surface.inkFaint)
        let value = points.map { Contrast.ratio(faint, $0) }.min() ?? 0
        check("\(theme.name) \(name): light ink keeps rasterising headroom", value >= 6.4,
              String(format: "%.2f", value))
    }

    let onTint = Contrast.ratio(.white, theme.tint)
    check("\(theme.name): white reads on the tint", onTint >= Contrast.smallText,
          String(format: "%.2f", onTint))
}

// The soft and faint levels have to be visibly quieter than the headline ink, or the
// hierarchy is gone even though the contrast passes.
for theme in ShiftTheme.all {
    let surface = theme.working
    let inkLuminance = Contrast.luminance(Contrast.components(of: surface.ink))
    let softLuminance = Contrast.luminance(Contrast.components(of: surface.inkSoft))
    let faintLuminance = Contrast.luminance(Contrast.components(of: surface.inkFaint))
    let towardSurface = Contrast.luminance(Contrast.samples(across: [surface.color]).last!) > inkLuminance
    let ordered = towardSurface
        ? inkLuminance <= softLuminance && softLuminance <= faintLuminance
        : inkLuminance >= softLuminance && softLuminance >= faintLuminance
    check("\(theme.name): ink > soft > faint in strength", ordered)
}

// MARK: Merged into EyeBreak

// EyeBreak's old hour-only Smart Schedule becomes a shift.
let fromHours = ShiftSchedule.fromWorkHours(start: 9, end: 17, days: [1, 2, 3, 4, 5])
check("work hours become a 9-5 shift", fromHours.startHour == 9 && fromHours.endHour == 17
      && fromHours.startMinute == 0 && fromHours.endMinute == 0, fromHours.summaryText(calendar: cal))
check("work hours keep their days", fromHours.weekdays == [1, 2, 3, 4, 5])
check("work hours follow this Mac", fromHours.followsSystemTimeZone)
let overnightHours = ShiftSchedule.fromWorkHours(start: 22, end: 6, days: [2])
check("overnight work hours become a night shift", overnightHours.durationMinutes == 8 * 60, "\(overnightHours.durationMinutes)")
let junkHours = ShiftSchedule.fromWorkHours(start: 30, end: -1, days: [0, 3, 9])
check("out-of-range hours and days are clamped", junkHours.startHour == 23 && junkHours.endHour == 0 && junkHours.weekdays == [3])

// Shift Countdown's own file, as it sits on disk, loads in EyeBreak.
let shiftCountdownFile = Data(#"{"themeID":"nightdesk","schedule":{"endHour":17,"startMinute":0,"weekdays":[3,1,2,5,7,4],"adjustedStart":813737796.117796,"startHour":9,"endMinute":0}}"#.utf8)
if let settings = try? JSONDecoder().decode(ShiftSettings.self, from: shiftCountdownFile) {
    check("Shift Countdown file keeps its theme", settings.themeID == "nightdesk" && ShiftTheme.named(settings.themeID).name == "Night Desk")
    check("Shift Countdown file keeps its days", settings.schedule.weekdays == [1, 2, 3, 4, 5, 7])
    check("Shift Countdown file keeps its late start", settings.schedule.adjustedStart != nil)
} else {
    check("Shift Countdown file loads", false)
}
check("unknown theme falls back to the default", ShiftTheme.named("forest").id == ShiftTheme.defaultID)
check("thirteen widget themes, unique ids", ShiftTheme.all.count == 13 && Set(ShiftTheme.all.map(\.id)).count == 13)

// Smart Schedule: breaks run only while on shift, late starts included.
check("breaks run mid-shift", day.status(at: midShift, calendar: cal)?.phase == .onShift)
check("breaks pause before a late start", late.status(at: date("2026-09-08 09:20"), calendar: cal)?.phase != .onShift)
check("breaks run past the scheduled end on a late day", late.status(at: date("2026-09-08 17:20"), calendar: cal)?.phase == .onShift)

// MARK: Pomodoro rounds on the break timer

do {
    var round = BreakRound()
    check("long breaks off: never long", !round.nextIsLong(every: 0))
    check("round starts with nothing filled", round.filled(every: 4, isOnBreak: false) == 0)
    for _ in 0..<3 {
        check("short break before the fourth", !round.nextIsLong(every: 4))
        round.breakEnded(wasLong: false)
    }
    check("fourth break is the long one", round.nextIsLong(every: 4))
    check("three dots filled while working toward it", round.filled(every: 4, isOnBreak: false) == 3)
    check("all four filled during the long break", round.filled(every: 4, isOnBreak: true) == 4)
    round.breakEnded(wasLong: true)
    check("long break closes the round", round.position == 0 && !round.nextIsLong(every: 4))

    var shortened = BreakRound()
    for _ in 0..<3 { shortened.breakEnded(wasLong: false) }
    check("round shortened mid-way counts as complete", shortened.nextIsLong(every: 2))
    check("dots never overflow a shortened round", shortened.filled(every: 2, isOnBreak: true) == 2)

    var away = BreakRound()
    away.breakEnded(wasLong: false)
    away.reset()
    check("coming back from away starts a fresh round", away.position == 0)
}

// MARK: The Pomodoro timer

do {
    var p = Pomodoro()
    check("a Pomodoro starts with nothing done", p.completed == 0 && !p.isWaiting && p.filled(every: 4, isOnBreak: false) == 0)
    for block in 1...3 {
        let long = p.blockEnded(finished: true, every: 4)
        check("block \(block) earns a short break", !long)
        check("its dot fills during the break", p.filled(every: 4, isOnBreak: true) == block)
        p.breakEnded(wasLong: long, continues: true)
    }
    check("three blocks done", p.completed == 3 && p.filled(every: 4, isOnBreak: false) == 3)
    check("the fourth block's break will be long", p.nextBreakIsLong(every: 4))
    let fourth = p.blockEnded(finished: true, every: 4)
    check("the fourth block earns the long break", fourth)
    check("all four dots during the long break", p.filled(every: 4, isOnBreak: true) == 4)
    p.breakEnded(wasLong: fourth, continues: true)
    check("the long break closes the round, the count carries on", p.completed == 4 && p.filled(every: 4, isOnBreak: false) == 0)

    var early = Pomodoro()
    for _ in 0..<3 { early.breakEnded(wasLong: early.blockEnded(finished: true, every: 4), continues: true) }
    let cut = early.blockEnded(finished: false, every: 4)
    check("a block ended early gets a short break", !cut)
    check("and doesn't count", early.completed == 3)
    check("its dot stays empty during that break", early.filled(every: 4, isOnBreak: true) == 3)
    early.breakEnded(wasLong: cut, continues: true)
    check("the round doesn't move on for it", early.nextBreakIsLong(every: 4) && early.completed == 3)

    var later = Pomodoro()
    let first = later.blockEnded(finished: true, every: 4)
    // 5 More Minutes: the same break comes back, from the timer or from Take a Break Now
    let again = later.blockEnded(finished: false, every: 4)
    check("a break held back by 5 More Minutes isn't counted twice", later.completed == 1 && first == again)
    later.breakEnded(wasLong: again, continues: false)
    check("the round moves on once", later.filled(every: 4, isOnBreak: false) == 1)
    check("off, the next block waits for you", later.isWaiting)
    later.startNextBlock()
    check("Start runs the next block", !later.isWaiting)
}

// MARK: History with Pomodoros

do {
    // 2.2.0's breakStatistics entry: no Pomodoro fields
    let old = Data(#"[{"date":813740000,"breaksCompleted":12,"totalBreakTime":360,"breaksSkipped":2}]"#.utf8)
    let days = try? JSONDecoder().decode([DayStats].self, from: old)
    check("2.2.0 history still loads", days?.first?.breaksCompleted == 12 && days?.first?.breaksSkipped == 2)
    check("its Pomodoro fields read as zero", days?.first?.pomodorosCompleted == 0 && days?.first?.focusTime == 0)
    var day = DayStats.empty(Date(timeIntervalSinceReferenceDate: 813740000))
    day.pomodorosCompleted = 4
    day.focusTime = 6000
    let again = (try? JSONEncoder().encode([day])).flatMap { try? JSONDecoder().decode([DayStats].self, from: $0) }
    check("Pomodoros survive a round trip", again?.first == day)
}

// MARK: Rhythm lines

do {
    let start = date("2026-09-08 09:00"), end = date("2026-09-08 17:00")
    let window = DateInterval(start: start, end: end)
    let span = window.duration

    let clean = Rhythm.points(misses: [], window: window, now: date("2026-09-08 13:00"))
    check("no misses: a straight line along the top", clean.allSatisfy { $0.y == 1 })
    check("drawn only up to now", (clean.last?.x ?? 0) <= 0.5 + 1e-9 && (clean.last?.x ?? 0) > 0.49, "\(clean.last?.x ?? -1)")
    check("nothing drawn before the window", Rhythm.points(misses: [], window: window, now: date("2026-09-08 08:00")).isEmpty)

    let miss = date("2026-09-08 11:00")
    check("straight until the miss", Rhythm.level(at: date("2026-09-08 10:59"), misses: [miss], span: span) == 1)
    check("the miss is where it starts to catch", Rhythm.level(at: miss, misses: [miss], span: span) == 1)
    let deepest = Rhythm.level(at: miss.addingTimeInterval(span * 0.01), misses: [miss], span: span)
    check("one miss dips the line by its depth", abs(deepest - (1 - Rhythm.missDepth)) < 1e-9, "\(deepest)")
    let halfway = Rhythm.level(at: miss.addingTimeInterval(span * 0.01 + span * 0.045), misses: [miss], span: span)
    check("eases back up afterwards", halfway > deepest && halfway < 1, "\(halfway)")
    check("back on the line once recovered", Rhythm.level(at: miss.addingTimeInterval(span * 0.11), misses: [miss], span: span) == 1)

    let pileUp = Array(repeating: miss, count: 5)
    check("misses together sink deeper but never to the floor",
          Rhythm.level(at: miss.addingTimeInterval(span * 0.01), misses: pileUp, span: span) == Rhythm.floor)
    let withMiss = Rhythm.points(misses: [miss], window: window, now: end)
    check("the catch's corner is sampled exactly", withMiss.contains { abs($0.x - 0.25) < 1e-9 })
    check("points run left to right", withMiss.map(\.x) == withMiss.map(\.x).sorted())

    // Window: the shift, widened for anything outside it; 8-to-8 with no shift
    let early = ActivityEvent(date: date("2026-09-08 08:30"), kind: .drank)
    let widened = Rhythm.window(shiftStart: start, shiftEnd: end, events: [early], day: start, calendar: cal)
    check("window widens to take in an early glass", widened.start == early.date && widened.end == end)
    let noShift = Rhythm.window(shiftStart: nil, shiftEnd: nil, events: [], day: start, calendar: cal)
    check("no shift: 8 AM to 8 PM", noShift.start == date("2026-09-08 08:00") && noShift.end == date("2026-09-08 20:00"))

    // Scores and the log
    var log = ActivityLog()
    log.record(.breakTaken, at: date("2026-09-08 09:20"), calendar: cal)
    log.record(.breakSkipped, at: date("2026-09-08 09:40"), calendar: cal)
    log.record(.breakTaken, at: date("2026-09-08 10:00"), calendar: cal)
    log.record(.drank, at: date("2026-09-08 09:45"), calendar: cal)
    log.record(.waterMissed, at: date("2026-09-08 10:30"), calendar: cal)
    let day = log.events(on: start, calendar: cal)
    check("eyes score: 2 of 3 taken", abs((Rhythm.score(.eyes, events: day) ?? 0) - 2.0 / 3.0) < 1e-9)
    check("water score: 1 of 2", Rhythm.score(.water, events: day) == 0.5)
    check("nothing recorded: no score", Rhythm.score(.water, events: []) == nil)
    check("misses by habit", log.misses(.eyes, on: start, calendar: cal) == [date("2026-09-08 09:40")])
    check("events kept in time order", log.events.map(\.date) == log.events.map(\.date).sorted())

    log.shiftStart = start
    log.shiftEnd = end
    check("today's stored shift sets the window", log.window(on: start, calendar: cal).start == start)
    check("yesterday's stored shift doesn't", log.window(on: date("2026-09-09 12:00"), calendar: cal).start == date("2026-09-09 08:00"))

    log.record(.drank, at: date("2026-09-20 12:00"), calendar: cal)
    check("old days are trimmed", log.events.allSatisfy { $0.date >= date("2026-09-13 00:00") }, "\(log.events.count)")

    let week = log.weekScores(.water, endingOn: date("2026-09-20 12:00"), calendar: cal)
    check("week has seven days, oldest first", week.count == 7 && week[6] != nil && week[0] == nil)
    // 250 ml by noon of an 8-to-8 day: a third of 2 L was due, so 250 of 667 ml
    check("today's water is scored against what's due so far", abs((week[6] ?? 0) - 0.375) < 0.01, "\(week[6] ?? -1)")

    let saved = try! JSONEncoder().encode(log)
    check("activity log round-trips", try! JSONDecoder().decode(ActivityLog.self, from: saved) == log)
    check("summary words", Rhythm.summary(misses: 0) == "On track" && Rhythm.summary(misses: 1) == "1 miss" && Rhythm.summary(misses: 3) == "3 misses")
}

// MARK: Water goal

do {
    // Drinks, not total water: ESPEN's 1.6 / 2.0 L at the reference weights
    check("60 kg woman: 1.6 L of drinks", WaterGoal.estimate(weightKg: 60, sex: .female) == 1600,
          "\(WaterGoal.estimate(weightKg: 60, sex: .female))")
    check("70 kg man: 2.0 L", WaterGoal.estimate(weightKg: 70, sex: .male) == 2000)
    check("rather not say sits between: 65 kg, 1.8 L", WaterGoal.estimate(weightKg: 65) == 1800)
    // The old 33 ml/kg asked a 120 kg man for 3.96 L; turnover data put it nearer 2.5
    check("weight adds 10 ml a kilo, not 33", WaterGoal.estimate(weightKg: 120, sex: .male) == 2500,
          "\(WaterGoal.estimate(weightKg: 120, sex: .male))")
    check("half an hour of moderate exercise adds 200 ml",
          WaterGoal.estimate(weightKg: 70, sex: .male, exerciseMinutes: 30) == 2200)
    check("vigorous exercise adds 400 ml a half hour",
          WaterGoal.estimate(weightKg: 70, sex: .male, exerciseMinutes: 30, intensity: .vigorous) == 2400)
    check("heat without air conditioning adds 500 ml", WaterGoal.estimate(weightKg: 70, sex: .male, hot: true) == 2500)
    check("rounded to 50 ml", WaterGoal.estimate(weightKg: 61.3, sex: .female) % 50 == 0)
    check("never below 1.2 L", WaterGoal.estimate(weightKg: 10, sex: .female) == 1200)
    check("never above 4 L", WaterGoal.estimate(weightKg: 200, sex: .male, exerciseMinutes: 240, intensity: .vigorous, hot: true) == 4000)

    // Never prompted faster than the kidneys clear it (about 500 ml an hour)
    check("a 250 ml glass: reminders at least 30 min apart", WaterGoal.minimumInterval(glass: 250) == 30)
    check("a 500 ml bottle: at least an hour apart", WaterGoal.minimumInterval(glass: 500) == 60)
    check("2 L of 250 ml glasses over an 8h shift: every 60 min",
          WaterGoal.reminderInterval(goal: 2000, glass: 250, over: 480) == 60)
    check("a big goal in a short shift is still spaced out",
          WaterGoal.reminderInterval(goal: 6000, glass: 100, over: 240) == WaterGoal.minimumInterval(glass: 100),
          "\(WaterGoal.reminderInterval(goal: 6000, glass: 100, over: 240))")

    let en = { (s: String) in s.replacingOccurrences(of: "\u{00A0}", with: " ") }
    check("ml under a litre", WaterAmount.text(250, unit: .milliliters) == "250 ml")
    check("litres without trailing zeros", en(WaterAmount.text(2000, unit: .milliliters)) == "2 L", WaterAmount.text(2000, unit: .milliliters))
    check("fluid ounces", WaterAmount.text(237, unit: .fluidOunces) == "8 fl oz", WaterAmount.text(237, unit: .fluidOunces))
    check("progress in litres", en(WaterAmount.progress(1250, of: 2000, unit: .milliliters)) == "1.25 of 2 L",
          WaterAmount.progress(1250, of: 2000, unit: .milliliters))

    var log = ActivityLog()
    log.record(.drank, amount: 330, at: date("2026-09-08 10:00"), calendar: cal)
    log.record(.drank, at: date("2026-09-08 11:00"), calendar: cal)
    check("water today sums glass sizes, 250 ml when unknown", log.waterML(on: date("2026-09-08 12:00"), calendar: cal) == 580)
}

// MARK: Water pace: a dip only when a glass behind

do {
    // 2 L over 9-to-5 is 250 ml an hour; glasses of 250 ml
    let window = DateInterval(start: date("2026-09-08 09:00"), end: date("2026-09-08 17:00"))
    let hourly = (0..<8).map { (date: date("2026-09-08 09:00").addingTimeInterval(Double($0) * 3600 + 3540), ml: 250) }
    check("a glass every hour, just before it's due: never behind",
          Rhythm.paceMisses(drinks: hourly, goal: 2000, glass: 250, window: window, until: window.end).isEmpty)
    let noneAtAll = Rhythm.paceMisses(drinks: [], goal: 2000, glass: 250, window: window, until: window.end)
    check("nothing drunk all day: one catch per glass behind, from a glass and a half", noneAtAll.count == 7, "\(noneAtAll.count)")
    check("the first catch comes at an hour and a half", noneAtAll.first == date("2026-09-08 10:30"), noneAtAll.first.map(show) ?? "nil")
    let caughtUp = [(date: date("2026-09-08 11:00"), ml: 500)]
    let lagThenCatch = Rhythm.paceMisses(drinks: caughtUp, goal: 2000, glass: 250, window: window, until: date("2026-09-08 12:00"))
    check("catching up clears the lag", lagThenCatch == [date("2026-09-08 10:30")], lagThenCatch.map(show).joined(separator: ", "))
    check("nothing is judged ahead of now",
          Rhythm.paceMisses(drinks: [], goal: 2000, glass: 250, window: window, until: date("2026-09-08 10:00")).isEmpty)

    var log = ActivityLog()
    log.shiftStart = window.start
    log.shiftEnd = window.end
    log.record(.waterMissed, at: date("2026-09-08 09:50"), calendar: cal)
    log.record(.drank, at: date("2026-09-08 10:00"), calendar: cal)
    check("a single 'not now' isn't a dip on its own",
          log.misses(.water, on: date("2026-09-08 11:00"), calendar: cal).isEmpty)
}

// MARK: The default work week follows the region

do {
    var saudi = Calendar(identifier: .gregorian)
    saudi.locale = Locale(identifier: "ar_SA")
    var us = Calendar(identifier: .gregorian)
    us.locale = Locale(identifier: "en_US")
    check("a Saudi Mac works Sunday to Thursday", ShiftSchedule.regionWorkweek(calendar: saudi) == [1, 2, 3, 4, 5],
          "\(ShiftSchedule.regionWorkweek(calendar: saudi).sorted())")
    check("a US Mac works Monday to Friday", ShiftSchedule.regionWorkweek(calendar: us) == [2, 3, 4, 5, 6])
}

// MARK: Night shifts stay one day

do {
    let night = ShiftSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0, weekdays: [2, 3, 4, 5, 6])
    check("a night shift's day starts mid-afternoon", night.dayStartMinutes == 14 * 60, "\(night.dayStartMinutes)")
    check("a day shift's day starts at midnight", ShiftSchedule.standard.dayStartMinutes == 0)
    var log = ActivityLog()
    log.dayStartMinutes = night.dayStartMinutes
    log.record(.breakTaken, at: date("2026-09-08 23:30"), calendar: cal)
    log.record(.breakSkipped, at: date("2026-09-09 03:10"), calendar: cal)
    check("both sides of midnight count as the same day",
          log.events(on: date("2026-09-09 04:00"), calendar: cal).count == 2)
    check("and the skip after midnight is that night's miss",
          log.misses(.eyes, on: date("2026-09-09 04:00"), calendar: cal) == [date("2026-09-09 03:10")])
}

// MARK: The break routine

do {
    check("a 30 s break opens by looking away", BreakGuide.step(elapsed: 0, duration: 30, isLong: false) == .lookAway)
    check("…for 20 s", BreakGuide.step(elapsed: 19.9, duration: 30, isLong: false) == .lookAway)
    check("then closes the eyes", BreakGuide.step(elapsed: 20, duration: 30, isLong: false) == .blink(cycle: 1, of: 2, phase: .close))
    check("squeezes", BreakGuide.step(elapsed: 22.5, duration: 30, isLong: false) == .blink(cycle: 1, of: 2, phase: .squeeze))
    check("opens", BreakGuide.step(elapsed: 24.5, duration: 30, isLong: false) == .blink(cycle: 1, of: 2, phase: .open))
    check("and blinks a second time", BreakGuide.step(elapsed: 29, duration: 30, isLong: false) == .blink(cycle: 2, of: 2, phase: .open))
    check("a long break starts by standing up", BreakGuide.step(elapsed: 10, duration: 300, isLong: true) == .standUp)
    check("and ends with the blinks", BreakGuide.step(elapsed: 291, duration: 300, isLong: true).isBlink)
    check("a 15 s break has room for one blink", BreakGuide.blinkCycles(for: 15) == 1)
    check("a 5 s break has none", BreakGuide.step(elapsed: 4, duration: 5, isLong: false) == .lookAway)
    check("every step has words", [BreakStep.lookAway, .standUp, .blink(cycle: 1, of: 2, phase: .close)]
        .allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty && !$0.symbol.isEmpty })
}

// MARK: The day's break goal

do {
    // 8 hours of 20 min work, 30 s breaks, every third one 5 min: 21 breaks, 16 to meet the goal
    check("breaks an 8-hour shift holds",
          BreakGoal.scheduled(shiftMinutes: 480, workMinutes: 20, breakSeconds: 30, longEvery: 3, longMinutes: 5) == 21,
          "\(BreakGoal.scheduled(shiftMinutes: 480, workMinutes: 20, breakSeconds: 30, longEvery: 3, longMinutes: 5))")
    check("the goal is three quarters of them",
          BreakGoal.fromShift(shiftMinutes: 480, workMinutes: 20, breakSeconds: 30, longEvery: 3, longMinutes: 5) == 16)
    check("Pomodoro over 8 hours: 14 breaks, goal 11",
          BreakGoal.fromShift(shiftMinutes: 480, workMinutes: 25, breakSeconds: 300, longEvery: 4, longMinutes: 15) == 11,
          "\(BreakGoal.fromShift(shiftMinutes: 480, workMinutes: 25, breakSeconds: 300, longEvery: 4, longMinutes: 15))")
    check("never below one", BreakGoal.fromShift(shiftMinutes: 10, workMinutes: 20, breakSeconds: 20, longEvery: 0, longMinutes: 0) == 1)
}

// MARK: Streak over work days

do {
    let sunThu: Set<Int> = [1, 2, 3, 4, 5]   // Sunday to Thursday
    func days(_ list: [String]) -> Set<Date> { Set(list.map { cal.startOfDay(for: date($0 + " 12:00")) }) }
    // Thu 10 Sep, then the weekend off (Fri 11, Sat 12), then Sun 13 and Mon 14
    let worked = days(["2026-09-08", "2026-09-09", "2026-09-10", "2026-09-13", "2026-09-14"])
    check("a weekend off doesn't break it",
          Streak.workDays(withBreaks: worked, workdays: sunThu, today: date("2026-09-14 18:00"), calendar: cal) == 5)
    check("today still under way doesn't break it",
          Streak.workDays(withBreaks: worked, workdays: sunThu, today: date("2026-09-15 09:00"), calendar: cal) == 5)
    let oneMissed = days(["2026-09-06", "2026-09-07", "2026-09-09", "2026-09-10", "2026-09-13"])
    check("one missed work day is forgiven",
          Streak.workDays(withBreaks: oneMissed, workdays: sunThu, today: date("2026-09-13 18:00"), calendar: cal) == 5)
    let twoMissed = days(["2026-09-06", "2026-09-09", "2026-09-10", "2026-09-13"])
    check("two missed in the same week end it",
          Streak.workDays(withBreaks: twoMissed, workdays: sunThu, today: date("2026-09-13 18:00"), calendar: cal) == 3,
          "\(Streak.workDays(withBreaks: twoMissed, workdays: sunThu, today: date("2026-09-13 18:00"), calendar: cal))")
    check("no history, no streak", Streak.workDays(withBreaks: [], workdays: sunThu, today: date("2026-09-13 18:00"), calendar: cal) == 0)
}

// MARK: App themes

do {
    func pair(_ a: UInt32, _ b: UInt32) -> Double { Contrast.ratio(Color(rgb: a), Color(rgb: b)) }
    // Secondary text on paper, light and dark, for both themes
    check("violet: description text on paper (light)", pair(0x73726E, 0xFFFFFF) >= 4.5, String(format: "%.2f", pair(0x73726E, 0xFFFFFF)))
    check("violet: description text on paper (dark)", pair(0x9B9A97, 0x191919) >= 4.5, String(format: "%.2f", pair(0x9B9A97, 0x191919)))
    check("garden: description text on linen", pair(0x66705F, 0xFAF9F4) >= 4.5, String(format: "%.2f", pair(0x66705F, 0xFAF9F4)))
    check("garden: description text at night", pair(0x9BA595, 0x151A15) >= 4.5, String(format: "%.2f", pair(0x9BA595, 0x151A15)))
    check("garden: white on the leaf-green fill", pair(0xFFFFFF, 0x2C7A43) >= 4.5, String(format: "%.2f", pair(0xFFFFFF, 0x2C7A43)))
    check("garden: ink on the rain-blue fill", pair(0x0B3550, 0x86D3EF) >= 4.5, String(format: "%.2f", pair(0x0B3550, 0x86D3EF)))
    check("violet: white on the deep violet fill", pair(0xFFFFFF, 0x6B36E0) >= 4.5, String(format: "%.2f", pair(0xFFFFFF, 0x6B36E0)))

    Theme.current = .garden
    let gardenAccent = Contrast.components(of: Theme.accent)
    Theme.current = .classic
    let classicAccent = Contrast.components(of: Theme.accent)
    check("switching the theme recolours the accent", gardenAccent != classicAccent)
    check("every theme has a name and a line of description", AppTheme.allCases.allSatisfy { !$0.name.isEmpty && !$0.detail.isEmpty })
}

do {
    let older = Data(#"{"events":[{"date":813740000,"kind":"drank"}],"breakGoal":12,"waterGoal":8}"#.utf8)
    let log = try? JSONDecoder().decode(ActivityLog.self, from: older)
    check("an older activity file keeps its events", log?.events.count == 1 && log?.breakGoal == 12)
    check("missing keys take their defaults", log?.waterGoalML == 2000 && log?.appTheme == .classic)
}

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
