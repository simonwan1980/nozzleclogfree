import Foundation
import AppKit
import PDFKit
import UniformTypeIdentifiers

@MainActor
class PrinterManager: ObservableObject {
    @Published var selectedPrinter: String?
    @Published var availablePrinters: [String] = []
    @Published var customPDFPath: String?
    
    private let customPDFPathKey = "CustomPDFPath"
    private let printInfoKey = "SavedPrintInfo"
    
    init() {
        updatePrinterList()
        loadCustomPDFPath()
    }
    
    func updatePrinterList() {
        print("开始更新打印机列表...")
        
        // 获取默认打印机
        let defaultPrinter = NSPrintInfo.shared.printer
        print("系统默认打印机: \(defaultPrinter.name)")
        
        // 获取所有打印机
        availablePrinters = NSPrinter.printerNames
        print("找到的打印机列表: \(availablePrinters)")
        
        // 自动查找Epson打印机
        if let epsonPrinter = availablePrinters.first(where: { $0.lowercased().contains("epson") }) {
            print("找到 Epson 打印机: \(epsonPrinter)")
            selectedPrinter = epsonPrinter
        } else {
            print("未找到 Epson 打印机")
            
            // 如果没有找到 Epson 打印机，使用第一个可用的打印机
            if let firstPrinter = availablePrinters.first {
                print("使用第一个可用的打印机: \(firstPrinter)")
                selectedPrinter = firstPrinter
            }
        }
    }
    
    // 获取要打印的 PDF 文档
    private func getPDFDocument() -> PDFDocument? {
        if let customPath = customPDFPath, !customPath.isEmpty {
            // 使用用户选择的 PDF 文件
            if let pdfDocument = PDFDocument(url: URL(fileURLWithPath: customPath)) {
                return pdfDocument
            } else {
                // 如果用户选择的文件无法加载，回退到默认测试页
                guard let pdfUrl = Bundle.main.url(forResource: "testpage", withExtension: "pdf") else {
                    print("无法找到测试页PDF文件")
                    return nil
                }
                return PDFDocument(url: pdfUrl)
            }
        } else {
            // 使用应用内置的测试页
            guard let pdfUrl = Bundle.main.url(forResource: "testpage", withExtension: "pdf") else {
                print("无法找到测试页PDF文件")
                return nil
            }
            return PDFDocument(url: pdfUrl)
        }
    }
    
    // 打印相关错误类型
    enum PrintError: Error {
        case noPrinterSelected
        case pdfLoadFailed
        case printOperationFailed(String)
    }

    // 打印测试页，返回详细错误
    /// 打印测试页，返回 (结果, 文件名)
    func printTestPage() -> (Result<Void, PrintError>, String) {
        // 判断打印文件名
        var fileName = "default file"
        if let customPath = customPDFPath, !customPath.isEmpty {
            fileName = (customPath as NSString).lastPathComponent
        }
        guard let printerName = selectedPrinter else {
            print(NSLocalizedString("printer_error_no_printer_selected", comment: ""))
            return (.failure(.noPrinterSelected), fileName)
        }
        // 获取 PDF 文档
        guard let pdfDocument = getPDFDocument() else {
            print(NSLocalizedString("printer_error_pdf_load_failed", comment: ""))
            return (.failure(.pdfLoadFailed), fileName)
        }
        // 创建 PDF 视图并配置
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.backgroundColor = .clear
        pdfView.displaysPageBreaks = false
        pdfView.wantsLayer = true
        pdfView.layer?.borderWidth = 0
        pdfView.layer?.borderColor = NSColor.clear.cgColor
        pdfView.frame = NSRect(x: 0, y: 0, width: 612, height: 792)  // 标准A4尺寸
        // 检查是否有保存的打印设置
        if let savedPrintInfo = loadSavedPrintInfo() {
            // 使用保存的打印设置
            if let printer = NSPrinter(name: printerName) {
                savedPrintInfo.printer = printer
            }
            let printOperation = NSPrintOperation(view: pdfView, printInfo: savedPrintInfo)
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = true
            let success = printOperation.run()
            if success {
                print(NSLocalizedString("printer_operation_success", comment: ""))
                return (.success(()), fileName)
            } else {
                let reason = NSLocalizedString("printer_operation_failed_unknown", comment: "")
                print(String(format: NSLocalizedString("printer_error_print_operation_failed", comment: ""), reason))
                return (.failure(.printOperationFailed(reason)), fileName)
            }
        } else {
            // 使用默认打印设置
            let printInfo = NSPrintInfo.shared
            if let printer = NSPrinter(name: printerName) {
                printInfo.printer = printer
            }
            
            // 设置打印选项
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .fit
            printInfo.orientation = .portrait
            printInfo.isHorizontallyCentered = true
            printInfo.isVerticallyCentered = true
            printInfo.topMargin = 0
            printInfo.bottomMargin = 0
            printInfo.leftMargin = 0
            printInfo.rightMargin = 0
            
            // 创建打印操作
            let printOperation = NSPrintOperation(view: pdfView, printInfo: printInfo)
            printOperation.canSpawnSeparateThread = true
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = true
            let success = printOperation.run()
            if success {
                print(NSLocalizedString("printer_operation_success", comment: ""))
                return (.success(()), fileName)
            } else {
                let reason = NSLocalizedString("printer_operation_failed_unknown", comment: "")
                print(String(format: NSLocalizedString("printer_error_print_operation_failed", comment: ""), reason))
                return (.failure(.printOperationFailed(reason)), fileName)
            }
        }
    }
    
    // 选择自定义 PDF 文件
    func selectCustomPDF() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select PDF File".localized
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [UTType.pdf]
        
        openPanel.beginSheetModal(for: NSApp.keyWindow!) { response in
            if response == .OK, let url = openPanel.url {
                self.customPDFPath = url.path
                self.saveCustomPDFPath()
            }
        }
    }
    
    // 清除自定义 PDF 文件
    func clearCustomPDF() {
        customPDFPath = nil
        saveCustomPDFPath()
    }
    
    // 保存自定义 PDF 路径
    private func saveCustomPDFPath() {
        UserDefaults.standard.set(customPDFPath, forKey: customPDFPathKey)
    }
    
    // 加载自定义 PDF 路径
    private func loadCustomPDFPath() {
        customPDFPath = UserDefaults.standard.string(forKey: customPDFPathKey)
    }
    
    // 显示打印设置
    func showPrintSettings() {
        // 如果有保存的打印设置，先应用到共享打印信息
        if let savedPrintInfo = getUserPrintInfo() {
            NSPrintInfo.shared = savedPrintInfo
        }
        
        // 创建页面设置对话框
        let pageLayout = NSPageLayout()
        
        // 显示页面设置对话框
        if pageLayout.runModal() == NSApplication.ModalResponse.OK.rawValue {
            // 保存当前的共享打印设置
            NSPrintInfo.shared.horizontalPagination = .fit
            NSPrintInfo.shared.verticalPagination = .fit
            savePrintInfo(NSPrintInfo.shared)
            print("✅ 打印设置已保存")
        }
    }
    
    /*
    // 执行实际打印
    private func executePrint() {
        guard let printerName = selectedPrinter else { return }
        
        // 获取 PDF 文档
        guard let pdfDocument = getPDFDocument() else {
            print("无法加载 PDF 文件进行打印")
            return
        }
        
        // 创建 PDF 视图并配置
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.backgroundColor = .clear
        pdfView.displaysPageBreaks = false
        pdfView.wantsLayer = true
        pdfView.layer?.borderWidth = 0
        pdfView.layer?.borderColor = NSColor.clear.cgColor
        pdfView.frame = NSRect(x: 0, y: 0, width: 612, height: 792)  // 标准A4尺寸
        
        // 检查是否有保存的打印设置
        if let savedPrintInfo = loadSavedPrintInfo() {
            // 使用保存的打印设置
            if let printer = NSPrinter(name: printerName) {
                savedPrintInfo.printer = printer
            }
            
            let printOperation = NSPrintOperation(view: pdfView, printInfo: savedPrintInfo)
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = true
            
            let success = printOperation.run()
            if success {
                print(NSLocalizedString("printer_operation_success", comment: ""))
            } else {
                let reason = NSLocalizedString("printer_operation_failed_unknown", comment: "")
                print(String(format: NSLocalizedString("printer_error_print_operation_failed", comment: ""), reason))
            }
        } else {
            // 使用默认打印设置
            let printInfo = NSPrintInfo.shared
            if let printer = NSPrinter(name: printerName) {
                printInfo.printer = printer
            }
            
            // 设置打印选项
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .fit
            printInfo.orientation = .portrait
            printInfo.isHorizontallyCentered = true
            printInfo.isVerticallyCentered = true
            printInfo.topMargin = 0
            printInfo.bottomMargin = 0
            printInfo.leftMargin = 0
            printInfo.rightMargin = 0
            
            // 创建打印操作
            let printOperation = NSPrintOperation(view: pdfView, printInfo: printInfo)
            printOperation.canSpawnSeparateThread = true
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = false
            
            printOperation.run()
        }
        // 默认成功（理论上不应到达此处）
        return (.success(()), fileName)
    }
    }
    */
    
    // 保存打印设置
    private func savePrintInfo(_ printInfo: NSPrintInfo) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: printInfo, requiringSecureCoding: false)
            UserDefaults.standard.set(data, forKey: printInfoKey)
            print("✅ 打印设置已保存")
        } catch {
            print("❌ 无法保存打印设置: \(error)")
        }
    }
    
    // 加载保存的打印设置
    private func loadSavedPrintInfo() -> NSPrintInfo? {
        guard let data = UserDefaults.standard.data(forKey: printInfoKey) else {
            return nil
        }
        
        do {
            if let savedPrintInfo = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSPrintInfo.self, from: data) {
                return savedPrintInfo
            }
        } catch {
            print("❌ 加载打印设置失败: \(error)")
        }
        
        return nil
    }
    
    // 获取用户打印设置
    private func getUserPrintInfo() -> NSPrintInfo? {
        guard let data = UserDefaults.standard.data(forKey: printInfoKey) else {
            return nil
        }
        
        do {
            if let savedPrintInfo = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSPrintInfo.self, from: data) {
                return savedPrintInfo
            }
        } catch {
            print("❌ 加载打印设置失败: \(error)")
        }
        
        return nil
    }
}

// 扩展 NSView 以支持动态调用方法
extension NSView {
    @objc func performAction(_ sender: NSButton) {
        if let selector = objc_getAssociatedObject(sender, "actionSelector") as? Selector,
           let target = self.window?.windowController?.document?.owner ?? NSApp.delegate {
            _ = target.perform(selector, with: sender)
        }
    }
}

// 添加通知名称
extension Notification.Name {
    static let pdfFileNotFound = Notification.Name("pdfFileNotFound")
}
