//
//  main.swift
//  com.example.NozzleClogFreeHelper
//
//  Created by simon on 2025/4/27.
//

import Foundation
import ServiceManagement

//print("Hello, World!")
NSLog("com.example.NozzleClogFreeHelper Hello, World!")
NSLog("com.example.NozzleClogFreeHelper uid = \(getuid()), euid = \(geteuid()), pid = \(getpid())")

// 设置心跳日志
let heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
    let timestamp = Date().description(with: .current)
    let processInfo = ProcessInfo.processInfo
    let memoryUsage = processInfo.physicalMemory / 1024 / 1024  // 转换为MB
    
    NSLog("com.example.NozzleClogFreeHelper Heartbeat - Time: \(timestamp), Memory: \(memoryUsage)MB")
}

/*
// 启动XPC Listener
let delegate = Helper()
let listener = NSXPCListener(machServiceName: "com.apple.bsd.SMJobBlessHelper")
listener.delegate = delegate
listener.resume()
NSLog("com.apple.bsd.SMJobBlessHelper XPC Listener started successfully")
*/

//demo
// Create the delegate for the service.
let delegate = ServiceDelegate()
delegate.showme()
// Set up the one NSXPCListener for this service. It will handle all incoming connections.
//let listener = NSXPCListener.service()
let listener = NSXPCListener(machServiceName: "com.example.NozzleClogFreeHelper")
listener.delegate = delegate
NSLog("com.example.NozzleClogFreeHelper XPCDemo Listener started successfully")
// Resuming the serviceListener starts this service. This method does not return.
listener.resume()
//demo

// 运行主循环
RunLoop.main.run()

