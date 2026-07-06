import SwiftUI

struct CircularKnob: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var gaugeStyle: GaugeStyle = .rainbow
    var pointerColor: Color = .accentColor
    var scrollSensitivity: Double = 0.05
    var icon: Image?

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
            // Translucent tints rather than opaque .windowBackgroundColor
            // mixes: the window material is lighter than that color, so an
            // opaque fill reads darker than the window. Tinting whatever the
            // window actually draws keeps the body matched to it.
            let surfaceTop = Color.black.opacity(isDark ? 0.04 : 0.025)
            let surfaceBottom = Color.white.opacity(isDark ? 0.06 : 0.28)
            let trackColor = Color.black.opacity(isDark ? 0.24 : 0.2)
            let trackWidth: CGFloat = 2
            let gaugeWidth: CGFloat = 2
            let trackPadding: CGFloat = 8

            ZStack {
                // Neumorphic body: tints the window background showing
                // through, with an inverted vertical surface gradient and
                // straight-on relief.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [surfaceTop, surfaceBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.primary.opacity(isDark ? 0.12 : 0.1), location: 0),
                                        .init(color: Color.primary.opacity(isDark ? 0.04 : 0.035), location: 0.45),
                                        .init(color: surfaceBottom.opacity(0), location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(isDark ? 0.28 : 0.16), radius: 5, x: 0, y: 5)
                    .shadow(color: .white.opacity(isDark ? 0.08 : 0.85), radius: 5, x: 0, y: -5)
                    .padding(knobInset)

                // Engraved groove: a light edge peeking out just below the
                // dark track line makes it read as carved into the surface.
                Circle()
                    .stroke(Color.white.opacity(isDark ? 0.03 : 0.35), lineWidth: trackWidth)
                    .padding(trackPadding)
                    .offset(y: 1)

                Circle()
                    .stroke(trackColor, lineWidth: trackWidth)
                    .padding(trackPadding)


                // When disabled, the arc replicates the inner disk's layering
                // (opaque window background + the same tint), so it visually
                // merges with it and "cuts through" the groove.
                Circle()
                    .trim(from: 0, to: gaugeProgress)
                    .stroke(
                        isEnabled
                            ? AnyShapeStyle(gaugeGradient)
                            : AnyShapeStyle(Color(nsColor: .windowBackgroundColor)),
                        style: StrokeStyle(lineWidth: gaugeWidth, lineCap: .round)
                    )
                    .overlay {
                        if !isEnabled {
                            Circle()
                                .trim(from: 0, to: gaugeProgress)
                                .stroke(Color.primary.opacity(0.04), style: StrokeStyle(lineWidth: gaugeWidth, lineCap: .round))
                        }
                    }
                    .padding(trackPadding)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: gaugeProgress)
                    // Slightly muted so the arc doesn't overpower the UI;
                    // stays opaque when disabled to blend with the inner disk.
                    .opacity(isEnabled ? 0.65 : 1)

                Circle()
                    .fill(isEnabled ? pointerColor : trackColor)
                    .frame(width: 5, height: 5)
                    .offset(y: -knobRadius * 0.65)
                    .rotationEffect(.degrees(pointerAngle))
                    .animation(dragAngle == nil ? .smooth(duration: 0.15) : .linear(duration: 0.05), value: pointerAngle)

                HStack(spacing: 3) {
                    Text("\(Int(normalizedValue * 100))%")
                        .font(.system(size: 12, design: .monospaced))

                    if let icon {
                        icon
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                    }
                }
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
