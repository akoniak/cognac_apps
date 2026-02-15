import Foundation

protocol CameraServiceProtocol: Sendable {
    var brand: CameraBrand { get }
    func fetchSnapshot(for camera: Camera) async throws -> CameraSnapshot
}

extension CameraServiceProtocol {
    func fetchAllSnapshots(for cameras: [Camera]) async -> [Result<CameraSnapshot, Error>] {
        await withTaskGroup(of: Result<CameraSnapshot, Error>.self) { group in
            for camera in cameras {
                group.addTask {
                    do {
                        let snapshot = try await self.fetchSnapshot(for: camera)
                        return .success(snapshot)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var results: [Result<CameraSnapshot, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}
