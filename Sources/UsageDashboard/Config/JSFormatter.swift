import Foundation

/// Re-indents a JavaScript snippet using a token-aware, conservative algorithm.
/// It never touches the inside of strings or comments (they are kept verbatim),
/// and it breaks/groups lines around `{` / `}` / `;` / `,`. It is tuned for
/// short extractor scripts rather than a full general-purpose prettifier.
enum JSFormatter {
    static func format(_ source: String, indentSize: Int = 2) -> String {
        let tokens = JSTokenizer.tokenize(source)
        var lines: [String] = []
        var line = ""
        var depth = 0
        var openers: [Character] = []

        func indentation() -> String {
            String(repeating: " ", count: depth * indentSize)
        }

        // Remove only trailing whitespace, preserving the leading indentation.
        func trimTrailing(_ s: String) -> String {
            String(s.reversed().drop(while: { $0.isWhitespace }).reversed())
        }

        func flush() {
            let trimmed = trimTrailing(line)
            if !trimmed.isEmpty { lines.append(trimmed) }
            line = ""
        }

        func beginLineIfNeeded() {
            if line.isEmpty { line += indentation() }
        }

        func appendWithSpace(_ text: String) {
            beginLineIfNeeded()
            if !line.isEmpty && !line.hasSuffix(" ") && !line.hasSuffix("(") && !line.hasSuffix("[") && !line.hasSuffix("{") && !line.hasSuffix(".") {
                line += " "
            }
            line += text
        }

        for token in tokens {
            switch token.kind {
            case .whitespace:
                if !line.isEmpty && !line.hasSuffix(" ") { line += " " }

            case .comment:
                if !trimTrailing(line).isEmpty { flush() }
                line += indentation() + token.text
                flush()

            case .punctuation:
                if let ch = token.text.first {
                    switch ch {
                    case "{":
                        if !trimTrailing(line).isEmpty {
                            line = trimTrailing(line) + " {"
                        } else {
                            line += indentation() + "{"
                        }
                        openers.append("{")
                        depth += 1
                        flush()

                    case "}":
                        flush()
                        depth = max(0, depth - 1)
                        if openers.last == "{" { openers.removeLast() }
                        line = indentation() + "}"

                    case "[":
                        beginLineIfNeeded()
                        if !line.hasSuffix("[") { line += "[" }
                        openers.append("[")
                        depth += 1
                        flush()

                    case "]":
                        if openers.last == "[" { openers.removeLast() }
                        flush()
                        depth = max(0, depth - 1)
                        line = indentation() + "]"

                    case "(":
                        beginLineIfNeeded()
                        openers.append("(")
                        line += "("

                    case ")":
                        if openers.last == "(" { openers.removeLast() }
                        line += ")"

                    case ";":
                        line = trimTrailing(line) + ";"
                        flush()

                    case ",":
                        line = trimTrailing(line) + ","
                        if let top = openers.last, top == "{" || top == "[" {
                            flush()
                        } else {
                            line += " "
                        }

                    case ":":
                        line = trimTrailing(line) + ": "

                    default:
                        beginLineIfNeeded()
                        line += token.text
                    }
                }

            default:
                appendWithSpace(token.text)
            }
        }
        flush()
        return lines.joined(separator: "\n")
    }
}
