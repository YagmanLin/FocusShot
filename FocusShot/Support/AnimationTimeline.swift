import Foundation
import CoreGraphics

struct AnimationTimeline {
    let totalProgress: CGFloat
    let stepProgresses: [CGFloat]

    init(
        elapsed: TimeInterval,
        totalDuration: Double,
        stepCount: Int,
        independentAnimationEasing: Bool,
        easingCurve: AnimationEasingCurve
    ) {
        guard totalDuration > 0, stepCount > 0 else {
            self.totalProgress = 0
            self.stepProgresses = []
            return
        }

        let loopedElapsed = elapsed.truncatingRemainder(dividingBy: totalDuration)
        let progress = CGFloat(max(0, min(1, loopedElapsed / totalDuration)))
        self.totalProgress = progress
        self.stepProgresses = AnimationTimeline.progresses(
            totalProgress: progress,
            stepCount: stepCount,
            independentAnimationEasing: independentAnimationEasing,
            easingCurve: easingCurve
        )
    }

    init(
        totalProgress: CGFloat,
        stepCount: Int,
        independentAnimationEasing: Bool,
        easingCurve: AnimationEasingCurve
    ) {
        self.totalProgress = totalProgress
        self.stepProgresses = AnimationTimeline.progresses(
            totalProgress: totalProgress,
            stepCount: stepCount,
            independentAnimationEasing: independentAnimationEasing,
            easingCurve: easingCurve
        )
    }

    private static func progresses(
        totalProgress: CGFloat,
        stepCount: Int,
        independentAnimationEasing: Bool,
        easingCurve: AnimationEasingCurve
    ) -> [CGFloat] {
        guard stepCount > 0 else { return [] }

        let scaled = independentAnimationEasing
            ? totalProgress * CGFloat(stepCount)
            : easingCurve.value(at: totalProgress) * CGFloat(stepCount)

        return (0..<stepCount).map { index in
            let localRaw = min(max(scaled - CGFloat(index), 0), 1)
            return independentAnimationEasing ? easingCurve.value(at: localRaw) : localRaw
        }
    }
}
