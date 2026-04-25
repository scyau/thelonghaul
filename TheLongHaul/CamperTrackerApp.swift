import SwiftUI

@main
struct CamperTrackerApp: App {
    @StateObject private var store = AppDataStore()
    @State private var showLaunch = true

    var body: some Scene {
        WindowGroup {
            if showLaunch {
                LaunchScreenView()
                    .environmentObject(store)
                    .onAppear {
                        store.startICloudSync()
                        let allPhotoFilenames = store.allPhotoFilenames
                        PhotoStorage.syncMissingPhotos(filenames: allPhotoFilenames)

                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation(.easeOut(duration: 1.5)) {
                                showLaunch = false
                            }
                        }
                    }
            } else {
                ContentView()
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
