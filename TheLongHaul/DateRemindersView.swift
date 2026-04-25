import SwiftUI

struct DateRemindersView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var showingAdd = false
    @State private var reminderToEdit: DateReminder?

    var upcoming: [DateReminder] {
        store.dateReminders
            .filter { $0.isActive && $0.reminderDate >= Date() }
            .sorted { $0.reminderDate < $1.reminderDate }
    }

    var past: [DateReminder] {
        store.dateReminders
            .filter { $0.reminderDate < Date() }
            .sorted { $0.reminderDate > $1.reminderDate }
    }

    var body: some View {
        NavigationView {
            Group {
                if store.dateReminders.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "No Reminders",
                        message: "Add date-based reminders for seasonal tasks, renewals, or anything time-based."
                    )
                } else {
                    List {
                        if !upcoming.isEmpty {
                            Section("Upcoming") {
                                ForEach(upcoming) { reminder in
                                    ReminderRow(reminder: reminder)
                                        .contentShape(Rectangle())
                                        .onTapGesture { reminderToEdit = reminder }
                                }
                                .onDelete { indexSet in
                                    indexSet.map { upcoming[$0] }.forEach { store.deleteDateReminder($0) }
                                }
                            }
                        }
                        if !past.isEmpty {
                            Section("Past") {
                                ForEach(past) { reminder in
                                    ReminderRow(reminder: reminder)
                                        .contentShape(Rectangle())
                                        .onTapGesture { reminderToEdit = reminder }
                                }
                                .onDelete { indexSet in
                                    indexSet.map { past[$0] }.forEach { store.deleteDateReminder($0) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { AddEditReminderView(reminder: nil) }
            .sheet(item: $reminderToEdit) { reminder in AddEditReminderView(reminder: reminder) }
        }
    }
}

struct ReminderRow: View {
    var reminder: DateReminder

    var isPast: Bool { reminder.reminderDate < Date() }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPast ? "calendar.badge.exclamationmark" : "calendar.badge.clock")
                .foregroundColor(isPast ? .purple : .accentColor)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.headline)
                    .foregroundColor(isPast ? .secondary : .primary)
                if !reminder.notes.isEmpty {
                    Text(reminder.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(reminder.reminderDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(isPast ? .red : .secondary)
                    if reminder.repeatInterval != .none {
                        Text("· Repeats \(reminder.repeatInterval.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(reminder.isActive ? 1.0 : 0.5)
    }
}

struct AddEditReminderView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    var reminder: DateReminder?

    @State private var title = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var repeatInterval: DateReminder.ReminderRepeat = .none
    @State private var isActive = true

    var isEditing: Bool { reminder != nil }

    var body: some View {
        NavigationView {
            Form {
                Section("Reminder") {
                    TextField("Title (e.g. Renew registration, Winterize)", text: $title)
                    TextField("Notes (optional)", text: $notes)
                }
                Section("Date & Time") {
                    DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Repeats", selection: $repeatInterval) {
                        ForEach(DateReminder.ReminderRepeat.allCases, id: \.self) { interval in
                            Text(interval.rawValue).tag(interval)
                        }
                    }
                }
                if isEditing {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    }
                    Section {
                        Button("Delete Reminder", role: .destructive) {
                            store.deleteDateReminder(reminder!)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Reminder" : "New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard let r = reminder else { return }
        title = r.title; notes = r.notes; date = r.reminderDate
        repeatInterval = r.repeatInterval; isActive = r.isActive
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let updated = DateReminder(
            id: reminder?.id ?? UUID(),
            title: trimmed, notes: notes,
            reminderDate: date,
            repeatInterval: repeatInterval,
            isActive: isActive
        )
        if isEditing { store.updateDateReminder(updated) }
        else { store.addDateReminder(updated) }
        dismiss()
    }
}
