import Testing
@testable import MenuBarStatsFeature

struct FormattingTests {
    @Test func formatsPercentagesAndLoadingState() {
        #expect(StatsFormatting.cpuUsageText(for: .loading) == "Loading…")
        #expect(StatsFormatting.cpuUsageText(for: .value(12.34)) == "12.3%")
    }

    @Test func formatsUsageSnapshot() {
        let text = StatsFormatting.usageText(for: UsageSnapshot(usedBytes: 512 * 1024 * 1024, totalBytes: 1024 * 1024 * 1024))
        #expect(text.contains("/"))
        #expect(text.contains("50.0%"))
    }
}
