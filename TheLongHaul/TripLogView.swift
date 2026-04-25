import SwiftUI


struct TripLogView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var showingAddTrip = false
    @State private var tripToEdit: Trip?

    var body: some View {
        NavigationView {
            Group {
                if store.trips.isEmpty {
                    EmptyStateView(
                        icon: "road.lanes",
                        title: "No Trips Yet",
                        message: "Log your first trip to start tracking mileage."
                    )
                } else {
                    List {
                        ForEach(store.trips) { trip in
                            TripRow(trip: trip)
                                .contentShape(Rectangle())
                                .onTapGesture { tripToEdit = trip }
                        }
                        .onDelete { indexSet in
                            indexSet.map { store.trips[$0] }.forEach { store.deleteTrip($0) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Trip Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTrip = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                AddEditTripView(trip: nil)
            }
            .sheet(item: $tripToEdit) { trip in
                AddEditTripView(trip: trip)
            }
        }
    }
}

struct TripRow: View {
    var trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(trip.name.isEmpty ? "Unnamed Trip" : trip.name)
                        .font(.headline)
                    if trip.isInProgress {
                        Text("IN PROGRESS")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(5)
                    }
                }
                Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let nights = trip.nights, nights > 0 {
                    Text("\(nights) night\(nights == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !trip.notes.isEmpty {
                    Text(trip.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(trip.isInProgress ? "—" : "\(Int(trip.miles))")
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text("km")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddEditTripView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    var trip: Trip?

    @State private var name: String = ""
    @State private var startOdo: String = ""
    @State private var endOdo: String = ""
    @State private var date: Date = Date()
    @State private var notes: String = ""

    // Nights camping
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()

    var isEditing: Bool { trip != nil }

    // Fixed: use startOfDay on both dates to avoid time-of-day off-by-one
    var nightsCount: Int? {
        guard hasEndDate else { return nil }
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: date)
        let endDay = cal.startOfDay(for: endDate)
        let nights = cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return nights > 0 ? nights : nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Trip Details") {
                    TextField("Trip name (optional)", text: $name)
                    DatePicker("Start Date", selection: $date, displayedComponents: .date)
                        .onChange(of: date) { newStart in
                            // Keep end date at least on start date
                            if endDate < newStart {
                                endDate = newStart
                            }
                        }

                    Toggle("Has End Date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(
                            "End Date",
                            selection: $endDate,
                            in: date...,
                            displayedComponents: .date
                        )
                        if let nights = nightsCount {
                            HStack {
                                Text("Nights camping")
                                Spacer()
                                Text("\(nights) night\(nights == 1 ? "" : "s")")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Odometer (tow vehicle)") {
                    HStack {
                        Text("Start")
                        Spacer()
                        TextField("km", text: $startOdo)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        TextField("leave blank if in progress", text: $endOdo)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if !startOdo.isEmpty, let start = Double(startOdo),
                   let end = Double(endOdo), end >= start {
                    Section {
                        HStack {
                            Text("km this trip")
                            Spacer()
                            Text("\(Int(end - start))")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Trip" : "New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(startOdo.isEmpty || Double(startOdo) == nil)
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
        guard let trip = trip else { return }
        name = trip.name
        startOdo = String(trip.startOdometer)
        endOdo = trip.endOdometer.map { String($0) } ?? ""
        date = trip.date
        notes = trip.notes
        if let tripEndDate = trip.endDate {
            hasEndDate = true
            endDate = tripEndDate
        } else {
            hasEndDate = false
            endDate = trip.date
        }
    }

    private func save() {
        guard let start = Double(startOdo) else { return }
        let end = Double(endOdo)

        let updated = Trip(
            id: trip?.id ?? UUID(),
            name: name,
            startOdometer: start,
            endOdometer: end,
            date: date,
            endDate: hasEndDate ? endDate : nil,
            notes: notes
        )

        if isEditing {
            store.updateTrip(updated)
        } else {
            store.addTrip(updated)
        }
        dismiss()
    }
}
