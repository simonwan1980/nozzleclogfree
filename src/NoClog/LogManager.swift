import Foundation

struct PrintLog: Codable, Identifiable {
    let id: Int
    let timestamp: Date
    let message: String
    
    init(id: Int, timestamp: Date = Date(), message: String = "Print test page") {
        self.id = id
        self.timestamp = timestamp
        self.message = message
    }
}

@MainActor
class LogManager: ObservableObject {
    @Published var logs: [PrintLog] = []
    private let fileManager = FileManager.default
    private let logFileURL: URL
    private var nextId: Int = 1
    
    init() {
        // 获取应用程序支持目录
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("NozzleClogFree")
        
        // 创建应用程序目录
        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Unable to create application directory: %@".localized(with: error.localizedDescription))
        }
        
        // 设置日志文件路径
        logFileURL = appDirectory.appendingPathComponent("print_logs.json")
        
        // 确保日志文件存在且有效
        ensureValidLogFile()
        
        // 加载现有日志
        loadLogs()
        
        // 设置下一个ID
        if let maxId = logs.map({ $0.id }).max() {
            nextId = maxId + 1
        }
        
        // 监听打印通知
        NotificationCenter.default.addObserver(self,
                                            selector: #selector(handlePrintResult(_:)),
                                            name: .printResult,
                                            object: nil)
        
        // 监听日程调整通知
        NotificationCenter.default.addObserver(self,
                                            selector: #selector(handleScheduleAdjusted(_:)),
                                            name: .scheduleAdjusted,
                                            object: nil)
        
        // 监听PDF文件未找到通知
        NotificationCenter.default.addObserver(self,
                                            selector: #selector(handlePDFFileNotFound(_:)),
                                            name: .pdfFileNotFound,
                                            object: nil)
    }
    
    private func ensureValidLogFile() {
        // 检查日志文件是否存在
        if !fileManager.fileExists(atPath: logFileURL.path) {
            print("Log file does not exist, creating new log file".localized)
            // 创建一个空的日志数组
            do {
                let emptyArray = "[]".data(using: .utf8)!
                try emptyArray.write(to: logFileURL, options: .atomic)
                print("Successfully created new log file".localized)
            } catch {
                print("Failed to create log file: \(error.localizedDescription)")
            }
            return
        }
        
        // 验证日志文件是否有效
        do {
            let data = try Data(contentsOf: logFileURL)
            if data.isEmpty {
                print("Log file is empty, reinitializing".localized)
                let emptyArray = "[]".data(using: .utf8)!
                try emptyArray.write(to: logFileURL, options: .atomic)
                return
            }
            
            // 尝试解析JSON，验证格式
            do {
                _ = try JSONSerialization.jsonObject(with: data, options: [])
                print("Log file is valid".localized)
            } catch {
                print("Log file JSON format is invalid, trying to backup and recreate: \(error.localizedDescription)")
                
                // 备份损坏的文件
                let backupURL = logFileURL.deletingPathExtension().appendingPathExtension("backup.json")
                try? fileManager.removeItem(at: backupURL) // 删除旧备份
                try fileManager.copyItem(at: logFileURL, to: backupURL)
                print("Original log file backed up to: \(backupURL.path)".localized)
                
                // 创建新的空日志文件
                let emptyArray = "[]".data(using: .utf8)!
                try emptyArray.write(to: logFileURL, options: .atomic)
                print("Successfully recreated log file".localized)
            }
        } catch {
            print("Error checking log file: \(error.localizedDescription)")
            do {
                // 创建新的空日志文件
                let emptyArray = "[]".data(using: .utf8)!
                try emptyArray.write(to: logFileURL, options: .atomic)
                print("Successfully recreated log file".localized)
            } catch {
                print("Failed to recreate log file: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadLogs() {
        do {
            let data = try Data(contentsOf: logFileURL)
            print("Read log data: \(data.count) bytes".localized)
            
            // 打印日志文件内容（仅用于调试）
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Log file content: \(jsonString)".localized)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            do {
                let decodedLogs = try decoder.decode([PrintLog].self, from: data)
                self.logs = decodedLogs
                print("Successfully loaded \(decodedLogs.count) logs".localized)
            } catch {
                print("Failed to decode logs, trying to recreate log file: \(error)".localized)
                // 创建一个空的日志数组
                let emptyArray = "[]".data(using: .utf8)!
                try emptyArray.write(to: logFileURL, options: .atomic)
                self.logs = []
            }
        } catch {
            print("Failed to load logs: \(error.localizedDescription)".localized)
            logs = [] // 确保即使加载失败也有一个空数组
        }
    }
    
    private func saveLogs() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(logs)
            try data.write(to: logFileURL, options: .atomic)
        } catch {
            print("Failed to save logs: \(error.localizedDescription)".localized)
        }
    }
    
    @objc private func handlePrintResult(_ notification: Notification) {
        let resultInfo = notification.object as? String ?? "Print test page"
        print("Received print result notification: \(resultInfo)".localized)
        
        // 创建新的日志记录，使用递增的ID，内容为实际文件名或结果
        let log = PrintLog(id: nextId, timestamp: Date(), message: resultInfo)
        nextId += 1
        
        print("Created log: \(log)".localized)
        
        // 在主线程上更新 UI
        DispatchQueue.main.async {
            self.logs.insert(log, at: 0)
            self.saveLogs()
            
            // 打印当前日志数量，用于调试
            print("Current log count: \(self.logs.count)".localized)
        }
    }
    
    @objc private func handleScheduleAdjusted(_ notification: Notification) {
        print("Received schedule adjusted notification".localized)
        
        // 从通知中获取消息
        let message = notification.userInfo?["message"] as? String ?? "Schedule adjusted"
        
        // 创建新的日志记录
        let log = PrintLog(id: nextId, timestamp: Date(), message: message)
        nextId += 1
        
        print("Created schedule adjustment log: \(log)".localized)
        
        // 在主线程上更新 UI
        DispatchQueue.main.async {
            self.logs.insert(log, at: 0)
            self.saveLogs()
            
            // 打印当前日志数量，用于调试
            print("Current log count: \(self.logs.count)".localized)
        }
    }
    
    @objc private func handlePDFFileNotFound(_ notification: Notification) {
        print("Received PDF file not found notification".localized)
        
        // 从通知中获取消息
        let message = notification.userInfo?["message"] as? String ?? "Custom PDF file not found, using default test page"
        
        // 创建新的日志记录
        let log = PrintLog(id: nextId, timestamp: Date(), message: message)
        nextId += 1
        
        print("Created PDF file not found log: \(log)".localized)
        
        // 在主线程上更新 UI
        DispatchQueue.main.async {
            self.logs.insert(log, at: 0)
            self.saveLogs()
            
            // 打印当前日志数量，用于调试
            print("Current log count: \(self.logs.count)".localized)
        }
    }
    
    // 添加手动记录日志的方法
    func addLog() {
        let log = PrintLog(id: nextId, message: "Manual log")
        nextId += 1
        
        // 在主线程上更新 UI
        DispatchQueue.main.async {
            self.logs.insert(log, at: 0)
            self.saveLogs()
            
            // 打印当前日志数量，用于调试
            print("Added test log, current log count: \(self.logs.count)".localized)
        }
    }
}


