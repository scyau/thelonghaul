import SwiftUI

struct LaunchScreenView: View {
    @EnvironmentObject var store: AppDataStore

    // MARK: - Computed Stats

    private var totalKm: Int {
        Int(store.trips.reduce(0.0) { $0 + $1.miles })
    }

    private var totalNights: Int {
        store.trips.reduce(0) { $0 + ($1.nights ?? 0) }
    }

    private var nextTrip: (name: String, daysAway: Int)? {
        let now = Date()
        let upcoming = store.plannedTrips
            .filter { $0.status == .upcoming && $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
        guard let trip = upcoming.first else { return nil }
        return (name: trip.name, daysAway: trip.daysUntil)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 28) {

                // App name
                Text("The Long Haul")
                    .font(.custom("Nunito-Bold", size: 28))
                    .foregroundColor(Color(red: 0.25, green: 0.30, blue: 0.27))

                // App Icon
                Image("AppIcon-Launch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

                // Top row — km + nights
                HStack(spacing: 24) {
                    LaunchStatUnit(value: "\(totalKm)", label: "km travelled")
                    LaunchDivider()
                    LaunchStatUnit(value: "\(totalNights)", label: "nights away")
                }

                // Bottom — next trip
                LaunchNextTripView(nextTrip: nextTrip)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Subviews

private struct LaunchStatUnit: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.custom("Nunito-Bold", size: 32))
                .foregroundColor(Color(red: 0.95, green: 0.60, blue: 0.45))
            Text(label)
                .font(.custom("Nunito-Regular", size: 13))
                .foregroundColor(Color(red: 0.25, green: 0.30, blue: 0.27))
        }
        .frame(minWidth: 80)
    }
}

private struct LaunchDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.25, green: 0.30, blue: 0.27).opacity(0.2))
            .frame(width: 1, height: 36)
    }
}

private struct LaunchNextTripView: View {
    let nextTrip: (name: String, daysAway: Int)?

    var body: some View {
        VStack(spacing: 4) {
            if let trip = nextTrip {
                Text(trip.name)
                    .font(.custom("Nunito-Bold", size: 17))
                    .foregroundColor(Color(red: 0.25, green: 0.30, blue: 0.27))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(trip.daysAway == 0 ? "Today!" : "in \(trip.daysAway) day\(trip.daysAway == 1 ? "" : "s")")
                        .font(.custom("Nunito-Regular", size: 13))
                }
                .foregroundColor(Color(red: 0.95, green: 0.60, blue: 0.45))
            } else {
                Text("No trips planned")
                    .font(.custom("Nunito-Regular", size: 15))
                    .foregroundColor(Color(red: 0.25, green: 0.30, blue: 0.27).opacity(0.45))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.95, green: 0.60, blue: 0.45).opacity(0.10))
        )
    }
}

#Preview {
    LaunchScreenView()
        .environmentObject(AppDataStore())
}
