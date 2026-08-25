import Foundation
import Testing
@testable import UsageDashboard

private func kind(of text: String, in source: String) -> JSTokenKind? {
    JSTokenizer.tokenize(source).first { $0.text == text }?.kind
}

@Test func tokenizerRecognizesKeywordsStringsCommentsNumbers() {
    let source = "function(r) {\n  // note\n  var a = 'x';\n  return { n: 42, ok: true };\n}"
    let tokens = JSTokenizer.tokenize(source)

    #expect(kind(of: "function", in: source) == .keyword)
    #expect(kind(of: "var", in: source) == .keyword)
    #expect(kind(of: "return", in: source) == .keyword)
    #expect(kind(of: "'x'", in: source) == .string)
    #expect(kind(of: "// note", in: source) == .comment)
    #expect(kind(of: "42", in: source) == .number)
    #expect(kind(of: "n", in: source) == .identifier)
    #expect(tokens.map(\.text).joined() == source)
}

@Test func formatterIndentsFunctionReturningObject() {
    let input = "function(r){ return { status: 'ok', rows: [1, 2, 3] }; }"

    let output = JSFormatter.format(input, indentSize: 2)

    #expect(output == """
    function(r) {
      return {
        status: 'ok',
        rows: [
          1,
          2,
          3
        ]
      };
    }
    """)
}

@Test func formatterPreservesCommentsAndStringWithBraces() {
    let input = "function(r){ return { s: 'a {b} c' }; } // end"

    let output = JSFormatter.format(input, indentSize: 2)

    #expect(output.contains("'a {b} c'"))
    #expect(output.contains("// end"))
}

@Test func formatterKeepsFunctionCallArgsOnOneLine() {
    let input = "function(r){ return make('a', 'b'); }"

    let output = JSFormatter.format(input, indentSize: 2)

    #expect(output.contains("make('a', 'b')"))
}

@Test func formatIsIdempotent() {
    let input = "function(r){ var w = response.windowLimits; return { status: 'ok', message: '', rows: w }; }"
    let once = JSFormatter.format(input)
    let twice = JSFormatter.format(once)

    #expect(twice == once)
}
