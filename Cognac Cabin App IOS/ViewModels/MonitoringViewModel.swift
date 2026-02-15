import Foundation
import Observation

@Observable
final class MonitoringViewModel {
    var snapshots: [CameraSnapshot] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let cameraServices: [any CameraServiceProtocol]
    private let cameras: [Camera]

    init(cameraServices: [any CameraServiceProtocol], cameras: [Camera] = Constants.cameras) {
        self.cameraServices = cameraServices
        self.cameras = cameras
    }

    func loadSnapshots() async {
        isLoading = true
        errorMessage = nil

        var allSnapshots: [CameraSnapshot] = []
        var errors: [String] = []

        for service in cameraServices {
            let camerasForBrand = cameras.filter { $0.brand == service.brand }
            guard !camerasForBrand.isEmpty else { continue }

            let results = await service.fetchAllSnapshots(for: camerasForBrand)
            for result in results {
                switch result {
                case .success(let snapshot):
                    allSnapshots.append(snapshot)
                case .failure(let error):
                    errors.append(error.localizedDescription)
                }
            }
        }

        snapshots = allSnapshots
        if !errors.isEmpty && allSnapshots.isEmpty {
            errorMessage = errors.first
        }

        isLoading = false
    }

    static func withMockServices() -> MonitoringViewModel {
        MonitoringViewModel(
            cameraServices: [
                MockCameraService(brand: .dahua),
                MockCameraService(brand: .ring),
                MockCameraService(brand: .blink),
            ]
        )
    }
}
