import SwiftUI

struct ColorPickerGrid: View {
    @Binding var selectedColor: String

    private let columns = [
        GridItem(.adaptive(minimum: 44), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SectionColor.allCases) { sectionColor in
                Button {
                    selectedColor = sectionColor.rawValue
                } label: {
                    ZStack {
                        Circle()
                            .fill(sectionColor.color)
                            .frame(width: 40, height: 40)

                        if selectedColor == sectionColor.rawValue {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sectionColor.displayName)
            }
        }
    }
}

#Preview {
    @Previewable @State var color = "blue"
    ColorPickerGrid(selectedColor: $color)
        .padding()
}
