#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  // A snapshot of the fragments' layouts and their origins in the selection scope.
  final class LiveTextLayoutCollection: TextLayoutCollection {
    private(set) lazy var layouts: [any TextLayout] = makeLayouts()

    private let base: [Text.Layout]
    private let origins: [CGPoint]

    @MainActor
    init(boxes: [TextLayoutBox]) {
      // Fragments that have not been drawn yet have no layout
      let boxes = boxes.filter { $0.layout != nil }
      self.base = boxes.compactMap(\.layout)
      self.origins = boxes.map { box in
        CGPoint(x: box.origin.x + box.layoutOrigin.x, y: box.origin.y + box.layoutOrigin.y)
      }
    }

    func isEqual(to other: any TextLayoutCollection) -> Bool {
      guard let other = other as? LiveTextLayoutCollection else { return false }
      return base == other.base && origins == other.origins
    }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool {
      // Same layouts with different origins do not need position reconciliation
      base != (other as? LiveTextLayoutCollection)?.base
    }

    func index(of layout: Text.Layout) -> Int? {
      base.firstIndex(of: layout)
    }

    private func makeLayouts() -> [any TextLayout] {
      zip(base, origins).map(LiveTextLayout.init)
    }
  }

  final class LiveTextLayout: TextLayout {
    var attributedString: NSAttributedString {
      joinedAttributedString.joined
    }

    let origin: CGPoint

    private(set) lazy var bounds: CGRect = makeBounds()
    private(set) lazy var lines: [any TextLine] = makeLines()

    let base: Text.Layout

    private lazy var contents = base.materializeContents()
    private lazy var joinedAttributedString = contents.attributedStrings.joined()

    init(base: Text.Layout, origin: CGPoint) {
      self.base = base
      self.origin = origin
    }

    private func makeBounds() -> CGRect {
      base.map(\.typographicBounds.rect)
        .reduce(CGRect.null, CGRectUnion)
    }

    private func makeLines() -> [any TextLine] {
      guard contents.attributedStrings.count > 1 else {
        return base.map {
          LiveTextLine(base: $0)
        }
      }

      // Get the offset mappings on the layout strings to maintain object identity
      let (_, characterOffsets) = contents.layoutAttributedStrings.joined()

      return zip(base, contents.lineFragments).compactMap { line, lineFragment in
        guard let offset = characterOffsets[.init(lineFragment.attributedString)] else {
          return nil
        }

        return LiveTextLine(base: line, offset: offset)
      }
    }
  }

  final class LiveTextLine: TextLine {
    var origin: CGPoint {
      base.origin
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    private(set) lazy var runs: [any TextRun] = makeRuns()

    let base: Text.Layout.Line
    let offset: Int

    init(base: Text.Layout.Line, offset: Int = 0) {
      self.base = base
      self.offset = offset
    }

    private func makeRuns() -> [any TextRun] {
      if base.isEmpty {
        // Return a newline run for empty lines
        return [
          EmptyRun(
            typographicBounds: base.typographicBounds.rect,
            slice: .init(
              typographicBounds: base.typographicBounds.rect,
              characterRange: offset..<(offset + 1)
            )
          )
        ]
      } else {
        return base.map { run in
          LiveTextRun(base: run, offset: offset)
        }
      }
    }
  }

  final class LiveTextRun: TextRun {
    var layoutDirection: LayoutDirection {
      base.layoutDirection
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    var url: URL? {
      base.url
    }

    private(set) lazy var slices: [any TextRunSlice] = makeRunSlices()

    let base: Text.Layout.Run
    let offset: Int

    init(base: Text.Layout.Run, offset: Int) {
      self.base = base
      self.offset = offset
    }

    private func makeRunSlices() -> [any TextRunSlice] {
      zip(base, base.characterRanges).map { slice, characterRange in
        LiveTextRunSlice(
          base: slice,
          characterRange: characterRange.offset(by: offset)
        )
      }
    }
  }

  struct EmptyRun: TextRun {
    let layoutDirection: LayoutDirection = .localeBased()
    let typographicBounds: CGRect
    let url: URL? = nil
    let slice: EmptyRunSlice

    var slices: [any TextRunSlice] {
      [slice]
    }
  }

  final class LiveTextRunSlice: TextRunSlice {
    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    let characterRange: Range<Int>
    let base: Text.Layout.RunSlice

    init(base: Text.Layout.RunSlice, characterRange: Range<Int>) {
      self.base = base
      self.characterRange = characterRange
    }
  }

  struct EmptyRunSlice: TextRunSlice {
    let typographicBounds: CGRect
    let characterRange: Range<Int>
  }
#endif
