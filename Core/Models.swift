import Foundation

public enum ScrollShotError: LocalizedError {
    case invalidInput(String), io(String), unavailable(String)
    public var errorDescription: String? {
        switch self { case .invalidInput(let s), .io(let s), .unavailable(let s): return s }
    }
}
public struct CropInsets: Codable, Sendable, Equatable {
    public var top: Int
    public var bottom: Int
    public init(top: Int = 0, bottom: Int = 0) { self.top = top; self.bottom = bottom }
}
public struct FrameRecord: Codable, Sendable, Equatable {
    public var fileName: String
    public var width: Int
    public var height: Int
    public var offsetY: Int
    public var timestamp: Double
    public var segment: Int
    public init(fileName: String, width: Int, height: Int, offsetY: Int, timestamp: Double, segment: Int = 0) {
        self.fileName = fileName; self.width = width; self.height = height
        self.offsetY = offsetY; self.timestamp = timestamp; self.segment = segment
    }
}
public enum SessionState: String, Codable, Sendable { case recording, paused, ready, interrupted, failed }
public struct SessionManifest: Codable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var state: SessionState
    public var frames: [FrameRecord]
    public var crop: CropInsets
    public var warnings: [String]
    public var outputs: [String]
    public var maxProcessingMs: Double
    public init(id: UUID = UUID()) {
        self.id = id; createdAt = Date(); state = .recording; frames = []
        crop = CropInsets(); warnings = []; outputs = []; maxProcessingMs = 0
    }
}
public struct ImagePiece: Sendable, Equatable {
    public var fileName: String
    public var sourceY: Int
    public var height: Int
    public var destinationY: Int
}
public struct StitchSegment: Sendable {
    public var width: Int
    public var height: Int
    public var pieces: [ImagePiece]
}
