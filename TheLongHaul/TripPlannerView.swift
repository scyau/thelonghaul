import SwiftUI
import PhotosUI
import WeatherKit
import CoreLocation
import MapKit
import Combine

// MARK: - Maps helper (global so all views can call it)
func openInMaps(_ location: String) {
    let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    if let googleURL = URL(string: "comgooglemaps://?q=\(encoded)"),
       UIApplication.shared.canOpenURL(googleURL) {
        UIApplication.shared.open(googleURL)
    } else if let appleMapsURL = URL(string: "https://maps.apple.com/?q=\(encoded)") {
        UIApplication.shared.open(appleMapsURL)
    }
}

// MARK: - Trip Planner List
struct TripPlannerView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var showingAdd = false
    @State private var selectedTrip: PlannedTrip?

    var upcoming: [PlannedTrip] {
        store.plannedTrips
            .filter { $0.status == .upcoming }
            .sorted { $0.startDate < $1.startDate }
    }

    var past: [PlannedTrip] {
        store.plannedTrips
            .filter { $0.status != .upcoming }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationView {
            Group {
                if store.plannedTrips.isEmpty {
                    EmptyStateView(
                        icon: "tent",
                        title: "No Trips Planned",
                        message: "Add upcoming camping trips to track reservations, dates, and pre-trip tasks."
                    )
                } else {
                    List {
                        if !upcoming.isEmpty {
                            Section("Upcoming") {
                                ForEach(upcoming) { trip in
                                    PlannedTripRow(trip: trip)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedTrip = trip }
                                }
                                .onDelete { indexSet in
                                    indexSet.map { upcoming[$0] }.forEach { store.deletePlannedTrip($0) }
                                }
                            }
                        }
                        if !past.isEmpty {
                            Section("Past") {
                                ForEach(past) { trip in
                                    PlannedTripRow(trip: trip)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedTrip = trip }
                                }
                                .onDelete { indexSet in
                                    indexSet.map { past[$0] }.forEach { store.deletePlannedTrip($0) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Trip Planner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                EditPlannedTripView(trip: nil)
            }
            .sheet(item: $selectedTrip) { trip in
                PlannedTripDetailView(trip: trip)
            }
        }
    }
}

// MARK: - Planned Trip Row
struct PlannedTripRow: View {
    var trip: PlannedTrip

    var statusColor: Color {
        switch trip.status {
        case .upcoming: return trip.isPast ? .secondary : .green
        case .completed: return .blue
        case .cancelled: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trip.name)
                        .font(.headline)
                    if trip.status != .upcoming {
                        Text(trip.status.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(statusColor)
                            .cornerRadius(5)
                    }
                }
                if !trip.location.isEmpty {
                    Button(action: { openInMaps(trip.location) }) {
                        Label(trip.location, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if trip.status == .upcoming && !trip.isPast {
                    Text("\(trip.daysUntil)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundColor(.green)
                    Text("days away")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(trip.nights)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundColor(.secondary)
                    Text("night\(trip.nights == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Planned Trip Detail
struct PlannedTripDetailView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss
    @State private var showingEdit = false
    @State private var fullscreenPhoto: UIImage? = nil

    // Use a live binding to always show current data
    var trip: PlannedTrip {
        store.plannedTrips.first(where: { $0.id == tripId }) ?? originalTrip
    }

    let tripId: UUID
    let originalTrip: PlannedTrip

    init(trip: PlannedTrip) {
        self.tripId = trip.id
        self.originalTrip = trip
    }

    var todoChecked: Int { trip.todos.filter { $0.isChecked }.count }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Header card
                    VStack(spacing: 6) {
                        Text(trip.name)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        if !trip.location.isEmpty {
                            Button(action: { openInMaps(trip.location) }) {
                                Label(trip.location, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                        HStack(spacing: 20) {
                            VStack(spacing: 2) {
                                Text(trip.startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline.weight(.medium))
                                Text("Arrival")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            VStack(spacing: 2) {
                                Text(trip.endDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline.weight(.medium))
                                Text("Departure")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)

                        if trip.status == .upcoming && !trip.isPast {
                            Text("\(trip.daysUntil) days away · \(trip.nights) night\(trip.nights == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

                    // Weather forecast (only for upcoming trips with a location)
                    if trip.status == .upcoming {
                        TripWeatherView(trip: trip)
                    }

                    // Reservation info
                    let hasReservation = !trip.campsiteName.isEmpty || !trip.siteNumber.isEmpty || !trip.confirmationNumber.isEmpty
                    if hasReservation || !trip.receiptPhotoFilenames.isEmpty {
                        DetailCard(title: "Reservation", icon: "building.2") {
                            VStack(spacing: 0) {
                                if !trip.campsiteName.isEmpty {
                                    DetailRow(label: "Campsite", value: trip.campsiteName)
                                    Divider().padding(.horizontal)
                                }
                                if !trip.siteNumber.isEmpty {
                                    DetailRow(label: "Site #", value: trip.siteNumber)
                                    Divider().padding(.horizontal)
                                }
                                if !trip.confirmationNumber.isEmpty {
                                    DetailRow(label: "Confirmation #", value: trip.confirmationNumber)
                                    Divider().padding(.horizontal)
                                }
                                if !trip.reservationNotes.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Notes")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(trip.reservationNotes)
                                            .font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    Divider().padding(.horizontal)
                                }

                                // Receipt photos
                                if !trip.receiptPhotoFilenames.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Receipts / Documents")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 10) {
                                                ForEach(trip.receiptPhotoFilenames, id: \.self) { fn in
                                                    if let img = PhotoStorage.load(filename: fn) {
                                                        Image(uiImage: img)
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 100, height: 130)
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                            .onTapGesture { fullscreenPhoto = img }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                    }

                    // Pre-trip to-dos
                    if !trip.todos.isEmpty {
                        DetailCard(title: "Pre-Trip To-Dos", icon: "checklist") {
                            VStack(spacing: 0) {
                                // Progress bar
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("\(todoChecked) of \(trip.todos.count) done")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3).fill(Color(.systemFill)).frame(height: 5)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(todoChecked == trip.todos.count ? Color.green : Color.accentColor)
                                                .frame(width: trip.todos.isEmpty ? 0 : geo.size.width * Double(todoChecked) / Double(trip.todos.count), height: 5)
                                                .animation(.easeInOut(duration: 0.3), value: todoChecked)
                                        }
                                    }
                                    .frame(height: 5)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)

                                Divider().padding(.horizontal)

                                ForEach(trip.todos) { todo in
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            store.togglePlannedTripTodo(tripId: trip.id, todoId: todo.id)
                                        }) {
                                            Image(systemName: todo.isChecked ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundColor(todo.isChecked ? .green : Color(.systemGray3))
                                        }
                                        .buttonStyle(.plain)
                                        Text(todo.title)
                                            .font(.subheadline)
                                            .foregroundColor(todo.isChecked ? .secondary : .primary)
                                            .strikethrough(todo.isChecked, color: .secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                    }

                    // General notes
                    if !trip.notes.isEmpty {
                        DetailCard(title: "Notes", icon: "note.text") {
                            Text(trip.notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showingEdit = true }
                }
            }
            .sheet(isPresented: $showingEdit) {
                EditPlannedTripView(trip: trip)
            }
            .fullScreenCover(item: Binding(
                get: { fullscreenPhoto.map { IdentifiableImage(image: $0) } },
                set: { fullscreenPhoto = $0?.image }
            )) { id in FullscreenPhotoView(image: id.image) }
        }
    }

}

// MARK: - Detail Card helper
struct DetailCard<Content: View>: View {
    var title: String
    var icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
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

struct DetailRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Edit Planned Trip
struct EditPlannedTripView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    var trip: PlannedTrip?
    var isEditing: Bool { trip != nil }

    @State private var name = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var status: PlannedTrip.TripStatus = .upcoming

    @State private var campsiteName = ""
    @State private var siteNumber = ""
    @State private var confirmationNumber = ""
    @State private var reservationNotes = ""
    @State private var receiptPhotoFilenames: [String] = []
    @State private var pendingReceiptImages: [UIImage] = []
    @State private var selectedReceiptItems: [PhotosPickerItem] = []

    @State private var todos: [PlannedTripTodo] = []
    @State private var newTodoText = ""

    @State private var notes = ""
    @State private var showingDeleteConfirm = false
    @State private var showingLocationSearch = false
    @State private var locationLatitude: Double? = nil
    @State private var locationLongitude: Double? = nil

    var body: some View {
        NavigationView {
            Form {
                // Basic info
                Section("Trip") {
                    TextField("Trip name (e.g. Labour Day at Cultus Lake)", text: $name)
                    // Location picker row — NavigationLink is most reliable inside Form
                    NavigationLink(destination: LocationSearchView(
                        currentName: location,
                        onSelect: { name, lat, lon in
                            location = name
                            locationLatitude = lat
                            locationLongitude = lon
                        }
                    )) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.isEmpty ? "Location / Park name" : location)
                                    .font(.body)
                                    .foregroundColor(location.isEmpty ? Color(.placeholderText) : .primary)
                                if locationLatitude != nil {
                                    Label("Location confirmed", systemImage: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.accentColor)
                                .font(.caption)
                        }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(PlannedTrip.TripStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                Section("Dates") {
                    DatePicker("Arrival", selection: $startDate, displayedComponents: .date)
                    DatePicker("Departure", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                // Reservation
                Section("Reservation") {
                    TextField("Campsite / Park name", text: $campsiteName)
                    TextField("Site number", text: $siteNumber)
                    TextField("Confirmation number", text: $confirmationNumber)
                    TextField("Reservation notes", text: $reservationNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Receipt photos
                Section("Receipts & Documents") {
                    let allImages: [(String?, UIImage)] = receiptPhotoFilenames.compactMap { fn in
                        guard let img = PhotoStorage.load(filename: fn) else { return nil }
                        return (fn, img)
                    } + pendingReceiptImages.map { (nil, $0) }

                    if !allImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(allImages.enumerated()), id: \.offset) { idx, pair in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: pair.1)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 90, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        Button(action: { removeReceiptImage(at: idx, filename: pair.0) }) {
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

                    PhotosPicker(selection: $selectedReceiptItems, maxSelectionCount: 10, matching: .images) {
                        Label("Add Photo / Screenshot", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedReceiptItems) { items in
                        for item in items {
                            item.loadTransferable(type: Data.self) { result in
                                DispatchQueue.main.async {
                                    if case .success(let data) = result, let data = data, let img = UIImage(data: data) {
                                        pendingReceiptImages.append(img)
                                    }
                                    selectedReceiptItems = []
                                }
                            }
                        }
                    }
                }

                // Pre-trip to-dos
                Section("Pre-Trip To-Dos") {
                    ForEach(todos) { todo in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text(todo.title)
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in todos.remove(atOffsets: indexSet) }

                    HStack {
                        TextField("Add to-do item...", text: $newTodoText)
                        Button(action: addTodo) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Notes
                Section("Notes") {
                    TextField("Any other details about this trip...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Delete
                if isEditing {
                    Section {
                        Button("Delete Trip", role: .destructive) { showingDeleteConfirm = true }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Trip" : "New Trip")
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
            .onAppear { populate() }
            .confirmationDialog("Delete this trip?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let t = trip { store.deletePlannedTrip(t) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func addTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        todos.append(PlannedTripTodo(title: trimmed))
        newTodoText = ""
    }

    private func removeReceiptImage(at index: Int, filename: String?) {
        let savedCount = receiptPhotoFilenames.count
        if index < savedCount, let fn = filename {
            PhotoStorage.delete(filename: fn)
            receiptPhotoFilenames.removeAll { $0 == fn }
        } else {
            let pendingIndex = index - savedCount
            if pendingIndex < pendingReceiptImages.count {
                pendingReceiptImages.remove(at: pendingIndex)
            }
        }
    }

    private func populate() {
        guard let t = trip else { return }
        name = t.name; location = t.location
        locationLatitude = t.locationLatitude; locationLongitude = t.locationLongitude
        startDate = t.startDate; endDate = t.endDate; status = t.status
        campsiteName = t.campsiteName; siteNumber = t.siteNumber
        confirmationNumber = t.confirmationNumber; reservationNotes = t.reservationNotes
        receiptPhotoFilenames = t.receiptPhotoFilenames
        todos = t.todos; notes = t.notes
    }

    private func save() {
        // Save pending receipt photos
        var allReceiptFilenames = receiptPhotoFilenames
        for img in pendingReceiptImages {
            let fn = PhotoStorage.newFilename()
            PhotoStorage.save(img, filename: fn)
            allReceiptFilenames.append(fn)
        }

        let updated = PlannedTrip(
            id: trip?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            location: location,
            startDate: startDate,
            endDate: endDate,
            status: status,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            campsiteName: campsiteName,
            siteNumber: siteNumber,
            confirmationNumber: confirmationNumber,
            reservationNotes: reservationNotes,
            receiptPhotoFilenames: allReceiptFilenames,
            todos: todos,
            notes: notes
        )

        if isEditing { store.updatePlannedTrip(updated) }
        else { store.addPlannedTrip(updated) }
        dismiss()
    }
}

// MARK: - Location Search View
struct LocationSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentationMode) var presentationMode
    var currentName: String
    var onSelect: (String, Double, Double) -> Void

    @State private var searchText = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @State private var isSearching = false
    @StateObject private var completer = SearchCompleter()

    var body: some View {
        NavigationView {
            List {
                if results.isEmpty && !searchText.isEmpty {
                    HStack {
                        Spacer()
                        if isSearching {
                            ProgressView()
                        } else {
                            Text("No results found")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    ForEach(results, id: \.self) { result in
                        Button(action: { resolveAndSelect(result) }) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a park or location")
            .onChange(of: searchText) { text in
                completer.search(text)
                isSearching = !text.isEmpty
            }
            .onReceive(completer.$results) { results in
                self.results = results
                isSearching = false
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)

            .onAppear {
                // Pre-populate with existing location
                if !currentName.isEmpty { searchText = currentName }
            }
        }
    }

    private func resolveAndSelect(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        // Bias results towards BC
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 54.0, longitude: -125.0),
            span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
        )
        MKLocalSearch(request: request).start { response, _ in
            guard let item = response?.mapItems.first else { return }
            let coord = item.placemark.coordinate
            let name = completion.title + (completion.subtitle.isEmpty ? "" : ", " + completion.subtitle)
            onSelect(name, coord.latitude, coord.longitude)
            DispatchQueue.main.async {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - MKLocalSearchCompleter wrapper
class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address, .query]
        // Bias towards BC, Canada
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 54.0, longitude: -125.0),
            span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
        )
    }

    func search(_ query: String) {
        guard !query.isEmpty else { results = []; return }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { self.results = completer.results }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { self.results = [] }
    }
}
