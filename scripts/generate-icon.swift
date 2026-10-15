import AppKit
import Foundation
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024,height: 1024))
image.lockFocus()
NSColor(srgbRed: 0.035,green: 0.38,blue: 0.64,alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0,y: 0,width: 1024,height: 1024)).fill()
for (x,y,w,h,alpha) in [(260.0,700.0,504.0,120.0,0.35),(220.0,560.0,584.0,160.0,0.65),(180.0,180.0,664.0,420.0,1.0)] {
    NSColor.white.withAlphaComponent(alpha).setFill()
    NSBezierPath(roundedRect: NSRect(x: x,y: y,width: w,height: h),xRadius: 36,yRadius: 36).fill()
}
NSColor(srgbRed: 0.035,green: 0.38,blue: 0.64,alpha: 1).setFill()
for y in [285.0,370.0,455.0] {NSBezierPath(roundedRect: NSRect(x: 286,y: y,width: 452,height: 30),xRadius: 15,yRadius: 15).fill()}
image.unlockFocus()
let cg = image.cgImage(forProposedRect: nil,context: nil,hints: nil)!
let rep = NSBitmapImageRep(cgImage: cg)
try rep.representation(using: .png,properties: [:])!.write(to: url)
