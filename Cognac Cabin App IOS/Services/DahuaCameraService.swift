import Foundation
import UIKit

final class DahuaCameraService: CameraServiceProtocol, @unchecked Sendable {
    let brand: CameraBrand = .dahua

    func fetchSnapshot(for camera: Camera) async throws -> CameraSnapshot {
        let port = camera.port ?? 80
        let urlString = "http://\(camera.host):\(port)/cgi-bin/snapshot.cgi?channel=\(camera.channel)"

        guard let url = URL(string: urlString) else {
            throw CameraError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let configuration = URLSessionConfiguration.default
        let delegate = DigestAuthDelegate(credentials: camera.credentials)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CameraError.snapshotFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw CameraError.authenticationFailed
            }
            throw CameraError.snapshotFailed
        }

        guard let image = UIImage(data: data) else {
            throw CameraError.invalidImageData
        }

        return CameraSnapshot(
            cameraId: camera.id,
            cameraName: camera.name,
            brand: .dahua,
            image: image
        )
    }
}

// MARK: - Digest Authentication Delegate

private final class DigestAuthDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let credentials: CameraCredentials?

    init(credentials: CameraCredentials?) {
        self.credentials = credentials
        super.init()
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let credentials = credentials,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let credential = URLCredential(
            user: credentials.username,
            password: credentials.password,
            persistence: .forSession
        )
        completionHandler(.useCredential, credential)
    }
}
