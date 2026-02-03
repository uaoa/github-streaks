import SwiftUI

struct GlassBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color(nsColor: .windowBackgroundColor).opacity(0.95)
                        : Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark
                            ? .white.opacity(0.1)
                            : .black.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
    }
}

struct MainPopoverView: View {
    @ObservedObject var viewModel: ContributionsViewModel
    @State private var animateStreak = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showSettings {
                SettingsView(viewModel: viewModel)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                mainContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 340)
        .modifier(GlassBackgroundModifier())
        .animation(.easeInOut(duration: 0.3), value: viewModel.showSettings)
    }

    private var mainContent: some View {
        VStack(spacing: 12) {
            headerView

            Divider()

            Group {
                if viewModel.username.isEmpty {
                    emptyStateView
                        .transition(.opacity.combined(with: .scale))
                } else if viewModel.isLoading && viewModel.contributions == nil {
                    loadingView
                        .transition(.opacity.combined(with: .scale))
                } else if let error = viewModel.error, viewModel.contributions == nil {
                    errorView(error)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    contributionsContent
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.easeInOut(duration: 0.4), value: viewModel.username.isEmpty)
            .animation(.easeInOut(duration: 0.4), value: viewModel.isLoading)
            .animation(.easeInOut(duration: 0.4), value: viewModel.error != nil)
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
                            .opacity(viewModel.currentStreak > 0 ? 1.0 : 0.6)
                            .scaleEffect(animateStreak ? 1.05 : 1.0)
                            .animation(
                                animateStreak ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default,
                                value: animateStreak
                            )
                            .onAppear {
                                animateStreak = viewModel.currentStreak > 0
                            }
                            .task(id: viewModel.currentStreak) {
                                animateStreak = viewModel.currentStreak > 0
                            }

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
                Button(action: {
                    if !viewModel.isLoading {
                        viewModel.refresh()
                    }
                }) {
                    Label(viewModel.isLoading ? "Refreshing..." : "Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)

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
                Image(systemName: viewModel.isLoading ? "arrow.clockwise" : "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(viewModel.isLoading ? .secondary : .primary)
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .animation(
                        viewModel.isLoading 
                        ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                        : .easeOut(duration: 0.3),
                        value: viewModel.isLoading
                    )
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
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .opacity(0.8)
                .scaleEffect(1.0)

            Text("No GitHub username set")
                .font(.headline)

            Text("Go to Settings to configure your GitHub username.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.showSettings = true
                }
            } label: {
                Text("Open Settings")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

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
        VStack(spacing: 16) {
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

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.refresh()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Spacer()
        }
    }
}
