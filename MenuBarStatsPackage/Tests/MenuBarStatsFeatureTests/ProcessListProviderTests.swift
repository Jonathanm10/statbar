import Foundation
import Testing
@testable import MenuBarStatsFeature

struct ProcessListProviderTests {
    @Test func parsesSingleProcessScanIntoCpuAndMemoryLists() {
        let subject = ProcessListProvider(commandRunner: StubCommandRunner(outputByArguments: [
            "-Aceo pid=,pcpu=,time=,rss=,comm=": """
            1 5.0 0:00.00 100 /usr/bin/low
            2 20.0 0:00.00 300 /Applications/High.app/Contents/MacOS/High
            3 10.0 0:00.00 500 /usr/bin/mid
            4 40.0 0:00.00 200 /usr/bin/top
            5 30.0 0:00.00 400 /usr/bin/five
            6 25.0 0:00.00 600 /usr/bin/six
            """
        ]))

        let rows = subject.topProcesses(limit: 5)

        #expect(rows.cpu.map { Int($0.pid) } == [4, 5, 6, 2, 3])
        #expect(rows.cpu.first?.name == "top")
        #expect(rows.memory.map { Int($0.pid) } == [6, 3, 5, 2, 4])
        #expect(rows.memory.first?.metric == .bytes(600 * 1024))
    }

    @Test func fallsBackToPidWhenProcessNameIsMissing() {
        let subject = ProcessListProvider(commandRunner: StubCommandRunner(outputByArguments: [
            "-Aceo pid=,pcpu=,time=,rss=,comm=": "99 1.5 0:00.00 42"
        ]))

        let rows = subject.topProcesses(limit: 5)

        #expect(rows.cpu == [ProcessRow(pid: 99, name: "PID 99", metric: .percent(1.5))])
        #expect(rows.memory == [ProcessRow(pid: 99, name: "PID 99", metric: .bytes(42 * 1024))])
    }

    @Test func prefersPrivilegedFetcherOverPSWhenAvailable() {
        let privileged = StubPrivilegedFetcher(result: ProcessLists(
            cpu: [ProcessRow(pid: 42, name: "fromHelper", metric: .percent(9.9))],
            memory: [ProcessRow(pid: 42, name: "fromHelper", metric: .bytes(4096))]
        ))
        let runner = StubCommandRunner(outputByArguments: [:])
        let subject = ProcessListProvider(commandRunner: runner, privilegedFetcher: privileged)

        let rows = subject.topProcesses(limit: 5)

        #expect(rows.cpu.first?.name == "fromHelper")
        #expect(privileged.callCount == 1)
        #expect(runner.callCount == 0)
    }

    @Test func fallsBackToPSWhenPrivilegedFetcherReturnsNil() {
        let privileged = StubPrivilegedFetcher(result: nil)
        let runner = StubCommandRunner(outputByArguments: [
            "-Aceo pid=,pcpu=,time=,rss=,comm=": "7 3.0 0:00.00 128 /usr/bin/fallback"
        ])
        let subject = ProcessListProvider(commandRunner: runner, privilegedFetcher: privileged)

        let rows = subject.topProcesses(limit: 5)

        #expect(rows.cpu.first?.name == "fallback")
        #expect(privileged.callCount == 1)
        #expect(runner.callCount == 1)
    }

    @Test func computesCpuPercentFromDeltaOnSubsequentSamples() {
        let runner = StubCommandRunner(outputByArguments: [:])
        var now: TimeInterval = 1000
        let subject = ProcessListProvider(
            commandRunner: runner,
            privilegedFetcher: nil,
            clock: { now }
        )

        runner.output = "42 5.0 0:10.00 128 /usr/bin/busy"
        _ = subject.topProcesses(limit: 5)

        now = 1002
        runner.output = "42 5.0 0:13.00 128 /usr/bin/busy"
        let rows = subject.topProcesses(limit: 5)

        #expect(rows.cpu.first?.metric == .percent(150.0))
    }

    @Test func parsesHoursMinutesSecondsCpuTime() {
        #expect(ProcessListProvider.parseCpuTime("1:02:03.50") == 3723.5)
        #expect(ProcessListProvider.parseCpuTime("5:30.25") == 330.25)
        #expect(ProcessListProvider.parseCpuTime("0:00.00") == 0)
    }
}

private final class StubCommandRunner: CommandRunning {
    var outputByArguments: [String: String]
    var output: String?
    private(set) var callCount = 0

    init(outputByArguments: [String: String]) {
        self.outputByArguments = outputByArguments
    }

    func run(executable: String, arguments: [String]) throws -> String {
        callCount += 1
        if let output {
            return output
        }
        return outputByArguments[arguments.joined(separator: " ")] ?? ""
    }
}

private final class StubPrivilegedFetcher: PrivilegedProcessListFetching {
    let result: ProcessLists?
    private(set) var callCount = 0

    init(result: ProcessLists?) {
        self.result = result
    }

    func fetchTopProcesses(limit: Int) -> ProcessLists? {
        callCount += 1
        return result
    }
}
