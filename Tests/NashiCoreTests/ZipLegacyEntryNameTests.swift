import XCTest
import Foundation
@testable import NashiCore

final class ZipLegacyEntryNameTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws { root = try OutputFiles.temporaryDirectory() }
    override func tearDownWithError() throws { if let root { try? FileManager.default.removeItem(at: root) } }

    /// Windows Explorer and older ZIP tools store names in the DOS code page
    /// without the UTF-8 flag; "résumé.txt" is 72 82 73 75 6D 82 in CP437.
    func testNamesWithoutTheUTF8FlagAreExtracted() throws {
        let input = root.appendingPathComponent("Windows.zip")
        try zip(name: [0x72, 0x82, 0x73, 0x75, 0x6d, 0x82, 0x2e, 0x74, 0x78, 0x74]).write(to: input)
        let output = root.appendingPathComponent("Extracted", isDirectory: true)
        try ArchiveCodec.extract(input, into: output, token: .init())
        let names = try FileManager.default.contentsOfDirectory(atPath: output.path).map(\.precomposedStringWithCanonicalMapping)
        XCTAssertEqual(names, ["résumé.txt"])
        XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent(names[0])), Data("hello".utf8))
    }

    private func zip(name: [UInt8]) -> Data {
        func u16(_ value: Int) -> [UInt8] { [UInt8(value & 0xff), UInt8(value >> 8 & 0xff)] }
        func u32(_ value: UInt32) -> [UInt8] { u16(Int(value & 0xffff)) + u16(Int(value >> 16)) }
        let content = Array("hello".utf8), crc: UInt32 = 0x3610a686
        // Version 2.0, no flags (so no UTF-8 name), stored, DOS time and date.
        let common = u16(20) + u16(0) + u16(0) + u16(0) + u16(0x21) + u32(crc) + u32(UInt32(content.count)) + u32(UInt32(content.count)) + u16(name.count) + u16(0)
        let local = [0x50, 0x4b, 0x03, 0x04] + common + name + content
        let central = [0x50, 0x4b, 0x01, 0x02] + u16(20) + common + u16(0) + u16(0) + u16(0) + u32(0) + u32(0) + name
        let end = [0x50, 0x4b, 0x05, 0x06] + u16(0) + u16(0) + u16(1) + u16(1) + u32(UInt32(central.count)) + u32(UInt32(local.count)) + u16(0)
        return Data(local + central + end)
    }
}
