#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  // MARK: - Overview
  //
  // `TextSelectionModel` is the shared state object that backs selection and interaction.
  //
  // Platform views (AppKit/UIKit) mutate `selectedRange` in response to gestures and editing
  // commands. The model delegates layout-specific work to a `TextLayoutCollection`, which can be
  // rebuilt at any time as SwiftUI resolves new `Text.Layout` values. When the layout collection
  // changes, the model attempts to reconcile the current selection into the new layout so the
  // selection stays stable across updates.

  @Observable
  final class TextSelectionModel {
    var selectedRange: TextRange? {
      willSet {
        selectionWillChange?()
      }
      didSet {
        if selectedRange != nil {
          coordinator?.modelDidSelectText(self)
        }
        selectionDidChange?()
      }
    }

    @ObservationIgnored
    var selectionWillChange: (() -> Void)?

    @ObservationIgnored
    var selectionDidChange: (() -> Void)?

    @ObservationIgnored
    private var layoutCollection: any TextLayoutCollection

    @ObservationIgnored
    private weak var coordinator: TextSelectionCoordinator?

    init(
      layoutCollection: any TextLayoutCollection = EmptyTextLayoutCollection(),
      coordinator: TextSelectionCoordinator? = nil
    ) {
      self.layoutCollection = layoutCollection
      setCoordinator(coordinator)
    }

    func setLayoutCollection(_ layoutCollection: any TextLayoutCollection) {
      guard !layoutCollection.isEqual(to: self.layoutCollection) else {
        return
      }

      let oldLayoutCollection = self.layoutCollection
      self.layoutCollection = layoutCollection

      guard
        let selectedRange,
        layoutCollection.needsPositionReconciliation(with: oldLayoutCollection)
      else {
        return
      }

      // Try to reconcile the selected text range
      self.selectedRange = layoutCollection.reconcileRange(
        selectedRange,
        from: oldLayoutCollection
      )
    }

    func setCoordinator(_ coordinator: TextSelectionCoordinator?) {
      if self.coordinator === coordinator {
        return
      }

      self.coordinator = coordinator
      coordinator?.register(self)
    }

    func url(for point: CGPoint) -> URL? {
      layoutCollection.url(for: point)
    }

    func layoutIndex(of layout: Text.Layout) -> Int? {
      layoutCollection.index(of: layout)
    }
  }

  extension TextSelectionModel {
    // UIKit and AppKit can hand back positions created before the layout collection was
    // rebuilt (for example, the edit menu is shown on a timer after a long press). Indexing
    // the new layouts with such a position traps, so treat it as invalid instead.
    private func isValid(_ position: TextPosition) -> Bool {
      layoutCollection.contains(position)
    }

    private func isValid(_ range: TextRange) -> Bool {
      isValid(range.start) && isValid(range.end)
    }

    var hasText: Bool {
      layoutCollection.stringLength > 0
    }

    var startPosition: TextPosition {
      layoutCollection.startPosition
    }

    var endPosition: TextPosition {
      layoutCollection.endPosition
    }

    func attributedText(in range: TextRange) -> NSAttributedString {
      guard isValid(range) else { return NSAttributedString() }
      return layoutCollection.attributedText(in: range)
    }

    func text(in range: TextRange) -> String {
      attributedText(in: range).string
    }

    func position(from position: TextPosition, offset: Int) -> TextPosition? {
      guard isValid(position) else { return nil }
      return layoutCollection.position(from: position, offset: offset)
    }

    func offset(from: TextPosition, to: TextPosition) -> Int {
      guard isValid(from), isValid(to) else { return 0 }
      return layoutCollection.characterIndex(at: to) - layoutCollection.characterIndex(at: from)
    }

    func firstRect(for range: TextRange) -> CGRect {
      guard isValid(range) else { return .zero }
      return layoutCollection.firstRect(for: range)
    }

    func caretRect(for position: TextPosition) -> CGRect {
      guard isValid(position) else { return .zero }
      return layoutCollection.caretRect(for: position)
    }

    func selectionRects(for range: TextRange) -> [TextSelectionRect] {
      guard isValid(range) else { return [] }
      return layoutCollection.selectionRects(for: range)
    }

    func selectionRects(for range: TextRange, layout: Text.Layout) -> [TextSelectionRect] {
      guard isValid(range) else { return [] }
      return layoutCollection.selectionRects(for: range, layout: layout)
    }

    func closestPosition(to point: CGPoint) -> TextPosition? {
      layoutCollection.closestPosition(to: point)
    }

    func closestPosition(to point: CGPoint, within range: TextRange) -> TextPosition? {
      guard let position = closestPosition(to: point) else { return nil }
      if position <= range.start { return range.start }
      if position >= range.end { return range.end }
      return position
    }

    func isPositionAtBlockBoundary(_ position: TextPosition) -> Bool {
      guard isValid(position) else { return false }
      return layoutCollection.isPositionAtBlockBoundary(position)
    }

    func positionAbove(_ position: TextPosition, anchor: TextPosition) -> TextPosition? {
      guard isValid(position), isValid(anchor) else { return nil }
      return layoutCollection.positionAbove(position, anchor: anchor)
    }

    func positionBelow(_ position: TextPosition, anchor: TextPosition) -> TextPosition? {
      guard isValid(position), isValid(anchor) else { return nil }
      return layoutCollection.positionBelow(position, anchor: anchor)
    }

    func characterRange(at point: CGPoint) -> TextRange? {
      layoutCollection.characterRange(at: point)
    }

    func blockStart(for position: TextPosition) -> TextPosition? {
      guard isValid(position) else { return nil }
      return layoutCollection.blockStart(for: position)
    }

    func blockEnd(for position: TextPosition) -> TextPosition? {
      guard isValid(position) else { return nil }
      return layoutCollection.blockEnd(for: position)
    }

    func blockRange(for position: TextPosition) -> TextRange? {
      guard isValid(position) else { return nil }
      return layoutCollection.blockRange(for: position)
    }

    @available(macOS 10.0, *)
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func wordRange(for position: TextPosition) -> TextRange? {
      guard isValid(position) else { return nil }
      return layoutCollection.wordRange(for: position)
    }

    @available(macOS 10.0, *)
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func nextWord(from position: TextPosition) -> TextPosition? {
      guard isValid(position) else { return nil }
      return layoutCollection.nextWord(from: position)
    }

    @available(macOS 10.0, *)
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func previousWord(from position: TextPosition) -> TextPosition? {
      guard isValid(position) else { return nil }
      return layoutCollection.previousWord(from: position)
    }
  }
#endif
