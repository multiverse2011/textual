import ConcurrencyExtras
import SwiftUI

// MARK: - Overview
//
// `TextLayoutBox` holds the resolved `Text.Layout` of one `TextFragment`.
//
// Reading `Text.LayoutKey` makes SwiftUI resolve the layout again (and re-run every reader of it)
// whenever the text moves, which happens on every frame while an enclosing scroll view scrolls.
// Instead, `TextLayoutCapture` receives the layout when SwiftUI draws the text and stores it here.
//
// The drawn layout is in fragment-local coordinates, except when glyphs overflow the text (for
// example, some Arabic text): SwiftUI then draws into an enlarged area and the layout is offset
// by that margin, which the renderer cannot see. Such fragments fall back to reading
// `Text.LayoutKey` (see `AnchoredLayoutFallback`), which gives `layoutOrigin` precisely.
//
// `layoutOrigin` is the layout's origin in fragment coordinates. `origin` is the fragment's origin
// in the enclosing selection scope, updated only when it changes relative to that scope (not when
// the whole scope scrolls).

@MainActor @Observable
final class TextLayoutBox {
  private(set) var layout: Text.Layout?
  private(set) var layoutOrigin: CGPoint = .zero
  private(set) var usesAnchoredLayout = false
  var origin: CGPoint = .zero

  private nonisolated let captured = LockIsolated(Captured())

  private struct Captured: @unchecked Sendable {
    var layout: Text.Layout?
    var usesAnchoredLayout = false
  }

  // Called while SwiftUI draws the text, possibly off the main thread.
  nonisolated func capture(_ layout: Text.Layout) {
    let layout = UncheckedSendable(layout)
    let update: (@MainActor () -> Void)? = captured.withValue { captured in
      guard !captured.usesAnchoredLayout, captured.layout != layout.value else {
        return nil
      }
      captured.layout = layout.value
      if layout.value.isOffsetByDrawingMargin {
        captured.usesAnchoredLayout = true
        return { self.usesAnchoredLayout = true }
      }
      return { self.layout = layout.value }
    }
    guard let update else { return }

    // On the main run loop rather than the main queue, so that it also runs while a block on the
    // main queue spins a nested run loop
    let main = CFRunLoopGetMain()
    CFRunLoopPerformBlock(main, CFRunLoopMode.commonModes.rawValue) {
      MainActor.assumeIsolated(update)
    }
    CFRunLoopWakeUp(main)
  }

  func setAnchoredLayout(_ layout: Text.Layout, origin: CGPoint) {
    self.layout = layout
    self.layoutOrigin = origin
  }
}

extension Text.Layout {
  // In fragment coordinates, the lines start at the leading edge and the top. Allow up to half
  // a point for rounding.
  fileprivate var isOffsetByDrawingMargin: Bool {
    let bounds = map(\.typographicBounds.rect).reduce(CGRect.null, CGRectUnion)
    return !bounds.isNull && (bounds.minX > 0.5 || bounds.minY > 0.5)
  }
}

struct TextLayoutCapture: TextRenderer {
  let box: TextLayoutBox

  func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
    for line in layout {
      ctx.draw(line)
    }
    box.capture(layout)
  }
}

// Reads `Text.LayoutKey` for fragments whose drawn layout is offset (see `TextLayoutBox`). This
// costs a layout query on every frame while the fragment scrolls, so it is limited to them.
struct AnchoredLayoutFallback: ViewModifier {
  let layoutBox: TextLayoutBox

  func body(content: Content) -> some View {
    if layoutBox.usesAnchoredLayout {
      content
        .overlayPreferenceValue(Text.LayoutKey.self) { value in
          if let anchoredLayout = value.first {
            GeometryReader { geometry in
              let layout = AnchoredLayout(
                layout: anchoredLayout.layout,
                origin: geometry[anchoredLayout.origin]
              )
              Color.clear
                .onChange(of: layout, initial: true) {
                  layoutBox.setAnchoredLayout(layout.layout, origin: layout.origin)
                }
            }
          }
        }
    } else {
      content
    }
  }

  private struct AnchoredLayout: Equatable {
    let layout: Text.Layout
    let origin: CGPoint
  }
}

// Collects the fragments of a selection scope in view order.
struct TextLayoutBoxKey: PreferenceKey {
  static let defaultValue: [TextLayoutBox] = []

  static func reduce(value: inout [TextLayoutBox], nextValue: () -> [TextLayoutBox]) {
    value.append(contentsOf: nextValue())
  }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  static var textSelectionScope: NamedCoordinateSpace {
    .named("textSelectionScope")
  }
}
