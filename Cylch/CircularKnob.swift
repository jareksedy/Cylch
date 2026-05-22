import SwiftUI

struct CircularKnob: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var gaugeStyle: GaugeStyle = .rainbow
    var pointerColor: Color = .accentColor
    var gaugeLineWidth: CGFloat = 2
    var gaugeGlowRadius: CGFloat = 4
    var gaugeGlowOpacity: Double = 0.5
    var gaugeMinOpacity: Double = 0.1
    var trackLineWidth: CGFloat = 3
    var trackOpacity: Double = 0.15
    var scrollSensitivity: Double = 0.05

    enum GaugeStyle {
        case rainbow
        case solid(Color)
        case gradient([Gradient.Stop])
    }

    @Environment(\.colorScheme) private var colorScheme

    private var normalizedValue: Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var gaugeGradient: AngularGradient {
        let opacity = gaugeMinOpacity + (1 - gaugeMinOpacity) * normalizedValue
        switch gaugeStyle {
        case .rainbow:
            return AngularGradient(
                colors: [Color.red, .yellow, .green, .cyan, .blue, .purple, .red]
                    .map { $0.opacity(opacity) },
                center: .center
            )
        case .solid(let color):
            return AngularGradient(
                colors: [color.opacity(opacity)],
                center: .center
            )
        case .gradient(let stops):
            return AngularGradient(
                stops: stops.map { Gradient.Stop(color: $0.color.opacity(opacity), location: $0.location) },
                center: .center
            )
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let knobInset = size * 0.15
            let knobRadius = (size / 2) - knobInset
            let pointerAngle = normalizedValue * 360

            let isDark = colorScheme == .dark
            let baseColor = isDark ? Color(white: 0.16) : Color(white: 0.88)
            let lightShadow = isDark ? Color(white: 0.28) : Color.white
            let darkShadow = isDark ? Color.black : Color(white: 0.55)

            ZStack {
                StaticKnobChrome(
                    isDark: isDark,
                    baseColor: baseColor,
                    lightShadow: lightShadow,
                    darkShadow: darkShadow,
                    trackOpacity: trackOpacity,
                    trackLineWidth: trackLineWidth,
                    knobInset: knobInset
                )
                .drawingGroup()

                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(gaugeGradient, style: StrokeStyle(lineWidth: gaugeLineWidth * 2, lineCap: .round))
                    .blur(radius: gaugeGlowRadius)
                    .opacity(gaugeGlowOpacity)
                    .padding(7)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(gaugeGradient, style: StrokeStyle(lineWidth: gaugeLineWidth, lineCap: .round))
                    .padding(7)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(pointerColor)
                    .frame(width: 5, height: 5)
                    .shadow(color: pointerColor.opacity(0.6), radius: 4)
                    .offset(y: -knobRadius * 0.65)
                    .rotationEffect(.degrees(pointerAngle))
                    .animation(.smooth(duration: 0.1), value: pointerAngle)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let dx = drag.location.x - center.x
                        let dy = drag.location.y - center.y
                        var rawAngle = atan2(dy, dx) * 180 / .pi + 90
                        if rawAngle < 0 { rawAngle += 360 }
                        let currentAngle = normalizedValue * 360
                        let projected = projectedAngle(rawAngle, near: currentAngle)
                        let clamped = min(max(projected, 0), 360)
                        let normalized = clamped / 360.0
                        let rawValue = range.lowerBound + normalized * (range.upperBound - range.lowerBound)
                        let snappedValue = (rawValue / step).rounded() * step
                        value = min(range.upperBound, max(range.lowerBound, snappedValue))
                    }
            )
            .background(
                ScrollWheelView { delta in
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

private struct StaticKnobChrome: View {
    let isDark: Bool
    let baseColor: Color
    let lightShadow: Color
    let darkShadow: Color
    let trackOpacity: Double
    let trackLineWidth: CGFloat
    let knobInset: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(baseColor)
                .overlay(
                    Circle()
                        .stroke(darkShadow.opacity(0.6), lineWidth: 6)
                        .blur(radius: 5)
                        .clipShape(Circle())
                )
                .overlay(
                    Circle()
                        .stroke(lightShadow.opacity(0.15), lineWidth: 6)
                        .blur(radius: 5)
                        .clipShape(Circle())
                )

            Circle()
                .stroke(darkShadow.opacity(trackOpacity), lineWidth: trackLineWidth)
                .blur(radius: 0.5)
                .padding(7)

            Circle()
                .fill(
                    LinearGradient(
                        colors: isDark
                            ? [Color(white: 0.22), Color(white: 0.16)]
                            : [Color(white: 0.94), Color(white: 0.86)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: lightShadow.opacity(0.18), radius: 5, x: 0, y: 0)
                .shadow(color: darkShadow.opacity(0.6), radius: 5, x: 0, y: 0)
                .padding(knobInset)
        }
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
