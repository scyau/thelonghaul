import SwiftUI
import UserNotifications

struct DashboardView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var selectedPlannedTrip: PlannedTrip?

    // Tasks where either km or date interval is overdue
    var dueTasks: [MaintenanceTaskType] {
        store.maintenanceTaskTypes.filter { store.isEitherDue(for: $0) }
    }

    // Tasks not yet overdue but within 1000 km or 30 days of due
    var upcomingTasks: [MaintenanceTaskType] {
        store.maintenanceTaskTypes.filter {
            !store.isEitherDue(for: $0) && store.isAnythingDueSoon(for: $0)
        }
    }

    var overdueReminders: [DateReminder] {
        store.dateReminders.filter { $0.isActive && $0.reminderDate < Date() }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Total km card
                    VStack(spacing: 6) {
                        Text("Total Trailer km")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(store.totalMiles.formatted(.number.precision(.fractionLength(0))))
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                        Text("\(store.trips.count) trip\(store.trips.count == 1 ? "" : "s") logged")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

                    // Notification settings
                    NotificationSettingsView()

                    // Next planned trip banner — tappable to open detail
                    if let next = store.nextPlannedTrip {
                        NextTripBanner(trip: next)
                            .onTapGesture { selectedPlannedTrip = next }
                    }

                    // Active trip banner
                    if let active = store.activeTrip {
                        ActiveTripBanner(trip: active)
                    }

                    // Overdue date reminders
                    if !overdueReminders.isEmpty {
                        SectionCard(title: "Reminders Overdue", color: .purple) {
                            ForEach(overdueReminders) { reminder in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reminder.title)
                                            .font(.subheadline.weight(.medium))
                                        Text(reminder.reminderDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .foregroundColor(.purple)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                Divider().padding(.horizontal)
                            }
                        }
                    }

                    // Due now
                    if !dueTasks.isEmpty {
                        SectionCard(title: "Due Now", color: .red) {
                            ForEach(dueTasks) { task in
                                MaintenanceStatusRow(task: task)
                            }
                        }
                    }

                    // Coming up
                    if !upcomingTasks.isEmpty {
                        SectionCard(title: "Coming Up", color: .orange) {
                            ForEach(upcomingTasks) { task in
                                MaintenanceStatusRow(task: task)
                            }
                        }
                    }

                    if dueTasks.isEmpty && upcomingTasks.isEmpty && overdueReminders.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("All caught up!")
                                    .font(.headline)
                                Text("No maintenance due soon.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("The Long Haul")
            .sheet(item: $selectedPlannedTrip) { trip in
                PlannedTripDetailView(trip: trip)
            }
        }
    }
}

// MARK: - Next Trip Banner
struct NextTripBanner: View {
    var trip: PlannedTrip

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Next Trip", systemImage: "tent.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
                Text(trip.name)
                    .font(.headline)
                if !trip.location.isEmpty {
                    Text(trip.location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) · \(trip.nights) night\(trip.nights == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(trip.daysUntil)")
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundColor(.green)
                Text("days away")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.25), lineWidth: 1))
        .cornerRadius(16)
        // Indicate tappability
        .contentShape(Rectangle())
    }
}

// MARK: - Active Trip Banner
struct ActiveTripBanner: View {
    var trip: Trip

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Trip in Progress", systemImage: "location.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
                Text(trip.name.isEmpty ? "Unnamed Trip" : trip.name)
                    .font(.headline)
                Text("Started at \(trip.startOdometer.formatted(.number.precision(.fractionLength(0)))) km")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.25), lineWidth: 1))
        .cornerRadius(16)
    }
}

// MARK: - Section Card
struct SectionCard<Content: View>: View {
    var title: String
    var color: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(color)
            }
            .padding(.horizontal)
            .padding(.top, 14)
            .padding(.bottom, 8)
            Divider().padding(.horizontal)
            content
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Maintenance Status Row
struct MaintenanceStatusRow: View {
    @EnvironmentObject var store: AppDataStore
    var task: MaintenanceTaskType

    var hasKm: Bool { task.intervalMiles > 0 }
    var hasDate: Bool { task.intervalMonths > 0 }

    var milesSince: Double { store.milesSinceLastService(for: task) }
    var milesUntil: Double { max(0, task.intervalMiles - milesSince) }
    var kmProgress: Double { store.progressFraction(for: task) }
    var kmDue: Bool { store.isDue(for: task) }

    var dateDue: Bool { store.isDateDue(for: task) }
    var daysLeft: Int { store.daysUntilNextService(for: task) ?? 0 }
    var nextServiceDate: Date? { store.nextServiceDate(for: task) }

    var isOverdue: Bool { store.isEitherDue(for: task) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.name).font(.subheadline.weight(.medium))
                Spacer()
                if isOverdue {
                    Text("OVERDUE")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.red).cornerRadius(6)
                } else if hasKm {
                    Text("\(Int(milesUntil)) km left")
                        .font(.caption).foregroundColor(.secondary)
                } else if hasDate, let next = nextServiceDate {
                    Text("Due \(next.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // km progress bar (only if task has a km interval)
            if hasKm {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(.systemFill)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(kmDue ? Color.red : Color.orange)
                            .frame(width: geo.size.width * kmProgress, height: 6)
                    }
                }
                .frame(height: 6)
                Text("\(Int(milesSince)) / \(Int(task.intervalMiles)) km since last service")
                    .font(.caption2).foregroundColor(.secondary)
            }

            // Date subtitle (only if task has a date interval and no km interval shown)
            if hasDate && !hasKm {
                if let last = store.lastServiceDate(for: task) {
                    Text("Last serviced \(last.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2).foregroundColor(.secondary)
                } else {
                    Text("No service date recorded")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal).padding(.vertical, 10)
        Divider().padding(.horizontal)
    }
}
