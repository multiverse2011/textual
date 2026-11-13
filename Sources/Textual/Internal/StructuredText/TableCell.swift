import SwiftUI

extension StructuredText {
  struct TableCell: View {
    @Environment(\.tableCellStyle) private var tableCellStyle
    @State private var bounds: CGRect?

    private let content: AttributedSubstring
    private let identifier: TableCell.Identifier

    init(_ content: AttributedSubstring, row: Int, column: Int) {
      self.content = content
      self.identifier = .init(row: row, column: column)
    }

    var body: some View {
      let configuration = TableCellStyleConfiguration(
        label: .init(label),
        indentationLevel: indentationLevel,
        row: identifier.row,
        column: identifier.column
      )
      let resolvedStyle =
        tableCellStyle
        .resolve(configuration: configuration)
        // Measured in the table's coordinate space, so scrolling the table does not change it
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .textTable) }) {
          bounds = $0
        }
        .preference(key: BoundsKey.self, value: bounds.map { [identifier: $0] } ?? [:])

      AnyView(resolvedStyle)
    }

    private var label: some View {
      WithInlineStyle(AttributedString(content)) {
        TextFragment($0)
      }
    }

    private var indentationLevel: Int {
      content.presentationIntent?.indentationLevel ?? 0
    }
  }
}

extension StructuredText.TableCell {
  struct Identifier: Hashable {
    let row: Int
    let column: Int
  }

  struct BoundsKey: PreferenceKey {
    static let defaultValue: [Identifier: CGRect] = [:]

    static func reduce(
      value: inout [Identifier: CGRect],
      nextValue: () -> [Identifier: CGRect]
    ) {
      value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
  }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  static var textTable: NamedCoordinateSpace {
    .named("textTable")
  }
}

extension StructuredText.TableCell {
  struct Spacing: Sendable, Hashable {
    let horizontal: CGFloat?
    let vertical: CGFloat?

    init(horizontal: CGFloat? = nil, vertical: CGFloat? = nil) {
      self.horizontal = horizontal
      self.vertical = vertical
    }
  }

  struct SpacingKey: PreferenceKey {
    static let defaultValue = Spacing()

    static func reduce(value: inout Spacing, nextValue: () -> Spacing) {
      value = nextValue()
    }
  }
}
