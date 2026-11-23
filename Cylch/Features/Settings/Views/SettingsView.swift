import SwiftUI

struct SettingsView: View {
    var showsInlineHeader = false

    @StateObject private var viewModel = SettingsViewModel.shared
    @Namespace private var pickerNamespace
    @State private var showConnectionPopover = false

    @ViewBuilder
    var body: some View {
        if showsInlineHeader {
            VStack(spacing: 0) {
                inlineHeader
                settingsContent
            }
            .onAppear {
                viewModel.onAppear()
            }
        } else {
            settingsContent
                .onAppear {
                    viewModel.onAppear()
                }
                .toolbar {
                    ToolbarItem {
                        connectionToolbarButton
                    }
                }
        }
    }

    private var settingsContent: some View {
        VStack(spacing: 28) {
            effectPicker
                .frame(width: 320, height: 36)

            transportRow

            colorPalette
                .frame(width: 320, height: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, showsInlineHeader ? 36 : 32)
        .font(.system(size: 13, design: .monospaced))
    }

    private var inlineHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image("settings")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.accentColor)

                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            connectionToolbarButton
                .padding(4)
                .background {
                    Capsule()
                        .fill(Color.primary.opacity(0.04))
                        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var connectionToolbarButton: some View {
        Button {
            showConnectionPopover.toggle()
        } label: {
            Image(viewModel.connected ? "connect_on" : "connect_off")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Connection")
        .popover(isPresented: $showConnectionPopover, arrowEdge: .bottom) {
            ConnectionPopoverView()
        }
    }

    private var effectPicker: some View {
        HStack(spacing: 0) {
            ForEach(LEDEffect.allCases) { effect in
                let isSelected = viewModel.selectedEffect == effect

                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        viewModel.selectedEffect = effect
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(effect.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)

                        Text(effect.rawValue)
                            .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    }
                    .offset(x: -3)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "selectedEffect", in: pickerNamespace)
                    }
                }
            }
        }
        .background(Capsule().fill(Color.primary.opacity(0.04)))
    }

    private var transportRow: some View {
        HStack(spacing: 44) {
            CircularKnob(
                value: $viewModel.brightness,
                gaugeStyle: viewModel.selectedEffect == .static ? .solid(viewModel.staticColor.color) : .rainbow,
                icon: Image("brightness"),
                usesPopoverSurface: showsInlineHeader
            )
                .frame(width: 140, height: 140)
                .help("Brightness")

            CircularKnob(
                value: $viewModel.speed,
                gaugeStyle: .gradient([
                    .init(color: .accentColor, location: 0),
                    .init(color: Color.accentColor.mix(with: .white, by: 0.45), location: 0.5),
                    .init(color: .accentColor, location: 1)
                ]),
                icon: Image("speed"),
                usesPopoverSurface: showsInlineHeader
            )
                .frame(width: 140, height: 140)
                .disabled(viewModel.selectedEffect == .static)
                .help("Speed")
        }
        .disabled(!viewModel.connected || viewModel.disconnecting)
    }

    private var colorPalette: some View {
        let isInactive = viewModel.selectedEffect == .rainbow || !viewModel.connected || viewModel.disconnecting

        return HStack(spacing: 0) {
            ForEach(LEDColor.palette) { ledColor in
                let isSelected = viewModel.staticColor == ledColor

                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        viewModel.staticColor = ledColor
                    }
                } label: {
                    Circle()
                        .fill(ledColor.color)
                        .frame(width: isSelected ? 22 : 18, height: isSelected ? 22 : 18)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? ledColor.color : Color.primary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                        )
                        .overlay {
                            if isSelected {
                                Circle()
                                    .stroke(ledColor.color.opacity(0.28), lineWidth: 5)
                                    .padding(-3)
                            }
                        }
                        .overlay {
                            if isSelected {
                                Image("check")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(ledColor.contrastingColor)
                                    .transition(
                                        .scale.combined(with: .opacity)
                                            .animation(.spring(response: 0.35, dampingFraction: 0.55))
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedEffect == .rainbow)
                .help(ledColor.name)
            }
        }
        .padding(.horizontal, -2)
        .background(Capsule().fill(Color.primary.opacity(0.04)))
        .disabled(!viewModel.connected || viewModel.disconnecting)
        .opacity(isInactive ? 0.45 : 1)
        .saturation(isInactive ? 0.25 : 1)
    }

}
