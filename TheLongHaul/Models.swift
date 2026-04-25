import Foundation
import Combine
import SwiftUI
import UserNotifications
import UIKit
import CloudKit

// MARK: - Trip Model
struct Trip: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var startOdometer: Double
    var endOdometer: Double?
    var date: Date
    var endDate: Date?
    var notes: String = ""

    var miles: Double {
        guard let end = endOdometer else { return 0 }
        return max(0, end - startOdometer)
    }

    var isInProgress: Bool { endOdometer == nil }
    
    var nights: Int? {
        guard let end = endDate else { return nil }
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: date)
        let endDay = cal.startOfDay(for: end)
        return cal.dateComponents([.day], from: startDay, to: endDay).day
    }
}


// MARK: - Maintenance Task Type
struct MaintenanceTaskType: Identifiable, Codable, Hashable {
    // Date interval
    var intervalMonths: Int = 0   // 0 = no date interval
    var lastServiceDate: Date? = nil
    var id: UUID = UUID()
    var name: String
    var intervalMiles: Double
    var notes: String = ""
}

// MARK: - Maintenance Log Entry
struct MaintenanceEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var taskTypeId: UUID
    var taskTypeName: String
    var mileageAtService: Double
    var date: Date
    var notes: String = ""
    var cost: Double?
}

// MARK: - Note Item
struct NoteItem: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var date: Date = Date()
    var isResolved: Bool = false
    var photoFilenames: [String] = []
    var priority: NotePriority = .none

    enum NotePriority: String, Codable, CaseIterable {
        case none   = "none"
        case normal = "normal"
        case urgent = "urgent"

        var next: NotePriority {
            switch self {
            case .none:   return .normal
            case .normal: return .urgent
            case .urgent: return .none
            }
        }

        var color: Color {
            switch self {
            case .none:   return Color(.systemGray3)
            case .normal: return .orange
            case .urgent: return .red
            }
        }

        var label: String {
            switch self {
            case .none:   return "No Priority"
            case .normal: return "Normal"
            case .urgent: return "Urgent"
            }
        }

        var sortOrder: Int {
            switch self {
            case .urgent: return 0
            case .normal: return 1
            case .none:   return 2
            }
        }
    }
}

// MARK: - Checklist Item
struct ChecklistItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var isChecked: Bool = false
    var sortOrder: Int = 0
}

// MARK: - Packing Item
struct PackingItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var category: PackingCategory = .other
    var isPacked: Bool = false
    var quantity: Int = 1
    var sortOrder: Int = 0

    enum PackingCategory: String, Codable, CaseIterable {
        case kitchen  = "Kitchen"
        case bedding  = "Bedding"
        case clothing = "Clothing"
        case safety   = "Safety"
        case tools    = "Tools"
        case outdoor  = "Outdoor"
        case other    = "Other"

        var icon: String {
            switch self {
            case .kitchen:  return "fork.knife"
            case .bedding:  return "bed.double"
            case .clothing: return "tshirt"
            case .safety:   return "cross.case"
            case .tools:    return "wrench.and.screwdriver"
            case .outdoor:  return "sun.max"
            case .other:    return "shippingbox"
            }
        }

        var color: Color {
            switch self {
            case .kitchen:  return .orange
            case .bedding:  return .indigo
            case .clothing: return .pink
            case .safety:   return .red
            case .tools:    return .gray
            case .outdoor:  return .green
            case .other:    return .brown
            }
        }
    }
}

// MARK: - Date Reminder
struct DateReminder: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var reminderDate: Date
    var repeatInterval: ReminderRepeat = .none
    var isActive: Bool = true

    enum ReminderRepeat: String, Codable, CaseIterable {
        case none = "Once"
        case monthly = "Monthly"
        case yearly = "Yearly"
    }
}

// MARK: - Trailer Profile
struct TrailerProfile: Codable {
    var make: String = ""
    var model: String = ""
    var year: String = ""
    var vin: String = ""
    var purchasedDate: String = ""
    var licensePlate: String = ""
    var tireSize: String = ""
    var axles: String = ""
    var gvwr: String = ""
    var tareWeight: String = ""
    var payload: String = ""
    var drawbar: String = ""
    var length: String = ""
    var width: String = ""
    var height: String = ""
    var chassis: String = ""
    var body: String = ""
    var brakes: String = ""
    var coupling: String = ""
    var jockeyWheel: String = ""
    var suspension: String = ""
    var wheels: String = ""
    var wheelBearings: String = ""
    var tires: String = ""
    var battery: String = ""
    var bms: String = ""
    var inverter: String = ""
    var solar: String = ""
    var fridge: String = ""
    var stove: String = ""
    var waterHeater: String = ""
    var waterFiltrationSystem: String = ""
    var sedimentFilterCartridge: String = ""
    var carbonFilterCartridge: String = ""
    var waterPump: String = ""
    var awning: String = ""
    var showerPod: String = ""
    var rtt: String = ""
    var mattress: String = ""
    var notes: String = ""
    var photoFilename: String? = nil
}

// MARK: - Planned Trip
struct PlannedTrip: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var location: String = ""
    var startDate: Date
    var endDate: Date
    var status: TripStatus = .upcoming

    // Location coordinates (set when user picks from search)
    var locationLatitude: Double? = nil
    var locationLongitude: Double? = nil

    // Reservation info
    var campsiteName: String = ""
    var siteNumber: String = ""
    var confirmationNumber: String = ""
    var reservationNotes: String = ""
    var receiptPhotoFilenames: [String] = []

    // Pre-trip to-dos
    var todos: [PlannedTripTodo] = []

    // General notes
    var notes: String = ""

    enum TripStatus: String, Codable, CaseIterable {
        case upcoming = "Upcoming"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }

    var nights: Int {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: startDate)
        let endDay = cal.startOfDay(for: endDate)
        return cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }

    var daysUntil: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0)
    }

    var isPast: Bool { endDate < Date() }
}

// MARK: - Planned Trip To-Do
struct PlannedTripTodo: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var isChecked: Bool = false
}

// MARK: - Campsite Review
struct CampsiteReview: Identifiable, Codable {
    var id: UUID = UUID()
    var campsiteId: String          // matches id in campsites.json
    var campsiteName: String
    var rating: Int = 0             // 1–5, 0 = unrated
    var visitDate: Date = Date()
    var notes: String = ""
    var photoFilenames: [String] = []
    var wouldReturn: Bool = true
}

// MARK: - User-Added Campsite
struct CustomCampsite: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Photo Storage Helpers
enum PhotoStorage {
    static let containerID = "iCloud.com.sjor.thelonghaul"

    static var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("NotePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Save locally and upload to CloudKit
    static func save(_ image: UIImage, filename: String) {
        let url = photosDirectory.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: url)
        uploadToCloudKit(localURL: url, filename: filename)
    }

    static func load(filename: String) -> UIImage? {
        let url = photosDirectory.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        // Not cached locally — trigger a background fetch
        downloadFromCloudKit(filename: filename)
        return nil
    }

    static func delete(filename: String) {
        let url = photosDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        deleteFromCloudKit(filename: filename)
    }

    static func newFilename() -> String { "\(UUID().uuidString).jpg" }

    // MARK: CloudKit photo sync

    private static var container: CKContainer { CKContainer(identifier: containerID) }
    private static var db: CKDatabase { container.privateCloudDatabase }

    private static func uploadToCloudKit(localURL: URL, filename: String) {
        let recordID = CKRecord.ID(recordName: "photo-\(filename)")
        let record = CKRecord(recordType: "Photo", recordID: recordID)
        record["filename"] = filename as CKRecordValue
        record["asset"] = CKAsset(fileURL: localURL)
        db.save(record) { _, _ in }  // fire and forget; local copy is source of truth
    }

    static func downloadFromCloudKit(filename: String) {
        let recordID = CKRecord.ID(recordName: "photo-\(filename)")
        db.fetch(withRecordID: recordID) { record, error in
            guard let record = record,
                  let asset = record["asset"] as? CKAsset,
                  let assetURL = asset.fileURL,
                  let data = try? Data(contentsOf: assetURL) else { return }
            let localURL = photosDirectory.appendingPathComponent(filename)
            try? data.write(to: localURL)
        }
    }

    private static func deleteFromCloudKit(filename: String) {
        let recordID = CKRecord.ID(recordName: "photo-\(filename)")
        db.delete(withRecordID: recordID) { _, _ in }
    }

    /// Call on app launch to pull any photos that exist in CloudKit but not locally
    static func syncMissingPhotos(filenames: [String]) {
        for filename in filenames {
            let url = photosDirectory.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: url.path) {
                downloadFromCloudKit(filename: filename)
            }
        }
    }
}

// MARK: - App Data Store
class AppDataStore: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var maintenanceTaskTypes: [MaintenanceTaskType] = []
    @Published var maintenanceLog: [MaintenanceEntry] = []
    @Published var notes: [NoteItem] = []
    @Published var checklistItems: [ChecklistItem] = []
    @Published var packingItems: [PackingItem] = []
    @Published var dateReminders: [DateReminder] = []
    @Published var trailerProfile: TrailerProfile = TrailerProfile()
    @Published var plannedTrips: [PlannedTrip] = []
    @Published var campsiteReviews: [CampsiteReview] = []
    @Published var customCampsites: [CustomCampsite] = []
    @Published var notificationsAuthorized: Bool = false

    private let tripsKey = "camper_trips"
    private let taskTypesKey = "camper_task_types"
    private let logKey = "camper_maintenance_log"
    private let notesKey = "camper_notes"
    private let checklistKey = "camper_checklist"
    private let packingItemsKey = "camper_packing_items"
    private let remindersKey = "camper_reminders"
    private let profileKey = "camper_profile"
    private let plannedTripsKey = "camper_planned_trips"
    private let campsiteReviewsKey = "camper_campsite_reviews"
    private let customCampsitesKey = "camper_custom_campsites"

    init() {
        loadData()
        if maintenanceTaskTypes.isEmpty { seedDefaultTasks() }
        if checklistItems.isEmpty { seedDefaultChecklist() }
        checkNotificationStatus()
    }

    // MARK: - Computed
    var totalMiles: Double { trips.reduce(0) { $0 + $1.miles } }
    var activeTrip: Trip? { trips.first(where: { $0.isInProgress }) }

    var nextPlannedTrip: PlannedTrip? {
        plannedTrips
            .filter { $0.status == .upcoming && $0.startDate >= Date() }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    /// All photo filenames across the whole app — used to sync missing photos on launch
    var allPhotoFilenames: [String] {
        let notePhotos = notes.flatMap { $0.photoFilenames }
        let tripPhotos = plannedTrips.flatMap { $0.receiptPhotoFilenames }
        let reviewPhotos = campsiteReviews.flatMap { $0.photoFilenames }
        let profilePhoto = trailerProfile.photoFilename.map { [$0] } ?? []
        return notePhotos + tripPhotos + reviewPhotos + profilePhoto
    }

    var longestTrip: Trip? {
        trips.filter { !$0.isInProgress }.max(by: { $0.miles < $1.miles })
    }

    var tripsThisYear: [Trip] {
        let year = Calendar.current.component(.year, from: Date())
        return trips.filter {
            Calendar.current.component(.year, from: $0.date) == year && !$0.isInProgress
        }
    }

    var milesThisYear: Double { tripsThisYear.reduce(0) { $0 + $1.miles } }

    var milesByYear: [(Int, Double)] {
        let grouped = Dictionary(grouping: trips.filter { !$0.isInProgress }) {
            Calendar.current.component(.year, from: $0.date)
        }
        return grouped.map { (year, trips) in
            (year, trips.reduce(0) { $0 + $1.miles })
        }.sorted { $0.0 < $1.0 }
    }
    
    var totalNights: Int {
        trips.filter { !$0.isInProgress }.compactMap { $0.nights }.reduce(0, +)
    }

    var nightsThisYear: Int {
        let year = Calendar.current.component(.year, from: Date())
        return trips
            .filter { !$0.isInProgress && Calendar.current.component(.year, from: $0.date) == year }
            .compactMap { $0.nights }
            .reduce(0, +)
    }

    // MARK: - Maintenance helpers

    func milesSinceLastService(for taskType: MaintenanceTaskType) -> Double {
        // Guard: tasks with no km interval should never appear overdue on km basis
        guard taskType.intervalMiles > 0 else { return 0 }
        let lastServiceMileage = maintenanceLog
            .filter { $0.taskTypeId == taskType.id }
            .sorted { $0.date > $1.date }   // most-recent log entry by date
            .first?.mileageAtService ?? 0
        return totalMiles - lastServiceMileage
    }

    func isDue(for taskType: MaintenanceTaskType) -> Bool {
        guard taskType.intervalMiles > 0 else { return false }
        return milesSinceLastService(for: taskType) >= taskType.intervalMiles
    }

    func isApproachingDue(for taskType: MaintenanceTaskType, threshold: Double = 0.85) -> Bool {
        guard taskType.intervalMiles > 0 else { return false }
        let miles = milesSinceLastService(for: taskType)
        return miles >= taskType.intervalMiles * threshold && miles < taskType.intervalMiles
    }

    func progressFraction(for taskType: MaintenanceTaskType) -> Double {
        guard taskType.intervalMiles > 0 else { return 0 }
        return min(1.0, milesSinceLastService(for: taskType) / taskType.intervalMiles)
    }

    // MARK: - Date-based service helpers
    func lastServiceDate(for taskType: MaintenanceTaskType) -> Date? {
        maintenanceLog
            .filter { $0.taskTypeId == taskType.id }
            .sorted { $0.date > $1.date }
            .first?.date ?? taskType.lastServiceDate
    }

    func nextServiceDate(for taskType: MaintenanceTaskType) -> Date? {
        guard taskType.intervalMonths > 0 else { return nil }
        let base = lastServiceDate(for: taskType) ?? Date()
        return Calendar.current.date(byAdding: .month, value: taskType.intervalMonths, to: base)
    }

    func daysSinceLastService(for taskType: MaintenanceTaskType) -> Int? {
        guard let last = lastServiceDate(for: taskType) else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }

    func daysUntilNextService(for taskType: MaintenanceTaskType) -> Int? {
        guard let next = nextServiceDate(for: taskType) else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: next).day
    }

    func isDateDue(for taskType: MaintenanceTaskType) -> Bool {
        guard taskType.intervalMonths > 0 else { return false }
        guard let days = daysUntilNextService(for: taskType) else { return false }
        // strictly negative — on the exact due date it is not yet overdue
        return days < 0
    }

    func isDateApproaching(for taskType: MaintenanceTaskType, thresholdDays: Int = 14) -> Bool {
        guard taskType.intervalMonths > 0 else { return false }
        guard let days = daysUntilNextService(for: taskType) else { return false }
        return days >= 0 && days <= thresholdDays
    }

    func dateProgressFraction(for taskType: MaintenanceTaskType) -> Double {
        guard taskType.intervalMonths > 0,
              let last = lastServiceDate(for: taskType),
              let next = nextServiceDate(for: taskType) else { return 0 }
        let total = next.timeIntervalSince(last)
        let elapsed = Date().timeIntervalSince(last)
        return min(1.0, max(0, elapsed / total))
    }

    // Combined status: due if either km OR date is overdue
    func isEitherDue(for taskType: MaintenanceTaskType) -> Bool {
        (taskType.intervalMiles > 0 && isDue(for: taskType)) ||
        (taskType.intervalMonths > 0 && isDateDue(for: taskType))
    }

    func isEitherApproaching(for taskType: MaintenanceTaskType) -> Bool {
        !isEitherDue(for: taskType) && (
            (taskType.intervalMiles > 0 && isApproachingDue(for: taskType)) ||
            (taskType.intervalMonths > 0 && isDateApproaching(for: taskType))
        )
    }

    // MARK: - Dashboard threshold helpers

    /// Due within 1000 km OR already overdue (km-based)
    func isKmDueSoon(for taskType: MaintenanceTaskType, threshold: Double = 1000) -> Bool {
        guard taskType.intervalMiles > 0 else { return false }
        let kmLeft = taskType.intervalMiles - milesSinceLastService(for: taskType)
        return kmLeft <= threshold  // includes overdue (kmLeft <= 0)
    }

    /// Due within 30 days OR already overdue (date-based)
    func isDateDueSoon(for taskType: MaintenanceTaskType, thresholdDays: Int = 30) -> Bool {
        guard taskType.intervalMonths > 0 else { return false }
        guard let days = daysUntilNextService(for: taskType) else { return false }
        return days <= thresholdDays  // includes overdue (days < 0)
    }

    /// Either km or date qualifies as "due soon" for dashboard purposes
    func isAnythingDueSoon(for taskType: MaintenanceTaskType) -> Bool {
        isKmDueSoon(for: taskType) || isDateDueSoon(for: taskType)
    }

    // Odometer history: cumulative km at end of each month
    var odometerByMonth: [(label: String, km: Double)] {
        let completed = trips.filter { !$0.isInProgress }.sorted { $0.date < $1.date }
        guard !completed.isEmpty else { return [] }
        var result: [(String, Double)] = []
        var running: Double = 0
        let cal = Calendar.current
        // Group trips by year-month
        let grouped = Dictionary(grouping: completed) { trip -> String in
            let comps = cal.dateComponents([.year, .month], from: trip.date)
            return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        }
        let sortedKeys = grouped.keys.sorted()
        for key in sortedKeys {
            let monthTrips = grouped[key] ?? []
            running += monthTrips.reduce(0) { $0 + $1.miles }
            // Format label as "Jan 24"
            let parts = key.split(separator: "-")
            if parts.count == 2,
               let y = Int(parts[0]), let m = Int(parts[1]),
               let date = cal.date(from: DateComponents(year: y, month: m)) {
                let label = date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
                result.append((label, running))
            }
        }
        return result
    }

    // MARK: - Trip Mutations
    func addTrip(_ trip: Trip) {
        trips.insert(trip, at: 0); saveData(); scheduleAllNotifications()
    }

    func updateTrip(_ trip: Trip) {
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[idx] = trip; saveData(); scheduleAllNotifications()
        }
    }

    func deleteTrip(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }; saveData()
    }

    // MARK: - Maintenance Mutations
    func addMaintenanceEntry(_ entry: MaintenanceEntry) {
        maintenanceLog.insert(entry, at: 0); saveData(); scheduleAllNotifications()
    }

    func deleteMaintenanceEntry(_ entry: MaintenanceEntry) {
        maintenanceLog.removeAll { $0.id == entry.id }; saveData()
    }

    func addTaskType(_ task: MaintenanceTaskType) {
        maintenanceTaskTypes.append(task); saveData()
    }

    func updateTaskType(_ task: MaintenanceTaskType) {
        if let idx = maintenanceTaskTypes.firstIndex(where: { $0.id == task.id }) {
            maintenanceTaskTypes[idx] = task; saveData()
        }
    }

    func deleteTaskType(_ task: MaintenanceTaskType) {
        maintenanceTaskTypes.removeAll { $0.id == task.id }; saveData()
    }

    func moveTaskTypes(from source: IndexSet, to destination: Int) {
        maintenanceTaskTypes.move(fromOffsets: source, toOffset: destination)
        saveData()
    }

    // MARK: - Notes Mutations
    func addNote(_ note: NoteItem) { notes.insert(note, at: 0); saveData() }

    func updateNote(_ note: NoteItem) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note; saveData()
        }
    }

    func deleteNote(_ note: NoteItem) {
        note.photoFilenames.forEach { PhotoStorage.delete(filename: $0) }
        notes.removeAll { $0.id == note.id }; saveData()
    }

    func toggleResolved(_ note: NoteItem) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].isResolved.toggle(); saveData()
        }
    }

    // MARK: - Checklist Mutations
    func addChecklistItem(_ item: ChecklistItem) { checklistItems.append(item); saveData() }

    func updateChecklistItem(_ item: ChecklistItem) {
        if let idx = checklistItems.firstIndex(where: { $0.id == item.id }) {
            checklistItems[idx] = item; saveData()
        }
    }

    func deleteChecklistItem(_ item: ChecklistItem) {
        checklistItems.removeAll { $0.id == item.id }; saveData()
    }

    func toggleChecklistItem(_ item: ChecklistItem) {
        if let idx = checklistItems.firstIndex(where: { $0.id == item.id }) {
            checklistItems[idx].isChecked.toggle(); saveData()
        }
    }

    func resetChecklist() {
        for idx in checklistItems.indices { checklistItems[idx].isChecked = false }
        saveData()
    }

    func moveChecklistItems(from source: IndexSet, to destination: Int) {
        checklistItems.move(fromOffsets: source, toOffset: destination)
        for (i, _) in checklistItems.enumerated() { checklistItems[i].sortOrder = i }
        saveData()
    }

    // MARK: - Packing List Mutations
    func addPackingItem(_ item: PackingItem) { packingItems.append(item); saveData() }

    func updatePackingItem(_ item: PackingItem) {
        if let idx = packingItems.firstIndex(where: { $0.id == item.id }) {
            packingItems[idx] = item; saveData()
        }
    }

    func deletePackingItem(_ item: PackingItem) {
        packingItems.removeAll { $0.id == item.id }; saveData()
    }

    func togglePackingItem(_ item: PackingItem) {
        if let idx = packingItems.firstIndex(where: { $0.id == item.id }) {
            packingItems[idx].isPacked.toggle(); saveData()
        }
    }

    func resetPackingList() {
        for idx in packingItems.indices { packingItems[idx].isPacked = false }
        saveData()
    }

    func movePackingItems(in category: PackingItem.PackingCategory, from source: IndexSet, to destination: Int) {
        var categoryItems = packingItems
            .enumerated()
            .filter { $0.element.category == category }
            .map { $0 }
        let globalIndices = categoryItems.map { $0.offset }

        var movedItems = categoryItems.map { $0.element }
        movedItems.move(fromOffsets: source, toOffset: destination)

        for (i, globalIdx) in globalIndices.enumerated() {
            packingItems[globalIdx] = movedItems[i]
        }
        for (i, _) in packingItems.enumerated() { packingItems[i].sortOrder = i }
        saveData()
    }

    // MARK: - Date Reminder Mutations
    func addDateReminder(_ reminder: DateReminder) {
        dateReminders.append(reminder); saveData(); scheduleAllNotifications()
    }

    func updateDateReminder(_ reminder: DateReminder) {
        if let idx = dateReminders.firstIndex(where: { $0.id == reminder.id }) {
            dateReminders[idx] = reminder; saveData(); scheduleAllNotifications()
        }
    }

    func deleteDateReminder(_ reminder: DateReminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["reminder-\(reminder.id)"])
        dateReminders.removeAll { $0.id == reminder.id }; saveData()
    }

    // MARK: - Planned Trip Mutations
    func addPlannedTrip(_ trip: PlannedTrip) {
        plannedTrips.insert(trip, at: 0); saveData(); scheduleAllNotifications()
    }

    func updatePlannedTrip(_ trip: PlannedTrip) {
        if let idx = plannedTrips.firstIndex(where: { $0.id == trip.id }) {
            plannedTrips[idx] = trip; saveData(); scheduleAllNotifications()
        }
    }

    func deletePlannedTrip(_ trip: PlannedTrip) {
        trip.receiptPhotoFilenames.forEach { PhotoStorage.delete(filename: $0) }
        plannedTrips.removeAll { $0.id == trip.id }; saveData()
    }

    func togglePlannedTripTodo(tripId: UUID, todoId: UUID) {
        if let ti = plannedTrips.firstIndex(where: { $0.id == tripId }),
           let di = plannedTrips[ti].todos.firstIndex(where: { $0.id == todoId }) {
            plannedTrips[ti].todos[di].isChecked.toggle(); saveData()
        }
    }

    // MARK: - Campsite Review Mutations
    func addCampsiteReview(_ review: CampsiteReview) {
        campsiteReviews.removeAll { $0.campsiteId == review.campsiteId }
        campsiteReviews.append(review)
        saveData()
    }

    func updateCampsiteReview(_ review: CampsiteReview) {
        if let idx = campsiteReviews.firstIndex(where: { $0.id == review.id }) {
            campsiteReviews[idx] = review; saveData()
        }
    }

    func deleteCampsiteReview(_ review: CampsiteReview) {
        review.photoFilenames.forEach { PhotoStorage.delete(filename: $0) }
        campsiteReviews.removeAll { $0.id == review.id }
        saveData()
    }

    func review(for campsiteId: String) -> CampsiteReview? {
        campsiteReviews.first { $0.campsiteId == campsiteId }
    }

    // MARK: - Custom Campsite Mutations
    func addCustomCampsite(_ site: CustomCampsite) {
        customCampsites.append(site); saveData()
    }

    func updateCustomCampsite(_ site: CustomCampsite) {
        if let idx = customCampsites.firstIndex(where: { $0.id == site.id }) {
            customCampsites[idx] = site; saveData()
        }
    }

    func deleteCustomCampsite(_ site: CustomCampsite) {
        // Also delete associated review
        if let r = review(for: site.id.uuidString) { deleteCampsiteReview(r) }
        customCampsites.removeAll { $0.id == site.id }; saveData()
    }

    func reviewForCustom(_ site: CustomCampsite) -> CampsiteReview? {
        campsiteReviews.first { $0.campsiteId == site.id.uuidString }
    }

    // MARK: - Trailer Profile Mutations
    func updateTrailerProfile(_ profile: TrailerProfile) {
        trailerProfile = profile; saveData()
    }

    // MARK: - Notifications
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.notificationsAuthorized = granted
                if granted { self.scheduleAllNotifications() }
                completion(granted)
            }
        }
    }

    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func scheduleAllNotifications() {
        guard notificationsAuthorized else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        scheduleMaintenanceNotifications()
        scheduleDateReminderNotifications()
        schedulePlannedTripNotifications()
    }

    private func scheduleMaintenanceNotifications() {
        // km-based due
        for task in maintenanceTaskTypes where task.intervalMiles > 0 && isDue(for: task) {
            let content = UNMutableNotificationContent()
            content.title = "Maintenance Due 🔧"
            content.body = "\(task.name) is due on The Long Haul."
            content.sound = .default
            var dc = DateComponents(); dc.hour = 9; dc.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "due-km-\(task.id)", content: content, trigger: trigger))
        }
        // km-based upcoming
        for task in maintenanceTaskTypes where task.intervalMiles > 0 && isApproachingDue(for: task) {
            let milesLeft = Int(max(0, task.intervalMiles - milesSinceLastService(for: task)))
            let content = UNMutableNotificationContent()
            content.title = "Service Coming Up"
            content.body = "\(task.name) is due in ~\(milesLeft) km."
            content.sound = .default
            if let future = Calendar.current.date(byAdding: .day, value: 3, to: Date()) {
                var dc = Calendar.current.dateComponents([.year, .month, .day], from: future)
                dc.hour = 9; dc.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: "upcoming-km-\(task.id)", content: content, trigger: trigger))
            }
        }
        // Date-based due
        for task in maintenanceTaskTypes where task.intervalMonths > 0 && isDateDue(for: task) {
            let content = UNMutableNotificationContent()
            content.title = "Maintenance Due 🔧"
            content.body = "\(task.name) service date has passed."
            content.sound = .default
            var dc = DateComponents(); dc.hour = 9; dc.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "due-date-\(task.id)", content: content, trigger: trigger))
        }
        // Date-based upcoming (notify on the service date itself)
        for task in maintenanceTaskTypes where task.intervalMonths > 0 && isDateApproaching(for: task) {
            guard let next = nextServiceDate(for: task), next > Date() else { continue }
            let days = daysUntilNextService(for: task) ?? 0
            let content = UNMutableNotificationContent()
            content.title = "Service Due Soon"
            content.body = "\(task.name) is due in \(days) day\(days == 1 ? "" : "s")."
            content.sound = .default
            var dc = Calendar.current.dateComponents([.year, .month, .day], from: next)
            dc.hour = 9; dc.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "upcoming-date-\(task.id)", content: content, trigger: trigger))
        }
    }

    private func scheduleDateReminderNotifications() {
        for reminder in dateReminders where reminder.isActive {
            let content = UNMutableNotificationContent()
            content.title = "Trailer Reminder 📅"
            content.body = reminder.title
            if !reminder.notes.isEmpty { content.subtitle = reminder.notes }
            content.sound = .default
            let dc = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.reminderDate)
            let repeats = reminder.repeatInterval != .none
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: repeats)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "reminder-\(reminder.id)", content: content, trigger: trigger))
        }
    }

    private func schedulePlannedTripNotifications() {
        let cal = Calendar.current

        for trip in plannedTrips where trip.status == .upcoming {

            // ── Reservation window notifications (BC Parks opens 3 months before arrival) ──

            // The exact date reservations open
            if let reservationOpens = cal.date(byAdding: .month, value: -3, to: trip.startDate),
               reservationOpens > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Reservations Open Today! 🏕️"
                content.body = "BC Parks reservations for \(trip.name) are now available. Book now before sites fill up!"
                content.sound = .default
                var dc = cal.dateComponents([.year, .month, .day], from: reservationOpens)
                dc.hour = 8; dc.minute = 0   // 8am — early so you can grab a site
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: "res-open-\(trip.id)", content: content, trigger: trigger))
            }

            // Day before reservations open — heads-up to be ready
            if let dayBeforeRes = cal.date(byAdding: .day, value: -1,
                                    to: cal.date(byAdding: .month, value: -3, to: trip.startDate) ?? trip.startDate),
               dayBeforeRes > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Reservations Open Tomorrow 📅"
                content.body = "BC Parks reservations for \(trip.name) open tomorrow. Be ready to book at 8am!"
                content.sound = .default
                var dc = cal.dateComponents([.year, .month, .day], from: dayBeforeRes)
                dc.hour = 9; dc.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: "res-eve-\(trip.id)", content: content, trigger: trigger))
            }

            // ── Trip countdown notifications ──

            // 7-day heads-up
            if let sevenDayBefore = cal.date(byAdding: .day, value: -7, to: trip.startDate),
               sevenDayBefore > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Trip in 1 Week 🏕️"
                content.body = "\(trip.name) starts \(trip.startDate.formatted(date: .abbreviated, time: .omitted))."
                content.sound = .default
                var dc = cal.dateComponents([.year, .month, .day], from: sevenDayBefore)
                dc.hour = 9; dc.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: "trip7-\(trip.id)", content: content, trigger: trigger))
            }

            // Day-before reminder
            if let dayBefore = cal.date(byAdding: .day, value: -1, to: trip.startDate),
               dayBefore > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Trip Tomorrow! 🚐"
                content.body = "\(trip.name) — don't forget your pre-trip checklist."
                content.sound = .default
                var dc = cal.dateComponents([.year, .month, .day], from: dayBefore)
                dc.hour = 9; dc.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: "trip1-\(trip.id)", content: content, trigger: trigger))
            }
        }
    }

    // MARK: - Persistence
    private func seedDefaultTasks() {
        maintenanceTaskTypes = [
            MaintenanceTaskType(name: "Wheel Bearing Service", intervalMiles: 12000),
            MaintenanceTaskType(name: "Wheel Bearing Replacement", intervalMiles: 36000),
            MaintenanceTaskType(name: "Brake Inspection", intervalMiles: 12000),
            MaintenanceTaskType(name: "Tire Rotation & Inspection", intervalMiles: 6000),
            MaintenanceTaskType(name: "Hitch Lube", intervalMiles: 3000),
            MaintenanceTaskType(name: "Spring Servicing", intervalMiles: 12000),
            MaintenanceTaskType(name: "Storage Prep", intervalMiles: 0, notes: "Annual — complete before storing for season"),
        ]
        saveData()
    }

    private func seedDefaultChecklist() {
        checklistItems = [
            ChecklistItem(title: "Hitch connected and locked", sortOrder: 0),
            ChecklistItem(title: "Safety chains crossed and attached", sortOrder: 1),
            ChecklistItem(title: "Breakaway cable attached", sortOrder: 2),
            ChecklistItem(title: "Trailer lights working (brake, turn, running)", sortOrder: 3),
            ChecklistItem(title: "Tires inflated and visually checked", sortOrder: 4),
            ChecklistItem(title: "Wheel lug nuts torqued", sortOrder: 5),
            ChecklistItem(title: "Tongue jack fully retracted", sortOrder: 6),
            ChecklistItem(title: "Stabilizer jacks raised", sortOrder: 7),
            ChecklistItem(title: "Doors and windows latched", sortOrder: 8),
            ChecklistItem(title: "All items secured inside", sortOrder: 9),
        ]
        saveData()
    }

    // MARK: - Persistence (local + iCloud KV sync)

    /// Writes to both UserDefaults (instant) and iCloud KV store (syncs across devices)
    private func saveData() {
        let encoder = JSONEncoder()
        let local = UserDefaults.standard
        let cloud = NSUbiquitousKeyValueStore.default

        func encode<T: Encodable>(_ value: T, key: String) {
            guard let data = try? encoder.encode(value) else { return }
            local.set(data, forKey: key)
            cloud.set(data, forKey: key)
        }
        encode(trips, key: tripsKey)
        encode(maintenanceTaskTypes, key: taskTypesKey)
        encode(maintenanceLog, key: logKey)
        encode(notes, key: notesKey)
        encode(checklistItems, key: checklistKey)
        encode(packingItems, key: packingItemsKey)
        encode(dateReminders, key: remindersKey)
        encode(trailerProfile, key: profileKey)
        encode(plannedTrips, key: plannedTripsKey)
        encode(campsiteReviews, key: campsiteReviewsKey)
        encode(customCampsites, key: customCampsitesKey)
        cloud.synchronize()
    }

    /// Loads from iCloud KV store first (most up-to-date), falls back to local UserDefaults
    private func loadData() {
        let decoder = JSONDecoder()
        let local = UserDefaults.standard
        let cloud = NSUbiquitousKeyValueStore.default

        func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
            // Prefer cloud data; fall back to local
            if let data = cloud.data(forKey: key), let value = try? decoder.decode(type, from: data) {
                // Mirror back to local so offline use works
                local.set(data, forKey: key)
                return value
            }
            if let data = local.data(forKey: key) {
                return try? decoder.decode(type, from: data)
            }
            return nil
        }
        trips = decode([Trip].self, key: tripsKey) ?? []
        maintenanceTaskTypes = decode([MaintenanceTaskType].self, key: taskTypesKey) ?? []
        maintenanceLog = decode([MaintenanceEntry].self, key: logKey) ?? []
        notes = decode([NoteItem].self, key: notesKey) ?? []
        checklistItems = decode([ChecklistItem].self, key: checklistKey) ?? []
        packingItems = decode([PackingItem].self, key: packingItemsKey) ?? []
        dateReminders = decode([DateReminder].self, key: remindersKey) ?? []
        trailerProfile = decode(TrailerProfile.self, key: profileKey) ?? TrailerProfile()
        plannedTrips = decode([PlannedTrip].self, key: plannedTripsKey) ?? []
        campsiteReviews = decode([CampsiteReview].self, key: campsiteReviewsKey) ?? []
        customCampsites = decode([CustomCampsite].self, key: customCampsitesKey) ?? []
    }

    /// Call this from the app entry point to listen for iCloud push changes
    func startICloudSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    @objc private func iCloudDidChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.loadData()
            self.scheduleAllNotifications()
        }
    }
}
