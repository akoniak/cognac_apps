import Foundation
import Observation

@Observable
final class WeatherViewModel {
    var dailyForecasts: [DailyForecast] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let weatherService: WeatherService

    init(weatherService: WeatherService = WeatherService()) {
        self.weatherService = weatherService
    }

    func loadForecast() async {
        isLoading = true
        errorMessage = nil

        do {
            dailyForecasts = try await weatherService.fetchForecast(
                latitude: Constants.cabinLatitude,
                longitude: Constants.cabinLongitude
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
