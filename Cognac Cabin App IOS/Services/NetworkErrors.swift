import Foundation

enum CameraError: Error, LocalizedError {
    case invalidURL
    case snapshotFailed
    case invalidImageData
    case notImplemented(brand: CameraBrand)
    case authenticationFailed
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid camera URL"
        case .snapshotFailed:
            "Failed to capture snapshot"
        case .invalidImageData:
            "Invalid image data received"
        case .notImplemented(let brand):
            "\(brand.rawValue) integration not yet available"
        case .authenticationFailed:
            "Camera authentication failed"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        }
    }
}

enum WeatherError: Error, LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed(underlying: Error)
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid weather API URL"
        case .requestFailed(let code):
            "Weather request failed (HTTP \(code))"
        case .decodingFailed:
            "Failed to decode weather data"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        }
    }
}
