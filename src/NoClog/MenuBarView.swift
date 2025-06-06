import SwiftUI
import Foundation
import AppKit
import CoreLocation

struct MenuBarView: View {
    @EnvironmentObject var printerManager: PrinterManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var logManager: LogManager
    @State private var showingLogs = false
    @State private var showingScheduleConfig = false
    @State private var showingLanguageSelector = false
    @State private var showingHelpView = false
    @State private var refreshView = UUID() // 用于强制刷新视图
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text("NozzleClogFree".localized)
                .font(.headline)
                .textSelection(.enabled)
            
            // 打印机选择
            VStack(alignment: .leading) {
                Text("Select Printer:".localized)
                    .textSelection(.enabled)
                Picker("Printer".localized, selection: Binding(
                    get: { printerManager.selectedPrinter ?? "" },
                    set: { printerManager.selectedPrinter = $0 }
                )) {
                    ForEach(printerManager.availablePrinters, id: \.self) { printer in
                        Text(printer).tag(printer)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // 自定义打印文件选择
            VStack(alignment: .leading) {
                Text("Print File:".localized)
                    .textSelection(.enabled)
                
                HStack {
                    if let customPath = printerManager.customPDFPath {
                        Text(URL(fileURLWithPath: customPath).lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Text("Default Test Page".localized)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    
                    Button("Select...".localized) {
                        printerManager.selectCustomPDF()
                    }
                    .buttonStyle(.borderless)
                    
                    if printerManager.customPDFPath != nil {
                        Button("Clear".localized) {
                            printerManager.clearCustomPDF()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            
            // 打印设置按钮
            Button("Print Settings".localized) {
                printerManager.showPrintSettings()
            }
            .disabled(printerManager.selectedPrinter == nil)
            
            Divider()
            
            // 自动打印开关
            Button(scheduleManager.isEnabled ? "Disable Auto Print".localized : "Enable Auto Print".localized) {
                scheduleManager.toggleSchedule()
            }
            Text(scheduleManager.isEnabled ? "(Enabled)".localized : "(Disabled)".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            
            // 打印计划摘要，只在自动打印功能启用时显示
            if scheduleManager.isEnabled {
                Text(scheduleManager.getScheduleSummary())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if scheduleManager.scheduleOption.type == .auto && scheduleManager.isEnabled {
                // 在 auto 模式下且自动打印启用时显示进度信息
                if let fetcher = scheduleManager.appDelegate?.fetcher {
                    let nextPrintETAString = fetcher.nextPrintETAString
                    Text("Next Print ETA: \(nextPrintETAString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            } else if let nextPrintDate = scheduleManager.nextPrintDate {
                // 在其他模式下显示下次打印时间
                Text("Next Print Time: %@".localized(with: nextPrintDate.formatted(.dateTime)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            
            // 打印计划配置按钮
            Button("Configure Schedule".localized) {
                showingScheduleConfig = true
            }
            .sheet(isPresented: $showingScheduleConfig) {
                ScheduleConfigView(scheduleOption: scheduleManager.scheduleOption) { newOption in
                    scheduleManager.updateScheduleOption(newOption)
                }
                .environmentObject(scheduleManager)  // 确保传递环境对象
            }
            
            // 手动打印按钮
            Button("Print Now".localized) {
                let (result, printFileName) = printerManager.printTestPage()
                switch result {
                case .success:
                    print("Print file [\(printFileName)] result: success")
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
            }
            .disabled(printerManager.selectedPrinter == nil)
            
            Divider()
            
            // 日志按钮
            Button("View Logs".localized) {
                showingLogs = true
            }
            .sheet(isPresented: $showingLogs) {
                LogView(logs: logManager.logs)
            }
            
            Spacer()
            
            // 语言切换按钮（在左下角）
            HStack {
                Button("Language".localized) {
                    showingLanguageSelector = true
                }
                .sheet(isPresented: $showingLanguageSelector) {
                    LanguageSelectorView()
                }
                
                Button("About".localized) {
                    showingHelpView = true
                }
                .sheet(isPresented: $showingHelpView) {
                    HelpView()
                }
                
                Spacer()
                
                // 退出按钮
                Button("Exit".localized) {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 300)
        .id(refreshView) // 使用 id 修饰符强制刷新视图
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshView = UUID() // 当语言变更时强制刷新视图
        }
    }
}

// 语言选择器视图
struct LanguageSelectorView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedLanguage = LocalizationManager.shared.getCurrentLanguage()
    @State private var searchText = ""
    let languages = LocalizationManager.shared.getSupportedLanguages()
    
    var filteredLanguages: [(code: String, name: String)] {
        if searchText.isEmpty {
            return languages
        } else {
            return languages.filter { 
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.code.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Language".localized)
                .font(.headline)
                .padding(.top)
            
            // 搜索框
            TextField("Search".localized, text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            List {
                ForEach(filteredLanguages, id: \.code) { language in
                    HStack {
                        Text(language.name)
                            .lineLimit(1)
                        Spacer()
                        if selectedLanguage == language.code {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedLanguage = language.code
                        LocalizationManager.shared.setLanguage(language.code)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Button("Cancel".localized) {
                presentationMode.wrappedValue.dismiss()
            }
            .padding(.bottom)
        }
        .frame(width: 300, height: 400)
    }
}

struct ScheduleConfigView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var scheduleManager: ScheduleManager
    @State private var scheduleOption: ScheduleOption
    @State private var selectedType: ScheduleType
    @State private var hour: Int
    @State private var minute: Int
    @State private var dayOfWeek: Int
    @State private var dayOfMonth: Int
    
    private let onSave: (ScheduleOption) -> Void
    
    init(scheduleOption: ScheduleOption, onSave: @escaping (ScheduleOption) -> Void) {
        self._scheduleOption = State(initialValue: scheduleOption)
        self._selectedType = State(initialValue: scheduleOption.type)
        self._hour = State(initialValue: scheduleOption.hour)
        self._minute = State(initialValue: scheduleOption.minute)
        self._dayOfWeek = State(initialValue: scheduleOption.dayOfWeek ?? 7) // 默认星期六
        self._dayOfMonth = State(initialValue: scheduleOption.dayOfMonth ?? 1) // 默认每月1日
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Configure Print Schedule".localized)
                    .font(.headline)
                    .textSelection(.enabled)
                Spacer()
                Button("Close".localized) {
                    saveSchedule()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            
            Form {
                // 选择计划类型
                Picker("Schedule Type".localized, selection: $selectedType) {
                    ForEach(ScheduleType.allCases) { type in
                        Text(type.localizedName).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.bottom, 10)
                
                // 选择时间（仅非 auto 模式显示）
                if selectedType != .auto {
                    HStack {
                        Text("Time".localized)
                            .textSelection(.enabled)
                        Spacer()
                        Picker("Hour".localized, selection: $hour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                        
                        Text(":")
                            .textSelection(.enabled)
                        
                        Picker("Minute".localized, selection: $minute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                    }
                }
                
                // 根据选择的类型显示不同的选项
                if selectedType == .weekly {
                    // 选择星期几
                    HStack {
                        Text("Day of Week".localized)
                            .textSelection(.enabled)
                        Spacer()
                        Picker("Day of Week".localized, selection: $dayOfWeek) {
                            Text("Sunday".localized).tag(1)
                            Text("Monday".localized).tag(2)
                            Text("Tuesday".localized).tag(3)
                            Text("Wednesday".localized).tag(4)
                            Text("Thursday".localized).tag(5)
                            Text("Friday".localized).tag(6)
                            Text("Saturday".localized).tag(7)
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                } else if selectedType == .monthly {
                    // 选择每月几号
                    HStack {
                        Text("Day of Month".localized)
                            .textSelection(.enabled)
                        Spacer()
                        Picker("Day of Month".localized, selection: $dayOfMonth) {
                            ForEach(1..<32, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                    }
                } else if selectedType == .auto {
                    // Auto模式下选择时间
                    HStack {
                        Text("Time".localized)
                            .textSelection(.enabled)
                        Spacer()
                        Picker("Hour".localized, selection: $hour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                        
                        Text(":")
                            .textSelection(.enabled)
                        
                        Picker("Minute".localized, selection: $minute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                    }
                }

            }
            .padding()
            
            // 显示当前设置的描述
            VStack(alignment: .leading) {
                Text("Schedule Summary".localized)
                    .font(.headline)
                    .padding(.bottom, 5)
                    .textSelection(.enabled)
                
                Text(scheduleDescription)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(width: 400, height: 500)
    }
    
    private var scheduleDescription: String {
        let timeString = String(format: "%02d:%02d", hour, minute)
        
        switch selectedType {
        case .daily:
            let format = NSLocalizedString("Print every day at %@", comment: "Daily schedule format")
            return String(format: format, timeString)
        case .weekly:
            let weekdayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let localizedWeekday = NSLocalizedString(weekdayNames[dayOfWeek], comment: "Day of week")
            let format = NSLocalizedString("Print every %@ at %@", comment: "Weekly schedule format")
            return String(format: format, localizedWeekday, timeString)
        case .monthly:
            let format = NSLocalizedString("Print on day %d of each month at %@", comment: "Monthly schedule format")
            return String(format: format, dayOfMonth, timeString)
        case .auto:
            // 基本描述
            if let fetcher = scheduleManager.appDelegate?.fetcher {
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
                    
                    result += ")\n"
                }
                
                return result
            }
            return NSLocalizedString("Smart print by humidity", comment: "Auto print schedule description")
        }
    }
    
    private func saveSchedule() {
        var newOption = ScheduleOption(
            type: selectedType,
            hour: hour,
            minute: minute
        )
        
        // 根据选择的类型设置相应的日期参数
        switch selectedType {
        case .daily:
            newOption.dayOfWeek = nil
            newOption.dayOfMonth = nil
        case .weekly:
            newOption.dayOfWeek = dayOfWeek
            newOption.dayOfMonth = nil
        case .monthly:
            newOption.dayOfWeek = nil
            newOption.dayOfMonth = dayOfMonth
        case .auto:
            newOption.dayOfWeek = nil
            newOption.dayOfMonth = nil
        }
        
        onSave(newOption)
    }
}

struct LogView: View {
    let logs: [PrintLog]
    @Environment(\.presentationMode) var presentationMode
    @State private var refreshView = UUID() // 用于强制刷新视图
    
    var body: some View {
        VStack {
            HStack {
                Text("Print Logs".localized)
                    .font(.headline)
                    .textSelection(.enabled)
                Spacer()
                Button("Close".localized) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            
            if logs.isEmpty {
                VStack {
                    Text("No logs yet".localized)
                        .foregroundColor(.gray)
                        .padding()
                        .textSelection(.enabled)
                    Text("Click the button to generate test data".localized)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .textSelection(.enabled)
                }
            } else {
                Text("Total %d log entries".localized(with: logs.count))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .textSelection(.enabled)
                
                List(logs) { log in
                    HStack {
                        Text(log.message)
                            .font(.headline)
                            .textSelection(.enabled)
                        Spacer()
                        Text("%@".localized(with: log.timestamp.formatted(.dateTime)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(minWidth: 300, minHeight: 400)
        .id(refreshView) // 使用 id 修饰符强制刷新视图
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshView = UUID() // 当语言变更时强制刷新视图
        }
    }
}

struct HelpView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var refreshView = UUID() // 用于强制刷新视图
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Help Title".localized)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider()
            
            ScrollView {
                Text("Help Content".localized)
                    .padding()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Version info line
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text(String(format: NSLocalizedString("About_Version", comment: ""), version))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
            Spacer()
            
            Button("Close".localized) {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .id(refreshView) // 使用 id 修饰符强制刷新视图
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshView = UUID() // 当语言变更时强制刷新视图
        }
    }
}
