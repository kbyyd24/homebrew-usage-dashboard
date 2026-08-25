import Foundation

enum JSTokenKind: Equatable {
    case keyword
    case string
    case comment
    case number
    case identifier
    case punctuation
    case whitespace
    case other
}

struct JSToken: Equatable {
    let kind: JSTokenKind
    let text: String
    let range: Range<String.Index>
}

/// A small JavaScript lexer good enough for short extractor scripts (function
/// bodies returning objects). It covers keywords, strings, comments, numbers,
/// identifiers, and punctuation, and records each token's source range so the
/// highlighter can color it and the formatter can re-indent safely.
enum JSTokenizer {
    private static let keywords: Set<String> = [
        "function", "return", "var", "let", "const", "if", "else", "for",
        "while", "do", "switch", "case", "break", "continue", "new", "delete",
        "typeof", "instanceof", "in", "of", "this", "true", "false", "null",
        "undefined", "try", "catch", "finally", "throw", "class", "extends",
        "super", "default",
    ]

    static func tokenize(_ source: String) -> [JSToken] {
        var tokens: [JSToken] = []
        var idx = source.startIndex

        func peek(after i: String.Index) -> Character? {
            let next = source.index(after: i)
            return next < source.endIndex ? source[next] : nil
        }

        func isIdentStart(_ c: Character) -> Bool { c.isLetter || c == "_" || c == "$" }
        func isIdentPart(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" || c == "$" }

        func emit(_ kind: JSTokenKind, _ range: Range<String.Index>) {
            tokens.append(JSToken(kind: kind, text: String(source[range]), range: range))
        }

        while idx < source.endIndex {
            let start = idx
            let c = source[idx]

            if c.isWhitespace {
                while idx < source.endIndex && source[idx].isWhitespace {
                    idx = source.index(after: idx)
                }
                emit(.whitespace, start..<idx)
                continue
            }

            if c == "/" && peek(after: idx) == "/" {
                while idx < source.endIndex && source[idx] != "\n" {
                    idx = source.index(after: idx)
                }
                emit(.comment, start..<idx)
                continue
            }

            if c == "/" && peek(after: idx) == "*" {
                idx = source.index(after: idx)
                idx = source.index(after: idx)
                while idx < source.endIndex {
                    if source[idx] == "*" && peek(after: idx) == "/" {
                        idx = source.index(after: idx)
                        idx = source.index(after: idx)
                        break
                    }
                    idx = source.index(after: idx)
                }
                emit(.comment, start..<idx)
                continue
            }

            if c == "'" || c == "\"" || c == "`" {
                let quote = c
                idx = source.index(after: idx)
                while idx < source.endIndex {
                    let ch = source[idx]
                    if ch == "\\" {
                        idx = source.index(after: idx)
                        if idx < source.endIndex { idx = source.index(after: idx) }
                        continue
                    }
                    if ch == quote {
                        idx = source.index(after: idx)
                        break
                    }
                    idx = source.index(after: idx)
                }
                emit(.string, start..<idx)
                continue
            }

            if c.isNumber || (c == "." && peek(after: idx).map { $0.isNumber } == true) {
                while idx < source.endIndex {
                    let ch = source[idx]
                    if ch.isNumber { idx = source.index(after: idx); continue }
                    if ch == "." || ch == "e" || ch == "E" {
                        idx = source.index(after: idx)
                        if idx < source.endIndex && (source[idx] == "+" || source[idx] == "-") {
                            idx = source.index(after: idx)
                        }
                        continue
                    }
                    break
                }
                emit(.number, start..<idx)
                continue
            }

            if isIdentStart(c) {
                while idx < source.endIndex && isIdentPart(source[idx]) {
                    idx = source.index(after: idx)
                }
                let word = String(source[start..<idx])
                emit(keywords.contains(word) ? .keyword : .identifier, start..<idx)
                continue
            }

            // punctuation: single character
            idx = source.index(after: idx)
            emit(.punctuation, start..<idx)
        }
        return tokens
    }
}
