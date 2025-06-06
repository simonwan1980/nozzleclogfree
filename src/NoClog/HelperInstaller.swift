//
//  HelperInstaller.swift
//  SMJobBlessDemo
//
//  Created by Simon Wan on 2025/4/26.
//

import Foundation
import Cocoa
import ServiceManagement
import Security

class HelperInstaller {
    static let shared = HelperInstaller()  // 单例
    
    private var authRef: AuthorizationRef?
    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var messageTextField: NSTextField!
    @IBOutlet weak var sendButton: NSButton!
    private let helperLabel = "com.example.NozzleClogFreeHelper"
    private let helperPath = "/Library/PrivilegedHelperTools/com.example.NozzleClogFreeHelper"
    private let mainAppBundleID = "com.example.NozzleClogFree"
    

    /*func installIfNeeded() {
        var error: NSError?

        let status = AuthorizationCreate(nil, nil, [], &authRef)
        if status != errAuthorizationSuccess {
            // AuthorizationCreate really shouldn't fail.
            assert(false)
            authRef = nil
        }

        if !blessHelper(label: "com.example.NozzleClogFreeHelper", error: &error) {
            if let error = error {
                NSLog("Something went wrong! \(error.domain) / \(error.code)")
            }
        } else {
            // At this point, the job is available. However, this is a very
            // simple sample, and there is no IPC infrastructure set up to
            // make it launch-on-demand. You would normally achieve this by
            // using XPC (via a MachServices dictionary in your launchd.plist).
            NSLog("Job is available!")
            //textField.isHidden = false
        }
    
    }
    */

    // 检查并安装辅助进程
    func installIfNeeded() {
        NSLog("Checking if helper needs installation...")
        
        // 检查是否已安装
        if isHelperInstalled() {
            NSLog("Helper is already installed")
            return
        }
        
        // 安装新版本
        installHelper()
    }
    
    // 检查辅助进程是否已安装
    private func isHelperInstalled() -> Bool {
        NSLog("Checking if helper is installed...")
        
        // 检查文件系统中是否存在辅助进程文件
        let path = "/Library/PrivilegedHelperTools/\(helperLabel)"
        let exists = FileManager.default.fileExists(atPath: path)
        
        if exists {
            NSLog("Helper found at path: \(path)")
        } else {
            NSLog("Helper not found at path: \(path)")
        }
        
        return exists
    }
    
    // 安装辅助进程
    private func installHelper() {
        NSLog("Installing helper...")
        var error: NSError?
        
        // 创建授权引用
        let status = AuthorizationCreate(nil, nil, [], &authRef)
        if status != errAuthorizationSuccess {
            NSLog("Failed to create authorization: \(status)")
            return
        }
        
        // 安装辅助进程
        if !blessHelper(label: helperLabel, error: &error) {
            if let error = error {
                NSLog("Failed to install helper: \(error)")
            }
        } else {
            NSLog("Helper installed successfully")
        }
    }
    
    
    private func blessHelper(label: String, error errorPtr: inout NSError?) -> Bool {
            var result = false
            var error: NSError?

            var authItem: AuthorizationItem!
            kSMRightBlessPrivilegedHelper.withCString { cString in
                authItem = AuthorizationItem(
                    name: cString,
                    valueLength: 0,
                    value: nil,
                    flags: 0
                )
            }
            var authRights = AuthorizationRights(count: 1, items: &authItem)
            
            let flags: AuthorizationFlags = [[], .interactionAllowed, .preAuthorize, .extendRights]

            // Obtain the right to install our privileged helper tool (kSMRightBlessPrivilegedHelper).
            let status = AuthorizationCopyRights(authRef!, &authRights, nil, flags, nil)
            if status != errAuthorizationSuccess {
                error = NSError(domain: NSOSStatusErrorDomain as String, code: Int(status), userInfo: nil)
            } else {
                var cfError: Unmanaged<CFError>?

                result = SMJobBless(kSMDomainSystemLaunchd, label as CFString, authRef, &cfError)
                if !result {
                    if let cfError = cfError?.takeRetainedValue() {
                        error = cfError as Error as NSError
                    }
                }
            }

            if !result {
                assert(error != nil)
                errorPtr = error
            }

            return result
        }
}
