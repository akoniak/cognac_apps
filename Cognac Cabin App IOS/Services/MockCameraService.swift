import Foundation
import UIKit

final class MockCameraService: CameraServiceProtocol, @unchecked Sendable {
    let brand: CameraBrand

    init(brand: CameraBrand = .dahua) {
        self.brand = brand
    }

    func fetchSnapshot(for camera: Camera) async throws -> CameraSnapshot {
        try await Task.sleep(for: .milliseconds(300))

        let image = Self.generatePlaceholderImage(name: camera.name, brand: camera.brand)
        return CameraSnapshot(
            cameraId: camera.id,
            cameraName: camera.name,
            brand: camera.brand,
            image: image
        )
    }

    private static func generatePlaceholderImage(name: String, brand: CameraBrand) -> UIImage {
        let size = CGSize(width: 640, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Background gradient based on brand
            let bgColor: UIColor = switch brand {
            case .dahua: .systemTeal
            case .ring: .systemBlue
            case .blink: .systemCyan
            }
            bgColor.withAlphaComponent(0.3).setFill()
            context.fill(rect)

            // Camera icon
            let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
            if let cameraIcon = UIImage(systemName: "video.fill", withConfiguration: iconConfig) {
                let iconSize = cameraIcon.size
                let iconOrigin = CGPoint(
                    x: (size.width - iconSize.width) / 2,
                    y: (size.height - iconSize.height) / 2 - 20
                )
                UIColor.white.withAlphaComponent(0.6).setFill()
                cameraIcon.draw(at: iconOrigin)
            }

            // Camera name label
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle,
            ]

            let textRect = CGRect(x: 20, y: size.height - 60, width: size.width - 40, height: 30)
            name.draw(in: textRect, withAttributes: attributes)

            // Brand label
            let brandAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7),
                .paragraphStyle: paragraphStyle,
            ]
            let brandRect = CGRect(x: 20, y: size.height - 35, width: size.width - 40, height: 20)
            brand.rawValue.draw(in: brandRect, withAttributes: brandAttributes)
        }
    }
}
