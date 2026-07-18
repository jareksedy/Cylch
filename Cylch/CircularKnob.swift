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
            // Translucent tints rather than opaque .windowBackgroundColor
            // mixes: the window material is lighter than that color, so an
            // opaque fill reads darker than the window. Tinting whatever the
            // window actually draws keeps the body matched to it.
            // Separate palettes per theme: opacities that read well on a
            // dark background are nearly invisible on a light one.
            // Sheen and shade tones for the polished conic sweep.
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
                // Neumorphic body: tints the window background showing
                // through — a perfectly symmetric spun-metal conic sweep:
                // identical highlights at the top and bottom, softer sheens
                // on the sides and dark diagonals between them.
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

                // Broad 90-degree light gives the metal face a clear dome:
                // the highlight begins directly above and rolls into a soft
                // shade below while keeping the spun-metal sweep visible.
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

                // A soft edge vignette bends the face away from the viewer
                // on every side. Combined with the directional light above,
                // it adds depth inside the knob instead of making it float.
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

                // A restrained inner rim catches the same directional light
                // and separates the convex face from the outer bezel.
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

                // Convex bezel: the rim between the outer stroke and the
                // groove is lit from above so it reads as a raised ring.
                // Inset by an extra point so it doesn't wash out the stroke.
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

                // Fine analog-dial markers form a separate ring just inside
                // the gauge, with their outer tips aligned to one radius.
                // Twenty divisions keep it calm; every fifth establishes rhythm.
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

                // Engraved groove: a light edge peeking out just below the
                // dark track line makes it read as carved into the surface.
                // The edge fades out towards the bottom, where it would
                // otherwise stack with the bezel's dark side and the track
                // line into a striped "multiple grooves" look.
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


                // The arc is drawn only while enabled; a disabled knob shows
                // just the empty groove.
                if isEnabled {
                    // A separate blurred copy preserves the gradient's own
                    // colors in the glow instead of tinting the entire arc
                    // with one generic shadow color.
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
                        // Must match the pointer dot's animation exactly —
                        // any difference in curve or duration makes the dot
                        // visibly lag behind the arc on fast scrolls.
                        .animation(dragAngle == nil ? .smooth(duration: 0.15) : .linear(duration: 0.05), value: gaugeProgress)
                        // Muted in the dark theme so the arc doesn't
                        // overpower the UI, fully opaque in the light one.
                        .opacity(isDark ? 0.5 : 1)
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
                    // A hidden "100%" reserves the widest possible value; the
                    // live value sits on its trailing edge at natural size,
                    // with layout animations suppressed — otherwise the
                    // withAnimation transaction from the scroll handler
                    // animates the text frame and the digits slide around
                    // the % sign on width changes (9→10, 99→100).
                    // Deliberately NOT monospacedDigit: tabular figures pad
                    // narrow glyphs ("1") inside fixed cells, which makes the
                    // optical gap to the % sign vary (51% vs 56%). Natural
                    // kerning keeps the last digit snug against % instead.
                    // ZStack alignment rather than overlay+fixedSize: the
                    // latter mislaid the value on the first layout pass in
                    // previews until the first change re-laid it out.
                    ZStack(alignment: .trailing) {
                        Text("100%")
                            .hidden()

                        Text("\(displayedPercentage)%")
                            .contentTransition(.numericText(value: normalizedValue))
                            .transaction { transaction in
                                transaction.animation = .linear(duration: 0.01)
                            }
                    }
                    .font(.system(size: 12, weight: .semibold).width(.expanded))
                    // Optical centering: nudge the digits a hair left so the
                    // value+icon group doesn't read as right-heavy.
                    .offset(x: -2)
                    // Flatten the fast system odometer before applying one
                    // accent glow to the complete readout.
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
            // A nested, dense system material calms the desktop show-through
            // without turning the knobs into two fixed dark discs. It picks
            // up the popover's tone; when disabled, the surface itself also
            // recedes so the whole control participates in the muted state.
            .background {
                if usesPopoverSurface {
                    Circle()
                        .fill(.ultraThickMaterial)
                        .opacity(isEnabled ? 0.9 : 0.45)
                        .padding(knobInset)
                        .shadow(
                            color: Color.black.opacity(isEnabled ? (isDark ? 0.38 : 0.2) : 0.08),
                            radius: isEnabled ? 8 : 3,
                            x: 0,
                            y: 5
                        )
                        .shadow(
                            color: Color.black.opacity(isEnabled ? (isDark ? 0.3 : 0.14) : 0.06),
                            radius: isEnabled ? 2 : 1,
                            x: 0,
                            y: 1
                        )
                        .shadow(
                            color: Color.white.opacity(isEnabled ? (isDark ? 0.12 : 0.75) : 0.03),
                            radius: isEnabled ? 6 : 2,
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
