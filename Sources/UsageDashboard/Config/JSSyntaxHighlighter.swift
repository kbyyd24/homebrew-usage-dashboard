import AppKit

enum JSSyntaxHighlighter {
    static func color(for kind: JSTokenKind) -> NSColor? {
        switch kind {
        case .keyword: return .systemPurple
        case .string: return .systemRed
        case .comment: return .systemGreen
        case .number: return .systemOrange
        case .punctuation: return .systemTeal
        // identifiers / whitespace / other keep the default text color
        case .identifier, .whitespace, .other: return nil
        }
    }
}
