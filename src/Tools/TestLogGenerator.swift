import Foundation

// 获取应用程序支持目录路径
func getLogFileURL() -> URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let appDirectory = appSupport.appendingPathComponent("NoClog")
    
    // 创建应用程序目录（如果不存在）
    do {
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("无法创建应用程序目录：\(error.localizedDescription)")
    }
    
    // 返回日志文件路径
    return appDirectory.appendingPathComponent("print_logs.json")
}

// 简化的打印日志结构体
struct PrintLog: Codable, Identifiable {
    let id: Int
    let timestamp: Date
}

// 生成测试日志数据
func generateTestLogs() -> [PrintLog] {
    var logs: [PrintLog] = []
    
    // 生成10条日志，每条日志只包含顺序ID和时间戳
    for i in 1...10 {
        // 创建不同时间的日志（过去7天内）
        let timeOffset = Double(i * 3600 * (1 + Int.random(in: 0...24)))
        let timestamp = Date().addingTimeInterval(-timeOffset)
        
        let log = PrintLog(
            id: i,
            timestamp: timestamp
        )
        
        logs.append(log)
    }
    
    return logs
}

// 保存日志到文件
func saveLogsToFile(_ logs: [PrintLog]) {
    let fileURL = getLogFileURL()
    
    do {
        // 先检查文件是否存在，如果存在则先删除
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("删除现有日志文件")
        }
        
        let encoder = JSONEncoder()
        // 使用与应用程序相同的日期编码策略
        encoder.dateEncodingStrategy = .secondsSince1970
        
        // 不使用 prettyPrinted，确保与应用程序格式一致
        let data = try encoder.encode(logs)
        
        // 先验证编码后的数据是否有效
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        if let jsonArray = jsonObject as? [[String: Any]], !jsonArray.isEmpty {
            print("验证：JSON数据有效，包含 \(jsonArray.count) 条记录")
        } else {
            print("警告：JSON数据格式可能不正确")
        }
        
        try data.write(to: fileURL, options: .atomic)
        
        // 设置文件权限确保应用程序可以读取
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path)
        
        print("成功写入 \(logs.count) 条测试日志到: \(fileURL.path)")
        
        // 验证写入的文件
        let readData = try Data(contentsOf: fileURL)
        print("Verification: file size is \(readData.count) bytes")
        
        // Try decoding for verification
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let testDecode = try decoder.decode([PrintLog].self, from: readData)
        print("Verification: successfully decoded \(testDecode.count) logs")
        
        // Print file content (for debugging only)
        if let jsonString = String(data: readData, encoding: .utf8) {
            print("File content: \(jsonString)")
        }
    } catch {
        print("Failed to save log: \(error.localizedDescription)")
    }
}

// Main function
func main() {
    print("Start generating test logs...")
    let logs = generateTestLogs()
    
    // Print generated logs
    for (index, log) in logs.enumerated() {
        print("Log #\(index + 1):")
        print("ID: \(log.id)")
        print("Time: \(log.timestamp)")
        print("")
    }
    
    // Save to file
    saveLogsToFile(logs)
    print("Test log generation completed!")
}

// 运行主函数
main()
