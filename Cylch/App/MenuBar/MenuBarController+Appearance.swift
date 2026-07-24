import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
extension MenuBarController {
    func menuBarIcon(brightness: Double, isConnected: Bool) -> NSImage {
        let imageSize = NSSize(width: 16, height: 16)
        let image = NSImage(size: imageSize, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let artworkScale = rect.width / 24
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let discRadius = 11 * artworkScale
            let markerRadius = 2.35 * artworkScale
            let markerOrbit = hypot(3.4, 3.4) * artworkScale
            let normalizedBrightness = min(100, max(0, brightness)) / 100
            let angle = normalizedBrightness * 2 * Double.pi
            let markerCenter = CGPoint(
                x: center.x + CGFloat(sin(angle)) * markerOrbit,
                y: center.y + CGFloat(cos(angle)) * markerOrbit
            )

            let discRect = CGRect(
                x: center.x - discRadius,
                y: center.y - discRadius,
                width: discRadius * 2,
                height: discRadius * 2
            )
            context.setFillColor(NSColor.black.cgColor)

            if isConnected {
                context.addEllipse(in: discRect)
                context.addEllipse(in: CGRect(
                    x: markerCenter.x - markerRadius,
                    y: markerCenter.y - markerRadius,
                    width: markerRadius * 2,
                    height: markerRadius * 2
                ))
                context.drawPath(using: .eoFill)
            } else {
                let outlineWidth = 2 * artworkScale
                context.setStrokeColor(NSColor.black.cgColor)
                context.setLineWidth(outlineWidth)
                context.strokeEllipse(in: discRect.insetBy(
                    dx: outlineWidth / 2,
                    dy: outlineWidth / 2
                ))
                context.fillEllipse(in: CGRect(
                    x: markerCenter.x - markerRadius,
                    y: markerCenter.y - markerRadius,
                    width: markerRadius * 2,
                    height: markerRadius * 2
                ))
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
