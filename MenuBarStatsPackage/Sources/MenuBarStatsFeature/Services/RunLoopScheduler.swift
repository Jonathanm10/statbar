import Foundation

public protocol ScheduledTask {
    func cancel()
}

public protocol RepeatingScheduling {
    @discardableResult
    func scheduleRepeating(every interval: TimeInterval, action: @escaping @Sendable () -> Void) -> ScheduledTask
}

public final class RunLoopScheduler: RepeatingScheduling {
    public init() {}

    @discardableResult
    public func scheduleRepeating(every interval: TimeInterval, action: @escaping @Sendable () -> Void) -> ScheduledTask {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            action()
        }
        return TimerScheduledTask(timer: timer)
    }
}

private final class TimerScheduledTask: ScheduledTask {
    private var timer: Timer?

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
