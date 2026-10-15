import Foundation
public enum StitchPlanner {
    public static func build(records: [FrameRecord], crop: CropInsets) throws -> [StitchSegment] { [] }
    public static func split(_ segment: StitchSegment, maxHeight: Int = 60_000) throws -> [StitchSegment] { [] }
    public static func trim(_ segment: StitchSegment, top: Int, bottom: Int) throws -> StitchSegment { segment }
}
public struct SamplerGate {
    public init(interval: Double = 0.2) {}
    public mutating func accept(timestamp: Double) -> Bool { false }
}
