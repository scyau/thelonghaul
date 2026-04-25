import SwiftUI


struct TripStatsView: View {
    @EnvironmentObject var store: AppDataStore

    var completedTrips: [Trip] { store.trips.filter { !$0.isInProgress } }

    var avgTripLength: Double {
        guard !completedTrips.isEmpty else { return 0 }
        return store.totalMiles / Double(completedTrips.count)
    }

    var hasNightsData: Bool {
        completedTrips.contains { $0.nights != nil }
    }

    var body: some View {
        NavigationView {
            Group {
                if completedTrips.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "No Stats Yet",
                        message: "Complete your first trip to start seeing stats."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {

                            // Mileage summary cards
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                StatCard(
                                    title: "Total km",
                                    value: store.totalMiles.formatted(.number.precision(.fractionLength(0))),
                                    icon: "road.lanes", color: .blue
                                )
                                StatCard(
                                    title: "Total Trips",
                                    value: "\(completedTrips.count)",
                                    icon: "car.rear.and.caravan", color: .orange
                                )
                                StatCard(
                                    title: "This Year",
                                    value: store.milesThisYear.formatted(.number.precision(.fractionLength(0))) + " km",
                                    icon: "calendar", color: .green
                                )
                                StatCard(
                                    title: "Avg Trip",
                                    value: avgTripLength.formatted(.number.precision(.fractionLength(0))) + " km",
                                    icon: "arrow.left.and.right", color: .purple
                                )
                            }

                            // Nights camping cards — only shown once at least one trip has an end date
                            if hasNightsData {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    StatCard(
                                        title: "Total Nights",
                                        value: "\(store.totalNights)",
                                        icon: "moon.stars.fill", color: .indigo
                                    )
                                    StatCard(
                                        title: "Nights This Year",
                                        value: "\(store.nightsThisYear)",
                                        icon: "tent.fill", color: .teal
                                    )
                                }
                            }

                            // Longest trip
                            if let longest = store.longestTrip {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Label("Longest Trip", systemImage: "trophy.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.orange)
                                        Spacer()
                                    }
                                    .padding(.horizontal).padding(.top, 14).padding(.bottom, 8)

                                    Divider().padding(.horizontal)

                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(longest.name.isEmpty ? "Unnamed Trip" : longest.name)
                                                .font(.headline)
                                            Text(longest.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(longest.miles.formatted(.number.precision(.fractionLength(0))))
                                                .font(.title2.weight(.semibold).monospacedDigit())
                                            Text("km").font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal).padding(.vertical, 12)
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                            }

                            // Longest camping trip (most nights) — shown when data available
                            if hasNightsData, let longestCamp = completedTrips.filter({ $0.nights != nil }).max(by: { ($0.nights ?? 0) < ($1.nights ?? 0) }) {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Label("Longest Stay", systemImage: "moon.stars.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.indigo)
                                        Spacer()
                                    }
                                    .padding(.horizontal).padding(.top, 14).padding(.bottom, 8)

                                    Divider().padding(.horizontal)

                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(longestCamp.name.isEmpty ? "Unnamed Trip" : longestCamp.name)
                                                .font(.headline)
                                            Text(longestCamp.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if let nights = longestCamp.nights {
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("\(nights)")
                                                    .font(.title2.weight(.semibold).monospacedDigit())
                                                Text("nights").font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal).padding(.vertical, 12)
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                            }

                            // Odometer history line chart
                            if store.odometerByMonth.count >= 2 {
                                OdometerChartCard(dataPoints: store.odometerByMonth)
                            }

                            // km by year bar chart
                            if store.milesByYear.count > 0 {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("km by Year")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal).padding(.top, 14).padding(.bottom, 12)

                                    Divider().padding(.horizontal)

                                    let maxMiles = store.milesByYear.map { $0.1 }.max() ?? 1
                                    VStack(spacing: 14) {
                                        ForEach(store.milesByYear.reversed(), id: \.0) { year, miles in
                                            HStack(spacing: 12) {
                                                Text(String(year))
                                                    .font(.caption.monospacedDigit())
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 36, alignment: .trailing)
                                                GeometryReader { geo in
                                                    ZStack(alignment: .leading) {
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .fill(Color(.systemFill)).frame(height: 22)
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .fill(Color.accentColor)
                                                            .frame(width: geo.size.width * (miles / maxMiles), height: 22)
                                                    }
                                                }
                                                .frame(height: 22)
                                                Text(miles.formatted(.number.precision(.fractionLength(0))))
                                                    .font(.caption.monospacedDigit())
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 52, alignment: .trailing)
                                            }
                                        }
                                    }
                                    .padding(.horizontal).padding(.vertical, 12)
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                            }

                            // Recent trips
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Recent Trips")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal).padding(.top, 14).padding(.bottom, 8)
                                Divider().padding(.horizontal)
                                ForEach(completedTrips.prefix(5)) { trip in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(trip.name.isEmpty ? "Unnamed Trip" : trip.name)
                                                .font(.subheadline)
                                            Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(Int(trip.miles)) km")
                                                .font(.subheadline.monospacedDigit()).foregroundColor(.secondary)
                                            if let nights = trip.nights {
                                                Text("\(nights)n")
                                                    .font(.caption.monospacedDigit()).foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal).padding(.vertical, 10)
                                    Divider().padding(.horizontal)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

                            Spacer(minLength: 20)
                        }
                        .padding(.horizontal).padding(.top, 8)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Trip Stats")
        }
    }
}

// MARK: - Odometer History Chart
struct OdometerChartCard: View {
    var dataPoints: [(label: String, km: Double)]

    var displayed: [(label: String, km: Double)] {
        guard dataPoints.count > 12 else { return dataPoints }
        let step = Double(dataPoints.count - 1) / 11.0
        return (0..<12).map { i in dataPoints[Int((Double(i) * step).rounded())] }
    }

    var maxKm: Double { dataPoints.map { $0.km }.max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Odometer History", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Total km over time")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal).padding(.top, 14).padding(.bottom, 12)

            Divider().padding(.horizontal)

            GeometryReader { geo in
                let w = geo.size.width - 48
                let h = geo.size.height
                let pts = displayed
                let count = pts.count

                ZStack(alignment: .bottomLeading) {
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            Spacer()
                            Divider().opacity(0.4)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach((0..<4).reversed(), id: \.self) { i in
                            let val = maxKm * Double(i + 1) / 4.0
                            Text(val >= 1000
                                 ? String(format: "%.0fk", val / 1000)
                                 : String(format: "%.0f", val))
                                .font(.system(size: 9)).foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .frame(width: 38, height: h)

                    if count >= 2 {
                        let xStep = w / CGFloat(count - 1)

                        Path { path in
                            path.move(to: CGPoint(x: 40, y: h))
                            for (i, pt) in pts.enumerated() {
                                let x = 40 + CGFloat(i) * xStep
                                let y = h - CGFloat(pt.km / maxKm) * h
                                if i == 0 { path.addLine(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            path.addLine(to: CGPoint(x: 40 + CGFloat(count - 1) * xStep, y: h))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                        Path { path in
                            for (i, pt) in pts.enumerated() {
                                let x = 40 + CGFloat(i) * xStep
                                let y = h - CGFloat(pt.km / maxKm) * h
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        ForEach(Array(pts.enumerated()), id: \.offset) { i, pt in
                            let x = 40 + CGFloat(i) * xStep
                            let y = h - CGFloat(pt.km / maxKm) * h
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(height: 160)
            .padding(.horizontal, 4)
            .padding(.top, 8)

            let pts = displayed
            if pts.count >= 2 {
                HStack {
                    Text(pts.first?.label ?? "")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                    Spacer()
                    if pts.count > 4 {
                        Text(pts[pts.count / 2].label)
                            .font(.system(size: 9)).foregroundColor(.secondary)
                        Spacer()
                    }
                    Text(pts.last?.label ?? "")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color).font(.subheadline)
                Spacer()
            }
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}
