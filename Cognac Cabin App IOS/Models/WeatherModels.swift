import Foundation

// MARK: - OpenWeatherMap API Response

struct WeatherResponse: Codable, Sendable {
    let list: [WeatherEntry]
    let city: WeatherCity
}

struct WeatherCity: Codable, Sendable {
    let name: String
    let coord: WeatherCoord
}

struct WeatherCoord: Codable, Sendable {
    let lat: Double
    let lon: Double
}

struct WeatherEntry: Codable, Identifiable, Sendable {
    let dt: Int
    let main: WeatherMain
    let weather: [WeatherCondition]
    let dtTxt: String

    var id: Int { dt }

    enum CodingKeys: String, CodingKey {
        case dt, main, weather
        case dtTxt = "dt_txt"
    }
}

struct WeatherMain: Codable, Sendable {
    let temp: Double
    let tempMin: Double
    let tempMax: Double
    let humidity: Int

    enum CodingKeys: String, CodingKey {
        case temp
        case tempMin = "temp_min"
        case tempMax = "temp_max"
        case humidity
    }
}

struct WeatherCondition: Codable, Identifiable, Sendable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

// MARK: - Aggregated Daily Forecast

struct DailyForecast: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let highTemp: Double
    let lowTemp: Double
    let conditionDescription: String
    let conditionMain: String
    let iconCode: String
    let humidity: Int

    var sfSymbolName: String {
        WeatherIconMapper.sfSymbol(for: iconCode)
    }
}

// MARK: - Weather Icon to SF Symbol Mapping

enum WeatherIconMapper {
    static func sfSymbol(for iconCode: String) -> String {
        let baseCode = String(iconCode.prefix(2))
        let isNight = iconCode.hasSuffix("n")

        switch baseCode {
        case "01": return isNight ? "moon.stars.fill" : "sun.max.fill"
        case "02": return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case "03": return "cloud.fill"
        case "04": return "smoke.fill"
        case "09": return "cloud.drizzle.fill"
        case "10": return isNight ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill"
        case "11": return "cloud.bolt.fill"
        case "13": return "cloud.snow.fill"
        case "50": return "cloud.fog.fill"
        default: return "questionmark.circle"
        }
    }
}
