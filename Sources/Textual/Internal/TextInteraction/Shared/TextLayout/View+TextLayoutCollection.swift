#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  // MARK: - Overview
  //
  // `overlayTextLayoutCollection` adapts the fragments' `TextLayoutBox` values into a
  // `TextLayoutCollection` that the selection system can query.
  //
  // Each box holds a fragment's layout and its origin in this view's coordinate space
  // (`.textSelectionScope`), so the collection does not depend on where this view is on screen
  // and is not rebuilt while it scrolls. Platform interactions and selection rendering use the
  // collection for hit testing, position mapping, and selection rectangle computation.

  extension View {
    func overlayTextLayoutCollection(
      @ViewBuilder content: @escaping (any TextLayoutCollection) -> some View
    ) -> some View {
      coordinateSpace(.textSelectionScope)
        .overlayPreferenceValue(TextLayoutBoxKey.self) { boxes in
          TextLayoutCollectionReader(boxes: boxes, content: content)
        }
    }
  }

  // Reads the boxes in `body` so that the collection is rebuilt when a layout or origin changes.
  private struct TextLayoutCollectionReader<Content: View>: View {
    let boxes: [TextLayoutBox]
    let content: (any TextLayoutCollection) -> Content

    var body: some View {
      content(LiveTextLayoutCollection(boxes: boxes))
    }
  }
#endif
