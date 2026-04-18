import Foundation
import MenuBarStatsFeature

/// Thin XPC client that talks to the root `com.statbar.MenuBarStats.helper` daemon.
///
/// Connects lazily on first use and keeps the connection alive for the app's lifetime. Every
/// request runs on a background queue with a short semaphore timeout so a missing or
/// unresponsive helper never blocks the UI — callers just see `nil` and fall back to `ps`.
final class HelperXPCClient: PrivilegedProcessListFetching {
    private let replyTimeout: TimeInterval
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    /// 200 ms is well above the helper's typical 5–30 ms round-trip. If the helper is missing
    /// or stuck we cap the UI-thread wait here and let the caller fall back to `ps`.
    init(replyTimeout: TimeInterval = 0.2) {
        self.replyTimeout = replyTimeout
    }

    func fetchTopProcesses(limit: Int) -> ProcessLists? {
        guard limit > 0 else { return ProcessLists(cpu: [], memory: []) }

        let proxy = obtainProxy { _ in }
        guard let proxy else { return nil }

        let semaphore = DispatchSemaphore(value: 0)
        var payloadData: Data?

        proxy.topProcesses(limit: Int32(clamping: limit)) { data in
            payloadData = data
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + replyTimeout) == .success,
              let data = payloadData,
              let payload = try? JSONDecoder().decode(TopProcessesPayload.self, from: data)
        else {
            return nil
        }

        return ProcessLists(
            cpu: payload.cpu.map(Self.cpuRow),
            memory: payload.memory.map(Self.memoryRow)
        )
    }

    // MARK: - Connection management

    private func obtainProxy(
        errorHandler: @escaping (Error) -> Void
    ) -> ProcessInfoHelperProtocol? {
        lock.lock()
        if connection == nil {
            let new = NSXPCConnection(machServiceName: HelperService.machServiceName)
            new.remoteObjectInterface = NSXPCInterface(with: ProcessInfoHelperProtocol.self)
            new.invalidationHandler = { [weak self] in self?.resetConnection() }
            new.interruptionHandler = { [weak self] in self?.resetConnection() }
            new.resume()
            connection = new
        }
        let current = connection
        lock.unlock()

        guard let current else { return nil }
        return current.remoteObjectProxyWithErrorHandler { error in
            errorHandler(error)
        } as? ProcessInfoHelperProtocol
    }

    private func resetConnection() {
        lock.lock()
        connection?.invalidate()
        connection = nil
        lock.unlock()
    }

    // MARK: - Wire mapping

    private static func cpuRow(_ row: WireProcessRow) -> ProcessRow {
        ProcessRow(pid: row.pid, name: row.name, metric: .percent(row.cpuPercent))
    }

    private static func memoryRow(_ row: WireProcessRow) -> ProcessRow {
        ProcessRow(pid: row.pid, name: row.name, metric: .bytes(row.memoryBytes))
    }
}
