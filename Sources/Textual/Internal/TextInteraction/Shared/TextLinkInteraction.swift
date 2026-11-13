import SwiftUI

// MARK: - Overview
//
// `TextLinkInteraction` adds lightweight link tapping to a `Text` fragment.
//
// The fragment's resolved `Text.Layout` comes from its `TextLayoutBox`. On a tap, this modifier
// converts the location to layout coordinates and looks for the first run whose typographic
// bounds contains it. When a run has a `url`, the modifier invokes the environment’s `openURL` action.

struct TextLinkInteraction: ViewModifier {
  @Environment(\.openURL) private var openURL

  let layoutBox: TextLayoutBox

  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_LINKS
      content
        .overlay {
          Color.clear
            .contentShape(.rect)
            .gesture(tap)
        }
    #else
      content
    #endif
  }

  #if TEXTUAL_ENABLE_LINKS
    private var tap: some Gesture {
      SpatialTapGesture()
        .onEnded { value in
          guard let layout = layoutBox.layout else {
            return
          }
          let localPoint = CGPoint(
            x: value.location.x - layoutBox.layoutOrigin.x,
            y: value.location.y - layoutBox.layoutOrigin.y
          )
          let runs = layout.flatMap(\.self)
          let run = runs.first { run in
            run.typographicBounds.rect.contains(localPoint)
          }
          guard let url = run?.url else {
            return
          }
          openURL(url)
        }
    }
  #endif
}
