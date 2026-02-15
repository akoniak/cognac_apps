import Foundation

final class WeatherService: Sendable {
    private let apiKey: String
    private let baseURL: String

    init(apiKey: String = Constants.openWeatherMapAPIKey, baseURL: String = Constants.openWeatherMapBaseURL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func fetchForecast(latitude: Double, longitude: Double) async throws -> [DailyForecast] {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "imperial"),
        ]

        guard let url = components?.url else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.requestFailed(statusCode: 0)
        }

        guard httpResponse.statusCode == 200 else {
            throw WeatherError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
            return aggregateToDailyForecasts(weatherResponse.list)
        } catch {
            throw WeatherError.decodingFailed(underlying: error)
        }
    }

    private func aggregateToDailyForecasts(_ entries: [WeatherEntry]) -> [DailyForecast] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: entries) { entry -> Date in
            let date = Date(timeIntervalSince1970: TimeInterval(entry.dt))
            return calendar.startOfDay(for: date)
        }

        return grouped.keys.sorted().compactMap { dayStart -> DailyForecast? in
            guard let dayEntries = grouped[dayStart], !dayEntries.isEmpty else { return nil }

            let highTemp = dayEntries.map(\.main.tempMax).max() ?? 0
            let lowTemp = dayEntries.map(\.main.tempMin).min() ?? 0
            let avgHumidity = dayEntries.map(\.main.humidity).reduce(0, +) / dayEntries.count

            // Find the most common weather condition
            let conditionCounts = dayEntries
                .compactMap(\.weather.first)
                .reduce(into: [String: Int]()) { counts, condition in
                    counts[condition.main, default: 0] += 1
                }
            let mostCommonCondition = conditionCounts.max(by: { $0.value < $1.value })?.key ?? "Clear"

            // Get icon from the entry closest to noon
            let noonComponents = calendar.dateComponents([.year, .month, .day], from: dayStart)
            var noonTarget = noonComponents
            noonTarget.hour = 12
            let noonDate = calendar.date(from: noonTarget) ?? dayStart

            let closestToNoon = dayEntries.min(by: { entry1, entry2 in
                let date1 = Date(timeIntervalSince1970: TimeInterval(entry1.dt))
                let date2 = Date(timeIntervalSince1970: TimeInterval(entry2.dt))
                return abs(date1.timeIntervalSince(noonDate)) < abs(date2.timeIntervalSince(noonDate))
            })

            let iconCode = closestToNoon?.weather.first?.icon ?? "01d"
            let description = closestToNoon?.weather.first?.description.capitalized ?? "Clear"

            return DailyForecast(
                id: UUID(),
                date: dayStart,
                highTemp: highTemp,
                lowTemp: lowTemp,
                conditionDescription: description,
                conditionMain: mostCommonCondition,
                iconCode: iconCode,
                humidity: avgHumidity
            )
        }
    }
}
