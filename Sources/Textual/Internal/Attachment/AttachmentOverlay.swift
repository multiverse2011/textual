import SwiftUI

// MARK: - Overview
//
// `AttachmentOverlay` renders attachment views using resolved `Text.Layout` geometry.
//
// It’s applied at the text fragment level. The fragment's layout is captured into a
// `TextLayoutBox`; this modifier installs an `AttachmentView` that draws attachments at their run
// bounds. Fragments without attachments get no overlay.

struct AttachmentOverlay: ViewModifier {
  private let attachments: Set<AnyAttachment>
  private let layoutBox: TextLayoutBox

  init(attachments: Set<AnyAttachment>, layoutBox: TextLayoutBox) {
    self.attachments = attachments
    self.layoutBox = layoutBox
  }

  func body(content: Content) -> some View {
    content
      .overlay {
        if !attachments.isEmpty, let layout = layoutBox.layout {
          AttachmentView(
            attachments: attachments,
            origin: layoutBox.layoutOrigin,
            layout: layout
          )
        }
      }
  }
}
