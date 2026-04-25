import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var showingAddItem = false
    @State private var showingResetConfirm = false
    @State private var isEditing = false

    var checkedCount: Int { store.checklistItems.filter { $0.isChecked }.count }
    var total: Int { store.checklistItems.count }
    var allDone: Bool { total > 0 && checkedCount == total }

    var body: some View {
        NavigationView {
            List {
                // Progress header
                Section {
                    VStack(spacing: 10) {
                        HStack {
                            Text(allDone ? "Ready to roll! 🎉" : "\(checkedCount) of \(total) checked")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(allDone ? .green : .primary)
                            Spacer()
                            Button("Reset All") { showingResetConfirm = true }
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemFill))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(allDone ? Color.green : Color.accentColor)
                                    .frame(width: total > 0 ? geo.size.width * Double(checkedCount) / Double(total) : 0, height: 8)
                                    .animation(.easeInOut(duration: 0.3), value: checkedCount)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.vertical, 6)
                }

                // Checklist items
                Section {
                    ForEach(store.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                        ChecklistRow(item: item)
                    }
                    .onMove { store.moveChecklistItems(from: $0, to: $1) }
                    .onDelete { indexSet in
                        let sorted = store.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder })
                        indexSet.map { sorted[$0] }.forEach { store.deleteChecklistItem($0) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pre-Trip Checklist")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddChecklistItemView()
            }
            .confirmationDialog("Reset all items?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
                Button("Reset All", role: .destructive) { store.resetChecklist() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will uncheck all items so you can run through the checklist again.")
            }
        }
    }
}

struct ChecklistRow: View {
    @EnvironmentObject var store: AppDataStore
    var item: ChecklistItem

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { store.toggleChecklistItem(item) }) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isChecked ? .green : Color(.systemGray3))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.body)
                .foregroundColor(item.isChecked ? .secondary : .primary)
                .strikethrough(item.isChecked, color: .secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AddChecklistItemView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            Form {
                Section("Item") {
                    TextField("e.g. Check tire pressure", text: $title)
                        .focused($focused)
                }
            }
            .navigationTitle("New Checklist Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let order = store.checklistItems.count
                        store.addChecklistItem(ChecklistItem(title: title.trimmingCharacters(in: .whitespaces), sortOrder: order))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}
