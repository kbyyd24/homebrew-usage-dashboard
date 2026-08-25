import AppKit
import SwiftUI

/// A native code editor for the extractor script: an `NSTextView` wrapped in an
/// `NSScrollView`, with JavaScript syntax highlighting applied on text change.
/// Size is controlled by the caller with `.frame(width:height:)`.
struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CodeScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        textView.string = text
        scrollView.documentView = textView

        context.coordinator.highlight(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.highlight(textView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            highlight(textView)
        }

        func highlight(_ textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let source = textView.string
            let fullRange = NSRange(location: 0, length: source.utf16.count)

            storage.beginEditing()
            storage.setAttributes(
                [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor.textColor,
                ],
                range: fullRange
            )
            for token in JSTokenizer.tokenize(source) {
                guard let color = JSSyntaxHighlighter.color(for: token.kind) else { continue }
                storage.addAttribute(.foregroundColor, value: color, range: NSRange(token.range, in: source))
            }
            storage.endEditing()
        }
    }
}

private final class CodeScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let textView = documentView as? NSTextView else { return }
        let size = contentSize

        // Standard NSTextView-in-NSScrollView sizing: width tracks the container,
        // height grows with content so the scroll view scrolls when it overflows.
        textView.minSize = NSSize(width: 0, height: size.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: size.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.frame.size.width = size.width
    }
}
