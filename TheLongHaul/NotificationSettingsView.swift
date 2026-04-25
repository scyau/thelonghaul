import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var showingDeniedAlert = false
    @State private var showingDisableAlert = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: store.notificationsAuthorized ? "bell.fill" : "bell.slash.fill")
                .foregroundColor(store.notificationsAuthorized ? .accentColor : Color(.systemGray3))
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Maintenance Notifications")
                    .font(.subheadline.weight(.medium))
                Text(store.notificationsAuthorized
                     ? "You'll be notified when service is due or coming up."
                     : "Enable to get alerts when maintenance is due.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !store.notificationsAuthorized {
                Button("Enable") {
                    store.requestNotificationPermission { granted in
                        if !granted { showingDeniedAlert = true }
                    }
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button("Disable") {
                    showingDisableAlert = true
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.red)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .alert("Notifications Blocked", isPresented: $showingDeniedAlert) {
            Button("Open Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications for The Long Haul in iOS Settings.")
        }
        .alert("Disable Notifications", isPresented: $showingDisableAlert) {
            Button("Open Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("iOS doesn't allow apps to turn off their own notifications. Tap \"Open Settings\" to disable them there — it only takes a second.")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
