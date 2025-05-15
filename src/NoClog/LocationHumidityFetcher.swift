import Foundation
import CoreLocation
import SwiftUI
import AppKit

@MainActor
class LocationHumidityFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// 保存最近30天湿度数据（含今天）
    @Published var fullHumidity: [Double] = []
    @Published var totalHumidity: Double = 0
    /// 保存当前城市位置信息
    @Published var currentLocation: String = ""
    /// 保存今天的湿度值
    @Published var todayHumidity: Double = 0
    @Published var nextPrintETA: Date?  // 下次打印的预期时间
    @Published var nextPrintETAString: String = ""
    
    private let manager = CLLocationManager()

    override init() {
        super.init()
        print("📍 初始化 LocationHumidityFetcher")

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer

        let status = manager.authorizationStatus
        print("📍 当前定位权限状态：\(status.rawValue)")

        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        print("📍 已调用 startUpdatingLocation()")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("✅ locationManager(_:didUpdateLocations:) 被调用")

        guard let loc = locations.last else {
            print("⚠️ 位置数组为空")
            return
        }

        manager.stopUpdatingLocation()
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        print("✅ 当前地理位置：\(lat), \(lon)")

        getCityFromLocation(lat: lat, lon: lon)
        fetchHumidityHistory(lat: lat, lon: lon)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 定位失败：\(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("🔁 权限变化，当前状态：\(manager.authorizationStatus.rawValue)")
    }
    
    /// 供外部调用的刷新湿度数据的函数
    /// 只更新湿度数据，不更新位置
    func refreshHumidityData() {
        print("🔄 手动刷新湿度数据")
        
        // 使用最后已知的位置直接获取湿度数据
        if let location = manager.location {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            print("🔄 使用当前位置刷新湿度：\(lat), \(lon)")
            
            // 只获取湿度数据，不获取城市信息
            fetchHumidityHistory(lat: lat, lon: lon)
        } else {
            print("⚠️ 无法获取位置信息，无法刷新湿度数据")
        }
    }
    
    func getCityFromLocation(lat: Double, lon: Double) {
        let location = CLLocation(latitude: lat, longitude: lon)
        let geocoder = CLGeocoder()

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("❌ 反向地理编码失败：\(error.localizedDescription)")
                return
            }

            if let placemark = placemarks?.first {
                let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea
                let country = placemark.country ?? ""
                let result = [city, country].compactMap { $0 }.joined(separator: ", ")
                print("🏙 当前所在城市：\(result)")
                
                // 保存到类变量
                Task { @MainActor in
                    self.currentLocation = result
                }
            } else {
                print("⚠️ 未找到地址信息")
            }
        }
    }
    
    func fetchHumidityHistory(lat: Double, lon: Double) {
        fetchTodayHumidity(lat: lat, lon: lon) { todayHumidity in
            guard let todayHumidity = todayHumidity else {
                print("❌ 无法获取今天湿度")
                return
            }

            self.fetchHistoricalHumidity(lat: lat, lon: lon) { humidities in
                guard let historical = humidities else {
                    print("❌ 无法获取历史湿度")
                    return
                }

                // 构造最终数组：T-30 到 T
                // historical 为 T-30 到 T-2，共 29 天
                // 昨天(T-1)用 todayHumidity 替代
                var humidityArray: [Double] = historical
                humidityArray.append(todayHumidity)  // T-1
                humidityArray.append(todayHumidity)  // T

                // 保存到类变量
                Task { @MainActor in
                    self.fullHumidity = Array(humidityArray.suffix(30))
                    self.todayHumidity = todayHumidity
                    self.nextPrintETA = self.calculateNextPrintETA()
                    // 保留月和日的部分，并添加用户配置的时间
                    if let date = self.nextPrintETA {
                        // 从 UserDefaults 中获取用户配置的时间
                        let scheduleOptionKey = "ScheduleOption"
                        var hour = 0
                        var minute = 0
                        
                        if let savedOptionData = UserDefaults.standard.data(forKey: scheduleOptionKey),
                           let savedOption = try? JSONDecoder().decode(ScheduleOption.self, from: savedOptionData) {
                            hour = savedOption.hour
                            minute = savedOption.minute
                        }
                        
                        // 格式化日期，显示月-日 时:分
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MM-dd" // 月和日
                        let dateString = formatter.string(from: date)
                        
                        // 添加用户配置的时间
                        self.nextPrintETAString = String(format: "%@ %02d:%02d", dateString, hour, minute)
                    } else {
                        self.nextPrintETAString = ""
                    }
                }

                print("✅ 最终30天湿度（含今天）：")
                for (i, h) in humidityArray.suffix(30).enumerated() {
                    print("Day \(i - 29): \(h)%")
                }
            }
        }
    }
    
    /// 计算下次打印的预期时间
    /// - Returns: 预计的下次打印日期
    private func calculateNextPrintETA() -> Date? {
        // 创建湿度曲线计算器
        let humidityCurve = HumidityCurve()
        var total = 0.0
        
        // 检查湿度数据是否存在
        guard !fullHumidity.isEmpty else {
            print("没有湿度数据可用，无法计算下次打印时间")
            return nil
        }
        
        // 获取上次打印的时间
        let calendar = Calendar.current
        let now = Date()
        
        // 尝试从 UserDefaults 中获取上次打印时间
        let lastPrintDateKey = "LastSuccessfulPrintDate"
        var lastPrintDate: Date
        if let savedDate = UserDefaults.standard.object(forKey: lastPrintDateKey) as? Date {
            // 如果有保存的打印时间，使用它
            lastPrintDate = savedDate
            print("从 UserDefaults 找到上次打印时间：\(lastPrintDate)")
        } else {
            // 如果没有找到打印时间，则假设是昨天
            lastPrintDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            print("未找到打印时间记录，假设上次打印是昨天：\(lastPrintDate)")
        }
        
        print("使用的最近一次打印时间：\(lastPrintDate)")
        
        // 计算自上次打印以来的天数
        let components = calendar.dateComponents([.day], from: lastPrintDate, to: now)
        
        guard let daysSinceLastPrint = components.day, daysSinceLastPrint > 0 else {
            print("计算自上次打印以来的天数出错或小于一天")
            return calendar.date(byAdding: .day, value: 1, to: now)
        }
        
        print("自上次打印以来的天数：\(daysSinceLastPrint)")
        
        // 获取自上次打印以来的湿度数据（不包含打印日当天，但包含今天）
        var dayHumidity: [Double] = []
        
        // fullHumidity 数组中，最后一个值代表今天，倒数第二个表示昨天，依次类推
        let count = fullHumidity.count
        for i in 0..<min(daysSinceLastPrint, count) {
            // 从数组的末尾开始读取，最后一个元素是今天
            let index = count - 1 - i
            if index >= 0 {
                dayHumidity.append(fullHumidity[index])
                print("第 -\(i) 天: 添加湿度 \(fullHumidity[index])%")
            }
        }
        
        print("收集到 \(dayHumidity.count) 天的湿度数据")
        
        // 遍历每天的湿度数据，计算打印间隔
        for (index, humidity) in dayHumidity.enumerated() {
            let interval = humidityCurve.computePrintInterval(humidity: humidity)
            print("第 -\(index) 天: 湿度 \(humidity)%, 间隔 \(interval) 天")
            total += 1/interval
        }
        
        print("累积打印间隔：\(total) 天")
        
        // 如果累积的打印间隔超过或等于 1 天，则返回今天
        if total >= 1.0 {
            return now
        }
        
        // 如果累积的打印间隔小于 1 天，则预测未来的打印日期
        // 假设未来每天的湿度都跟今天一样
        let todayHumidity = fullHumidity.last ?? 50.0 // 默认值 50%
        let dailyInterval = humidityCurve.computePrintInterval(humidity: todayHumidity)
        let dailyContribution = 1.0 / dailyInterval
        
        // 计算还需要多少天才能达到打印条件
        let remainingContribution = 1.0 - total
        let daysNeeded = ceil(remainingContribution / dailyContribution)
        
        print("今天湿度 \(todayHumidity)%, 每天贡献 \(dailyContribution), 还需 \(daysNeeded) 天")
        
        // 计算预期打印日期
        return calendar.date(byAdding: .day, value: Int(daysNeeded), to: now)
    }

        private func fetchTodayHumidity(lat: Double, lon: Double, completion: @escaping (Double?) -> Void) {
            let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=relative_humidity_2m&timezone=auto"
            print("🌡️ 获取今天湿度 URL: \(urlStr)")
            
            guard let url = URL(string: urlStr) else {
                print("❌ 今天湿度 URL 构建失败")
                completion(nil)
                return
            }

            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("❌ 获取今天湿度失败: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 今天湿度请求状态码: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("⚠️ 今天湿度无返回数据")
                    completion(nil)
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("⚠️ 今天湿度 JSON 解析失败")
                        completion(nil)
                        return
                    }
                    
                    guard let current = json["current"] as? [String: Any] else {
                        print("⚠️ 今天湿度缺少 'current' 字段")
                        completion(nil)
                        return
                    }
                    
                    guard let humidity = current["relative_humidity_2m"] as? Double else {
                        print("⚠️ 今天湿度缺少 'relative_humidity_2m' 字段")
                        completion(nil)
                        return
                    }
                    
                    print("✅ 成功获取今天湿度: \(humidity)%")
                    
                    // 在主线程上更新 UI 相关的变量
                    DispatchQueue.main.async {
                        Task { @MainActor in
                            self.todayHumidity = humidity
                        }
                    }
                    completion(humidity)
                } catch {
                    print("❌ 今天湿度 JSON 解析错误: \(error)")
                    completion(nil)
                }
            }.resume()
        }

        private func fetchHistoricalHumidity(lat: Double, lon: Double, completion: @escaping ([Double]?) -> Void) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = Date()
            guard let start = Calendar.current.date(byAdding: .day, value: -30, to: today),
                  let end = Calendar.current.date(byAdding: .day, value: -2, to: today) else {
                print("❌ 无法计算历史湿度的日期范围")
                completion(nil)
                return
            }

            let startStr = formatter.string(from: start)
            let endStr = formatter.string(from: end)
            print("📅 历史湿度请求日期范围: \(startStr) 到 \(endStr)")

            let urlStr = "https://archive-api.open-meteo.com/v1/archive?latitude=\(lat)&longitude=\(lon)&start_date=\(startStr)&end_date=\(endStr)&daily=relative_humidity_2m_mean&timezone=auto"
            print("🌡️ 获取历史湿度 URL: \(urlStr)")
            
            guard let url = URL(string: urlStr) else {
                print("❌ 历史湿度 URL 构建失败")
                completion(nil)
                return
            }

            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("❌ 获取历史湿度失败: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 历史湿度请求状态码: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("⚠️ 历史湿度无返回数据")
                    completion(nil)
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("⚠️ 历史湿度 JSON 解析失败")
                        completion(nil)
                        return
                    }
                    
                    // 检查是否有错误信息
                    if let error = json["error"] as? Bool, error == true, let reason = json["reason"] as? String {
                        print("❌ 历史湿度 API 错误: \(reason)")
                        completion(nil)
                        return
                    }
                    
                    guard let daily = json["daily"] as? [String: Any] else {
                        print("⚠️ 历史湿度缺少 'daily' 字段")
                        completion(nil)
                        return
                    }
                    
                    guard let values = daily["relative_humidity_2m_mean"] as? [Double] else {
                        print("⚠️ 历史湿度缺少 'relative_humidity_2m_mean' 字段")
                        completion(nil)
                        return
                    }
                    
                    // 检查数据完整性
                    let expectedDays = Calendar.current.dateComponents([.day], from: start, to: end).day! + 1
                    
                    // 检查数组长度
                    if values.count < expectedDays {
                        print("⚠️ 历史湿度数据不完整: 需要 \(expectedDays) 天数据，但只获取到 \(values.count) 天")
                    } else {
                        print("✅ 成功获取历史湿度数据: \(values.count) 天")
                    }
                    
                    // 检查异常值（空值或无效值）
                    // 在 API 返回中，空值可能表现为极端值或特殊值
                    let abnormalValues = values.filter { $0 < 0 || $0 > 100 || $0.isNaN || !$0.isFinite }
                    let abnormalCount = abnormalValues.count
                    
                    if abnormalCount > 0 {
                        print("⚠️ 历史湿度数据中有 \(abnormalCount) 天的数据异常")
                        
                        // 打印异常值的具体位置和值
                        if let dates = daily["time"] as? [String] {
                            for (index, value) in values.enumerated() {
                                if (value < 0 || value > 100 || value.isNaN || !value.isFinite) && index < dates.count {
                                    print("  - \(dates[index]): 异常值 \(value)")
                                }
                            }
                        }
                    }
                    
                    // 检查是否有湿度值为 0 的情况（可能是缺失数据的替代值）
                    let zeroValues = values.filter { $0 == 0 }
                    if !zeroValues.isEmpty {
                        print("⚠️ 历史湿度数据中有 \(zeroValues.count) 天的湿度值为 0%，可能是缺失数据")
                        
                        // 打印值为 0 的具体日期
                        if let dates = daily["time"] as? [String] {
                            for (index, value) in values.enumerated() {
                                if value == 0 && index < dates.count {
                                    print("  - \(dates[index]): 湿度值为 0%")
                                }
                            }
                        }
                    }
                    
                    // 打印所有湿度值的范围
                    if !values.isEmpty {
                        let minHumidity = values.min()!
                        let maxHumidity = values.max()!
                        let avgHumidity = values.reduce(0, +) / Double(values.count)
                        print("📈 历史湿度范围: 最小 \(minHumidity)%, 最大 \(maxHumidity)%, 平均 \(avgHumidity)%")
                    }
                    
                    completion(values)
                } catch {
                    print("❌ 历史湿度 JSON 解析错误: \(error)")
                    completion(nil)
                }
            }.resume()
        }

    private func fetchHumidity(lat: Double, lon: Double) {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=relative_humidity_2m"
        guard let url = URL(string: urlStr) else {
            print("❌ URL 构建失败")
            return
        }

        print("🌐 请求天气：\(urlStr)")
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("❌ 获取天气失败：\(error.localizedDescription)")
                return
            }
            guard let data = data else {
                print("⚠️ 无返回数据")
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["current"] as? [String: Any],
                   let humidity = current["relative_humidity_2m"] as? Double {
                    print("🌦 当前湿度：\(humidity)%")
                } else {
                    print("⚠️ 解析失败")
                }
            } catch {
                print("❌ JSON解析错误：\(error)")
            }
        }.resume()
    }
}
