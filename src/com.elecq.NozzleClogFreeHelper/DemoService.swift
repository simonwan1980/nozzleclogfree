//
//  DemoService.swift
//  DemoService
//
//  Created by Tony Gorez on 21/12/2023.
//

import Foundation
import IOKit
import IOKit.pwr_mgt

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class DemoService: NSObject, DemoServiceProtocol {
    /// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
    @objc func uppercase(string: String, with reply: @escaping (String) -> Void) {
        NSLog("com.example.NozzleClogFreeHelper XPCDemo uppercase triggered")
        let response = string.uppercased()
        reply(response)
    }
    
    @objc func HelperSetWakeupTime(string: String, with reply: @escaping (String) -> Void) {
        NSLog("com.example.NozzleClogFreeHelper XPCDemo HelperSetWakeupTime triggered")
        let response = string

        // 将ISO 8601字符串转换为Date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let wakeupDate = formatter.date(from: string) else {
            NSLog("com.example.NozzleClogFreeHelper Failed to parse date string: \(string)")
        reply("com.example.NozzleClogFreeHelper Failed to parse date")
        return
        }
        
        // 确保唤醒时间在将来
        if wakeupDate <= Date() {
            NSLog("com.example.NozzleClogFreeHelper Wakeup time is in the past")
            reply("com.example.NozzleClogFreeHelper Wakeup time is in the past")
            return
        }
    
        // 转换为CFDateRef
        let wakeupDateCF = wakeupDate as NSDate
        // 使用IOPMSchedulePowerEvent设置唤醒时间
        let result = IOPMSchedulePowerEvent(
            wakeupDateCF,
            "com.example.NozzleClogFreeHelper" as CFString,
            kIOPMAutoWake as CFString
        )
        
        if result == kIOReturnSuccess {
            NSLog("com.example.NozzleClogFreeHelper Successfully scheduled wakeup at: \(wakeupDate)")
            reply("com.example.NozzleClogFreeHelper Successfully scheduled wakeup")
        } else {
            NSLog("com.example.NozzleClogFreeHelper Failed to schedule wakeup: \(result)")
            reply("com.example.NozzleClogFreeHelper Failed to schedule wakeup: \(result)")
        }

        reply(response)
    }
    
    func close() {
        exit(0)
    }
}

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    
    func showme(){
        NSLog("com.example.NozzleClogFreeHelper XPCDemo ServiceDelegate showme")
    }
    
    /// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        // Configure the connection.
        // First, set the interface that the exported object implements.
        newConnection.exportedInterface = NSXPCInterface(with: DemoServiceProtocol.self)
        
        // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
        let exportedObject = DemoService()
        newConnection.exportedObject = exportedObject
        
        // Resuming the connection allows the system to deliver more incoming messages.
        newConnection.resume()
        
        NSLog("com.example.NozzleClogFreeHelper XPCDemo Listener triggered")
        
        // Returning true from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call invalidate() on the connection and return false.
        return true
    }
}
