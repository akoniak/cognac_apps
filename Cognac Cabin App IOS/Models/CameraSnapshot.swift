import Foundation
import UIKit

struct CameraSnapshot: Identifiable, Sendable {
    let id: UUID
    let cameraId: UUID
    let cameraName: String
    let brand: CameraBrand
    let image: UIImage
    let timestamp: Date

    init(id: UUID = UUID(), cameraId: UUID, cameraName: String, brand: CameraBrand, image: UIImage, timestamp: Date = Date()) {
        self.id = id
        self.cameraId = cameraId
        self.cameraName = cameraName
        self.brand = brand
        self.image = image
        self.timestamp = timestamp
    }
}

extension CameraSnapshot: Hashable {
    static func == (lhs: CameraSnapshot, rhs: CameraSnapshot) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
