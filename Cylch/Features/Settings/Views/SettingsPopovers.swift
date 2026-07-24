import SwiftUI

private struct SettingsPopoverPanel<Content: View>: View {
    let title: String
    let imageName: String
    var headerOpticalOffset: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.leading, 2 + headerOpticalOffset)

            content()
        }
        .padding(16)
        .frame(width: 344, alignment: .leading)
        .font(.system(size: 13))
    }
}

private struct PopoverRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 36)
    }
}

private extension View {
    func controlCapsule() -> some View {
        background(Capsule().fill(Color.primary.opacity(0.04)))
    }

    func popoverNumericStyle(size: CGFloat) -> some View {
        font(.system(size: size, weight: .semibold).width(.expanded))
            .monospacedDigit()
    }
}

private struct GlyphButton: View {
    let systemName: String
    var symbolSize: CGFloat = 24
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: symbolSize, height: symbolSize)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

private struct CapsuleStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        HStack(spacing: 0) {
            GlyphButton(systemName: "minus.circle.fill", isEnabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }

            Text("\(value)")
                .popoverNumericStyle(size: 11)
                .contentTransition(.numericText(value: Double(value)))
                .frame(minWidth: 52)

            GlyphButton(systemName: "plus.circle.fill", isEnabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .frame(minWidth: 120)
        .controlCapsule()
    }
}

private struct TimeStepper: View {
    @Binding var time: Date
    var isEnabled: Bool = true

    var body: some View {
        ZStack {
            Text(timeString)
                .popoverNumericStyle(size: 11)
                .frame(minWidth: 60)

            HStack(spacing: 0) {
                GlyphButton(systemName: "minus.circle.fill", isEnabled: isEnabled) {
                    adjust(byMinutes: -30)
                }

                Spacer(minLength: 60)

                GlyphButton(systemName: "plus.circle.fill", isEnabled: isEnabled) {
                    adjust(byMinutes: 30)
                }
            }
        }
        .frame(minWidth: 132, maxWidth: .infinity)
        .controlCapsule()
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var timeString: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func adjust(byMinutes minutes: Int) {
        time = Calendar.current.date(byAdding: .minute, value: minutes, to: time) ?? time
    }
}

private struct ActionCapsuleButtonStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary.opacity(0.8)))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Capsule())
            .background {
                if prominent {
                    Capsule().fill(Color.accentColor)
                } else {
                    Capsule().fill(Color.primary.opacity(0.06))
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct ConnectionPopoverView: View {
    @StateObject private var viewModel = SettingsViewModel.shared

    var body: some View {
        SettingsPopoverPanel(title: "Connection", imageName: "connect_on") {
            VStack(spacing: 12) {
                PopoverRow(label: "Port") {
                    HStack(spacing: 8) {
                        portMenu

                        GlyphButton(
                            systemName: "arrow.trianglehead.2.clockwise.rotate.90",
                            symbolSize: 18,
                            isEnabled: !viewModel.connected
                        ) {
                            viewModel.refreshPorts()
                        }
                        .controlCapsule()
                        .help("Refresh Ports")
                    }
                }

                PopoverRow(label: "LED count") {
                    CapsuleStepper(value: $viewModel.ledCount, range: 1...300)
                        .disabled(viewModel.connected)
                        .opacity(viewModel.connected ? 0.45 : 1)
                }

                Button {
                    if viewModel.disconnecting {
                        return
                    } else if viewModel.connected {
                        viewModel.stopStreaming()
                    } else {
                        viewModel.connect()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(viewModel.connected || viewModel.disconnecting ? "connect_off" : "connect_on")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 13, height: 13)

                        Text(viewModel.disconnecting ? "Fading Out…" : viewModel.connected ? "Disconnect" : "Connect")
                    }
                }
                .buttonStyle(ActionCapsuleButtonStyle(prominent: !viewModel.connected))
                .disabled(viewModel.disconnecting || (!viewModel.connected && viewModel.selectedPort.isEmpty))
                .opacity(viewModel.disconnecting || (!viewModel.connected && viewModel.selectedPort.isEmpty) ? 0.45 : 1)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }
        }
        .onAppear {
            viewModel.refreshPorts()
        }
    }

    private var portMenu: some View {
        Menu {
            if viewModel.availablePorts.isEmpty {
                Button("No USB Serial Ports") {}
                    .disabled(true)
            }

            ForEach(viewModel.availablePorts, id: \.self) { port in
                Toggle(isOn: Binding(
                    get: { viewModel.selectedPort == port },
                    set: { _ in viewModel.selectedPort = port }
                )) {
                    Text(Self.shortPortName(port))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedPort.isEmpty ? "No USB Port" : Self.shortPortName(viewModel.selectedPort))
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                Image("unfold_more")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .controlCapsule()
        .disabled(viewModel.connected)
        .opacity(viewModel.connected ? 0.5 : 1)
    }

    private static func shortPortName(_ port: String) -> String {
        port.split(separator: "/").last.map(String.init) ?? port
    }
}

struct SchedulePopoverView: View {
    @StateObject private var viewModel = SettingsViewModel.shared

    var body: some View {
        SettingsPopoverPanel(
            title: "Night Schedule",
            imageName: "moon",
            headerOpticalOffset: 3
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Text("Enabled")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("", isOn: $viewModel.scheduleEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.accentColor)
                        .fixedSize()
                }
                .padding(.leading, 12)
                .padding(.trailing, 6)
                .frame(height: 36)
                .controlCapsule()

                HStack(alignment: .top, spacing: 16) {
                    scheduleTimeField(
                        caption: "From",
                        imageName: "moon",
                        time: $viewModel.scheduleStartTime
                    )

                    scheduleTimeField(
                        caption: "Until",
                        imageName: "sun",
                        time: $viewModel.scheduleEndTime
                    )
                }
            }
        }
    }

    private func scheduleTimeField(
        caption: String,
        imageName: String,
        time: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.accentColor)

                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 3)

            TimeStepper(time: time, isEnabled: viewModel.scheduleEnabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsView()
        .frame(width: 420, height: 330)
}

#Preview("Connection Popover") {
    ConnectionPopoverView()
}

#Preview("Schedule Popover") {
    SchedulePopoverView()
}
