import SwiftUI

struct MaintenanceLogView: View {
    @EnvironmentObject var store: AppDataStore

    var groupedEntries: [(String, [MaintenanceEntry])] {
        let sorted = store.maintenanceLog.sorted { $0.date > $1.date }
        let grouped = Dictionary(grouping: sorted) { entry in
            entry.date.formatted(.dateTime.year().month(.wide))
        }
        return grouped.sorted { a, b in
            let dateA = store.maintenanceLog.first(where: {
                $0.date.formatted(.dateTime.year().month(.wide)) == a.key
            })?.date ?? .distantPast
            let dateB = store.maintenanceLog.first(where: {
                $0.date.formatted(.dateTime.year().month(.wide)) == b.key
            })?.date ?? .distantPast
            return dateA > dateB
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if store.maintenanceLog.isEmpty {
                    EmptyStateView(
                        icon: "list.clipboard",
                        title: "No Service Logged",
                        message: "Log your first service from the Maintenance tab."
                    )
                } else {
                    List {
                        ForEach(groupedEntries, id: \.0) { month, entries in
                            Section(month) {
                                ForEach(entries) { entry in
                                    MaintenanceLogRow(entry: entry)
                                }
                                .onDelete { indexSet in
                                    indexSet.map { entries[$0] }.forEach { store.deleteMaintenanceEntry($0) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Service History")
        }
    }
}

struct MaintenanceLogRow: View {
    var entry: MaintenanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.taskTypeName)
                    .font(.headline)
                Spacer()
                if let cost = entry.cost {
                    Text("CA$\(cost, specifier: "%.0f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("·")
                    .foregroundColor(.secondary)
                Text("\(Int(entry.mileageAtService).formatted()) km")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

struct LogServiceView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    var taskType: MaintenanceTaskType

    @State private var date: Date = Date()
    @State private var mileageAtService: String = ""
    @State private var notes: String = ""
    @State private var cost: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Service") {
                    HStack {
                        Text(taskType.name)
                            .font(.headline)
                        Spacer()
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Mileage") {
                    HStack {
                        Text("Trailer km")
                        Spacer()
                        TextField(store.totalMiles == 0 ? "total km" : String(Int(store.totalMiles)), text: $mileageAtService)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if mileageAtService.isEmpty {
                        Text("Leave blank to use current total (\(Int(store.totalMiles).formatted()) km)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Details (optional)") {
                    HStack {
                        Text("Cost")
                        Spacer()
                        HStack(spacing: 2) {
                            Text("CA$").foregroundColor(.secondary)
                            TextField("0", text: $cost)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Log Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    private func save() {
        let mileage = Double(mileageAtService) ?? store.totalMiles
        let entry = MaintenanceEntry(
            taskTypeId: taskType.id,
            taskTypeName: taskType.name,
            mileageAtService: mileage,
            date: date,
            notes: notes,
            cost: Double(cost)
        )
        store.addMaintenanceEntry(entry)
        dismiss()
    }
}

// MARK: - Shared Empty State
struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
