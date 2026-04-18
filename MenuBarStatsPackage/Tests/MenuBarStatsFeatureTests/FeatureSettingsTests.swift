import Testing
@testable import MenuBarStatsFeature

struct FeatureSettingsTests {
    @Test func refreshPresetMappingsMatchPhaseFiveContract() {
        let light = RefreshPreset.light.samplingConfiguration(processCount: 3)
        #expect(light.closedSummaryInterval == 6)
        #expect(light.openSummaryInterval == 4)
        #expect(light.openProcessInterval == 4)
        #expect(light.diskRefreshInterval == 60)
        #expect(light.topProcessCount == 3)

        let balanced = RefreshPreset.balanced.samplingConfiguration(processCount: 5)
        #expect(balanced.closedSummaryInterval == 3)
        #expect(balanced.openSummaryInterval == 2)
        #expect(balanced.openProcessInterval == 2)
        #expect(balanced.diskRefreshInterval == 30)

        let frequent = RefreshPreset.frequent.samplingConfiguration(processCount: 10)
        #expect(frequent.closedSummaryInterval == 2)
        #expect(frequent.openSummaryInterval == 1)
        #expect(frequent.openProcessInterval == 1)
        #expect(frequent.diskRefreshInterval == 15)
    }

    @Test func statusItemFormattingMatchesDisplayFormats() {
        #expect(StatsFormatting.statusItemText(cpuUsage: .value(12.3), memoryUsage: nil, format: .iconOnly) == nil)
        #expect(StatsFormatting.statusItemText(cpuUsage: .value(12.3), memoryUsage: nil, format: .cpuPercent) == "12.3%")
        let combined = StatsFormatting.statusItemText(cpuUsage: .value(12.3), memoryUsage: UsageSnapshot(usedBytes: 1024, totalBytes: 2048), format: .cpuAndMemory)
        #expect(combined?.contains("CPU 12%") == true)
        #expect(combined?.contains("MEM") == true)
    }
}
