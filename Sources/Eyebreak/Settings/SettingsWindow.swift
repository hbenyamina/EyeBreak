import AppKit
import SwiftUI

// MARK: - Panes
enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case breaks = "Breaks"
    case reminders = "Reminders"
    case schedule = "Schedule"
    case appearance = "Appearance"
    case statistics = "Statistics"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .breaks: return "eye.fill"
        case .reminders: return "drop.fill"
        case .schedule: return "calendar.badge.clock"
        case .appearance: return "paintpalette.fill"
        case .statistics: return "chart.bar.fill"
        case .about: return "info.circle.fill"
        }
    }
}

final class SettingsNavigation: ObservableObject {
    @Published var pane: SettingsPane? = .general
}

struct SettingsActions {
    let previewBreak: () -> Void
    let showWaterNow: () -> Void
    let showAmbientNow: () -> Void
}

// MARK: - Root View
struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: StatsStore
    @ObservedObject var loginItemManager: LoginItemManager
    let actions: SettingsActions

    var body: some View {
        NavigationSplitView {
            // A native List so AppKit's table decides which row was clicked. A SwiftUI
            // ScrollView here hit-tested one row low once the window became key and the title
            // bar changed height. No selection binding: List's own highlight uses the system
            // accent colour, so rows draw their own violet selection instead.
            List {
                ForEach(SettingsPane.allCases) { pane in
                    SidebarRow(pane: pane, isSelected: (navigation.pane ?? .general) == pane) {
                        navigation.pane = pane
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SettingsBackdrop())
        }
        .tint(Theme.deep)
        .frame(minWidth: 760, minHeight: 600)
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.pane ?? .general {
        case .general:
            GeneralSettingsView(settings: settings, loginItemManager: loginItemManager)
        case .breaks:
            BreakSettingsView(settings: settings, previewBreak: actions.previewBreak)
        case .reminders:
            RemindersSettingsView(settings: settings, showWaterNow: actions.showWaterNow, showAmbientNow: actions.showAmbientNow)
        case .schedule:
            ScheduleSettingsView(settings: settings)
        case .appearance:
            AppearanceSettingsView(settings: settings)
        case .statistics:
            StatsView(stats: stats, settings: settings)
        case .about:
            AboutView()
        }
    }
}

private struct SidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: pane.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .frame(width: 18)
                Text(pane.rawValue)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Theme.deep : Color.primary.opacity(isHovering ? 0.06 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Plain frosted window background.
private struct SettingsBackdrop: View {
    var body: some View {
        FrostedBackdrop(material: .underWindowBackground)
            .ignoresSafeArea()
    }
}

// MARK: - Window Controller
final class SettingsWindowController {
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
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "EyeBreak Settings"
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: makeView(navigation))
            window.setContentSize(NSSize(width: 820, height: 640))
            window.center()
            window.setFrameAutosaveName("EyeBreakSettings")
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
