import DrivingTrainerDomain
import Foundation

public enum JSONStoreError: Error, Equatable {
    case invalidFilename
}

public actor JSONStore<Value: Codable & Sendable> {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL, filename: String) throws {
        guard !filename.isEmpty,
              filename == URL(fileURLWithPath: filename).lastPathComponent else {
            throw JSONStoreError.invalidFilename
        }

        self.fileURL = directory.appendingPathComponent(filename, isDirectory: false)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load(default defaultValue: @autoclosure () -> Value) throws -> Value {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return defaultValue()
        }
        return try decoder.decode(Value.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ value: Value) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(value)
        try data.write(to: fileURL, options: .atomic)
    }
}
