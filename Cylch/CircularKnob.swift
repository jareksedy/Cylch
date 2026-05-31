import SwiftUI

struct CircularKnob: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var gaugeStyle: GaugeStyle = .rainbow
    var pointerColor: Color = .accentColor
    var scrollSensitivity: Double = 0.05

    enum GaugeStyle {
        case rainbow
        case solid(Color)
        case gradient([Gradient.Stop])
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var dragAngle: Double?

    private var normalizedValue: Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var gaugeGradient: AngularGradient {
        switch gaugeStyle {
        case .rainbow:
            return AngularGradient(
                colors: [Color.red, .yellow, .green, .cyan, .blue, .purple, .red],
                center: .center
            )
        case .solid(let color):
            return AngularGradient(colors: [color], center: .center)
        case .gradient(let stops):
            return AngularGradient(stops: stops, center: .center)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let knobInset: CGFloat = 2
            let knobRadius = (size / 2) - knobInset
            let pointerAngle = dragAngle ?? (normalizedValue * 360)
            let gaugeProgress = pointerAngle / 360

            let isDark = colorScheme == .dark
            let knobBase = isDark ? Color.white : Color.black
            let knobFill = knobBase.opacity(0.075)
            let trackColor = Color.black.opacity(0.35)

            ZStack {
                Circle()
                    .fill(knobFill)
                    .padding(knobInset)

                Circle()
                    .stroke(trackColor, lineWidth: 2)
                    .padding(7)

                Circle()
                    .trim(from: 0, to: gaugeProgress)
                    .stroke(gaugeGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .padding(7)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: gaugeProgress)

                Circle()
                    .fill(pointerColor)
                    .frame(width: 5, height: 5)
                    .offset(y: -knobRadius * 0.65)
                    .rotationEffect(.degrees(pointerAngle))
                    .animation(dragAngle == nil ? .smooth(duration: 0.15) : .linear(duration: 0.05), value: pointerAngle)

                Text("\(Int(normalizedValue * 100))%")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.25))
            }
            .opacity(isEnabled ? 1 : 0.4)
            .saturation(isEnabled ? 1 : 0)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard isEnabled else { return }
                        let dx = drag.location.x - center.x
                        let dy = drag.location.y - center.y
                        var rawAngle = atan2(dy, dx) * 180 / .pi + 90
                        if rawAngle < 0 { rawAngle += 360 }

                        let targetAngle: Double
                        if drag.translation == .zero {
                            targetAngle = rawAngle
                        } else {
                            let currentAngle = dragAngle ?? (normalizedValue * 360)
                            let projected = projectedAngle(rawAngle, near: currentAngle)
                            targetAngle = min(max(projected, 0), 360)
                        }

                        dragAngle = targetAngle

                        let normalized = targetAngle / 360.0
                        let rawValue = range.lowerBound + normalized * (range.upperBound - range.lowerBound)
                        let snappedValue = (rawValue / step).rounded() * step
                        let clampedValue = min(range.upperBound, max(range.lowerBound, snappedValue))
                        if clampedValue != value { value = clampedValue }
                    }
                    .onEnded { _ in
                        dragAngle = nil
                    }
            )
            .background(
                ScrollWheelView { delta in
                    guard isEnabled else { return }
                    let newValue = value + delta * step * scrollSensitivity
                    withAnimation(.smooth(duration: 0.15)) {
                        value = min(range.upperBound, max(range.lowerBound, (newValue / step).rounded() * step))
                    }
                }
            )
        }
    }

    private func projectedAngle(_ rawAngle: Double, near currentAngle: Double) -> Double {
        let candidates = [rawAngle - 360, rawAngle, rawAngle + 360]
        return candidates.min(by: { abs($0 - currentAngle) < abs($1 - currentAngle) }) ?? rawAngle
    }
}

private struct ScrollWheelView: NSViewRepresentable {
    var onScroll: (Double) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }

    class ScrollWheelNSView: NSView {
        var onScroll: ((Double) -> Void)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self,
                      let eventWindow = event.window,
                      eventWindow == self.window else { return event }
                let locationInView = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(locationInView) else { return event }
                let delta = Double(event.scrollingDeltaY)
                if delta != 0 { self.onScroll?(delta) }
                return event
            }
        }

        override func removeFromSuperview() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            super.removeFromSuperview()
        }
    }
}
