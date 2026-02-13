//
//  MathFirstMarkdownViewRenderer.swift
//  MarkdownView
//
//  Created by Yanan Li on 2025/4/12.
//

import SwiftUI
import Markdown

struct MathFirstMarkdownViewRenderer: MarkdownViewRenderer {
    func makeBody(
        content: MarkdownContent,
        configuration: MarkdownRendererConfiguration
    ) -> some View {
        var configuration = configuration
        var rawText = content.raw.text
        
        // Collect all display math ranges first without modifying rawText.
        // The original code modified rawText inside the loop over pre-computed
        // String.Index ranges, which invalidated subsequent indices and caused
        // "Fatal error: String index is out of bounds".
        var mathOccurrences: [(utf8Start: Int, utf8End: Int)] = []
        
        var extractor = ParsingRangesExtractor()
        extractor.visit(content.parse(options: ParseOptions().union(.parseBlockDirectives)))
        for range in extractor.parsableRanges(in: rawText) {
            let segment = rawText[range]
            let segmentParser = MathParser(text: segment)
            for math in segmentParser.mathRepresentations where !math.kind.inline {
                // Store UTF-8 byte offsets instead of String.Index so they
                // remain valid across rawText mutations.
                let utf8Start = rawText.utf8.distance(
                    from: rawText.utf8.startIndex, to: math.range.lowerBound
                )
                let utf8End = rawText.utf8.distance(
                    from: rawText.utf8.startIndex, to: math.range.upperBound
                )
                mathOccurrences.append((utf8Start: utf8Start, utf8End: utf8End))
            }
        }
        
        // Replace from back to front so earlier byte offsets stay valid.
        for occurrence in mathOccurrences.sorted(by: { $0.utf8Start > $1.utf8Start }) {
            let startIdx = rawText.utf8.index(
                rawText.utf8.startIndex, offsetBy: occurrence.utf8Start
            )
            let endIdx = rawText.utf8.index(
                rawText.utf8.startIndex, offsetBy: occurrence.utf8End
            )
            guard let start = startIdx.samePosition(in: rawText),
                  let end = endIdx.samePosition(in: rawText) else { continue }
            
            let mathIdentifier = configuration.math.appendDisplayMath(
                rawText[start..<end]
            )
            rawText.replaceSubrange(
                start..<end,
                with: "@math(uuid:\(mathIdentifier))"
            )
        }
        
        let _content = MarkdownContent(raw: .plainText(rawText))
        return CmarkFirstMarkdownViewRenderer()
            .makeBody(content: _content, configuration: configuration)
    }
}
