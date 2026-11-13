#if TEXTUAL_ENABLE_TEXT_SELECTION && os(iOS) && !targetEnvironment(macCatalyst)
  import SnapshotTesting
  import SwiftUI

  @testable import Textual

  extension Snapshotting where Value: SwiftUI.View, Format == String {
    @MainActor
    static func textLayoutCollection(config: ViewImageConfig = .iPhoneSe) -> Snapshotting {
      return Snapshotting<CodableTextLayoutCollection, String>.json
        .asyncPullback { (view: Value) -> Async<CodableTextLayoutCollection> in
          Async { callback in
            // Capture layout from view
            var capturedLayoutCollection: (any TextLayoutCollection)?
            let viewWithCapture = view.overlayTextLayoutCollection { layoutCollection in
              capturedLayoutCollection = layoutCollection
              return Color.clear
            }

            let size = config.size ?? CGSize(width: 375, height: 667)
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            let host = UIHostingController(rootView: viewWithCapture)
            let container = UIViewController()
            container.addChild(host)
            container.view.addSubview(host.view)
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.didMove(toParent: container)
            container.setOverrideTraitCollection(config.traits, forChild: host)
            window.rootViewController = container
            container.view.frame = window.bounds
            host.view.frame = container.view.bounds
            window.makeKeyAndVisible()
            window.layoutIfNeeded()

            // Drawing hands the fragments' layouts to the selection (see `TextLayoutBox`)
            for _ in 0..<10 {
              UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
              }
              RunLoop.main.run(until: Date().addingTimeInterval(0.05))
              window.layoutIfNeeded()
            }
            guard let capturedLayoutCollection else {
              preconditionFailure("Failed to capture layout data")
            }
            window.isHidden = true
            callback(CodableTextLayoutCollection(capturedLayoutCollection))
          }
        }
    }
  }
#endif
