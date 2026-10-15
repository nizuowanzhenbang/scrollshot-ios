import Foundation
public enum ScrollActivity: Sendable {case stationary,scrolling,uncertain}
public struct IdleStopDetector: Sendable {
    private let enabled: Bool
    private let timeout: Double
    private var lastActivity: Double?
    private var lastClock: Double?
    private var fired = false
    public init(preferences: CapturePreferences) {
        timeout = preferences.idleSeconds
        enabled = preferences.idleStopEnabled && timeout.isFinite && timeout > 0
    }
    public mutating func observe(_ activity: ScrollActivity,at time: Double) {
        guard enabled,!fired,accept(time) else {return}
        switch activity {
        case .scrolling:lastActivity = time
        case .uncertain:if lastActivity != nil {lastActivity = time}
        case .stationary:break
        }
    }
    public mutating func poll(at time: Double) -> Bool {
        guard enabled,!fired,accept(time),let lastActivity,time-lastActivity >= timeout else {return false}
        fired = true;return true
    }
    public mutating func reset() {lastActivity = nil;lastClock = nil;fired = false}
    private mutating func accept(_ time: Double) -> Bool {
        guard time.isFinite,time >= 0,time >= (lastClock ?? 0) else {return false}
        lastClock = time;return true
    }
}
