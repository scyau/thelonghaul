import SwiftUI

struct PackingListView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var showingAddItem = false
    @State private var itemToEdit: PackingItem?
    @State private var showingResetConfirm = false
    @State private var collapsedCategories: Set<PackingItem.PackingCategory> = []

    var packedCount: Int { store.packingItems.filter { $0.isPacked }.count }
    var total: Int { store.packingItems.count }
    var allPacked: Bool { total > 0 && packedCount == total }

    var usedCategories: [PackingItem.PackingCategory] {
        let used = Set(store.packingItems.map { $0.category })
        return PackingItem.PackingCategory.allCases.filter { used.contains($0) }
    }

    func items(for category: PackingItem.PackingCategory) -> [PackingItem] {
        store.packingItems
            .filter { $0.category == category }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationView {
            Group {
                if store.packingItems.isEmpty {
                    EmptyStateView(
                        icon: "backpack",
                        title: "Packing List Empty",
                        message: "Add items to pack for your next trip. Tap + to get started."
                    )
                } else {
                    List {
                        // Progress header
                        Section {
                            VStack(spacing: 10) {
                                HStack {
                                    Text(allPacked ? "All packed! 🎉" : "\(packedCount) of \(total) packed")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(allPacked ? .green : .primary)
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
                                            .fill(allPacked ? Color.green : Color.accentColor)
                                            .frame(
                                                width: total > 0
                                                    ? geo.size.width * Double(packedCount) / Double(total)
                                                    : 0,
                                                height: 8
                                            )
                                            .animation(.easeInOut(duration: 0.3), value: packedCount)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding(.vertical, 6)
                        }

                        // Category sections
                        ForEach(usedCategories, id: \.self) { category in
                            let categoryItems = items(for: category)
                            let isCollapsed = collapsedCategories.contains(category)
                            let packedInCategory = categoryItems.filter { $0.isPacked }.count

                            Section {
                                // Category header row
                                Button(action: {
                                    withAnimation {
                                        if isCollapsed {
                                            collapsedCategories.remove(category)
                                        } else {
                                            collapsedCategories.insert(category)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(category.color.opacity(0.15))
                                                .frame(width: 28, height: 28)
                                            Image(systemName: category.icon)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(category.color)
                                        }
                                        Text(category.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(packedInCategory)/\(categoryItems.count)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                if !isCollapsed {
                                    ForEach(categoryItems) { item in
                                        PackingItemRow(item: item)
                                            .contentShape(Rectangle())
                                            .onTapGesture { itemToEdit = item }
                                    }
                                    .onDelete { indexSet in
                                        indexSet.map { categoryItems[$0] }.forEach { store.deletePackingItem($0) }
                                    }
                                    .onMove { source, destination in
                                        store.movePackingItems(in: category, from: source, to: destination)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Packing List")
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
                AddEditPackingItemView(item: nil)
            }
            .sheet(item: $itemToEdit) { item in
                AddEditPackingItemView(item: item)
            }
            .confirmationDialog("Reset packing list?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
                Button("Reset All", role: .destructive) { store.resetPackingList() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will unpack all items so you can pack fresh for your next trip.")
            }
        }
    }
}

// MARK: - Packing Item Row
struct PackingItemRow: View {
    @EnvironmentObject var store: AppDataStore
    var item: PackingItem

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { store.togglePackingItem(item) }) {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isPacked ? .green : Color(.systemGray3))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.body)
                .foregroundColor(item.isPacked ? .secondary : .primary)
                .strikethrough(item.isPacked, color: .secondary)

            Spacer()

            if item.quantity > 1 {
                Text("×\(item.quantity)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemFill))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add / Edit Packing Item
struct AddEditPackingItemView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    var item: PackingItem?

    @State private var title: String = ""
    @State private var category: PackingItem.PackingCategory = .other
    @State private var quantity: Int = 1
    @FocusState private var isFocused: Bool

    var isEditing: Bool { item != nil }

    var body: some View {
        NavigationView {
            Form {
                Section("Item") {
                    TextField("e.g. Camp chairs, Headlamp...", text: $title)
                        .focused($isFocused)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(PackingItem.PackingCategory.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                    .foregroundColor(cat.color)
                                Text(cat.rawValue)
                            }
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Quantity") {
                    Stepper("\(quantity)", value: $quantity, in: 1...99)
                }

                if isEditing {
                    Section {
                        Button("Delete Item", role: .destructive) {
                            if let item = item { store.deletePackingItem(item) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let item = item {
                    title = item.title
                    category = item.category
                    quantity = item.quantity
                }
                isFocused = true
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if var existing = item {
            existing.title = trimmed
            existing.category = category
            existing.quantity = quantity
            store.updatePackingItem(existing)
        } else {
            let sortOrder = store.packingItems.filter { $0.category == category }.count
            var newItem = PackingItem(title: trimmed, category: category, quantity: quantity, sortOrder: sortOrder)
            store.addPackingItem(newItem)
        }
        dismiss()
    }
}
