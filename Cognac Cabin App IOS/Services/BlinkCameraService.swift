import Foundation

final class BlinkCameraService: CameraServiceProtocol, @unchecked Sendable {
    let brand: CameraBrand = .blink

    func fetchSnapshot(for camera: Camera) async throws -> CameraSnapshot {
        // Blink uses unofficial API with token-based auth.
        // TODO: Implement Blink API integration:
        // 1. POST to https://rest-{region}.immedia-semi.com/api/v5/account/login
        // 2. Authenticate and obtain session token
        // 3. Fetch snapshot thumbnail from media endpoints
        throw CameraError.notImplemented(brand: .blink)
    }
}
