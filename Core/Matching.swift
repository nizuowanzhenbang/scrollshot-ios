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
    /// Positive displacement means content moved upward: the viewport scrolled down.
    public static func match(previous: GrayFrame, current: GrayFrame, topInset: Int = 0, bottomInset: Int = 0, expected: Int? = nil) -> Match? {
        let w = previous.width, h = previous.height
        guard w >= 8, h >= 24, w == current.width, h == current.height,
              previous.pixels.count == w*h, current.pixels.count == w*h,
              topInset >= 0, bottomInset >= 0, topInset+bottomInset < h-16 else { return nil }
        let top = topInset, bottom = h-bottomInset
        let xStep = max(1,w/24), yStep = max(1,h/180)
        var sum = 0.0, square = 0.0, count = 0.0
        for y in stride(from: top,to: bottom,by: yStep) {
            for x in stride(from: w/8,to: w-w/8,by: xStep) {
                let v = Double(previous.pixels[y*w+x]); sum += v; square += v*v; count += 1
            }
        }
        guard count > 0, square/count-pow(sum/count,2) > 20 else { return nil }
        let limit = Int(Double(bottom-top)*0.72)
        let low = max(-limit,(expected ?? 0)-(expected == nil ? limit : 12))
        let high = min(limit,(expected ?? 0)+(expected == nil ? limit : 12))
        guard low <= high else { return nil }
        let minimumOverlap = max(16,(bottom-top)/4)
        var scores: [(Int,Double)] = []
        scores.reserveCapacity(high-low+1)
        for d in low...high {
            let start = max(top,top-d), end = min(bottom,bottom-d)
            guard end-start >= minimumOverlap else { continue }
            var error = 0.0, samples = 0.0
            for y in stride(from: start,to: end,by: yStep) {
                for x in stride(from: w/8,to: w-w/8,by: xStep) {
                    error += abs(Double(previous.pixels[(y+d)*w+x])-Double(current.pixels[y*w+x]))
                    samples += 1
                }
            }
            if samples > 0 { scores.append((d,error/(samples*255))) }
        }
        guard let best = scores.min(by: {$0.1 < $1.1}), best.1 < 0.10 else { return nil }
        let second = scores.filter {abs($0.0-best.0)>2}.map(\.1).min() ?? 1
        let confidence = max(0,min(1,(second-best.1)/max(0.015,second)))
        guard confidence >= 0.16 else { return nil }
        return Match(displacement: best.0,error: best.1,confidence: confidence)
    }
    public static func difference(_ a: GrayFrame,_ b: GrayFrame) -> Double {
        guard a.width == b.width, a.height == b.height, a.pixels.count == b.pixels.count, !a.pixels.isEmpty else { return 1 }
        var sum = 0.0, count = 0.0
        for i in stride(from: 0,to: a.pixels.count,by: max(1,a.width/32)) {
            sum += abs(Double(a.pixels[i])-Double(b.pixels[i])); count += 1
        }
        return sum/(count*255)
    }
}
