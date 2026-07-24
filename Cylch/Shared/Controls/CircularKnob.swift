import SwiftUI

struct CircularKnob: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var gaugeStyle: GaugeStyle = .rainbow
    var pointerColor: Color = .accentColor
    var scrollSensitivity: Double = 0.05
    var icon: Image?
    var usesPopoverSurface = false

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
            let displayedPercentage = Int((normalizedValue * 100).rounded())

            let isDark = colorScheme == .dark
            let surfaceSheen = isDark
                ? Color.white.opacity(0.035)
                : Color.white.opacity(0.55)
            let surfaceShade = isDark
                ? Color.black.opacity(0.045)
                : Color.black.opacity(0.09)
            let trackColor = Color.black.opacity(isDark ? 0.24 : 0.2)
            let inactiveElementColor = Color.black.opacity(isDark ? 0.85 : 0.65)
            let trackWidth: CGFloat = 2
            let gaugeWidth: CGFloat = 2
            let trackPadding: CGFloat = 8
            let bezelWidth: CGFloat = trackPadding - knobInset - 1

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            stops: [
                                .init(color: surfaceSheen, location: 0),
                                .init(color: surfaceShade, location: 0.125),
                                .init(color: surfaceSheen, location: 0.25),
                                .init(color: surfaceShade, location: 0.375),
                                .init(color: surfaceSheen, location: 0.5),
                                .init(color: surfaceShade, location: 0.625),
                                .init(color: surfaceSheen, location: 0.75),
                                .init(color: surfaceShade, location: 0.875),
                                .init(color: surfaceSheen, location: 1)
                            ],
                            center: .center,
                            angle: .degrees(-90)
                        )
                    )
                    .padding(knobInset)

                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(
                                    color: Color.white.opacity(isDark ? 0.16 : 0.62),
                                    location: 0
                                ),
                                .init(color: Color.clear, location: 0.46),
                                .init(
                                    color: Color.black.opacity(isDark ? 0.3 : 0.13),
                                    location: 0.82
                                ),
                                .init(
                                    color: Color.white.opacity(isDark ? 0.035 : 0.16),
                                    location: 1
                                )
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(knobInset + 1)

                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(isDark ? 0.06 : 0.14), location: 0),
                                .init(color: Color.clear, location: 0.58),
                                .init(color: Color.black.opacity(isDark ? 0.22 : 0.085), location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: knobRadius
                        )
                    )
                    .padding(knobInset + 1)

                Circle()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(isDark ? 0.14 : 0.75), location: 0),
                                .init(color: Color.clear, location: 0.46),
                                .init(color: Color.black.opacity(isDark ? 0.24 : 0.12), location: 0.82),
                                .init(color: Color.white.opacity(isDark ? 0.045 : 0.24), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .padding(knobInset + 2)

                Circle()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(isDark ? 0.08 : 0.68), location: 0),
                                .init(color: Color.clear, location: 0.45),
                                .init(color: Color.black.opacity(isDark ? 0.3 : 0.11), location: 0.82),
                                .init(color: Color.white.opacity(isDark ? 0.035 : 0.2), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: bezelWidth
                    )
                    .padding(knobInset + 1 + bezelWidth / 2)

                ForEach(0 ..< 20, id: \.self) { index in
                    let isMajorMarker = index.isMultiple(of: 5)
                    let markerHeight: CGFloat = isMajorMarker ? 5 : 3

                    Capsule()
                        .fill(
                            isEnabled
                                ? Color.primary.opacity(
                                    isMajorMarker
                                        ? (isDark ? 0.3 : 0.35)
                                        : (isDark ? 0.22 : 0.25)
                                )
                                : inactiveElementColor
                        )
                        .frame(
                            width: 1,
                            height: markerHeight
                        )
                        .offset(
                            y: -(size / 2 - trackPadding - 4 - markerHeight / 2)
                        )
                        .rotationEffect(.degrees(Double(index) * 18))
                }

                Circle()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(isDark ? 0.03 : 0.35), location: 0),
                                .init(color: Color.white.opacity(isDark ? 0.015 : 0.15), location: 0.6),
                                .init(color: Color.white.opacity(0), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: trackWidth
                    )
                    .padding(trackPadding)
                    .offset(y: 1)

                Circle()
                    .stroke(trackColor, lineWidth: trackWidth)
                    .padding(trackPadding)

                if isEnabled {
                    Circle()
                        .trim(from: 0, to: gaugeProgress)
                        .stroke(
                            gaugeGradient,
                            style: StrokeStyle(lineWidth: gaugeWidth + 1, lineCap: .round)
                        )
                        .padding(trackPadding)
                        .rotationEffect(.degrees(-90))
                        .blur(radius: isDark ? 4 : 3)
                        .opacity(isDark ? 0.42 : 0.24)
                        .animation(
                            dragAngle == nil ? .smooth(duration: 0.15) : .linear(duration: 0.05),
                            value: gaugeProgress
                        )

                    Circle()
                        .trim(from: 0, to: gaugeProgress)
                        .stroke(gaugeGradient, style: StrokeStyle(lineWidth: gaugeWidth, lineCap: .round))
                        .padding(trackPadding)
                        .rotationEffect(.degrees(-90))
                        .animation(dragAngle == nil ? .smooth(duration: 0.15) : .linear(duration: 0.05), value: gaugeProgress)
                        .opacity(isDark ? 0.5 : 1)
                } else {
                    Circle()
                        .trim(from: 0, to: gaugeProgress)
                        .stroke(
                            inactiveElementColor,
                            style: StrokeStyle(lineWidth: gaugeWidth, lineCap: .round)
                        )
                        .padding(trackPadding)
                        .rotationEffect(.degrees(-90))
                        .opacity(0.5)
                }

                Circle()
                    .fill(isEnabled ? pointerColor : inactiveElementColor)
                    .frame(width: 5, height: 5)
                    .shadow(
                        color: isEnabled
                            ? pointerColor.opacity(isDark ? 0.8 : 0.45)
                            : .clear,
                        radius: isDark ? 4 : 2.5
                    )
                    .offset(y: -knobRadius * 0.65)
                    .rotationEffect(.degrees(pointerAngle))
                    .animation(dragAngle == nil ? .smooth(duration: 0.15) : .linear(duration: 0.05), value: pointerAngle)

                HStack(spacing: 5) {
                    HStack(spacing: 0) {
                        ZStack(alignment: .trailing) {
                            Text("100")
                                .hidden()

                            Text("\(displayedPercentage)")
                                .contentTransition(.numericText(value: normalizedValue))
                                .animation(.linear(duration: 0.01), value: displayedPercentage)
                        }

                        Text("%")
                    }
                    .font(.system(size: 12, weight: .semibold).width(.expanded))
                    .monospacedDigit()
                    .offset(x: -2)
                    .foregroundStyle(isEnabled ? Color.accentColor : inactiveElementColor)
                    .compositingGroup()
                    .blendMode(.normal)
                    .opacity(isDark ? 0.9 : 1)
                    .shadow(
                        color: isEnabled
                            ? Color.accentColor.opacity(isDark ? 0.65 : 0.32)
                            : .clear,
                        radius: isDark ? 4 : 2.5
                    )

                    if let icon {
                        icon
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 13, height: 13)
                            .foregroundStyle(isEnabled ? Color.accentColor : inactiveElementColor)
                            .shadow(
                                color: isEnabled
                                    ? Color.accentColor.opacity(isDark ? 0.72 : 0.36)
                                    : .clear,
                                radius: isDark ? 4 : 2.5
                            )
                    }
                }
            }
            .opacity(isEnabled ? 1 : 0.4)
            .saturation(isEnabled ? 1 : 0)
            .contentShape(Circle())
            .background {
                if usesPopoverSurface {
                    Circle()
                        .fill(.ultraThickMaterial)
                        .opacity(0.9)
                        .padding(knobInset)
                        .shadow(
                            color: Color.black.opacity(isDark ? 0.38 : 0.2),
                            radius: 8,
                            x: 0,
                            y: 5
                        )
                        .shadow(
                            color: Color.black.opacity(isDark ? 0.3 : 0.14),
                            radius: 2,
                            x: 0,
                            y: 1
                        )
                        .shadow(
                            color: Color.white.opacity(isDark ? 0.12 : 0.75),
                            radius: 6,
                            x: 0,
                            y: -4
                        )
                }
            }
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
