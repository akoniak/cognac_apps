import Foundation

struct Camera: Identifiable, Sendable {
    let id: UUID
    let name: String
    let brand: CameraBrand
    let host: String
    let port: Int?
    let channel: Int
    let credentials: CameraCredentials?

    init(id: UUID = UUID(), name: String, brand: CameraBrand, host: String, port: Int? = nil, channel: Int = 1, credentials: CameraCredentials? = nil) {
        self.id = id
        self.name = name
        self.brand = brand
        self.host = host
        self.port = port
        self.channel = channel
        self.credentials = credentials
    }
}

struct CameraCredentials: Sendable {
    let username: String
    let password: String
}
