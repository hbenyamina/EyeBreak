import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0"
    }

    var body: some View {
        SettingsPage(title: "About") {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EyeBreak")
                            .font(.title3.weight(.semibold))
                        Text("Version \(version)")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Text("Every 20 minutes, look at something 20 feet away for 20 seconds. EyeBreak reminds you, guides your eyes, and keeps you drinking water, and it gets out of the way the rest of the time.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Privacy") {
                Text("Everything EyeBreak records stays on your Mac. Nothing is sent anywhere.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
