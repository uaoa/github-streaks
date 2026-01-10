import SwiftUI

struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct MainPopoverView: View {
    @ObservedObject var viewModel: ContributionsViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showSettings {
                SettingsView(viewModel: viewModel)
            } else {
                mainContent
            }
        }
        .frame(width: 340)
        .modifier(GlassBackgroundModifier())
    }

    private var mainContent: some View {
        VStack(spacing: 12) {
            headerView

            Divider()

            if viewModel.username.isEmpty {
                emptyStateView
            } else if viewModel.isLoading && viewModel.contributions == nil {
                loadingView
            } else if let error = viewModel.error, viewModel.contributions == nil {
                errorView(error)
            } else {
                contributionsContent
            }
        }
        .padding()
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if !viewModel.username.isEmpty {
                    Text(viewModel.contributionsText)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label("\(viewModel.currentStreak) day streak", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Label("Longest: \(viewModel.longestStreak)", systemImage: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                } else {
                    Text("GitHub Streaks")
                        .font(.headline)

                    Text("Set your username to start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    viewModel.refresh()
                }

                Button("Settings", systemImage: "gear") {
                    viewModel.showSettings = true
                }

                Divider()

                Button {
                    LaunchAtLoginManager.shared.toggle()
                } label: {
                    if LaunchAtLoginManager.shared.isEnabled {
                        Label("Disable Launch at Login", systemImage: "checkmark")
                    } else {
                        Label("Launch at Login", systemImage: "power")
                    }
                }

                Divider()

                Button("Quit", systemImage: "xmark.circle", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var contributionsContent: some View {
        VStack(spacing: 8) {
            ContributionsGridView(
                weeks: viewModel.allWeeks,
                onTap: {
                    viewModel.openGitHubProfile()
                }
            )

            ContributionLegendView()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No GitHub username set")
                .font(.headline)

            Text("Go to Settings to configure your GitHub username.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                viewModel.showSettings = true
            }

            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Loading contributions...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Failed to load contributions")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry", systemImage: "arrow.clockwise") {
                viewModel.refresh()
            }

            Spacer()
        }
    }
}
