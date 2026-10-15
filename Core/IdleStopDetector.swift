import Foundation
public enum ScrollActivity: Sendable {case stationary,scrolling,uncertain}
public struct IdleStopDetector: Sendable {
    public init(preferences: CapturePreferences) {}
    public mutating func observe(_ activity: ScrollActivity,at time: Double) {}
    public mutating func poll(at time: Double) -> Bool {false}
    public mutating func reset() {}
}
