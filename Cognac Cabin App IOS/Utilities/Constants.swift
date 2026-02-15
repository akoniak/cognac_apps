import Foundation

enum Constants {
    // MARK: - Cabin Location (replace with your cabin's coordinates)
    static let cabinLatitude: Double = 44.0     // Replace with actual latitude
    static let cabinLongitude: Double = -73.5   // Replace with actual longitude

    // MARK: - OpenWeatherMap API
    static let openWeatherMapAPIKey = "YOUR_API_KEY_HERE"
    static let openWeatherMapBaseURL = "https://api.openweathermap.org/data/2.5/forecast"

    // MARK: - Camera Definitions (configure with your actual cameras)
    static let cameras: [Camera] = [
        Camera(
            name: "Front Door",
            brand: .dahua,
            host: "192.168.1.100",
            port: 80,
            channel: 1,
            credentials: CameraCredentials(username: "admin", password: "password")
        ),
        Camera(
            name: "Back Yard",
            brand: .dahua,
            host: "192.168.1.101",
            port: 80,
            channel: 1,
            credentials: CameraCredentials(username: "admin", password: "password")
        ),
        Camera(
            name: "Driveway",
            brand: .ring,
            host: "ring-device-id"
        ),
        Camera(
            name: "Side Entrance",
            brand: .blink,
            host: "blink-device-id"
        ),
    ]
}
