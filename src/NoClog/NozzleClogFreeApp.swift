//
//  NozzleClogFreeApp.swift
//  NozzleClogFree
//
//  Created by Simon on 2025/4/3.
//

import SwiftUI

@main
struct NozzleClogFreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // 移除所有默认菜单项
            CommandGroup(replacing: .appInfo) {}
            CommandGroup(replacing: .systemServices) {}
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .windowSize) {}
            CommandGroup(replacing: .windowList) {}
            CommandGroup(replacing: .help) {}
        }
    }
}
