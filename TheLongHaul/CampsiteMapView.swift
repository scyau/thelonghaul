import SwiftUI
import MapKit
import PhotosUI
import CoreLocation

// MARK: - Campsite data model (bundled JSON)
struct Campsite: Identifiable, Codable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Load campsites from bundled JSON
func loadCampsites() -> [Campsite] {
    guard let url = Bundle.main.url(forResource: "campsites", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let sites = try? JSONDecoder().decode([Campsite].self, from: data)
    else { return [] }
    return sites
}

// MARK: - Location permission manager
// Held alive as a private instance. Requests When In Use permission on init
// so UserAnnotation() can show the blue dot.
final class LocationPermissionManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermissionManager()
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { }
}

// MARK: - Main View
struct CampsiteMapView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var campsites: [Campsite] = []

    // Selection — separate optionals, but only one is ever non-nil at a time
    @State private var selectedBCParks: Campsite? = nil
    @State private var selectedCustom: CustomCampsite? = nil

    @State private var showingReview       = false
    @State private var showingCustomReview = false
    @State private var showingList         = false
    @State private var showingNameEntry    = false   // shown after long press
    @State private var pendingCoordinate: CLLocationCoordinate2D? = nil  // where user long-pressed
    @State private var showMapHint: Bool = false

    @State private var filterVisited: VisitedFilter = .all
    @State private var filterSource: SourceFilter   = .all

    // iOS 17 Map uses MapCameraPosition instead of MKCoordinateRegion
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 49.9, longitude: -119.5),
        span: MKCoordinateSpan(latitudeDelta: 4.5, longitudeDelta: 4.5)
    ))

    enum VisitedFilter: String, CaseIterable {
        case all       = "All"
        case visited   = "Visited"
        case unvisited = "Not Visited"
    }

    enum SourceFilter: String, CaseIterable {
        case all     = "All"
        case bcParks = "BC Parks"
        case mySpots = "My Spots"
    }

    // MARK: - Computed

    var visitedCount: Int { campsites.filter { store.review(for: $0.id) != nil }.count }

    var filteredBCParks: [Campsite] {
        guard filterSource != .mySpots else { return [] }
        switch filterVisited {
        case .all:       return campsites
        case .visited:   return campsites.filter { store.review(for: $0.id) != nil }
        case .unvisited: return campsites.filter { store.review(for: $0.id) == nil }
        }
    }

    var filteredCustom: [CustomCampsite] {
        guard filterSource != .bcParks else { return [] }
        switch filterVisited {
        case .all:       return store.customCampsites
        case .visited:   return store.customCampsites.filter { store.reviewForCustom($0) != nil }
        case .unvisited: return store.customCampsites.filter { store.reviewForCustom($0) == nil }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {

                // iOS 17 Map wrapped in MapReader for coordinate conversion via proxy
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        ForEach(filteredBCParks) { site in
                            Annotation(site.name, coordinate: site.coordinate, anchor: .center) {
                                CampsitePinView(
                                    rating: store.review(for: site.id)?.rating ?? 0,
                                    isSelected: selectedBCParks?.id == site.id,
                                    isCustom: false
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedCustom = nil
                                        selectedBCParks = site
                                    }
                                }
                            }
                            .annotationTitles(.hidden)
                        }

                        ForEach(filteredCustom) { site in
                            Annotation(site.name, coordinate: site.coordinate, anchor: .center) {
                                CampsitePinView(
                                    rating: store.reviewForCustom(site)?.rating ?? 0,
                                    isSelected: selectedCustom?.id == site.id,
                                    isCustom: true
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedBCParks = nil
                                        selectedCustom = site
                                    }
                                }
                            }
                            .annotationTitles(.hidden)
                        }
                        // Always-on blue dot
                        UserAnnotation()
                    }
                    .ignoresSafeArea(edges: .top)
                    .mapStyle(.standard)
                    .mapControls { }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                            .onEnded { value in
                                if case .second(true, let drag) = value {
                                    let point = drag?.startLocation ?? .zero
                                    if let coordinate = proxy.convert(point, from: .global) {
                                        selectedBCParks = nil
                                        selectedCustom = nil
                                        pendingCoordinate = coordinate
                                        showingNameEntry = true
                                    }
                                }
                            }
                    )
                }

                // First-launch hint banner — sits at the bottom, above the cards
                if showMapHint && selectedBCParks == nil && selectedCustom == nil {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.orange)
                        Text("Hold anywhere on the map to save a spot")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showMapHint = false
                            }
                            UserDefaults.standard.set(true, forKey: "hasSeenMapHint")
                        }) {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(true)
                }

                // Bottom card — BC Parks
                if let site = selectedBCParks {
                    CampsiteCardView(
                        campsite: site,
                        review: store.review(for: site.id),
                        onReview: { showingReview = true },
                        onDismiss: { withAnimation { selectedBCParks = nil } }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Bottom card — custom site
                if let site = selectedCustom {
                    CustomCampsiteCardView(
                        campsite: site,
                        review: store.reviewForCustom(site),
                        onReview: { showingCustomReview = true },
                        onDelete: {
                            withAnimation { selectedCustom = nil }
                            store.deleteCustomCampsite(site)
                        },
                        onDismiss: { withAnimation { selectedCustom = nil } }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Campsite Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Section("Site Type") {
                            ForEach(SourceFilter.allCases, id: \.self) { s in
                                Button(action: {
                                    withAnimation { filterSource = s }
                                    selectedBCParks = nil; selectedCustom = nil
                                }) {
                                    HStack {
                                        Text(s.rawValue)
                                        if filterSource == s { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        }
                        Section("Status") {
                            ForEach(VisitedFilter.allCases, id: \.self) { f in
                                Button(action: {
                                    withAnimation { filterVisited = f }
                                    selectedBCParks = nil; selectedCustom = nil
                                }) {
                                    HStack {
                                        Text(f.rawValue)
                                        if filterVisited == f { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        }
                    } label: {
                        let isDefault = filterVisited == .all && filterSource == .all
                        HStack(spacing: 4) {
                            Image(systemName: isDefault
                                  ? "checkmark.seal.fill"
                                  : "line.3.horizontal.decrease.circle.fill")
                                .foregroundColor(isDefault ? .green : .accentColor)
                                .font(.caption)
                            Text(isDefault
                                 ? "\(visitedCount)/\(campsites.count)"
                                 : "\(filterSource.rawValue) · \(filterVisited.rawValue)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(isDefault ? .secondary : .accentColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingList = true }) {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .onAppear {
                campsites = loadCampsites()
                LocationPermissionManager.shared.requestPermission()
                // TEMP: remove this line once banner is confirmed working
                UserDefaults.standard.removeObject(forKey: "hasSeenMapHint")
                showMapHint = !UserDefaults.standard.bool(forKey: "hasSeenMapHint")
            }
            .sheet(isPresented: $showingReview) {
                if let site = selectedBCParks {
                    EditCampsiteReviewView(campsite: site, existing: store.review(for: site.id))
                }
            }
            .sheet(isPresented: $showingCustomReview) {
                if let site = selectedCustom {
                    EditCustomCampsiteReviewView(campsite: site, existing: store.reviewForCustom(site))
                }
            }
            .sheet(isPresented: $showingNameEntry) {
                if let coordinate = pendingCoordinate {
                    NameNewSiteView(coordinate: coordinate) { newSite in
                        store.addCustomCampsite(newSite)
                        selectedBCParks = nil
                        selectedCustom = newSite
                    }
                    .presentationDetents([.height(180)])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingList) {
                CampsiteListView(campsites: campsites, onSelect: { site in
                    selectedBCParks = nil; selectedCustom = nil
                    showingList = false
                    cameraPosition = .region(MKCoordinateRegion(
                        center: site.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
                    ))
                })
            }
        }
    }
}

// MARK: - Pin view
struct CampsitePinView: View {
    var rating: Int
    var isSelected: Bool
    var isCustom: Bool = false

    var pinColor: Color {
        if rating == 0 { return .gray }
        if rating >= 4 { return .green }
        if rating >= 3 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: isSelected ? 36 : 26, height: isSelected ? 36 : 26)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: isCustom ? 2.5 : 2)
                )
            if rating > 0 {
                Text("\(rating)")
                    .font(.system(size: isSelected ? 14 : 11, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: isCustom ? "flame.fill" : "tent.fill")
                    .font(.system(size: isSelected ? 14 : 11))
                    .foregroundColor(.white)
            }
        }
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - Bottom card — BC Parks site
struct CampsiteCardView: View {
    var campsite: Campsite
    var review: CampsiteReview?
    var onReview: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(campsite.name)
                        .font(.headline)
                        .lineLimit(2)
                    if let r = review {
                        HStack(spacing: 4) {
                            StarRatingView(rating: r.rating, size: 14)
                            Text(r.visitDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !r.notes.isEmpty {
                            Text(r.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    } else {
                        Text("Not visited yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color(.systemGray3))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Button(action: onReview) {
                    Label(review == nil ? "Add Review" : "Edit Review",
                          systemImage: review == nil ? "star.badge.plus" : "star.badge.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: { openInMaps(campsite.name) }) {
                    Label("Directions", systemImage: "location.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: -4)
        )
    }
}

// MARK: - Bottom card — user-added site
struct CustomCampsiteCardView: View {
    var campsite: CustomCampsite
    var review: CampsiteReview?
    var onReview: () -> Void
    var onDelete: () -> Void
    var onDismiss: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(campsite.name)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    if let r = review {
                        HStack(spacing: 4) {
                            StarRatingView(rating: r.rating, size: 14)
                            Text(r.visitDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !r.notes.isEmpty {
                            Text(r.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    } else {
                        Text("My spot — not reviewed yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color(.systemGray3))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Button(action: onReview) {
                    Label(review == nil ? "Add Review" : "Edit Review",
                          systemImage: review == nil ? "star.badge.plus" : "star.badge.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: { openInMaps(campsite.name) }) {
                    Label("Directions", systemImage: "location.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: { showingDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: -4)
        )
        .confirmationDialog("Delete \"\(campsite.name)\"?",
                            isPresented: $showingDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete Site & Review", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Name entry sheet (shown after long press)
// Compact bottom sheet — just a name field and Save button.
// No map inside, so no camera position issues.
struct NameNewSiteView: View {
    @Environment(\.dismiss) var dismiss
    var coordinate: CLLocationCoordinate2D
    var onSave: (CustomCampsite) -> Void

    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                TextField("Name this spot", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit { saveIfValid() }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Button(action: saveIfValid) {
                Text("Save Spot")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(name.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color(.systemGray4)
                                : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    private func saveIfValid() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let site = CustomCampsite(
            name: trimmed,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        onSave(site)
        dismiss()
    }
}

// MARK: - Star rating display
struct StarRatingView: View {
    var rating: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(i <= rating ? .orange : Color(.systemGray4))
            }
        }
    }
}

// MARK: - Interactive star picker
struct StarPickerView: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: 32))
                    .foregroundColor(i <= rating ? .orange : Color(.systemGray4))
                    .onTapGesture { rating = i }
            }
        }
    }
}

// MARK: - Campsite List View (BC Parks)
struct CampsiteListView: View {
    @EnvironmentObject var store: AppDataStore
    var campsites: [Campsite]
    var onSelect: (Campsite) -> Void

    @State private var searchText = ""
    @State private var filter: VisitFilter = .all
    @Environment(\.dismiss) var dismiss

    enum VisitFilter: String, CaseIterable {
        case all      = "All"
        case visited  = "Visited"
        case unvisited = "Unvisited"
    }

    var filtered: [Campsite] {
        campsites
            .filter { site in
                let matchesSearch = searchText.isEmpty ||
                    site.name.localizedCaseInsensitiveContains(searchText)
                let hasReview = store.review(for: site.id) != nil
                let matchesFilter: Bool
                switch filter {
                case .all:       matchesFilter = true
                case .visited:   matchesFilter = hasReview
                case .unvisited: matchesFilter = !hasReview
                }
                return matchesSearch && matchesFilter
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filtered) { site in
                    let review = store.review(for: site.id)
                    Button(action: { onSelect(site) }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(review != nil ? Color.green.opacity(0.15) : Color(.systemFill))
                                    .frame(width: 38, height: 38)
                                if let r = review {
                                    Text("\(r.rating)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "tent")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(site.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                if let r = review {
                                    HStack(spacing: 4) {
                                        StarRatingView(rating: r.rating, size: 10)
                                        Text(r.visitDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Not visited")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search campsites")
            .navigationTitle("BC Parks Sites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("Filter", selection: $filter) {
                        ForEach(VisitFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

// MARK: - Edit / Add Review — BC Parks
struct EditCampsiteReviewView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    var campsite: Campsite
    var existing: CampsiteReview?

    @State private var rating: Int = 0
    @State private var visitDate: Date = Date()
    @State private var notes: String = ""
    @State private var wouldReturn: Bool = true
    @State private var photoFilenames: [String] = []
    @State private var pendingImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingDeleteConfirm = false
    @State private var fullscreenPhoto: UIImage? = nil

    var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "tent.fill")
                            .foregroundColor(.accentColor)
                        Text(campsite.name)
                            .font(.headline)
                    }
                }

                Section("Rating") {
                    VStack(spacing: 8) {
                        StarPickerView(rating: $rating)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        if rating > 0 {
                            Text(ratingLabel(rating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Visit Details") {
                    DatePicker("Date visited", selection: $visitDate, in: ...Date(), displayedComponents: .date)
                    Toggle("Would return", isOn: $wouldReturn)
                }

                Section("Notes") {
                    TextField("What did you think? Any tips for other campers...", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Photos") {
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
                                        Button(action: { removePhoto(at: idx, filename: pair.0) }) {
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

                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .images) {
                        Label("Add Photos", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedItems) { items in
                        for item in items {
                            item.loadTransferable(type: Data.self) { result in
                                DispatchQueue.main.async {
                                    if case .success(let data) = result, let data = data,
                                       let img = UIImage(data: data) {
                                        pendingImages.append(img)
                                    }
                                    selectedItems = []
                                }
                            }
                        }
                    }
                }

                if isEditing {
                    Section {
                        Button("Delete Review", role: .destructive) { showingDeleteConfirm = true }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Review" : "Add Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(rating == 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear { populate() }
            .confirmationDialog("Delete this review?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let r = existing { store.deleteCampsiteReview(r) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(item: Binding(
                get: { fullscreenPhoto.map { IdentifiableImage(image: $0) } },
                set: { fullscreenPhoto = $0?.image }
            )) { id in FullscreenPhotoView(image: id.image) }
        }
    }

    private func ratingLabel(_ r: Int) -> String {
        switch r {
        case 1: return "⭑ Poor"
        case 2: return "⭑⭑ Below average"
        case 3: return "⭑⭑⭑ Good"
        case 4: return "⭑⭑⭑⭑ Great"
        case 5: return "⭑⭑⭑⭑⭑ Outstanding!"
        default: return ""
        }
    }

    private func removePhoto(at index: Int, filename: String?) {
        let savedCount = photoFilenames.count
        if index < savedCount, let fn = filename {
            PhotoStorage.delete(filename: fn)
            photoFilenames.removeAll { $0 == fn }
        } else {
            let pi = index - savedCount
            if pi < pendingImages.count { pendingImages.remove(at: pi) }
        }
    }

    private func populate() {
        guard let r = existing else { return }
        rating = r.rating
        visitDate = r.visitDate
        notes = r.notes
        wouldReturn = r.wouldReturn
        photoFilenames = r.photoFilenames
    }

    private func save() {
        var allFilenames = photoFilenames
        for img in pendingImages {
            let fn = PhotoStorage.newFilename()
            PhotoStorage.save(img, filename: fn)
            allFilenames.append(fn)
        }
        let review = CampsiteReview(
            id: existing?.id ?? UUID(),
            campsiteId: campsite.id,
            campsiteName: campsite.name,
            rating: rating,
            visitDate: visitDate,
            notes: notes,
            photoFilenames: allFilenames,
            wouldReturn: wouldReturn
        )
        store.addCampsiteReview(review)
        dismiss()
    }
}

// MARK: - Edit / Add Review — Custom Campsite
struct EditCustomCampsiteReviewView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    var campsite: CustomCampsite
    var existing: CampsiteReview?

    @State private var rating: Int = 0
    @State private var visitDate: Date = Date()
    @State private var notes: String = ""
    @State private var wouldReturn: Bool = true
    @State private var photoFilenames: [String] = []
    @State private var pendingImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingDeleteConfirm = false
    @State private var fullscreenPhoto: UIImage? = nil

    var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text(campsite.name)
                            .font(.headline)
                    }
                }

                Section("Rating") {
                    VStack(spacing: 8) {
                        StarPickerView(rating: $rating)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        if rating > 0 {
                            Text(ratingLabel(rating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Visit Details") {
                    DatePicker("Date visited", selection: $visitDate, in: ...Date(), displayedComponents: .date)
                    Toggle("Would return", isOn: $wouldReturn)
                }

                Section("Notes") {
                    TextField("What did you think? Any tips for next time...", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Photos") {
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
                                        Button(action: { removePhoto(at: idx, filename: pair.0) }) {
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

                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .images) {
                        Label("Add Photos", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedItems) { items in
                        for item in items {
                            item.loadTransferable(type: Data.self) { result in
                                DispatchQueue.main.async {
                                    if case .success(let data) = result, let data = data,
                                       let img = UIImage(data: data) {
                                        pendingImages.append(img)
                                    }
                                    selectedItems = []
                                }
                            }
                        }
                    }
                }

                if isEditing {
                    Section {
                        Button("Delete Review", role: .destructive) { showingDeleteConfirm = true }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Review" : "Add Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(rating == 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear { populate() }
            .confirmationDialog("Delete this review?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let r = existing { store.deleteCampsiteReview(r) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(item: Binding(
                get: { fullscreenPhoto.map { IdentifiableImage(image: $0) } },
                set: { fullscreenPhoto = $0?.image }
            )) { id in FullscreenPhotoView(image: id.image) }
        }
    }

    private func ratingLabel(_ r: Int) -> String {
        switch r {
        case 1: return "⭑ Poor"
        case 2: return "⭑⭑ Below average"
        case 3: return "⭑⭑⭑ Good"
        case 4: return "⭑⭑⭑⭑ Great"
        case 5: return "⭑⭑⭑⭑⭑ Outstanding!"
        default: return ""
        }
    }

    private func removePhoto(at index: Int, filename: String?) {
        let savedCount = photoFilenames.count
        if index < savedCount, let fn = filename {
            PhotoStorage.delete(filename: fn)
            photoFilenames.removeAll { $0 == fn }
        } else {
            let pi = index - savedCount
            if pi < pendingImages.count { pendingImages.remove(at: pi) }
        }
    }

    private func populate() {
        guard let r = existing else { return }
        rating = r.rating
        visitDate = r.visitDate
        notes = r.notes
        wouldReturn = r.wouldReturn
        photoFilenames = r.photoFilenames
    }

    private func save() {
        var allFilenames = photoFilenames
        for img in pendingImages {
            let fn = PhotoStorage.newFilename()
            PhotoStorage.save(img, filename: fn)
            allFilenames.append(fn)
        }
        let review = CampsiteReview(
            id: existing?.id ?? UUID(),
            campsiteId: campsite.id.uuidString,
            campsiteName: campsite.name,
            rating: rating,
            visitDate: visitDate,
            notes: notes,
            photoFilenames: allFilenames,
            wouldReturn: wouldReturn
        )
        store.addCampsiteReview(review)
        dismiss()
    }
}
