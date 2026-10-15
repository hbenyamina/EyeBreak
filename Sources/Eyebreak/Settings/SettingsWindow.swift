import AppKit
import Combine
import SwiftUI

// MARK: - Panes
/// One page per thing you'd come to change: your breaks, your water, your working day, and
/// the app itself. How you're doing sits at the top of each habit's page.
enum SettingsPane: String, CaseIterable, Identifiable {
    case breaks = "Breaks"
    case water = "Water"
    case workday = "Workday"
    case app = "App"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .breaks: return "Breaks"
        case .water: return "Water"
        case .workday: return "Workday"
        case .app: return "App"
        }
    }

    var icon: String {
        switch self {
        case .breaks: return "eye"
        case .water: return "drop"
        case .workday: return "hourglass"
        case .app: return "gearshape"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .breaks: return "How you rest your eyes."
        case .water: return "How much you drink, and when you're asked."
        case .workday: return "When you work. Breaks, reminders and the widgets follow it."
        case .app: return "How EyeBreak looks and behaves."
        }
    }

    /// Water's page is the water blue; everything else is the eye colour.
    var tint: Color { self == .water ? Theme.Water.deep : Theme.onPage }
}

final class SettingsNavigation: ObservableObject {
    private static let key = "settingsPane"

    @Published var pane: SettingsPane {
        didSet { UserDefaults.standard.set(pane.rawValue, forKey: Self.key) }
    }

    init() {
        pane = UserDefaults.standard.string(forKey: Self.key).flatMap(SettingsPane.init) ?? .breaks
    }
}

struct SettingsActions {
    let previewBreak: () -> Void
    let showWaterNow: () -> Void
    let showAmbientNow: () -> Void
    /// Clears the break history and today's lines together.
    let resetHistory: () -> Void
}

// MARK: - Root View
struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var settings: AppSettings
    // Observed further down only, so a ticking countdown redraws the status line, not the page
    let stats: StatsStore
    let shift: ShiftModel
    let activity: ActivityModel
    let timerManager: TimerManager
    let unlockPrompt: UnlockPrompt
    let loginItemManager: LoginItemManager
    let actions: SettingsActions

    var body: some View {
        NavigationSplitView {
            // A native List so AppKit's table decides which row was clicked; rows draw their
            // own quiet selection instead of the system accent.
            List {
                SidebarStatus(timerManager: timerManager, shift: shift)
                    .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 10, trailing: 10))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                Section {
                    ForEach(SettingsPane.allCases) { row($0) }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Page.paper)
                .ignoresSafeArea(.container, edges: .top)
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    private func row(_ pane: SettingsPane) -> some View {
        SidebarRow(pane: pane, isSelected: navigation.pane == pane) {
            navigation.pane = pane
        }
        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.pane {
        case .breaks:
            BreakSettingsView(settings: settings, stats: stats, activity: activity, shift: shift, prompt: unlockPrompt,
                              previewBreak: actions.previewBreak, showBlinkNow: actions.showAmbientNow)
        case .water:
            WaterSettingsView(settings: settings, activity: activity, shift: shift, showWaterNow: actions.showWaterNow)
        case .workday:
            WorkdaySettingsView(settings: settings, shift: shift, prompt: unlockPrompt)
        case .app:
            AppSettingsView(settings: settings, shift: shift, loginItemManager: loginItemManager, resetHistory: actions.resetHistory)
        }
    }
}

/// The app's name and how the day stands right now, at the top of the sidebar.
private struct SidebarStatus: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var shift: ShiftModel

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("EyeBreak")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Page.ink)
                Text(breakStatus)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Page.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let shiftStatus {
                    Text(shiftStatus)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Page.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var breakStatus: String {
        if !timerManager.isRunning { return String(localized: "Not running") }
        if timerManager.isOnBreak { return String(localized: "On a break") }
        if let reason = timerManager.pauseReason {
            return reason == .outsideWorkHours ? String(localized: "Off shift") : String(localized: "Paused")
        }
        return String(localized: "Next break in \(TimerManager.format(timerManager.timeRemaining))")
    }

    private var shiftStatus: String? {
        guard let status = shift.status, status.phase == .onShift else { return nil }
        return String(localized: "\(ShiftText.short(for: status, now: shift.now)) left in your shift")
    }
}

private struct SidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: pane.icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? pane.tint : Theme.Page.secondaryInk)
                    .frame(width: 18)
                Text(pane.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Theme.Page.ink)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? pane.tint.opacity(0.12) : Color.primary.opacity(isHovering ? 0.05 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Window Controller
/// The app window. EyeBreak lives in the menu bar; while this window is open it also gets
/// a Dock icon and an app menu, like any app, and gives them up when it closes.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let navigation = SettingsNavigation()
    private let makeView: (SettingsNavigation) -> SettingsView

    init(makeView: @escaping (SettingsNavigation) -> SettingsView) {
        self.makeView = makeView
    }

    func show(pane: SettingsPane? = nil) {
        if let pane {
            navigation.pane = pane
        }

        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 880, height: 660),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = String(localized: "EyeBreak")
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentViewController = NSHostingController(rootView: makeView(navigation))
            window.setContentSize(NSSize(width: 880, height: 660))
            window.center()
            window.setFrameAutosaveName("EyeBreakWindow")
            #if DEBUG
            // `-settingsHeight 2600`: a window tall enough to capture a whole page
            let height = UserDefaults.standard.double(forKey: "settingsHeight")
            if height > 0 {
                window.setFrame(NSRect(x: 40, y: 40, width: 880, height: height), display: true)
            }
            #endif
            self.window = window
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // Opening a page shouldn't drop the cursor into its first text field
        DispatchQueue.main.async { [weak window] in window?.makeFirstResponder(nil) }
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu bar app once nothing of ours is on screen
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
