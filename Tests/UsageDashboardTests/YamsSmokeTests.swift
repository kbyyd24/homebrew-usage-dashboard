import Foundation
import Testing
import Yams

private struct SmokeDoc: Codable, Equatable {
    let defaultIntervalSec: Int
    let providers: [String]
}

private struct ScalarDoc: Codable, Equatable {
    let script: String
}

@Test func yamsEncodesAndDecodesCodableValue() throws {
    // Given
    let doc = SmokeDoc(defaultIntervalSec: 600, providers: ["kimi", "minimax"])

    // When
    let yaml = try YAMLEncoder().encode(doc)
    let decoded = try YAMLDecoder().decode(SmokeDoc.self, from: yaml)

    // Then
    #expect(yaml.contains("defaultIntervalSec"))
    #expect(decoded == doc)
}

@Test func yamsLiteralBlockScalarPreservesMultilineString() throws {
    // Given a multi-line string
    let script = "function(r){\n  return r.rows;\n}"

    // When encoding with literal block scalars enabled
    let encoder = YAMLEncoder()
    encoder.options.newLineScalarStyle = .literal
    let yaml = try encoder.encode(ScalarDoc(script: script))
    let decoded = try YAMLDecoder().decode(ScalarDoc.self, from: yaml)

    // Then the output uses a literal block and round-trips exactly
    #expect(yaml.contains("|"))
    #expect(decoded.script == script)
}
