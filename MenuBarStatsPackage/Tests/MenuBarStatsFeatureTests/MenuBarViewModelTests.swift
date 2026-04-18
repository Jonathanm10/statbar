import Testing
@testable import MenuBarStatsFeature

struct MenuBarViewModelTests {
    @MainActor
    @Test func loadingAndEmptyStatesAreExposedForTheView() {
        let subject = MenuBarViewModel()

        subject.apply(summary: HostSummarySnapshot(cpuUsage: .loading, memoryUsage: nil))
        subject.apply(diskUsage: nil)
        subject.apply(cpuProcesses: [], memoryProcesses: [])

        #expect(subject.cpuDisplayText == "Loading…")
        #expect(subject.memoryDisplayText == "Unavailable")
        #expect(subject.diskDisplayText == "Unavailable")
        #expect(subject.topCPUProcesses.isEmpty)
        #expect(subject.topMemoryProcesses.isEmpty)
    }

    @MainActor
    @Test func applyingSettingsFiltersVisibleContent() {
        let subject = MenuBarViewModel()
        subject.apply(cpuProcesses: [
            ProcessRow(pid: 1, name: "One", metric: .percent(1)),
            ProcessRow(pid: 2, name: "Two", metric: .percent(2)),
            ProcessRow(pid: 3, name: "Three", metric: .percent(3)),
            ProcessRow(pid: 4, name: "Four", metric: .percent(4))
        ], memoryProcesses: [])

        subject.apply(settings: FeatureSettings(
            refreshPreset: .balanced,
            menuBarDisplayFormat: .cpuPercent,
            processCount: .three,
            showsPID: false,
            showsDiskStats: false
        ))

        #expect(subject.visibleCPUProcesses.count == 3)
        #expect(subject.settings.showsPID == false)
        #expect(subject.settings.showsDiskStats == false)
    }

    @MainActor
    @Test func processCountOptionsAreAppliedForThreeFiveAndTen() {
        let subject = MenuBarViewModel()
        let rows = (1...10).map { value in
            ProcessRow(pid: Int32(value), name: "P\(value)", metric: .percent(Double(value)))
        }
        subject.apply(cpuProcesses: rows, memoryProcesses: rows)

        var settings = FeatureSettings.default
        settings.processCount = .three
        subject.apply(settings: settings)
        #expect(subject.visibleCPUProcesses.count == 3)

        settings.processCount = .five
        subject.apply(settings: settings)
        #expect(subject.visibleCPUProcesses.count == 5)

        settings.processCount = .ten
        subject.apply(settings: settings)
        #expect(subject.visibleCPUProcesses.count == 10)
    }

    @MainActor
    @Test func pidVisibilityFollowsSettingsToggle() {
        let subject = MenuBarViewModel()
        var settings = FeatureSettings.default
        settings.showsPID = false
        subject.apply(settings: settings)
        #expect(subject.showsPID == false)

        settings.showsPID = true
        subject.apply(settings: settings)
        #expect(subject.showsPID == true)
    }

    @MainActor
    @Test func diskSectionVisibilityFollowsSettingsToggle() {
        let subject = MenuBarViewModel()
        var settings = FeatureSettings.default
        settings.showsDiskStats = false
        subject.apply(settings: settings)
        #expect(subject.showsDiskSection == false)

        settings.showsDiskStats = true
        subject.apply(settings: settings)
        #expect(subject.showsDiskSection == true)
    }
}
