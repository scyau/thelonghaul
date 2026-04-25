import SwiftUI
import PhotosUI

struct NotesView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var showingAddNote = false
    @State private var noteToEdit: NoteItem?
    @State private var showResolved = false

    var openNotes: [NoteItem] {
        store.notes
            .filter { !$0.isResolved }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    var resolvedNotes: [NoteItem] {
        store.notes.filter { $0.isResolved }
    }

    var body: some View {
        NavigationView {
            Group {
                if store.notes.isEmpty {
                    EmptyStateView(
                        icon: "note.text",
                        title: "No Notes Yet",
                        message: "Jot down things to fix, check, or remember about your trailer."
                    )
                } else {
                    List {
                        if !openNotes.isEmpty {
                            Section("To Do (\(openNotes.count))") {
                                ForEach(openNotes) { note in
                                    NoteRow(note: note)
                                        .contentShape(Rectangle())
                                        .onTapGesture { noteToEdit = note }
                                }
                                .onDelete { indexSet in
                                    indexSet.map { openNotes[$0] }.forEach { store.deleteNote($0) }
                                }
                            }
                        }

                        if !resolvedNotes.isEmpty {
                            Section {
                                Button(action: { withAnimation { showResolved.toggle() } }) {
                                    HStack {
                                        Text("Resolved (\(resolvedNotes.count))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Image(systemName: showResolved ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                if showResolved {
                                    ForEach(resolvedNotes) { note in
                                        NoteRow(note: note)
                                            .contentShape(Rectangle())
                                            .onTapGesture { noteToEdit = note }
                                    }
                                    .onDelete { indexSet in
                                        indexSet.map { resolvedNotes[$0] }.forEach { store.deleteNote($0) }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddNote = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddNote) {
                AddEditNoteView(note: nil)
            }
            .sheet(item: $noteToEdit) { note in
                AddEditNoteView(note: note)
            }
        }
    }
}

// MARK: - Note Row
struct NoteRow: View {
    @EnvironmentObject var store: AppDataStore
    var note: NoteItem
    @State private var fullscreenPhoto: UIImage? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { store.toggleResolved(note) }) {
                Image(systemName: note.isResolved ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(note.isResolved ? .green : Color(.systemGray3))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(note.text)
                    .font(.body)
                    .foregroundColor(note.isResolved ? .secondary : .primary)
                    .strikethrough(note.isResolved, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Photo thumbnails
                if !note.photoFilenames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(note.photoFilenames, id: \.self) { filename in
                                if let img = PhotoStorage.load(filename: filename) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onTapGesture { fullscreenPhoto = img }
                                }
                            }
                        }
                    }
                }

                HStack {
                    Text(note.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if !note.photoFilenames.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Label("\(note.photoFilenames.count)", systemImage: "photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if !note.isResolved {
                Button(action: {
                    var updated = note
                    updated.priority = note.priority.next
                    store.updateNote(updated)
                }) {
                    Image(systemName: note.priority == .none ? "flag" : "flag.fill")
                        .font(.subheadline)
                        .foregroundColor(note.priority.color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .fullScreenCover(item: Binding(
            get: { fullscreenPhoto.map { IdentifiableImage(image: $0) } },
            set: { fullscreenPhoto = $0?.image }
        )) { identifiable in
            FullscreenPhotoView(image: identifiable.image)
        }
    }
}

// MARK: - Add / Edit Note
struct AddEditNoteView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    var note: NoteItem?

    @State private var text: String = ""
    @State private var priority: NoteItem.NotePriority = .none
    @State private var photoFilenames: [String] = []
    @State private var pendingImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var fullscreenPhoto: UIImage? = nil
    @FocusState private var isFocused: Bool

    var isEditing: Bool { note != nil }

    var body: some View {
        NavigationView {
            Form {
                Section("Note") {
                    TextField("e.g. Replace door latch, check tire pressure...", text: $text, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($isFocused)
                }

                Section("Priority") {
                    HStack(spacing: 0) {
                        ForEach(NoteItem.NotePriority.allCases, id: \.self) { level in
                            Button(action: { priority = level }) {
                                HStack(spacing: 6) {
                                    Image(systemName: level == .none ? "flag" : "flag.fill")
                                        .foregroundColor(priority == level ? level.color : Color(.systemGray3))
                                    Text(level.label)
                                        .font(.subheadline)
                                        .foregroundColor(priority == level ? level.color : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(priority == level ? level.color.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Photos") {
                    // Existing saved photos
                    let allImages: [(String?, UIImage)] = photoFilenames.compactMap { fn in
                        guard let img = PhotoStorage.load(filename: fn) else { return nil }
                        return (fn, img)
                    } + pendingImages.map { (nil, $0) }

                    if !allImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(allImages.enumerated()), id: \.offset) { idx, pair in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: pair.1)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 90, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onTapGesture { fullscreenPhoto = pair.1 }

                                        Button(action: { removeImage(at: idx, filename: pair.0) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.6).clipShape(Circle()))
                                                .font(.title3)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("Add Photos", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedItems) { items in
                        loadSelectedPhotos(items)
                    }
                }

                if isEditing, let note = note {
                    Section {
                        HStack {
                            Text("Added")
                            Spacer()
                            Text(note.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                        Button(note.isResolved ? "Mark as Open" : "Mark as Resolved") {
                            store.toggleResolved(note)
                            dismiss()
                        }
                        .foregroundColor(note.isResolved ? .orange : .green)
                    }

                    Section {
                        Button("Delete Note", role: .destructive) {
                            store.deleteNote(note)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let note = note {
                    text = note.text
                    priority = note.priority
                    photoFilenames = note.photoFilenames
                }
                isFocused = true
            }
            .fullScreenCover(item: Binding(
                get: { fullscreenPhoto.map { IdentifiableImage(image: $0) } },
                set: { fullscreenPhoto = $0?.image }
            )) { identifiable in
                FullscreenPhotoView(image: identifiable.image)
            }
        }
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    if case .success(let data) = result, let data = data, let img = UIImage(data: data) {
                        pendingImages.append(img)
                    }
                    selectedItems = []
                }
            }
        }
    }

    private func removeImage(at index: Int, filename: String?) {
        let savedCount = photoFilenames.count
        if index < savedCount {
            // It's a saved photo — remove from disk and filenames list
            if let fn = filename {
                PhotoStorage.delete(filename: fn)
                photoFilenames.removeAll { $0 == fn }
            }
        } else {
            // It's a pending (unsaved) image
            let pendingIndex = index - savedCount
            if pendingIndex < pendingImages.count {
                pendingImages.remove(at: pendingIndex)
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Save any pending images to disk
        var allFilenames = photoFilenames
        for img in pendingImages {
            let filename = PhotoStorage.newFilename()
            PhotoStorage.save(img, filename: filename)
            allFilenames.append(filename)
        }

        if var existing = note {
            existing.text = trimmed
            existing.priority = priority
            existing.photoFilenames = allFilenames
            store.updateNote(existing)
        } else {
            var newNote = NoteItem(text: trimmed)
            newNote.priority = priority
            newNote.photoFilenames = allFilenames
            store.addNote(newNote)
        }
        dismiss()
    }
}

// MARK: - Fullscreen Photo Viewer
struct FullscreenPhotoView: View {
    var image: UIImage
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

// MARK: - Identifiable wrapper for UIImage
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
