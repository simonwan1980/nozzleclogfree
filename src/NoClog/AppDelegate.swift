import SwiftUI
import AppKit
import Firebase

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var printerManager: PrinterManager!
    var scheduleManager: ScheduleManager!
    var logManager: LogManager!
    var xpcClient: XPCClientProtocol!//demo
    
    var fetcher: LocationHumidityFetcher!
    
    override init() {
        super.init()
        // 在初始化时就设置为 accessory 模式
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 打印版本号和构建号
        if let infoDict = Bundle.main.infoDictionary {
            let shortVersion = infoDict["CFBundleShortVersionString"] as? String ?? "Unknown"
            let buildVersion = infoDict["CFBundleVersion"] as? String ?? "Unknown"
            print("[启动] App Version (CFBundleShortVersionString): \(shortVersion)")
            print("[启动] Build Number (CFBundleVersion): \(buildVersion)")
        }
        // 初始化管理器
        FirebaseApp.configure()
        Analytics.logEvent("NozzleClogFree_Start", parameters: [:])
        
        HelperInstaller.shared.installIfNeeded()
        xpcClient = XPCClient();//demo
        
        printerManager = PrinterManager()
        scheduleManager = ScheduleManager(printerManager: printerManager, appDelegate: self)
        logManager = LogManager()
        
        fetcher = LocationHumidityFetcher()
   
                
        // 创建主视图
        let contentView = MenuBarView()
            .environmentObject(printerManager)
            .environmentObject(scheduleManager)
            .environmentObject(logManager)
        
        // 创建弹出窗口
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // 加载 PDF 图标
            if let image = NSImage(named: "MenuStatusIcon") {
                image.size = NSSize(width: 22, height: 22)
                image.isTemplate = true  // 使图标能够适应深色/浅色模式
                button.image = image
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
        xpcClient.close()
        scheduleManager.toggleSchedule()
    }
}
