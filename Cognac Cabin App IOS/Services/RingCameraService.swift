import Foundation

final class RingCameraService: CameraServiceProtocol, @unchecked Sendable {
    let brand: CameraBrand = .ring

    func fetchSnapshot(for camera: Camera) async throws -> CameraSnapshot {
        // Ring requires OAuth2 flow with unofficial API endpoints.
        // TODO: Implement Ring API integration:
        // 1. POST to https://oauth.ring.com/oauth/token with credentials
        // 2. Handle 2FA challenge
        // 3. Use session token to GET snapshot from
        //    https://api.ring.com/clients_api/snapshots/next/{device_id}
        throw CameraError.notImplemented(brand: .ring)
    }
}
