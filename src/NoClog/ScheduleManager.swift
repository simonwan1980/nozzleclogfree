import Foundation
import AppKit
import ServiceManagement
import Security
import IOKit.pwr_mgt

enum ScheduleType: String, CaseIterable, Identifiable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case auto = "auto"
    
    var id: String { self.rawValue }
    
    var localizedName: String {
        switch self {
        case .daily:
            return "Daily".localized
        case .weekly:
            return "Weekly".localized
        case .monthly:
            return "Monthly".localized
        case .auto:
            return "Smart".localized
        }
    }
}

struct ScheduleOption: Codable, Equatable {
    var type: ScheduleType
    var hour: Int
    var minute: Int
    var dayOfWeek: Int?  // 1-7, where 1 is Sunday (for weekly)
    var dayOfMonth: Int? // 1-31 (for monthly)
    
    static let `default` = ScheduleOption(
        type: .weekly,
        hour: 14,
        minute: 0,
        dayOfWeek: 7,  // Saturday
        dayOfMonth: nil
    )
    
    enum CodingKeys: String, CodingKey {
        case typeRaw = "type"
        case hour
        case minute
        case dayOfWeek
        case dayOfMonth
    }
    
    init(type: ScheduleType, hour: Int, minute: Int, dayOfWeek: Int? = nil, dayOfMonth: Int? = nil) {
        self.type = type
        self.hour = hour
        self.minute = minute
        self.dayOfWeek = dayOfWeek
        self.dayOfMonth = dayOfMonth
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeRaw = try container.decode(String.self, forKey: .typeRaw)
        self.type = ScheduleType(rawValue: typeRaw) ?? .weekly
        self.hour = try container.decode(Int.self, forKey: .hour)
        self.minute = try container.decode(Int.self, forKey: .minute)
        self.dayOfWeek = try container.decodeIfPresent(Int.self, forKey: .dayOfWeek)
        self.dayOfMonth = try container.decodeIfPresent(Int.self, forKey: .dayOfMonth)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .typeRaw)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
        try container.encodeIfPresent(dayOfWeek, forKey: .dayOfWeek)
        try container.encodeIfPresent(dayOfMonth, forKey: .dayOfMonth)
    }
}

@MainActor
class ScheduleManager: ObservableObject {
    @Published var isEnabled = false
    @Published var nextPrintDate: Date?
    @Published var scheduleOption: ScheduleOption = .default
    
    // Make timer nonisolated and manually manage access
    private nonisolated(unsafe) var _timer: DispatchSourceTimer? = nil
    
    private var isToggling = false // Flag to prevent re-entry
    
    // 用于防止系统睡眠的变量
    private var assertionID: IOPMAssertionID = 0
    private var hasActiveAssertion = false
    
    // 用于存储应用状态的UserDefaults键
    private let enabledKey = "PrintScheduleEnabled"
    private let nextPrintDateKey = "NextPrintDate"
    private let scheduleOptionKey = "ScheduleOption"
    
    // 添加对 PrinterManager 的引用
    private var printerManager: PrinterManager?

    weak var appDelegate: AppDelegate!

    init(printerManager: PrinterManager? = nil, appDelegate: AppDelegate) {
        print("ScheduleManager init")
        self.printerManager = printerManager
        self.appDelegate = appDelegate
        
        // 从UserDefaults加载状态
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        
        // 加载保存的日程设置
        if let savedOptionData = UserDefaults.standard.data(forKey: scheduleOptionKey),
           let savedOption = try? JSONDecoder().decode(ScheduleOption.self, from: savedOptionData) {
            scheduleOption = savedOption
        }
        
        if let savedDate = UserDefaults.standard.object(forKey: nextPrintDateKey) as? Date {
            nextPrintDate = savedDate
        }
        
        // 如果启用了自动打印，设置定时器并防止系统睡眠
        if isEnabled {
            setupTimer()
            //preventSleep() // 如果自动打印已启用，立即防止系统睡眠
        }
    }
    
    func toggleSchedule() {
        print("toggleSchedule called. isEnabled: \(isEnabled), isToggling: \(isToggling)")
        guard !isToggling else { 
            print("Schedule toggle already in progress. Exiting.")
            return 
        }
        
        isToggling = true
        
        if isEnabled {
            print("toggleSchedule: Disabling schedule...")
            self._timer?.cancel()
            self._timer = nil
            
            Task {
                await MainActor.run {
                    print("toggleSchedule: Updating state and flag.")
                    isEnabled = false
                    nextPrintDate = nil // 禁用时清除下次打印时间
                    //allowSleep() // 禁用自动打印时允许系统睡眠
                    isToggling = false
                    
                    // 保存状态到UserDefaults
                    UserDefaults.standard.set(isEnabled, forKey: enabledKey)
                    UserDefaults.standard.removeObject(forKey: nextPrintDateKey)
                }
            }
        } else {
            print("toggleSchedule: Enabling schedule...")
            Task {
                await enableSchedule()
            }
        }
    }
    
    func updateScheduleOption(_ option: ScheduleOption) {
        print("Updating schedule option to: \(option.type.rawValue), hour: \(option.hour), minute: \(option.minute)")
        scheduleOption = option
        
        
        // 保存到UserDefaults
        if let encodedData = try? JSONEncoder().encode(option) {
            UserDefaults.standard.set(encodedData, forKey: scheduleOptionKey)
        }
        
        // 发送日志通知，记录用户每次变更
        let summary = getScheduleSummary()
        NotificationCenter.default.post(
            name: .scheduleAdjusted,
            object: nil,
            userInfo: ["message": "User updated print schedule: \(summary)"]
        )
        
        // 如果已启用，重新计算下次打印时间并更新定时器
        if isEnabled {
            Task {
                if let fetcher = appDelegate.fetcher {
                    fetcher.refreshHumidityData()
                }
                await calculateNextPrintDate()
                await MainActor.run {
                    setupTimer()
                }
            }
        }
    }
    
    // 获取当前的打印计划摘要
    func getScheduleSummary() -> String {
        let timeString = String(format: "%02d:%02d", scheduleOption.hour, scheduleOption.minute)
        
        switch scheduleOption.type {
        case .daily:
            return String(format: NSLocalizedString("Print every day at %@", comment: "Daily schedule format"), timeString)
        case .weekly:
            if let dayOfWeek = scheduleOption.dayOfWeek {
                let weekdayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                let localizedWeekday = NSLocalizedString(weekdayNames[dayOfWeek], comment: "Day of week")
                return String(format: NSLocalizedString("Print every %@ at %@", comment: "Weekly schedule format"), localizedWeekday, timeString)
            } else {
                return String(format: NSLocalizedString("Print weekly at %@", comment: "Weekly schedule format"), timeString)
            }
        case .monthly:
            if let dayOfMonth = scheduleOption.dayOfMonth {
                return String(format: NSLocalizedString("Print on day %d of each month at %@", comment: "Monthly schedule format"), dayOfMonth, timeString)
            } else {
                return String(format: NSLocalizedString("Print monthly at %@", comment: "Monthly schedule format"), timeString)
            }
        case .auto:
            // 在 auto 模式下显示更详细的信息，包括城市、湿度和进度
            if let fetcher = appDelegate?.fetcher {
                let baseText = NSLocalizedString("Smart print by humidity", comment: "Auto print schedule description")
                var result = baseText
                
                // 添加城市和湿度信息
                if !fetcher.currentLocation.isEmpty || fetcher.todayHumidity > 0 {
                    result += " ("
                    
                    // 添加城市信息
                    if !fetcher.currentLocation.isEmpty {
                        result += fetcher.currentLocation
                    }
                    
                    // 添加湿度信息
                    if fetcher.todayHumidity > 0 {
                        let humidityInt = Int(fetcher.todayHumidity)
                        if !fetcher.currentLocation.isEmpty {
                            result += " "
                        }
                        result += String(format: "h%d%%", humidityInt)
                    }
                    
                    result += ")"
                }
                
                // 不再添加进度信息，因为这将在下一行显示
                
                return result
            }
            return NSLocalizedString("Smart print by humidity", comment: "Auto print schedule description")
        }
    }
    
    private func setupTimer() {
        print("setupTimer called")
        
        // 如果没有下次打印时间，计算一个
        if nextPrintDate == nil {
            Task {
                await calculateNextPrintDate()
                // 在异步计算完成后继续设置定时器
                await MainActor.run {
                    setupTimerInternal()
                }
            }
            return
        }
        
        // 如果已经有下次打印时间，直接设置定时器
        setupTimerInternal()
    }
    
    private func setWakeupTimer(_ nextPrint: Date) {
        
        // 安全地创建一个比nextPrint早10秒的日期
        guard let nextWakeup = Calendar.current.date(byAdding: .second, value: -10, to: nextPrint) else {
            print("Error: Failed to calculate wakeup time")
            return
        }
        // 使用ISO 8601格式
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // 将Date转换为ISO 8601格式的字符串
        let dateString = formatter.string(from: nextWakeup)
        
        print("nextPrint time: \(nextPrint)")
        print("nextWakeup time: \(nextWakeup)")
        
        appDelegate.xpcClient.HelperSetWakeupTime(for: dateString) { result in
            DispatchQueue.main.async {
                print("HelperSetWakeupTime result: \(result)")
            }
        }
    }
    
    private func setupTimerInternal() {
        print("setupTimerInternal called")
        guard let nextPrint = nextPrintDate else {
            print("Error: Failed to calculate next print date")
            return
        }
    
        // 取消之前的定时器
        self._timer?.cancel()
        self._timer = nil
        
        var timespec = timespec()
        timespec.tv_sec = Int(nextPrint.timeIntervalSince1970)
        timespec.tv_nsec = 0
        let wallTime = DispatchWallTime(timespec: timespec)
        let queue = DispatchQueue.main
        self._timer = DispatchSource.makeTimerSource(queue: queue)
        
        // 设置定时器的触发时间
        self._timer?.schedule(wallDeadline: wallTime)
        self._timer?.setEventHandler {
            self.timerFired()
        }
        self._timer?.resume()
        
        print("Timer set to fire at wall time: \(nextPrint)")
        // 设置唤醒时间
        setWakeupTimer(nextPrint)
    }
    
    @objc private func timerFired() {
        print("Timer fired at: \(Date())")
        
        // 使用 Task 启动异步操作
        Task {
            await handleTimerFired()
        }
    }

    private func shouldAutoPrint() -> Bool {

        // 计算累积打印间隔
        var total: Double = 0.0
        
        // 获取湿度数据
        guard let fetcher = appDelegate.fetcher else {
            print("Fetcher not available, recommending to print")
            total = 1.0
            appDelegate.fetcher?.totalHumidity = total
            return true
        }
        
        // 刷新湿度数据
        print("Refreshing humidity data before making print decision...")
        fetcher.refreshHumidityData()
        
        // 检查湿度数据是否存在
        guard !fetcher.fullHumidity.isEmpty else {
            print("No humidity data available, recommending to print")
            total = 1.0
            appDelegate.fetcher?.totalHumidity = total
            return true
        }

        // 从日志中获取上次成功打印的时间
        guard let logManager = appDelegate.logManager else {
            print("LogManager not available, recommending to print")
            total = 1.0
            fetcher.totalHumidity = total
            return true
        }
        
        // 查找最近一次成功打印的日志
        if let lastSuccessLog = logManager.logs.first(where: { $0.message.starts(with: "Success printed:") }) {
            let lastPrintDate = lastSuccessLog.timestamp
            print("Last successful print was at: \(lastPrintDate)")
            
            
            // 检查是否是今天打印的
            let calendar = Calendar.current
            if calendar.isDateInToday(lastPrintDate) {
                print("Already printed today, no need to print again")
                fetcher.totalHumidity = total
                return false
            }
            
            // 计算自上次打印以来的天数
            let components = calendar.dateComponents([.day], from: lastPrintDate, to: Date())
            guard let daysSinceLastPrint = components.day, daysSinceLastPrint > 0 else {
                print("Error calculating days since last print or less than a day, not printing")
                fetcher.totalHumidity = total
                return false
            }
            
            print("Days since last print: \(daysSinceLastPrint)")
            
            
            
            // 获取自上次打印以来的湿度数据（不包含打印日当天，但包含今天）
            var dayHumidity: [Double] = []
            
            // fullHumidity 数组中，最后一个值代表今天，倒数第二个表示昨天，依次类推
            let count = fetcher.fullHumidity.count
            for i in 0..<min(daysSinceLastPrint, count) {
                // 从数组的末尾开始读取，最后一个元素是今天
                let index = count - 1 - i
                if index >= 0 {
                    dayHumidity.append(fetcher.fullHumidity[index])
                    print("Day -\(i): Added humidity \(fetcher.fullHumidity[index])%")
                }
            }
            
            print("Collected \(dayHumidity.count) days of humidity data since last print")
            
            // 创建湿度曲线计算器
            // 直接创建一个新的 HumidityCurve 实例
            let humidityCurve = HumidityCurve()
            
            
            
            // 遍历每天的湿度数据，计算打印间隔
            for (index, humidity) in dayHumidity.enumerated() {
                let interval = humidityCurve.computePrintInterval(humidity: humidity)
                print("Day -\(index): Humidity \(humidity)%, Interval \(interval) days")
                total += 1/interval
            }
            
            print("Total accumulated print interval: \(total) days")
            
            // 如果累积的打印间隔超过或等于 1 天，则建议打印
            if total >= 1.0 {
                fetcher.totalHumidity = total
                return true
            }
            else {
                fetcher.totalHumidity = total
                return false
            }
        } 
        else {
            // 没有找到历史成功打印记录，直接返回 true
            print("No previous successful print found, recommending to print")
            total = 1.0
            fetcher.totalHumidity = total
            return true
        }
    }
    
    private func handleTimerFired() async {

        if scheduleOption.type == .auto {
            if shouldAutoPrint() {
                await doPrint()
            }
        }
        else {
            await doPrint()
        }
        
        // 打印完成后，设置下一次打印时间和定时器
        await calculateNextPrintDate()
        await MainActor.run {
            setupTimer()
        }
    }
    
    private func calculateNextPrintDate() async {
        var components = DateComponents()
        components.hour = scheduleOption.hour
        components.minute = scheduleOption.minute
        components.second = 0
        
        let calendar = Calendar.current
        let now = Date()
        
        // 根据不同的日程类型计算下一次打印时间
        switch scheduleOption.type {
        case .daily:
            // 每天在指定时间打印
            // 先尝试设置今天的时间
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayComponents.hour = scheduleOption.hour
            todayComponents.minute = scheduleOption.minute
            todayComponents.second = 0
            
            if let todayTime = calendar.date(from: todayComponents), todayTime > now {
                // 如果今天的设定时间还没过，就用今天的
                print("Next daily print date set to today: \(todayTime)")
                await MainActor.run {
                    nextPrintDate = todayTime
                }
            } else {
                // 否则用明天的
                if let nextTime = calendar.nextDate(after: now,
                                                  matching: components,
                                                  matchingPolicy: .nextTime) {
                    print("Next daily print date set to tomorrow: \(nextTime)")
                    await MainActor.run {
                        nextPrintDate = nextTime
                    }
                }
            }
            
        case .weekly:
            // 每周在指定日期和时间打印
            if let dayOfWeek = scheduleOption.dayOfWeek {
                components.weekday = dayOfWeek  // 1-7，1代表周日
                
                if let nextWeekday = calendar.nextDate(after: now,
                                                     matching: components,
                                                     matchingPolicy: .nextTime) {
                    print("Next weekly print date set to: \(nextWeekday)")
                    await MainActor.run {
                        nextPrintDate = nextWeekday
                    }
                }
            }
            
        case .monthly:
            // 每月在指定日期和时间打印
            if let dayOfMonth = scheduleOption.dayOfMonth {
                components.day = dayOfMonth
                
                // 查找下一个匹配的日期
                var nextDate = now
                var isRescheduled = false
                
                // 尝试找到下一个有效日期（处理月份天数不同的情况）
                for _ in 0..<12 { // 最多尝试12个月
                    if let candidate = calendar.nextDate(after: nextDate,
                                                       matching: components,
                                                       matchingPolicy: .nextTime) {
                        print("Next monthly print date set to: \(candidate)")
                        await MainActor.run {
                            nextPrintDate = candidate
                        }
                        
                        // 检查是否调整了日期（当月没有所选日期的情况）
                        let candidateComponents = calendar.dateComponents([.year, .month, .day], from: candidate)
                        if candidateComponents.day != dayOfMonth {
                            isRescheduled = true
                            // 发送通知，记录日志
                            await MainActor.run {
                                NotificationCenter.default.post(
                                    name: .scheduleAdjusted,
                                    object: nil,
                                    userInfo: ["message": "Monthly print rescheduled: selected day \(dayOfMonth) not available in month, adjusted to \(candidateComponents.day ?? 0)"]
                                )
                            }
                        }
                        break
                    }
                    
                    // 如果找不到匹配的日期（例如2月没有31日），尝试下一个月
                    nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
                    isRescheduled = true
                }
                
                // 如果调整了日期但没有发送通知（可能是跳到了下个月）
                if isRescheduled && nextPrintDate != nil {
                    let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextPrintDate!)
                    if nextComponents.day != dayOfMonth && nextComponents.month != calendar.component(.month, from: now) {
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .scheduleAdjusted,
                                object: nil,
                                userInfo: ["message": "Monthly print rescheduled: day \(dayOfMonth) not available, moved to next month on day \(nextComponents.day ?? 0)"]
                            )
                        }
                    }
                }
            }
        case .auto:
            // For auto mode, scheduling logic is not yet implemented. Skip scheduling.
           // 每天在指定时间醒来，再根据湿度信息判断是都要打印
            // 先尝试设置今天的时间
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayComponents.hour = scheduleOption.hour
            todayComponents.minute = scheduleOption.minute
            todayComponents.second = 0
            
            if let todayTime = calendar.date(from: todayComponents), todayTime > now {
                // 如果今天的设定时间还没过，就用今天的
                print("Planned auto print date set to today: \(todayTime)")
                await MainActor.run {
                    nextPrintDate = todayTime
                }
            } else {
                // 否则用明天的
                if let nextTime = calendar.nextDate(after: now,
                                                  matching: components,
                                                  matchingPolicy: .nextTime) {
                    print("Planned auto print date set to tomorrow: \(nextTime)")
                    await MainActor.run {
                        nextPrintDate = nextTime
                    }
                }
            }
        }
        
        // 如果计算失败，使用默认值（1天后）
        if nextPrintDate == nil {
            print("Failed to calculate next print date, using default (1 day later)")
            await MainActor.run {
                nextPrintDate = calendar.date(byAdding: .day, value: 1, to: now)
                
                // 发送通知，记录日志
                NotificationCenter.default.post(
                    name: .scheduleAdjusted,
                    object: nil,
                    userInfo: ["message": "Failed to calculate next print date based on schedule settings, defaulted to tomorrow"]
                )
            }
        }
        
        // 保存到UserDefaults
        if let nextPrint = nextPrintDate {
            await MainActor.run {
                UserDefaults.standard.set(nextPrint, forKey: nextPrintDateKey)
            }
        }
    }
    
    private func doPrint() async {
        print("doPrint called")
        
        // 记录更详细的诊断信息
        await MainActor.run {
            let isMainThread = Thread.isMainThread
            print("Is executing on main thread: \(isMainThread)")
            
            // 使用不依赖于 AppDelegate 的方式获取 printerManager
            if printerManager == nil {
                printerManager = PrinterManager()
            }
            
            if let printerManager = printerManager {
                print("Selected printer: \(printerManager.selectedPrinter ?? "nil")")
                
                // 打印测试页
                let (printResult, printFileName) = printerManager.printTestPage()
                switch printResult {
                case .success:
                    print("Print file [\(printFileName)] result: success")
                    
                    // 保存成功打印的时间
                    let lastPrintDateKey = "LastSuccessfulPrintDate"
                    UserDefaults.standard.set(Date(), forKey: lastPrintDateKey)
                    print("已保存成功打印时间到 UserDefaults")
                    
                    NotificationCenter.default.post(
                        name: .printResult,
                        object: "Success printed: \(printFileName)"
                    )
                case .failure(let error):
                    print("Print file [\(printFileName)] result: failed - \(error.localizedDescription)")
                    NotificationCenter.default.post(
                        name: .printResult,
                        object: "Failed to print: \(printFileName): \(error.localizedDescription)"
                    )
                }
            } else {
                print("No printer manager available")
            }
        }
    }
    
    private func enableSchedule() async {
        print("enableSchedule called")
        
        if let fetcher = appDelegate.fetcher {
            fetcher.refreshHumidityData()
        }
        // 计算下次打印时间
        await calculateNextPrintDate()
        
        // 设置定时器
        await MainActor.run {
            setupTimer()
        }
        
        // 防止系统睡眠
        //preventSleep()
        
        await MainActor.run {
            isEnabled = true
            isToggling = false
            
            // 保存状态到UserDefaults
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        }
    }
    
    // 防止系统进入睡眠 - 在启用自动打印功能时调用
    private func preventSleep() {
        guard !hasActiveAssertion else { return }
        
        let reason = "NozzleClogFree automatic printing enabled" as CFString
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        ) == kIOReturnSuccess
        
        hasActiveAssertion = success
        print("Preventing system sleep: \(success)")
    }
    
    // 允许系统进入睡眠 - 在禁用自动打印功能时调用
    private func allowSleep() {
        guard hasActiveAssertion else { return }
        
        let success = IOPMAssertionRelease(assertionID) == kIOReturnSuccess
        hasActiveAssertion = !success
        print("Allowing system sleep: \(success)")
    }
    
    deinit {
        self._timer?.cancel()
        
        // 确保在对象销毁时释放睡眠限制
        if hasActiveAssertion {
            IOPMAssertionRelease(assertionID)
        }
    }
}

extension Notification.Name {
    static let printResult = Notification.Name("printResult")
    static let scheduleAdjusted = Notification.Name("scheduleAdjusted")
}
