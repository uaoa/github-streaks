import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ContributionsViewModel

    @State private var usernameInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            VStack(spacing: 12) {
                usernameSection
                menuBarSection
                infoSection
            }
            .padding(12)
        }
        .onAppear {
            usernameInput = viewModel.username
        }
    }

    private var headerView: some View {
        HStack {
            Button {
                viewModel.showSettings = false
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Settings")
                .font(.headline)

            Spacer()

            Color.clear
                .frame(width: 50)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var usernameSection: some View {
        GroupBox("GitHub Username") {
            HStack {
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
    }

    private var menuBarSection: some View {
        GroupBox("Menu Bar Display") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Show Streak", isOn: $viewModel.menuBarShowStreak)

                Divider()

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

                if viewModel.menuBarMode == .grid {
                    gridDaysSettings
                }

                if viewModel.menuBarMode == .days {
                    daysModeSettings
                }
            }
        }
    }

    private var gridDaysSettings: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Grid Days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.menuBarDaysCount)")
                    .font(.caption)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach([7, 14, 21, 30], id: \.self) { days in
                    Button("\(days)") {
                        viewModel.menuBarDaysCount = days
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(viewModel.menuBarDaysCount == days ? .accentColor : .secondary)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Days to show")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.menuBarDaysModeCount)")
                    .font(.caption)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach([3, 5, 7, 10], id: \.self) { days in
                    Button("\(days)") {
                        viewModel.menuBarDaysModeCount = days
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(viewModel.menuBarDaysModeCount == days ? .accentColor : .secondary)
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

    private var infoSection: some View {
        GroupBox("About") {
            VStack(alignment: .leading, spacing: 4) {
                Label("Data refreshes every 30 minutes", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("Contributions are cached locally", systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func saveUsername() {
        viewModel.username = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
