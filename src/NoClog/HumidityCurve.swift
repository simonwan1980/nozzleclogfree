import Foundation

/// 湿度-打印间隔曲线工具
public class HumidityCurve {
    /// 控制点 [(湿度%, 打印间隔天数)]，可根据需要修改
    public let controlPoints: [(humidity: Double, interval: Double)] = [
        (5, 1),
        (30, 3),
        (60, 7),
        (70, 8),
        (80, 9),
        (90, 14),
        (99, 30)
    ]
    
    /// 计算给定湿度下的打印间隔（天），使用分段线性插值
    /// - Parameter humidity: 湿度（0~100）
    /// - Returns: 打印间隔（天）
    public func computePrintInterval(humidity: Double) -> Double {
        // 限制湿度在控制点范围内
        let clampedHumidity = min(max(humidity, controlPoints.first!.humidity), controlPoints.last!.humidity)
        // 查找区间
        for i in 0..<(controlPoints.count - 1) {
            let (h0, d0) = controlPoints[i]
            let (h1, d1) = controlPoints[i + 1]
            if clampedHumidity >= h0 && clampedHumidity <= h1 {
                // 线性插值
                let t = (clampedHumidity - h0) / (h1 - h0)
                return d0 + t * (d1 - d0)
            }
        }
        // 理论上不会到这里，兜底返回最大间隔
        return controlPoints.last!.interval
    }
}

