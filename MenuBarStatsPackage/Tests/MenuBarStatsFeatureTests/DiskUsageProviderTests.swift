import Foundation
import Testing
@testable import MenuBarStatsFeature

struct DiskUsageProviderTests {
    @Test func mapsFileSystemAttributesToUsedAndTotalBytes() {
        let subject = DiskUsageProvider(
            fileSystemReader: StubFileSystemReader(attributes: [
                .systemSize: NSNumber(value: 1000),
                .systemFreeSize: NSNumber(value: 250)
            ]),
            pathProvider: { "/" }
        )

        let snapshot = subject.readDiskUsage()

        #expect(snapshot == UsageSnapshot(usedBytes: 750, totalBytes: 1000))
    }
}

private struct StubFileSystemReader: FileSystemAttributesReading {
    let attributes: [FileAttributeKey: Any]

    func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
        attributes
    }
}
