import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var showingAddTask = false
    @State private var taskToEdit: MaintenanceTaskType?
    @State private var logTaskType: MaintenanceTaskType?
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            List {
                ForEach(store.maintenanceTaskTypes) { task in
                    MaintenanceTaskCard(task: task, onLogService: {
                        logTaskType = task
                    })
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Edit Task") { taskToEdit = task }
                        Button("Delete Task", role: .destructive) {
                            store.deleteTaskType(task)
                        }
                    }
                }
                .onMove { store.moveTaskTypes(from: $0, to: $1) }
                .onDelete { indexSet in
                    indexSet.map { store.maintenanceTaskTypes[$0] }.forEach { store.deleteTaskType($0) }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .navigationTitle("Maintenance")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation { isEditing.toggle() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddEditTaskTypeView(task: nil)
            }
            .sheet(item: $taskToEdit) { task in
                AddEditTaskTypeView(task: task)
            }
            .sheet(item: $logTaskType) { task in
                LogServiceView(taskType: task)
            }
        }
    }
}

// MARK: - Task Card
struct MaintenanceTaskCard: View {
    @EnvironmentObject var store: AppDataStore
    var task: MaintenanceTaskType
    var onLogService: () -> Void

    var hasKm: Bool { task.intervalMiles > 0 }
    var hasDate: Bool { task.intervalMonths > 0 }
    var isManual: Bool { !hasKm && !hasDate }

    // km status
    var milesSince: Double { store.milesSinceLastService(for: task) }
    var kmProgress: Double { store.progressFraction(for: task) }
    var kmDue: Bool { store.isDue(for: task) }
    var kmApproaching: Bool { store.isApproachingDue(for: task) }
    var kmLeft: Int { Int(max(0, task.intervalMiles - milesSince)) }

    // date status
    var dateDue: Bool { store.isDateDue(for: task) }
    var dateApproaching: Bool { store.isDateApproaching(for: task) }
    var dateProgress: Double { store.dateProgressFraction(for: task) }
    var daysLeft: Int { store.daysUntilNextService(for: task) ?? 0 }
    var nextServiceDate: Date? { store.nextServiceDate(for: task) }

    // overall worst-case status colour
    var statusColor: Color {
        if kmDue || dateDue { return .red }
        if kmApproaching || dateApproaching { return .orange }
        return .green
    }

    var lastService: MaintenanceEntry? {
        store.maintenanceLog
            .filter { $0.taskTypeId == task.id }
            .sorted { $0.date > $1.date }
            .first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Title row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name).font(.headline)
                    // Interval subtitle
                    if isManual {
                        Text("Manual / seasonal")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        let parts = [
                            hasKm ? "Every \(Int(task.intervalMiles).formatted()) km" : nil,
                            hasDate ? "Every \(monthLabel(task.intervalMonths))" : nil
                        ].compactMap { $0 }
                        Text(parts.joined(separator: " · "))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                // Status badge (worst of the two)
                if kmDue || dateDue {
                    Text("OVERDUE")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.red).cornerRadius(6)
                }
            }

            // ── km progress bar ──
            if hasKm {
                VStack(spacing: 4) {
                    HStack {
                        Label("km", systemImage: "road.lanes")
                            .font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text(kmDue ? "Overdue" : "\(kmLeft) km left")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(kmDue ? .red : kmApproaching ? .orange : .secondary)
                    }
                    ProgressBar(value: kmProgress, color: kmDue ? .red : kmApproaching ? .orange : .green)
                    HStack {
                        if let last = lastService {
                            Text("Last \(last.date.formatted(date: .abbreviated, time: .omitted)) · \(Int(last.mileageAtService).formatted()) km")
                                .font(.caption2).foregroundColor(.secondary)
                        } else {
                            Text("No service logged")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(Int(milesSince).formatted()) / \(Int(task.intervalMiles).formatted()) km")
                            .font(.caption2.monospacedDigit()).foregroundColor(.secondary)
                    }
                }
            }

            // ── date progress bar ──
            if hasDate {
                VStack(spacing: 4) {
                    HStack {
                        Label("Time", systemImage: "calendar")
                            .font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        if dateDue {
                            Text("Overdue")
                                .font(.caption2.weight(.medium)).foregroundColor(.red)
                        } else if let next = nextServiceDate {
                            Text("Due \(next.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(dateApproaching ? .orange : .secondary)
                        }
                    }
                    ProgressBar(value: dateProgress, color: dateDue ? .red : dateApproaching ? .orange : .green)
                    HStack {
                        if let last = store.lastServiceDate(for: task) {
                            Text("Last \(last.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2).foregroundColor(.secondary)
                        } else {
                            Text("No service date recorded")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        if !dateDue, let days = store.daysUntilNextService(for: task) {
                            Text("\(days) day\(days == 1 ? "" : "s") away")
                                .font(.caption2.monospacedDigit()).foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Notes
            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.caption).foregroundColor(.secondary).italic()
            }

            // Log service button
            Button(action: onLogService) {
                Text("Log Service")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func monthLabel(_ months: Int) -> String {
        if months == 12 { return "year" }
        if months == 6 { return "6 months" }
        if months == 3 { return "3 months" }
        if months == 1 { return "month" }
        return "\(months) months"
    }
}

// MARK: - Shared progress bar
struct ProgressBar: View {
    var value: Double  // 0–1
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(height: 7)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * min(1, max(0, value)), height: 7)
                    .animation(.easeInOut(duration: 0.4), value: value)
            }
        }
        .frame(height: 7)
    }
}

// MARK: - Add / Edit Task
struct AddEditTaskTypeView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    var task: MaintenanceTaskType?

    @State private var name: String = ""
    @State private var intervalMiles: String = ""
    @State private var intervalMonths: String = ""
    @State private var lastServiceDate: Date = Date()
    @State private var hasLastServiceDate: Bool = false
    @State private var notes: String = ""

    var isEditing: Bool { task != nil }

    // Convenience month options
    let monthOptions: [(String, Int)] = [
        ("None", 0), ("1 month", 1), ("3 months", 3),
        ("6 months", 6), ("1 year", 12), ("2 years", 24)
    ]
    @State private var selectedMonthOption: Int = 0

    var body: some View {
        NavigationView {
            Form {
                Section("Task") {
                    TextField("Task name", text: $name)
                }

                Section {
                    HStack {
                        TextField("km (leave blank if none)", text: $intervalMiles)
                            .keyboardType(.numberPad)
                        Text("km").foregroundColor(.secondary)
                    }
                } header: {
                    Text("km Interval")
                } footer: {
                    Text("Triggers when this many km have passed since last service.")
                }

                Section {
                    Picker("Repeat every", selection: $selectedMonthOption) {
                        ForEach(monthOptions, id: \.1) { label, months in
                            Text(label).tag(months)
                        }
                    }
                    if selectedMonthOption > 0 {
                        Toggle("Set last service date", isOn: $hasLastServiceDate)
                        if hasLastServiceDate {
                            DatePicker("Last serviced", selection: $lastServiceDate, in: ...Date(), displayedComponents: .date)
                        }
                    }
                } header: {
                    Text("Date Interval")
                } footer: {
                    Text("Triggers when this much time has passed since last service.")
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard let t = task else { return }
        name = t.name
        intervalMiles = t.intervalMiles == 0 ? "" : String(Int(t.intervalMiles))
        notes = t.notes
        selectedMonthOption = t.intervalMonths
        if let d = t.lastServiceDate {
            hasLastServiceDate = true
            lastServiceDate = d
        }
    }

    private func save() {
        let interval = Double(intervalMiles) ?? 0
        let updated = MaintenanceTaskType(
            intervalMonths: selectedMonthOption,
            lastServiceDate: (selectedMonthOption > 0 && hasLastServiceDate) ? lastServiceDate : nil,
            id: task?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            intervalMiles: interval,
            notes: notes
        )
        if isEditing { store.updateTaskType(updated) }
        else { store.addTaskType(updated) }
        dismiss()
    }
}
