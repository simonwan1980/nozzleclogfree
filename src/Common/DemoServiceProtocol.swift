//
//  DemoServiceProtocol.swift
//  DemoService
//
//  Created by Tony Gorez on 21/12/2023.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc protocol DemoServiceProtocol {
    func uppercase(string: String, with reply: @escaping (String) -> Void)
    func HelperSetWakeupTime(string: String, with reply: @escaping (String) -> Void)
    func close()
}

/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     let connectionToService = NSXPCConnection(serviceName: "com.tonygo.DemoService")
     connectionToService.remoteObjectInterface = NSXPCInterface(with: DemoServiceProtocol.self)
     connectionToService.resume()

 Once you have a connection to the service, you can use it like this:

     if let proxy = connectionToService.remoteObjectProxy as? DemoServiceProtocol {
         proxy.uppercase(string: "hello") { aString in
             NSLog("Result string was: \(aString)")
         }
     }

 And, when you are finished with the service, clean up the connection like this:

     connectionToService.invalidate()
*/
