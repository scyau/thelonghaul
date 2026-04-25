import SwiftUI
import PhotosUI

struct TrailerProfileView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var isEditing = false

    var profile: TrailerProfile { store.trailerProfile }

    var trailerPhoto: UIImage? {
        guard let fn = profile.photoFilename else { return nil }
        return PhotoStorage.load(filename: fn)
    }

    var hasData: Bool {
        !profile.make.isEmpty || !profile.model.isEmpty || !profile.year.isEmpty
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Photo
                    ZStack {
                        if let photo = trailerPhoto {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .clipped()
                                .cornerRadius(16)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemFill))
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                        Text("No trailer photo yet")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                    }

                    // Name / identity headline
                    if hasData {
                        VStack(spacing: 4) {
                            Text([profile.year, profile.make, profile.model]
                                .filter { !$0.isEmpty }
                                .joined(separator: " "))
                                .font(.title2.weight(.semibold))
                            if !profile.licensePlate.isEmpty {
                                Text(profile.licensePlate)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Identity & Registration
                    ProfileSpecCard(title: "Identity & Registration", specs: [
                        ("Make", profile.make),
                        ("Model", profile.model),
                        ("Year", profile.year),
                        ("VIN", profile.vin),
                        ("Purchased", profile.purchasedDate),
                        ("License Plate", profile.licensePlate),
                    ])

                    // Dimensions & Weights
                    ProfileSpecCard(title: "Dimensions & Weights", specs: [
                        ("GVWR", profile.gvwr),
                        ("Tare Weight", profile.tareWeight),
                        ("Payload", profile.payload),
                        ("Drawbar", profile.drawbar),
                        ("Length", profile.length),
                        ("Width", profile.width),
                        ("Height", profile.height),
                    ])

                    // Chassis & Running Gear
                    ProfileSpecCard(title: "Chassis & Running Gear", specs: [
                        ("Axles", profile.axles),
                        ("Chassis", profile.chassis),
                        ("Body", profile.body),
                        ("Brakes", profile.brakes),
                        ("Coupling", profile.coupling),
                        ("Jockey Wheel", profile.jockeyWheel),
                        ("Suspension", profile.suspension),
                        ("Wheels", profile.wheels),
                        ("Wheel Bearings", profile.wheelBearings),
                        ("Tire Size", profile.tireSize),
                        ("Tires", profile.tires),
                    ])

                    // Electrical & Power
                    ProfileSpecCard(title: "Electrical & Power", specs: [
                        ("Battery", profile.battery),
                        ("BMS", profile.bms),
                        ("Inverter", profile.inverter),
                        ("Solar", profile.solar),
                    ])

                    // Appliances & Systems
                    ProfileSpecCard(title: "Appliances & Systems", specs: [
                        ("Fridge", profile.fridge),
                        ("Stove", profile.stove),
                        ("Water Heater", profile.waterHeater),
                        ("Water Filtration System", profile.waterFiltrationSystem),
                        ("Sediment Filter Cartridge", profile.sedimentFilterCartridge),
                        ("Carbon Filter Cartridge", profile.carbonFilterCartridge),
                        ("Water Pump", profile.waterPump),
                    ])

                    // Extras & Accessories
                    ProfileSpecCard(title: "Extras & Accessories", specs: [
                        ("Awning", profile.awning),
                        ("Shower Pod", profile.showerPod),
                        ("RTT", profile.rtt),
                        ("Mattress", profile.mattress),
                    ])

                    // Notes
                    if !profile.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.subheadline.weight(.semibold))
                            Text(profile.notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                    }

                    if !hasData {
                        VStack(spacing: 12) {
                            Image(systemName: "car.rear")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No Profile Yet")
                                .font(.title3.weight(.semibold))
                            Text("Tap Edit to add your trailer's details.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trailer Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { isEditing = true }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditTrailerProfileView()
            }
        }
    }
}

// MARK: - Spec Card helper
struct ProfileSpecCard: View {
    var title: String
    var specs: [(String, String)]

    var filtered: [(String, String)] { specs.filter { !$0.1.isEmpty } }

    var body: some View {
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                Divider().padding(.horizontal)

                ForEach(filtered, id: \.0) { label, value in
                    HStack(alignment: .top) {
                        Text(label)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(minWidth: 130, alignment: .leading)
                        Spacer()
                        Text(value)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    Divider().padding(.horizontal)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Edit Trailer Profile
struct EditTrailerProfileView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss

    @State private var make = ""
    @State private var model = ""
    @State private var year = ""
    @State private var vin = ""
    @State private var purchasedDate = ""
    @State private var licensePlate = ""
    @State private var gvwr = ""
    @State private var tareWeight = ""
    @State private var payload = ""
    @State private var drawbar = ""
    @State private var length = ""
    @State private var width = ""
    @State private var height = ""
    @State private var axles = ""
    @State private var chassis = ""
    @State private var bodyType = ""
    @State private var brakes = ""
    @State private var coupling = ""
    @State private var jockeyWheel = ""
    @State private var suspension = ""
    @State private var wheels = ""
    @State private var wheelBearings = ""
    @State private var tireSize = ""
    @State private var tires = ""
    @State private var battery = ""
    @State private var bms = ""
    @State private var inverter = ""
    @State private var solar = ""
    @State private var fridge = ""
    @State private var stove = ""
    @State private var waterHeater = ""
    @State private var waterFiltrationSystem = ""
    @State private var sedimentFilterCartridge = ""
    @State private var carbonFilterCartridge = ""
    @State private var waterPump = ""
    @State private var awning = ""
    @State private var showerPod = ""
    @State private var rtt = ""
    @State private var mattress = ""
    @State private var notes = ""
    @State private var photoFilename: String? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoImage: UIImage? = nil

    var body: some View {
        NavigationView {
            Form {
                // Photo
                Section("Photo") {
                    if let img = photoImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipped()
                            .cornerRadius(10)
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(photoImage == nil ? "Add Photo" : "Change Photo", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedPhoto) { item in
                        item?.loadTransferable(type: Data.self) { result in
                            DispatchQueue.main.async {
                                if case .success(let data) = result, let data = data {
                                    photoImage = UIImage(data: data)
                                }
                            }
                        }
                    }
                    if photoImage != nil || photoFilename != nil {
                        Button("Remove Photo", role: .destructive) {
                            photoImage = nil
                            if let fn = photoFilename { PhotoStorage.delete(filename: fn) }
                            photoFilename = nil
                        }
                    }
                }

                // Identity
                Section("Identity") {
                    TextField("Make (e.g. Airstream)", text: $make)
                    TextField("Model (e.g. Bambi 16)", text: $model)
                    TextField("Year (e.g. 2019)", text: $year)
                        .keyboardType(.numberPad)
                }

                // Registration
                Section("Registration") {
                    TextField("License Plate", text: $licensePlate)
                    TextField("VIN", text: $vin)
                    TextField("Purchased Date (e.g. June 2021)", text: $purchasedDate)
                }

                // Dimensions & Weights
                Section("Dimensions & Weights") {
                    TextField("GVWR (e.g. 3500 kg)", text: $gvwr)
                    TextField("Tare Weight (e.g. 1800 kg)", text: $tareWeight)
                    TextField("Payload (e.g. 1700 kg)", text: $payload)
                    TextField("Drawbar (e.g. 200 kg)", text: $drawbar)
                    TextField("Length (e.g. 6.5 m)", text: $length)
                    TextField("Width (e.g. 2.4 m)", text: $width)
                    TextField("Height (e.g. 2.8 m)", text: $height)
                }

                // Chassis & Running Gear
                Section("Chassis & Running Gear") {
                    TextField("Axles (e.g. Dual)", text: $axles)
                    TextField("Chassis", text: $chassis)
                    TextField("Body", text: $bodyType)
                    TextField("Brakes (e.g. Electric)", text: $brakes)
                    TextField("Coupling (e.g. 50mm ball)", text: $coupling)
                    TextField("Jockey Wheel", text: $jockeyWheel)
                    TextField("Suspension (e.g. Coil over)", text: $suspension)
                    TextField("Wheels (e.g. 15\" alloy)", text: $wheels)
                    TextField("Wheel Bearings", text: $wheelBearings)
                    TextField("Tire Size (e.g. ST225/75R15)", text: $tireSize)
                    TextField("Tires (e.g. BF Goodrich AT)", text: $tires)
                }

                // Electrical & Power
                Section("Electrical & Power") {
                    TextField("Battery (e.g. 200Ah LiFePO4)", text: $battery)
                    TextField("BMS", text: $bms)
                    TextField("Inverter (e.g. 2000W)", text: $inverter)
                    TextField("Solar (e.g. 200W panel)", text: $solar)
                }

                // Appliances & Systems
                Section("Appliances & Systems") {
                    TextField("Fridge (e.g. 60L 12V compressor)", text: $fridge)
                    TextField("Stove (e.g. 2 burner gas)", text: $stove)
                    TextField("Water Heater", text: $waterHeater)
                    TextField("Water Filtration System", text: $waterFiltrationSystem)
                    TextField("Sediment Filter Cartridge", text: $sedimentFilterCartridge)
                    TextField("Carbon Filter Cartridge", text: $carbonFilterCartridge)
                    TextField("Water Pump", text: $waterPump)
                }

                // Extras & Accessories
                Section("Extras & Accessories") {
                    TextField("Awning (e.g. 2.5m Fiamma)", text: $awning)
                    TextField("Shower Pod", text: $showerPod)
                    TextField("RTT (Roof Top Tent)", text: $rtt)
                    TextField("Mattress", text: $mattress)
                }

                // Notes
                Section("Notes") {
                    TextField("Any other details...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear { populate() }
        }
    }

    private func populate() {
        let p = store.trailerProfile
        make = p.make; model = p.model; year = p.year
        vin = p.vin; purchasedDate = p.purchasedDate; licensePlate = p.licensePlate
        gvwr = p.gvwr; tareWeight = p.tareWeight; payload = p.payload
        drawbar = p.drawbar; length = p.length; width = p.width; height = p.height
        axles = p.axles; chassis = p.chassis; bodyType = p.body
        brakes = p.brakes; coupling = p.coupling; jockeyWheel = p.jockeyWheel
        suspension = p.suspension; wheels = p.wheels; wheelBearings = p.wheelBearings
        tireSize = p.tireSize; tires = p.tires
        battery = p.battery; bms = p.bms; inverter = p.inverter; solar = p.solar
        fridge = p.fridge; stove = p.stove; waterHeater = p.waterHeater
        waterFiltrationSystem = p.waterFiltrationSystem
        sedimentFilterCartridge = p.sedimentFilterCartridge
        carbonFilterCartridge = p.carbonFilterCartridge; waterPump = p.waterPump
        awning = p.awning; showerPod = p.showerPod; rtt = p.rtt; mattress = p.mattress
        notes = p.notes; photoFilename = p.photoFilename
        if let fn = p.photoFilename { photoImage = PhotoStorage.load(filename: fn) }
    }

    private func save() {
        var finalFilename = photoFilename
        if let img = photoImage {
            let fn = photoFilename ?? PhotoStorage.newFilename()
            PhotoStorage.save(img, filename: fn)
            finalFilename = fn
        }

        let updated = TrailerProfile(
            make: make, model: model, year: year,
            vin: vin, purchasedDate: purchasedDate, licensePlate: licensePlate,
            tireSize: tireSize, axles: axles, gvwr: gvwr,
            tareWeight: tareWeight, payload: payload, drawbar: drawbar,
            length: length, width: width, height: height,
            chassis: chassis, body: bodyType, brakes: brakes,
            coupling: coupling, jockeyWheel: jockeyWheel, suspension: suspension,
            wheels: wheels, wheelBearings: wheelBearings, tires: tires,
            battery: battery, bms: bms, inverter: inverter, solar: solar,
            fridge: fridge, stove: stove, waterHeater: waterHeater,
            waterFiltrationSystem: waterFiltrationSystem,
            sedimentFilterCartridge: sedimentFilterCartridge,
            carbonFilterCartridge: carbonFilterCartridge, waterPump: waterPump,
            awning: awning, showerPod: showerPod, rtt: rtt, mattress: mattress,
            notes: notes, photoFilename: finalFilename
        )
        store.updateTrailerProfile(updated)
        dismiss()
    }
}
