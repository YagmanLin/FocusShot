import CoreGraphics
import Foundation

struct AnimationEasingCurve: Codable, Equatable {
    var controlPoint1X: CGFloat
    var controlPoint1Y: CGFloat
    var controlPoint2X: CGFloat
    var controlPoint2Y: CGFloat

    static let `default` = AnimationEasingCurve(
        controlPoint1X: 0.42,
        controlPoint1Y: 0.0,
        controlPoint2X: 0.58,
        controlPoint2Y: 1.0
    )

    func value(at time: CGFloat) -> CGFloat {
        let x = min(max(time, 0), 1)
        guard x > 0, x < 1 else { return x }

        let solvedT = solveCurveX(x)
        let y = sampleCurveY(solvedT)
        return min(max(y, 0), 1)
    }

    private func sampleCurveX(_ t: CGFloat) -> CGFloat {
        let invT = 1 - t
        return 3 * invT * invT * t * controlPoint1X
            + 3 * invT * t * t * controlPoint2X
            + t * t * t
    }

    private func sampleCurveY(_ t: CGFloat) -> CGFloat {
        let invT = 1 - t
        return 3 * invT * invT * t * controlPoint1Y
            + 3 * invT * t * t * controlPoint2Y
            + t * t * t
    }

    private func sampleCurveDerivativeX(_ t: CGFloat) -> CGFloat {
        let invT = 1 - t
        return 3 * invT * invT * controlPoint1X
            + 6 * invT * t * (controlPoint2X - controlPoint1X)
            + 3 * t * t * (1 - controlPoint2X)
    }

    private func solveCurveX(_ x: CGFloat) -> CGFloat {
        var t = x
        for _ in 0..<8 {
            let xEstimate = sampleCurveX(t) - x
            if abs(xEstimate) < 0.0001 {
                return t
            }

            let derivative = sampleCurveDerivativeX(t)
            if abs(derivative) < 0.0001 {
                break
            }

            t -= xEstimate / derivative
        }

        var lower: CGFloat = 0
        var upper: CGFloat = 1
        t = x

        while lower < upper {
            let xEstimate = sampleCurveX(t)
            if abs(xEstimate - x) < 0.0001 {
                return t
            }
            if x > xEstimate {
                lower = t
            } else {
                upper = t
            }
            t = (upper - lower) * 0.5 + lower
            if abs(upper - lower) < 0.0001 {
                return t
            }
        }

        return t
    }
}
