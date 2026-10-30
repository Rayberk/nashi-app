import XCTest
import Foundation
@testable import NashiCore

final class PagesDOCXHighlightTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws { root = try OutputFiles.temporaryDirectory() }
    override func tearDownWithError() throws { if let root { try? FileManager.default.removeItem(at: root) } }

    /// w:highlight only takes named colours (ST_HighlightColor), never hex.
    func testNamedWordHighlightsBecomePagesBackgroundColors() throws {
        let runs = ["yellow", "darkBlue", "none"].map { "<w:r><w:rPr><w:highlight w:val=\"\($0)\"/></w:rPr><w:t>\($0)</w:t></w:r>" }.joined()
        let model = try pages("<w:p>\(runs)</w:p>")
        let blocks = try XCTUnwrap(model["blocks"] as? [[String: Any]])
        var colors: [String: [Double]] = [:]
        for run in blocks.flatMap({ $0["runs"] as? [[String: Any]] ?? [] }) {
            guard let text = run["text"] as? String, let color = (run["character"] as? [String: Any])?["backgroundColor"] as? [String: Any] else { continue }
            colors[text] = ["r", "g", "b"].map { ((color[$0] as? NSNumber)?.doubleValue ?? -1) * 255 }.map { $0.rounded() }
        }
        XCTAssertEqual(colors, ["yellow": [255, 255, 0], "darkBlue": [0, 0, 128]])
    }

    private func pages(_ body: String) throws -> [String: Any] {
        let package = root.appendingPathComponent("Package", isDirectory: true)
        let word = package.appendingPathComponent("word", isDirectory: true)
        try FileManager.default.createDirectory(at: word, withIntermediateDirectories: true)
        try "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\(body)</w:body></w:document>".write(to: word.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)
        let input = root.appendingPathComponent("Highlight.docx")
        try ArchiveCodec.create(from: package, at: input, format: "zip", token: .init())
        let output = root.appendingPathComponent("Highlight.pages")
        try PagesCodec.create(fromDOCX: input, at: output, token: .init())
        return try PagesCodec.model(output, token: .init())
    }
}
