import SwiftUI
import WeatherKit
import CoreLocation
import Combine

// MARK: - Weather Service
@MainActor
class WeatherService: ObservableObject {
    static let shared = WeatherService()
    private let service = WeatherKit.WeatherService.shared

    @Published var forecast: [DayWeather] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var locationName: String = ""

    private var geocodeTask: Task<Void, Never>? = nil

    func fetchForecast(for location: String, latitude: Double? = nil, longitude: Double? = nil, startDate: Date, endDate: Date) {
        guard !location.isEmpty else { return }

        // Cancel any in-flight request
        geocodeTask?.cancel()
        forecast = []
        errorMessage = nil
        isLoading = true
        locationName = location

        geocodeTask = Task {
            do {
                // Use stored coordinates if available, otherwise geocode
                let clLocation: CLLocation
                if let lat = latitude, let lon = longitude {
                    clLocation = CLLocation(latitude: lat, longitude: lon)
                } else {
                    let geocoder = CLGeocoder()
                    let placemarks = try await geocoder.geocodeAddressString(location)
                    guard let placemark = placemarks.first,
                          let resolved = placemark.location else {
                        errorMessage = "Couldn't find \"\(location)\" on the map."
                        isLoading = false
                        return
                    }
                    clLocation = resolved
                }

                guard !Task.isCancelled else { return }

                // Fetch weather
                let weather = try await service.weather(for: clLocation)
                let daily = weather.dailyForecast.forecast

                // Filter to trip date range (include a couple days either side for context)
                let cal = Calendar.current
                let rangeStart = cal.startOfDay(for: startDate)
                let rangeEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate

                let tripDays = daily.filter { day in
                    day.date >= rangeStart && day.date <= rangeEnd
                }

                forecast = tripDays
                isLoading = false

            } catch is CancellationError {
                isLoading = false
//            } catch {
//                if error.localizedDescription.contains("not authorized") ||
//                   error.localizedDescription.contains("denied") {
//                    errorMessage = "Weather unavailable — WeatherKit not authorized."
//                } else {
//                    errorMessage = "Weather data unavailable."
//                }
//                isLoading = false
//            }
                
            } catch {
                print("WeatherKit error: \(error)")
                print("WeatherKit error type: \(type(of: error))")
                if let wkError = error as? WeatherError {
                    print("WeatherError: \(wkError)")
                }
                if error.localizedDescription.contains("not authorized") ||
                   error.localizedDescription.contains("denied") {
                    errorMessage = "Weather unavailable — WeatherKit not authorized."
                } else {
                    errorMessage = "Weather data unavailable. (\(error.localizedDescription))"
                }
                isLoading = false
            }
        }
    }

    func clear() {
        geocodeTask?.cancel()
        forecast = []
        errorMessage = nil
        isLoading = false
    }
}

// MARK: - Trip Weather Card View
struct TripWeatherView: View {
    var trip: PlannedTrip
    @StateObject private var weatherService = WeatherService()

    // Only show weather if trip is within 10 days (WeatherKit forecast limit)
    var isInForecastRange: Bool {
        let daysUntilEnd = Calendar.current.dateComponents([.day], from: Date(), to: trip.endDate).day ?? 0
        return daysUntilEnd >= 0 && daysUntilEnd <= 10
    }

    var body: some View {
        Group {
            if !trip.location.isEmpty && isInForecastRange {
                DetailCard(title: "Weather Forecast", icon: "cloud.sun") {
                    Group {
                        if weatherService.isLoading {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 4)
                                Text("Loading forecast for \(trip.location)…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        } else if let error = weatherService.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        } else if weatherService.forecast.isEmpty {
                            Text("No forecast available yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(weatherService.forecast, id: \.date) { day in
                                    WeatherDayRow(day: day, tripStart: trip.startDate, tripEnd: trip.endDate)
                                    if day.date != weatherService.forecast.last?.date {
                                        Divider().padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.vertical, 4)

                            HStack {
                                Image(systemName: "apple.logo")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Weather data from Apple Weather")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 10)
                        }
                    }
                }
                .onAppear {
                    weatherService.fetchForecast(
                        for: trip.location,
                        latitude: trip.locationLatitude,
                        longitude: trip.locationLongitude,
                        startDate: trip.startDate,
                        endDate: trip.endDate
                    )
                }
                .onDisappear {
                    weatherService.clear()
                }
            } else if !trip.location.isEmpty && !isInForecastRange {
                // Trip is more than 10 days out — show a placeholder
                DetailCard(title: "Weather Forecast", icon: "cloud.sun") {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.secondary)
                        Text("Forecast available within 10 days of your trip.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
        }
    }
}

// MARK: - Individual day row
struct WeatherDayRow: View {
    var day: DayWeather
    var tripStart: Date
    var tripEnd: Date

    var isOnTrip: Bool {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day.date)
        let start = cal.startOfDay(for: tripStart)
        let end = cal.startOfDay(for: tripEnd)
        return dayStart >= start && dayStart <= end
    }

    var highC: Int { Int(day.highTemperature.converted(to: .celsius).value.rounded()) }
    var lowC: Int { Int(day.lowTemperature.converted(to: .celsius).value.rounded()) }

    var body: some View {
        HStack(spacing: 12) {
            // Day label
            VStack(alignment: .leading, spacing: 1) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.subheadline.weight(isOnTrip ? .semibold : .regular))
                    .foregroundColor(isOnTrip ? .primary : .secondary)
                Text(day.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, alignment: .leading)

            // Condition icon
            Image(systemName: day.symbolName)
                .font(.title3)
                .foregroundColor(iconColor(for: day.symbolName))
                .frame(width: 28)

            // Condition description
            Text(day.condition.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            // Precip chance
            if day.precipitationChance > 0.1 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("\(Int(day.precipitationChance * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.blue)
                }
            }

            // High / low
            HStack(spacing: 4) {
                Text("\(highC)°")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                Text("\(lowC)°")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(isOnTrip ? Color.accentColor.opacity(0.05) : Color.clear)
    }

    private func iconColor(for symbol: String) -> Color {
        if symbol.contains("sun") || symbol.contains("clear") { return .orange }
        if symbol.contains("rain") || symbol.contains("drizzle") { return .blue }
        if symbol.contains("snow") || symbol.contains("sleet") { return .cyan }
        if symbol.contains("thunder") { return .purple }
        if symbol.contains("wind") { return .teal }
        return .gray
    }
}
