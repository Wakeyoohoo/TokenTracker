import SwiftUI
import AppKit
import Combine

@main
struct TokenTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = TokenTrackerViewModel.shared
    
    var body: some Scene {
        Window("Settings", id: "settings") {
            SettingsView(viewModel: viewModel)
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowResizability(.automatic)
        .defaultSize(width: 880, height: 700)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var viewModel = TokenTrackerViewModel.shared
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 450)
        popover.behavior = .transient
        
        // Use a hosting controller to hold our SwiftUI view
        let hostingController = NSHostingController(rootView: MenuBarView(viewModel: viewModel))
        popover.contentViewController = hostingController
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.alignment = .left
            button.title = ""
        }

        updateTitle()
        
        // Initial setup and polling
        viewModel.startPolling()
        
        // Listen to title changes
        viewModel.$providers.sink { [weak self] _ in
            self?.updateTitle()
        }.store(in: &cancellables)
        
        viewModel.$usageData.sink { [weak self] _ in
            self?.updateTitle()
        }.store(in: &cancellables)
    }
    
    func updateTitle() {
        DispatchQueue.main.async {
            guard let button = self.statusItem.button else { return }
            let title = self.viewModel.menuBarTitle
            let showFallbackIcon = self.viewModel.enabledProviders.isEmpty || title == "TT"

            if showFallbackIcon {
                button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "TokenTracker")
                button.imagePosition = .imageLeading
                button.attributedTitle = NSAttributedString(string: "")
                self.statusItem.length = NSStatusItem.squareLength
                return
            }

            button.image = nil

            let attributedTitle = NSMutableAttributedString(string: "")
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineSpacing = -1
            paragraphStyle.minimumLineHeight = 11.0
            paragraphStyle.maximumLineHeight = 11.0

            let font = NSFont.monospacedSystemFont(ofSize: 11.0, weight: .regular)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle,
                .baselineOffset: -4
            ]

            let titleLeftPadding = "  "
            let paddedTitle = title
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { titleLeftPadding + String($0) }
                .joined(separator: "\n")

            let titleAttr = NSAttributedString(string: paddedTitle, attributes: attributes)
            attributedTitle.append(titleAttr)
            button.attributedTitle = attributedTitle

            let measuredWidth = ceil(titleAttr.boundingRect(
                with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).width)
            let textPadding: CGFloat = 16
            let maxWidth: CGFloat = 165
            let minWidth: CGFloat = 70
            self.statusItem.length = min(max(measuredWidth + textPadding, minWidth), maxWidth)
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                // Force it to become active so interaction works right away
                popover.contentViewController?.view.window?.makeKey()
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard !self.viewModel.isRefreshing else { return }
                    await self.viewModel.refreshAll()
                }
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
