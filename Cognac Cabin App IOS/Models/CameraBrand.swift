import Foundation

enum CameraBrand: String, CaseIterable, Sendable, Identifiable {
    case dahua = "Dahua (DMSS)"
    case ring = "Ring"
    case blink = "Blink"

    var id: String { rawValue }
}
