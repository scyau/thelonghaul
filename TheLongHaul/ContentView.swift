import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppDataStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "gauge.medium") }

            TripLogView()
                .tabItem { Label("Trips", systemImage: "road.lanes") }

            TripPlannerView()
                .tabItem { Label("Planner", systemImage: "tent") }

            MaintenanceView()
                .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver") }

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
    }
}
