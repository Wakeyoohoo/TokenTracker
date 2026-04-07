import SwiftUI
import AppKit
import Combine

@main
struct TokenTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Window("Settings", id: "settings") {
            SettingsView(viewModel: TokenTrackerViewModel.shared)
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowResizability(.automatic)
        .defaultSize(width: 880, height: 700)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private var lastTitleString: String = "" // 缓存上次设置的标题内容

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = TokenTrackerViewModel.shared.showStatusBar
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "TokenTracker")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // 设置弹窗
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 450)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: TokenTrackerViewModel.shared))
        
        // 核心性能优化：通过 debounce (节流) 减少标题更新次数
        let viewModel = TokenTrackerViewModel.shared
        Publishers.CombineLatest(viewModel.$providers, viewModel.$usageData)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main) // 150ms 窗口合并重复更新
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)

        viewModel.onShowStatusBarChanged = { [weak self] show in
            self?.statusItem.isVisible = show
        }

        // 异步启动轮询，不阻塞应用展示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.startPolling()
            self.updateTitle()
        }
    }
    
    func updateTitle() {
        let viewModel = TokenTrackerViewModel.shared
        guard let button = statusItem.button else { return }
        let title = viewModel.menuBarTitle
        
        // 优化点：内容没变就不刷新，极大地降低系统 UI 服务负载
        guard title != lastTitleString else { return }
        lastTitleString = title
        
        if viewModel.enabledProviders.isEmpty || title == "TT" {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "TokenTracker")
            button.imagePosition = .imageLeading
            button.attributedTitle = NSAttributedString(string: "")
            statusItem.length = 28
            return
        }

        button.image = nil
        
        let attributedTitle = NSMutableAttributedString(string: "")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = -1
        paragraphStyle.minimumLineHeight = 11.0
        paragraphStyle.maximumLineHeight = 11.0

        let font = NSFont.monospacedSystemFont(ofSize: 11.0, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: -4
        ]

        let titleAttr = NSAttributedString(string: title, attributes: attributes)
        attributedTitle.append(titleAttr)
        button.attributedTitle = attributedTitle

        // 计算宽度：增加缓存或简化测量
        let measuredWidth = ceil(titleAttr.boundingRect(
            with: NSSize(width: 400, height: 40),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).width)
        
        statusItem.length = min(max(measuredWidth + 6, 30), 400)
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            // 点击才触发手动刷新，不再频繁在后台请求
            Task { await TokenTrackerViewModel.shared.refreshAll() }
        }
    }

    func popoverWillShow(_ notification: Notification) { TokenTrackerViewModel.shared.isPopoverVisible = true }
    func popoverDidClose(_ notification: Notification) { TokenTrackerViewModel.shared.isPopoverVisible = false }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
