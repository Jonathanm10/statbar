import Foundation

public protocol DiskUsageProviding {
    func readDiskUsage() -> UsageSnapshot?
}

protocol FileSystemAttributesReading {
    func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey: Any]
}

extension FileManager: FileSystemAttributesReading {}

public final class DiskUsageProvider: DiskUsageProviding {
    private let fileSystemReader: FileSystemAttributesReading
    private let pathProvider: () -> String

    public convenience init() {
        self.init(fileSystemReader: FileManager.default, pathProvider: { NSHomeDirectory() })
    }

    init(fileSystemReader: FileSystemAttributesReading, pathProvider: @escaping () -> String) {
        self.fileSystemReader = fileSystemReader
        self.pathProvider = pathProvider
    }

    public func readDiskUsage() -> UsageSnapshot? {
        do {
            let attributes = try fileSystemReader.attributesOfFileSystem(forPath: pathProvider())
            guard
                let totalBytes = (attributes[.systemSize] as? NSNumber)?.uint64Value,
                let freeBytes = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value
            else {
                return nil
            }

            let usedBytes = totalBytes >= freeBytes ? totalBytes - freeBytes : 0
            return UsageSnapshot(usedBytes: usedBytes, totalBytes: totalBytes)
        } catch {
            return nil
        }
    }
}
