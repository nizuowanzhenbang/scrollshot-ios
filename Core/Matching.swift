import Foundation
public struct GrayFrame: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]
    public init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width; self.height = height; self.pixels = pixels
    }
}
public struct Match: Sendable {
    public let displacement: Int
    public let error: Double
    public let confidence: Double
}
public enum Matcher {
    public static func match(previous: GrayFrame, current: GrayFrame, topInset: Int = 0, bottomInset: Int = 0) -> Match? {
        nil // Test-first baseline.
    }
}
