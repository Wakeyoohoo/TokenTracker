import SwiftUI

/// Main menu bar popup view showing all provider usage data
struct MenuBarView: View {
    @ObservedObject var viewModel: TokenTrackerViewModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            if viewModel.enabledProviders.isEmpty {
                emptyStateView
            } else {
                // Provider cards
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.enabledProviders) { config in
                            if let usage = viewModel.usageData[config.id] {
                                ProviderCardView(config: config, usage: usage)
                            } else {
                                ProviderCardView(
                                    config: config,
                                    usage: .empty(providerId: config.id, providerName: config.displayName)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400)
            }
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(width: 380)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .foregroundColor(.orange)
            Text("TokenTracker")
                .font(.headline)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("还没有启用的平台")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("点击下方 ⚙ 进入设置添加 API Key")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            // Refresh button
            Button(action: {
                Task { await viewModel.refreshAll() }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.caption)
                        .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                        .animation(viewModel.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                    if let time = viewModel.lastRefreshTime {
                        Text(time.shortTimeString)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(viewModel.isRefreshing)
            
            Spacer()
            
            // Settings button
            Button(action: {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }) {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .foregroundColor(.secondary)
            
            // Quit button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
