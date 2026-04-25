import SwiftUI

struct MoreView: View {
    @EnvironmentObject var store: AppDataStore

    @State private var destination: MoreDestination? = nil

    var openNotes: Int { store.notes.filter { !$0.isResolved }.count }
    var campsitesVisited: Int { store.campsiteReviews.count }
    var totalCampsites: Int { loadCampsites().count }
    var uncheckedTodos: Int { store.checklistItems.filter { !$0.isChecked }.count }
    var overdueReminders: Int { store.dateReminders.filter { $0.isActive && $0.reminderDate < Date() }.count }
    var unpackedItems: Int { store.packingItems.filter { !$0.isPacked }.count }

    enum MoreDestination: String, Identifiable {
        case campsites, checklist, packingList, reminders, history, notes, stats, profile
        var id: String { rawValue }

        var title: String {
            switch self {
            case .campsites:   return "Campsites"
            case .checklist:   return "Checklist"
            case .packingList: return "Packing List"
            case .reminders:   return "Reminders"
            case .history:     return "Service History"
            case .notes:       return "Notes"
            case .stats:       return "Trip Stats"
            case .profile:     return "Trailer Profile"
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    MoreRow(icon: "map", color: .teal, title: "Campsites",
                            badge: campsitesVisited > 0 ? "\(campsitesVisited)/\(totalCampsites) visited" : nil)
                        .contentShape(Rectangle())
                        .onTapGesture { destination = .campsites }

                    MoreRow(icon: "checklist", color: .blue, title: "Checklist",
                            badge: uncheckedTodos > 0 ? "\(uncheckedTodos) left" : nil)
                        .contentShape(Rectangle())
                        .onTapGesture { destination = .checklist }

                    MoreRow(icon: "backpack", color: .teal, title: "Packing List",
                            badge: unpackedItems > 0 ? "\(unpackedItems) left" : nil)
                        .contentShape(Rectangle())
                        .onTapGesture { destination = .packingList }

                    MoreRow(icon: "calendar.badge.clock", color: .purple, title: "Reminders",
                            badge: overdueReminders > 0 ? "\(overdueReminders) overdue" : nil,
                            badgeColor: overdueReminders > 0 ? .red : .secondary)
                        .contentShape(Rectangle())
                        .onTapGesture { destination = .reminders }

                    MoreRow(icon: "list.clipboard", color: .orange, title: "Service History")
                        .contentShape(Rectangle())
                        .onTapGesture { destination = .history }

                    MoreRow(icon: "note.text", color: .yellow, title: "Notes",
                            badge: openNotes > 0 ? "\(openNotes) open" : nil)
                        .contentShape(Rectangle())
                        .onTapGesture { destination = .notes }

                    MoreRow(icon: "chart.bar", color: .green, title: "Trip Stats")
                        .contentShape(Rectangle())
                        .onTapGesture { destination = .stats }

                    MoreRow(icon: "car.rear", color: .brown, title: "Trailer Profile")
                        .contentShape(Rectangle())
                        .onTapGesture { destination = .profile }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
        }
        .sheet(item: $destination) { dest in
            MoreSheetWrapper(title: dest.title) {
                switch dest {
                case .campsites:   CampsiteMapView()
                case .checklist:   ChecklistView()
                case .packingList: PackingListView()
                case .reminders:   DateRemindersView()
                case .history:     MaintenanceLogView()
                case .notes:       NotesView()
                case .stats:       TripStatsView()
                case .profile:     TrailerProfileView()
                }
            }
        }
    }
}

// MARK: - Sheet wrapper with drag handle + Done button
struct MoreSheetWrapper<Content: View>: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle + header bar
            VStack(spacing: 8) {
                // Pill handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)

                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemGroupedBackground))

            Divider()

            // The actual view content
            content
        }
    }
}

// MARK: - Row
struct MoreRow: View {
    var icon: String
    var color: Color
    var title: String
    var badge: String? = nil
    var badgeColor: Color = .secondary

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            Text(title)
                .font(.body)
            Spacer()
            if let badge = badge {
                Text(badge)
                    .font(.caption)
                    .foregroundColor(badgeColor)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.vertical, 4)
    }
}
