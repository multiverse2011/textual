import SwiftUI

// MARK: - Overview
//
// `TextSelectionBackground` draws selection highlights behind a `Text` fragment.
//
// The platform selection interaction stores a `TextSelectionModel` in the environment at fragment
// scope. This modifier reads the fragment’s `Text.Layout` from its `TextLayoutBox` and forwards it to the AppKit selection view so it can convert the
// current selected range into highlight rectangles.

struct TextSelectionBackground: ViewModifier {
  let layoutBox: TextLayoutBox

  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit) && !targetEnvironment(macCatalyst)
      content
        .background {
          if let layout = layoutBox.layout {
            AppKitTextSelectionView(layout: layout, origin: layoutBox.layoutOrigin)
          }
        }
    #else
      content
    #endif
  }
}
