import SwiftUI

struct CameraDetailView: View {
    let snapshot: CameraSnapshot

    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                Image(uiImage: snapshot.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: geometry.size.width * scale,
                        height: geometry.size.height * scale
                    )
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = max(1.0, min(value.magnification, 5.0))
                            }
                            .onEnded { _ in
                                withAnimation(.spring) {
                                    if scale < 1.2 {
                                        scale = 1.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring) {
                            scale = scale > 1.0 ? 1.0 : 2.5
                        }
                    }
            }
        }
        .navigationTitle(snapshot.cameraName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                VStack(spacing: 2) {
                    Text(snapshot.brand.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Last updated: \(snapshot.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
