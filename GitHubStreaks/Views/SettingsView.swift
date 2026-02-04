import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ContributionsViewModel
    @State private var usernameInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            headerView

            VStack(spacing: 16) {
                usernameSection
                menuBarSection
                infoSection
            }
            .padding(16)
        }
        .fixedSize(horizontal: false, vertical: true)
        .glassBackground()
        .onAppear {
            usernameInput = viewModel.username
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button {
                viewModel.showSettings = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(GlassCircleButtonStyle())

            Spacer()

            Text("Settings")
                .font(.headline)

            Spacer()

            Color.clear
                .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Username Section

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("GitHub Username", systemImage: "person.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                TextField("Enter username", text: $usernameInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        saveUsername()
                    }

                if usernameInput != viewModel.username && !usernameInput.isEmpty {
                    Button("Save") {
                        saveUsername()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }

    // MARK: - Menu Bar Section

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Menu Bar Display", systemImage: "menubar.rectangle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Show Streak", isOn: $viewModel.menuBarShowStreak)
                    .toggleStyle(.switch)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Display Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Mode", selection: $viewModel.menuBarMode) {
                        ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if viewModel.menuBarMode == .grid {
                    gridDaysSettings
                }

                if viewModel.menuBarMode == .days {
                    daysModeSettings
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }

    private var gridDaysSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Text("Grid Days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.menuBarDaysCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach([7, 14, 21, 30], id: \.self) { days in
                    Button("\(days)") {
                        viewModel.menuBarDaysCount = days
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.menuBarDaysCount == days ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.menuBarDaysCount) },
                    set: { viewModel.menuBarDaysCount = Int($0) }
                ),
                in: 7...60,
                step: 1
            )
        }
    }

    private var daysModeSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Text("Days to show")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.menuBarDaysModeCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach([3, 5, 7, 10], id: \.self) { days in
                    Button("\(days)") {
                        viewModel.menuBarDaysModeCount = days
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.menuBarDaysModeCount == days ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.menuBarDaysModeCount) },
                    set: { viewModel.menuBarDaysModeCount = Int($0) }
                ),
                in: 1...14,
                step: 1
            )
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About", systemImage: "info.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 6) {
                Label("Data refreshes every 30 minutes", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("Contributions are cached locally", systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }

    // MARK: - Actions

    private func saveUsername() {
        viewModel.username = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Glass Circle Button Style

private struct GlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .background {
                Circle()
                    .fill(.regularMaterial)
            }
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .contentShape(Circle())
    }
}

// MARK: - Glass Effect Modifiers

private extension View {
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func glassCard(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
